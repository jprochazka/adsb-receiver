#!/usr/bin/env python3
"""
Seed development RRD databases with 7 days of realistic ADS-B / UAT / system data.

Run from the backend directory:
    python seed_rrd.py

Requires rrdtool on PATH and the config.yml in the current working directory.
"""

import math
import os
import random
import subprocess
import time
import yaml

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

with open('config.yml') as f:
    _cfg = yaml.safe_load(f)

_g = _cfg.get('graphs', {})
_w = _cfg.get('rrd_writer', {})

RRD_BASE = _g.get('rrd_base', 'instance/rrd')
HOSTNAME = _g.get('hostname', 'localhost')
D1090_INSTANCE = _g.get('dump1090_instance', 'localhost')
D978_INSTANCE = _g.get('dump978_instance', 'localhost')
STEP = int(_w.get('step_seconds', 30))

HOST_DIR = f'{RRD_BASE}/{HOSTNAME}'
D1090_DIR = f'{HOST_DIR}/dump1090-{D1090_INSTANCE}'
D978_DIR = f'{HOST_DIR}/dump978-{D978_INSTANCE}'

DAYS = 7
TOTAL_STEPS = (DAYS * 86400) // STEP   # 20160 for 30s step

# RRAs identical to what RrdWriter creates
RRAS = [
    f'RRA:AVERAGE:0.5:1:{2 * 86400 // STEP}',       # 2 days at full res
    f'RRA:AVERAGE:0.5:5:{7 * 86400 // STEP // 5}',  # 7 days at 5x res
    f'RRA:AVERAGE:0.5:30:{15 * 86400 // STEP // 30}', # 15 days at 30x res
    f'RRA:MIN:0.5:1:{2 * 86400 // STEP}',
    f'RRA:MAX:0.5:1:{2 * 86400 // STEP}',
]

NOW = int(time.time())
START_TS = NOW - DAYS * 86400


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def rrd(*args):
    r = subprocess.run(['rrdtool', *args], capture_output=True, text=True)
    if r.returncode != 0:
        print(f'  rrdtool error: {r.stderr.strip()}')


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def create_rrd(path, ds_defs):
    if os.path.exists(path):
        os.remove(path)
    ensure_dir(os.path.dirname(path))
    rrd('create', path,
        '--start', str(START_TS - 1),
        '--step', str(STEP),
        *ds_defs,
        *RRAS)


def _flush_updates(path, updates):
    """Send all updates for a file in a single rrdtool call (much faster than 100-at-a-time)."""
    if updates:
        rrd('update', path, *updates)


def seed_gauge(path, ds_defs, value_fn):
    """Seed a GAUGE RRD; value_fn(step_index) -> [v1, v2, ...]."""
    create_rrd(path, ds_defs)
    updates = [
        f'{START_TS + i * STEP}:{":".join(str(round(v, 3)) for v in value_fn(i))}'
        for i in range(TOTAL_STEPS)
    ]
    _flush_updates(path, updates)


def seed_derive(path, ds_defs, rate_fn):
    """
    Seed a DERIVE RRD.  rate_fn(step_index) -> [rate1, rate2, ...] in units/sec.
    We accumulate a monotonic counter so rrdtool can derive the rate.
    """
    create_rrd(path, ds_defs)
    n_ds = len(ds_defs)
    counters = [0.0] * n_ds
    updates = []
    for i in range(TOTAL_STEPS):
        ts = START_TS + i * STEP
        rates = rate_fn(i)
        for j, r in enumerate(rates):
            counters[j] += max(0.0, r) * STEP
        updates.append(f'{ts}:{":".join(str(int(c)) for c in counters)}')
    _flush_updates(path, updates)


# ---------------------------------------------------------------------------
# Realistic signal generators
# ---------------------------------------------------------------------------

rng = random.Random(42)   # fixed seed for reproducible data


def diurnal(step_index, peak=1.0, trough=0.3):
    """Return a 0..1 multiplier following a day/night cycle (peak at noon)."""
    t = (START_TS + step_index * STEP) % 86400  # seconds into day
    # cosine centred on 14:00 (busy afternoon flying)
    angle = 2 * math.pi * (t - 50400) / 86400   # 50400 = 14h * 3600
    base = (math.cos(angle) + 1) / 2             # 0..1
    return trough + base * (peak - trough)


def jitter(value, pct=0.05):
    """Add ±pct relative gaussian jitter."""
    return value * (1 + rng.gauss(0, pct))


# ---------------------------------------------------------------------------
# dump1090 seeding
# ---------------------------------------------------------------------------

def seed_dump1090():
    print('Seeding dump1090 RRDs ...')
    ensure_dir(D1090_DIR)

    # --- Messages / message-rate (DERIVE) ------------------------------------
    # Peak ~250 msg/sec during day, ~70 at night
    def msg_rates(i):
        base = jitter(diurnal(i, peak=250, trough=70))
        strong = base * jitter(0.12, 0.1)          # ~12% strong signals
        positions = base * jitter(0.55, 0.08)      # ~55% have position
        return [base, strong, positions]

    seed_derive(f'{D1090_DIR}/dump1090_messages-local_accepted.rrd',
                ['DS:value:DERIVE:120:0:800000'],
                lambda i: [msg_rates(i)[0]])

    seed_derive(f'{D1090_DIR}/dump1090_messages-remote_accepted.rrd',
                ['DS:value:DERIVE:120:0:800000'],
                lambda i: [jitter(10)])  # small constant remote feed

    _msg_cache = {}  # cache so strong/positions correlate with local_accepted

    def _msg(i):
        if i not in _msg_cache:
            _msg_cache[i] = msg_rates(i)
        return _msg_cache[i]

    seed_derive(f'{D1090_DIR}/dump1090_messages-strong_signals.rrd',
                ['DS:value:DERIVE:120:0:800000'],
                lambda i: [_msg(i)[1]])

    seed_derive(f'{D1090_DIR}/dump1090_messages-positions.rrd',
                ['DS:value:DERIVE:120:0:800000'],
                lambda i: [_msg(i)[2]])

    # DF-type breakdown (DERIVE).  DF17 dominates, then DF18, DF11.
    df_fracs = {4: 0.03, 5: 0.02, 11: 0.08, 17: 0.55, 18: 0.12, 20: 0.03, 21: 0.03}
    for idx, frac in df_fracs.items():
        seed_derive(
            f'{D1090_DIR}/dump1090_messages-local_accepted_{idx}.rrd',
            ['DS:value:DERIVE:120:0:800000'],
            lambda i, f=frac: [jitter(_msg(i)[0] * f, 0.07)],
        )

    # --- Tracks (DERIVE) -----------------------------------------------------
    # ~10 new tracks/sec at peak (many short pings), ~15% single-message
    def track_rates(i):
        base = jitter(diurnal(i, peak=10, trough=2))
        single = base * jitter(0.15, 0.1)
        return [base, single]

    seed_derive(f'{D1090_DIR}/dump1090_tracks-all.rrd',
                ['DS:value:DERIVE:120:0:500000'],
                lambda i: [track_rates(i)[0]])
    seed_derive(f'{D1090_DIR}/dump1090_tracks-single_message.rrd',
                ['DS:value:DERIVE:120:0:500000'],
                lambda i: [track_rates(i)[1]])

    # --- CPU (DERIVE) --------------------------------------------------------
    # rrdtool CPU is stored in milliseconds (ms used per 30s window → rate in ms/s)
    # demod: ~5-12% of a core → 50-120 ms/sec
    def cpu_rates(i):
        scale = diurnal(i, peak=1.0, trough=0.4)
        demod = jitter(scale * 90, 0.1)       # ms/sec
        reader = jitter(scale * 30, 0.12)
        bg = jitter(scale * 15, 0.15)
        return [demod, reader, bg]

    for k, col in [('demod', 0), ('reader', 1), ('background', 2)]:
        seed_derive(
            f'{D1090_DIR}/dump1090_cpu-{k}.rrd',
            ['DS:value:DERIVE:120:0:1200000'],
            lambda i, c=col: [cpu_rates(i)[c]],
        )

    # --- Aircraft (GAUGE) ----------------------------------------------------
    # Total 40-80 during peak, 8-20 at night; positions ~75% of total
    def aircraft_vals(i):
        total = max(1, int(jitter(diurnal(i, peak=75, trough=12))))
        positions = max(0, int(total * jitter(0.75, 0.05)))
        return [total, positions]

    seed_gauge(
        f'{D1090_DIR}/dump1090_aircraft-recent.rrd',
        ['DS:total:GAUGE:120:0:500', 'DS:positions:GAUGE:120:0:500'],
        lambda i: aircraft_vals(i),
    )

    # MLAT (~10% of positioned)
    seed_gauge(
        f'{D1090_DIR}/dump1090_mlat-recent.rrd',
        ['DS:value:GAUGE:120:0:500'],
        lambda i: [max(0, int(aircraft_vals(i)[1] * jitter(0.10, 0.1)))],
    )

    # --- Max range (GAUGE, metres) -------------------------------------------
    # 200–380 km peaks during day
    def range_val(i):
        base = jitter(diurnal(i, peak=370000, trough=200000), 0.04)
        return [max(50000, base)]

    seed_gauge(
        f'{D1090_DIR}/dump1090_range-max_range.rrd',
        ['DS:value:GAUGE:120:0:1000000'],
        range_val,
    )

    # --- Signal (GAUGE, dBFS – stored as negative floats) --------------------
    # signal: -17 to -15 dBFS; peak: -8 to -6; min: -29 to -27; noise: -27 to -25
    def signal_vals(i):
        sig = jitter(-16.0, 0.03)
        peak = jitter(-7.0, 0.04)
        mn = jitter(-28.0, 0.03)
        noise = jitter(-26.0, 0.03)
        return sig, peak, mn, noise

    for k, col in [('signal', 0), ('peak_signal', 1), ('min_signal', 2), ('noise', 3)]:
        seed_gauge(
            f'{D1090_DIR}/dump1090_dbfs-{k}.rrd',
            ['DS:value:GAUGE:120:U:0'],
            lambda i, c=col: [signal_vals(i)[c]],
        )

    print('  dump1090 done.')


# ---------------------------------------------------------------------------
# dump978 seeding
# ---------------------------------------------------------------------------

def seed_dump978():
    print('Seeding dump978 RRDs ...')
    ensure_dir(D978_DIR)

    # UAT is US-only 978 MHz; much fewer aircraft than ADS-B
    # Message rates: 30-70/sec during day, 5-15 at night
    def uat_msg_rate(i):
        return [jitter(diurnal(i, peak=60, trough=10))]

    seed_derive(
        f'{D978_DIR}/dump978_messages-messages.rrd',
        ['DS:value:DERIVE:120:0:U'],
        uat_msg_rate,
    )

    # Aircraft: 10-25 day, 1-5 night; positions ~80%, callsigns ~65%
    def uat_aircraft(i):
        total = max(1, int(jitter(diurnal(i, peak=22, trough=3))))
        positions = max(0, int(total * jitter(0.80, 0.06)))
        callsigns = max(0, int(total * jitter(0.65, 0.06)))
        return [total, positions, callsigns]

    seed_gauge(
        f'{D978_DIR}/dump978_aircraft-recent.rrd',
        ['DS:total:GAUGE:120:0:500',
         'DS:positions:GAUGE:120:0:500',
         'DS:with_callsign:GAUGE:120:0:500'],
        uat_aircraft,
    )

    # Max range (GAUGE, metres)
    seed_gauge(
        f'{D978_DIR}/dump978_range-max_range.rrd',
        ['DS:value:GAUGE:120:0:1000000'],
        lambda i: [max(30000, jitter(diurnal(i, peak=280000, trough=80000), 0.05))],
    )

    # Average RSSI (GAUGE, dBFS – negative)
    seed_gauge(
        f'{D978_DIR}/dump978_dbfs-signal.rrd',
        ['DS:value:GAUGE:120:-200:200'],
        lambda i: [jitter(-22.0, 0.04)],
    )

    # Average altitude (GAUGE, feet)
    seed_gauge(
        f'{D978_DIR}/dump978_altitude-average.rrd',
        ['DS:value:GAUGE:120:-2000:100000'],
        lambda i: [max(0, jitter(diurnal(i, peak=18000, trough=5000), 0.12))],
    )

    print('  dump978 done.')


# ---------------------------------------------------------------------------
# System seeding
# ---------------------------------------------------------------------------

def seed_system():
    print('Seeding system RRDs ...')

    # --- CPU -----------------------------------------------------------------
    cpu_dir = f'{HOST_DIR}/aggregation-cpu-average'
    ensure_dir(cpu_dir)

    def cpu_vals(i):
        scale = diurnal(i, peak=1.0, trough=0.4)
        user = jitter(scale * 12, 0.15)
        system = jitter(scale * 4, 0.15)
        wait = jitter(scale * 1.5, 0.20)
        softirq = jitter(0.5, 0.20)
        steal = 0.0
        nice = 0.0
        interrupt = jitter(0.2, 0.20)
        total_busy = user + system + wait + softirq + interrupt
        idle = max(0.0, 100.0 - total_busy)
        return {
            'idle': idle, 'user': user, 'system': system,
            'wait': wait, 'softirq': softirq, 'steal': steal,
            'nice': nice, 'interrupt': interrupt,
        }

    for name in ['idle', 'user', 'system', 'wait', 'softirq', 'steal', 'nice', 'interrupt']:
        seed_gauge(
            f'{cpu_dir}/cpu-{name}.rrd',
            ['DS:value:GAUGE:120:0:100'],
            lambda i, n=name: [cpu_vals(i)[n]],
        )

    # --- Disk usage (GAUGE, bytes) -------------------------------------------
    df_dir = f'{HOST_DIR}/df-root'
    ensure_dir(df_dir)
    TOTAL_DISK = 32 * 1024 ** 3   # 32 GB SD card
    USED_BASE = 6 * 1024 ** 3     # 6 GB used grows slowly over 7 days
    GROWTH_PER_STEP = 10 * 1024   # ~10 KB per 30s (writes, logs)

    def disk_used(i):
        return [int(USED_BASE + i * GROWTH_PER_STEP + jitter(0, 0.001) * 1024 ** 2)]

    seed_gauge(f'{df_dir}/df_complex-used.rrd', ['DS:value:GAUGE:120:0:U'], disk_used)
    seed_gauge(f'{df_dir}/df_complex-reserved.rrd', ['DS:value:GAUGE:120:0:U'],
               lambda i: [int(TOTAL_DISK * 0.05)])   # 5% reserved
    seed_gauge(f'{df_dir}/df_complex-free.rrd', ['DS:value:GAUGE:120:0:U'],
               lambda i: [max(0, int(TOTAL_DISK - disk_used(i)[0] - TOTAL_DISK * 0.05))])

    # --- Disk I/O (DERIVE) ---------------------------------------------------
    disk_dir = f'{HOST_DIR}/disk-mmcblk0'
    ensure_dir(disk_dir)

    def disk_iops(i):
        scale = diurnal(i, peak=1.0, trough=0.3)
        reads = jitter(scale * 40, 0.20)   # ops/sec
        writes = jitter(scale * 20, 0.20)
        return [reads, writes]

    def disk_octets(i):
        scale = diurnal(i, peak=1.0, trough=0.3)
        read_bw = jitter(scale * 512 * 1024, 0.25)   # bytes/sec
        write_bw = jitter(scale * 256 * 1024, 0.25)
        return [read_bw, write_bw]

    seed_derive(f'{disk_dir}/disk_ops.rrd',
                ['DS:read:DERIVE:120:0:U', 'DS:write:DERIVE:120:0:U'],
                disk_iops)
    seed_derive(f'{disk_dir}/disk_octets.rrd',
                ['DS:read:DERIVE:120:0:U', 'DS:write:DERIVE:120:0:U'],
                disk_octets)

    # --- Memory (GAUGE, bytes) -----------------------------------------------
    mem_dir = f'{HOST_DIR}/memory'
    ensure_dir(mem_dir)
    TOTAL_MEM = 1 * 1024 ** 3   # 1 GB Pi

    def mem_vals(i):
        scale = diurnal(i, peak=1.0, trough=0.7)
        used = int(jitter(scale * 480 * 1024 ** 2, 0.05))
        cached = int(jitter(180 * 1024 ** 2, 0.08))
        buffered = int(jitter(50 * 1024 ** 2, 0.10))
        free = max(0, int(TOTAL_MEM - used - cached - buffered))
        return {'used': used, 'cached': cached, 'buffered': buffered, 'free': free}

    for name in ['used', 'cached', 'buffered', 'free']:
        seed_gauge(
            f'{mem_dir}/memory-{name}.rrd',
            ['DS:value:GAUGE:120:0:U'],
            lambda i, n=name: [mem_vals(i)[n]],
        )

    # --- Temperature (GAUGE, millidegrees C) ---------------------------------
    temp_dir = f'{HOST_DIR}/thermal-thermal_zone0'
    ensure_dir(temp_dir)
    seed_gauge(
        f'{temp_dir}/temperature.rrd',
        ['DS:value:GAUGE:120:0:U'],
        lambda i: [int(jitter(diurnal(i, peak=62000, trough=48000), 0.03))],
    )

    # --- Network (DERIVE, bytes/sec) -----------------------------------------
    net_dir = f'{HOST_DIR}/interface-eth0'
    ensure_dir(net_dir)

    def net_octets(i):
        scale = diurnal(i, peak=1.0, trough=0.2)
        rx = jitter(scale * 350 * 1024, 0.20)   # ~350 KB/s peak RX
        tx = jitter(scale * 40 * 1024, 0.20)    # ~40 KB/s peak TX
        return [rx, tx]

    seed_derive(f'{net_dir}/if_octets.rrd',
                ['DS:rx:DERIVE:120:0:U', 'DS:tx:DERIVE:120:0:U'],
                net_octets)

    print('  system done.')


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    t0 = time.time()
    print(f'Seeding {TOTAL_STEPS:,} steps × {STEP}s = {DAYS} days of data')
    print(f'RRD base: {os.path.abspath(RRD_BASE)}')
    print()

    seed_dump1090()
    seed_dump978()
    seed_system()

    elapsed = time.time() - t0
    print(f'\nDone in {elapsed:.1f}s')
    print('Restart the portal backend to pick up the new databases.')
