import json
import logging
import math
import os
import shutil
import socket
import subprocess
import time
import psutil

from urllib.error import URLError
from json import JSONDecodeError
from sqlalchemy.exc import SQLAlchemyError
from urllib.request import urlopen
from flask import current_app
from backend.config_loader import get_graphs_config, get_rrd_writer_config, load_portal_config


class RrdWriter:
    def __init__(self):
        cfg = load_portal_config()
        graphs_cfg = get_graphs_config(cfg)
        writer_cfg = get_rrd_writer_config(cfg)

        self.enabled = bool(writer_cfg.get('enabled', True))
        self.step = int(writer_cfg.get('step_seconds', 30))
        self.timeout = float(writer_cfg.get('http_timeout_seconds', 5.0))

        self.rrd_base = graphs_cfg.get('rrd_base') or os.environ.get('RRD_BASE', 'instance/rrd')
        self.hostname = graphs_cfg.get('hostname', socket.gethostname())
        self.dump1090_instance = graphs_cfg.get('dump1090_instance', 'localhost')
        self.dump978_instance = graphs_cfg.get('dump978_instance', 'localhost')

        self.dump1090_url = writer_cfg.get('dump1090_url', 'http://127.0.0.1/dump1090')
        self.dump978_url = writer_cfg.get('dump978_url', 'http://127.0.0.1/dump978')

        self.host_dir = f'{self.rrd_base}/{self.hostname}'
        self.d1090_dir = f'{self.host_dir}/dump1090-{self.dump1090_instance}'
        self.d978_dir = f'{self.host_dir}/dump978-{self.dump978_instance}'

        os.makedirs(self.host_dir, exist_ok=True)
        os.makedirs(self.d1090_dir, exist_ok=True)
        os.makedirs(self.d978_dir, exist_ok=True)

    def log(self, msg: str):
        logging.info('[rrd_writer] %s', msg)

    def _run_rrdtool(self, args: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(['rrdtool', *args], capture_output=True, text=True)

    def _ensure_rrd(self, path: str, ds_defs: list[str]):
        if os.path.exists(path):
            return

        os.makedirs(os.path.dirname(path), exist_ok=True)
        start = int(time.time()) - 1

        rras = [
            'RRA:AVERAGE:0.5:1:2880',
            'RRA:AVERAGE:0.5:5:2016',
            'RRA:AVERAGE:0.5:30:1440',
            'RRA:MIN:0.5:1:2880',
            'RRA:MAX:0.5:1:2880',
        ]

        result = self._run_rrdtool([
            'create', path,
            '--start', str(start),
            '--step', str(self.step),
            *ds_defs,
            *rras,
        ])
        if result.returncode != 0:
            self.log(f'failed to create {path}: {result.stderr.strip()}')

    def _update_rrd(self, path: str, values: list):
        ts = str(int(time.time()))
        update = f"{ts}:{':'.join(str(v) for v in values)}"
        result = self._run_rrdtool(['update', path, update])
        if result.returncode != 0:
            self.log(f'failed to update {path}: {result.stderr.strip()}')

    def _write_rrd_values(self, path: str, ds_defs: list[str], values: list):
        self._ensure_rrd(path, ds_defs)
        self._update_rrd(path, values)

    def _write_value_rrd(self, path: str, ds_def: str, value):
        self._write_rrd_values(path, [ds_def], [value])

    def _write_metric_map(self, base_dir: str, prefix: str, metric_values: dict, ds_def: str):
        for name, value in metric_values.items():
            self._write_value_rrd(f'{base_dir}/{prefix}-{name}.rrd', ds_def, value)

    def _max_range_from_aircraft(self, receiver_lat, receiver_lon, aircraft):
        if receiver_lat is None or receiver_lon is None:
            return 0
        try:
            return self._greatcircle(
                float(receiver_lat),
                float(receiver_lon),
                float(aircraft['lat']),
                float(aircraft['lon']),
            )
        except (KeyError, TypeError, ValueError) as ex:
            self.log(f'could not calculate aircraft range: {ex}')
            return 0

    def _fetch_json(self, url: str):
        try:
            with urlopen(url, None, self.timeout) as r:
                return json.load(r)
        except (OSError, URLError, TimeoutError) as ex:
            self.log(f'fetch failed for {url}: {ex}')
        except JSONDecodeError as ex:
            self.log(f'invalid JSON from {url}: {ex}')
        return None

    def _greatcircle(self, lat0, lon0, lat1, lon1):
        lat0 = lat0 * math.pi / 180.0
        lon0 = lon0 * math.pi / 180.0
        lat1 = lat1 * math.pi / 180.0
        lon1 = lon1 * math.pi / 180.0
        return 6371e3 * math.acos(
            math.sin(lat0) * math.sin(lat1) +
            math.cos(lat0) * math.cos(lat1) * math.cos(abs(lon0 - lon1))
        )

    def _write_dump1090(self):
        stats = self._fetch_json(f'{self.dump1090_url}/data/stats.json')
        receiver = self._fetch_json(f'{self.dump1090_url}/data/receiver.json')
        aircraft_data = self._fetch_json(f'{self.dump1090_url}/data/aircraft.json')

        if stats:
            total = stats.get('total', {})
            local = total.get('local', {})
            remote = total.get('remote', {})
            cpr = total.get('cpr', {})
            tracks = total.get('tracks', {})
            cpu = total.get('cpu', {})

            local_acc = sum(local.get('accepted', []))
            remote_acc = sum(remote.get('accepted', []))
            strong = local.get('strong_signals', 0)
            positions = cpr.get('global_ok', 0) + cpr.get('local_ok', 0)

            message_metrics = {
                'local_accepted': local_acc,
                'remote_accepted': remote_acc,
                'strong_signals': strong,
                'positions': positions,
            }
            self._write_metric_map(
                self.d1090_dir,
                'dump1090_messages',
                message_metrics,
                'DS:value:DERIVE:120:0:800000',
            )

            local_types = local.get('accepted', [])
            for idx in [4, 5, 11, 17, 18, 20, 21]:
                value = local_types[idx] if idx < len(local_types) else 0
                path = f'{self.d1090_dir}/dump1090_messages-local_accepted_{idx}.rrd'
                self._write_value_rrd(path, 'DS:value:DERIVE:120:0:800000', value)

            all_tracks = tracks.get('all', 0)
            single_message_tracks = tracks.get('single_message', 0)
            self._write_metric_map(
                self.d1090_dir,
                'dump1090_tracks',
                {'all': all_tracks, 'single_message': single_message_tracks},
                'DS:value:DERIVE:120:0:500000',
            )
            self._write_metric_map(
                self.d1090_dir,
                'dump1090_cpu',
                {k: cpu.get(k, 0) for k in ['demod', 'reader', 'background']},
                'DS:value:DERIVE:120:0:1200000',
            )

            one_min = stats.get('last1min', {}).get('local', {})
            if one_min:
                for k in ['signal', 'peak_signal', 'min_signal', 'noise']:
                    if k in one_min:
                        path = f'{self.d1090_dir}/dump1090_dbfs-{k}.rrd'
                        self._write_value_rrd(path, 'DS:value:GAUGE:120:U:0', one_min[k])

        if receiver and aircraft_data:
            rlat = receiver.get('lat')
            rlon = receiver.get('lon')

            total = 0
            with_pos = 0
            mlat = 0
            max_range = 0

            for a in aircraft_data.get('aircraft', []):
                if a.get('seen', 9999) < 60:
                    total += 1
                if a.get('seen_pos', 9999) < 60 and 'lat' in a and 'lon' in a:
                    with_pos += 1
                    if rlat is not None and rlon is not None:
                        max_range = max(max_range, self._max_range_from_aircraft(rlat, rlon, a))
                    if 'lat' in a.get('mlat', []):
                        mlat += 1

            self._write_rrd_values(
                f'{self.d1090_dir}/dump1090_aircraft-recent.rrd',
                ['DS:total:GAUGE:120:0:500', 'DS:positions:GAUGE:120:0:500'],
                [total, with_pos],
            )
            self._write_value_rrd(f'{self.d1090_dir}/dump1090_mlat-recent.rrd', 'DS:value:GAUGE:120:0:500', mlat)
            self._write_value_rrd(
                f'{self.d1090_dir}/dump1090_range-max_range.rrd',
                'DS:value:GAUGE:120:0:1000000',
                max_range,
            )

    def _write_dump978(self):
        receiver = self._fetch_json(f'{self.dump978_url}/data/receiver.json')
        aircraft_data = self._fetch_json(f'{self.dump978_url}/data/aircraft.json')

        if not receiver or not aircraft_data:
            return

        rlat = receiver.get('lat')
        rlon = receiver.get('lon')

        total = 0
        with_pos = 0
        with_callsign = 0
        max_range = 0
        total_messages = 0
        rssi_values = []
        alt_values = []

        for a in aircraft_data.get('aircraft', []):
            if a.get('seen', 9999) < 60:
                total += 1
                if a.get('flight', '').strip():
                    with_callsign += 1
                if 'rssi' in a:
                    rssi_values.append(a['rssi'])
                if 'messages' in a:
                    total_messages += a.get('messages', 0)

            if a.get('seen_pos', 9999) < 60 and 'lat' in a and 'lon' in a:
                with_pos += 1
                if rlat is not None and rlon is not None:
                    max_range = max(max_range, self._max_range_from_aircraft(rlat, rlon, a))
                if isinstance(a.get('altitude'), (int, float)):
                    alt_values.append(a['altitude'])

        self._write_rrd_values(
            f'{self.d978_dir}/dump978_aircraft-recent.rrd',
            ['DS:total:GAUGE:120:0:500', 'DS:positions:GAUGE:120:0:500', 'DS:with_callsign:GAUGE:120:0:500'],
            [total, with_pos, with_callsign],
        )
        self._write_value_rrd(
            f'{self.d978_dir}/dump978_range-max_range.rrd',
            'DS:value:GAUGE:120:0:1000000',
            max_range,
        )
        self._write_value_rrd(
            f'{self.d978_dir}/dump978_messages-messages.rrd',
            'DS:value:DERIVE:120:0:U',
            total_messages,
        )

        avg_rssi = (sum(rssi_values) / len(rssi_values)) if rssi_values else -30.0
        self._write_value_rrd(f'{self.d978_dir}/dump978_dbfs-signal.rrd', 'DS:value:GAUGE:120:-200:200', avg_rssi)

        avg_alt = (sum(alt_values) / len(alt_values)) if alt_values else 0
        self._write_value_rrd(
            f'{self.d978_dir}/dump978_altitude-average.rrd',
            'DS:value:GAUGE:120:-2000:100000',
            avg_alt,
        )

    def _write_system(self):
        # CPU percentages
        cpu = psutil.cpu_times_percent(interval=None)
        cpu_dir = f'{self.host_dir}/aggregation-cpu-average'
        cpu_map = {
            'idle': cpu.idle,
            'interrupt': getattr(cpu, 'irq', 0.0),
            'nice': cpu.nice,
            'softirq': getattr(cpu, 'softirq', 0.0),
            'steal': getattr(cpu, 'steal', 0.0),
            'system': cpu.system,
            'user': cpu.user,
            'wait': getattr(cpu, 'iowait', 0.0),
        }
        for name, value in cpu_map.items():
            path = f'{cpu_dir}/cpu-{name}.rrd'
            self._ensure_rrd(path, ['DS:value:GAUGE:120:0:100'])
            self._update_rrd(path, [round(value, 3)])

        # Disk usage /
        du = shutil.disk_usage('/')
        df_dir = f'{self.host_dir}/df-root'
        reserved = 0
        self._ensure_rrd(f'{df_dir}/df_complex-used.rrd', ['DS:value:GAUGE:120:0:U'])
        self._update_rrd(f'{df_dir}/df_complex-used.rrd', [du.used])
        self._ensure_rrd(f'{df_dir}/df_complex-reserved.rrd', ['DS:value:GAUGE:120:0:U'])
        self._update_rrd(f'{df_dir}/df_complex-reserved.rrd', [reserved])
        self._ensure_rrd(f'{df_dir}/df_complex-free.rrd', ['DS:value:GAUGE:120:0:U'])
        self._update_rrd(f'{df_dir}/df_complex-free.rrd', [du.free])

        # Disk I/O
        dio = psutil.disk_io_counters()
        if dio:
            disk_dir = f'{self.host_dir}/disk-mmcblk0'
            self._ensure_rrd(f'{disk_dir}/disk_ops.rrd', ['DS:read:DERIVE:120:0:U', 'DS:write:DERIVE:120:0:U'])
            self._update_rrd(f'{disk_dir}/disk_ops.rrd', [dio.read_count, dio.write_count])
            self._ensure_rrd(f'{disk_dir}/disk_octets.rrd', ['DS:read:DERIVE:120:0:U', 'DS:write:DERIVE:120:0:U'])
            self._update_rrd(f'{disk_dir}/disk_octets.rrd', [dio.read_bytes, dio.write_bytes])

        # Memory
        mem = psutil.virtual_memory()
        mem_dir = f'{self.host_dir}/memory'
        mem_map = {
            'buffered': getattr(mem, 'buffers', 0),
            'cached': getattr(mem, 'cached', 0),
            'free': mem.free,
            'used': mem.used,
        }
        for name, value in mem_map.items():
            path = f'{mem_dir}/memory-{name}.rrd'
            self._ensure_rrd(path, ['DS:value:GAUGE:120:0:U'])
            self._update_rrd(path, [int(value)])

        # Temperature in millidegrees C if available
        temps = psutil.sensors_temperatures(fahrenheit=False) if hasattr(psutil, 'sensors_temperatures') else {}
        temp_value = None
        if temps:
            for _, entries in temps.items():
                if entries:
                    temp_value = int(entries[0].current * 1000)
                    break
        if temp_value is not None:
            temp_dir = f'{self.host_dir}/thermal-thermal_zone0'
            self._ensure_rrd(f'{temp_dir}/temperature.rrd', ['DS:value:GAUGE:120:0:U'])
            self._update_rrd(f'{temp_dir}/temperature.rrd', [temp_value])

        # Network interface
        iface = 'eth0'
        try:
            from backend.models import db, Setting
            from sqlalchemy import select
            row = db.session.execute(select(Setting).filter_by(name='graphs_network_interface')).scalar_one_or_none()
            if row and row.value:
                iface = row.value
        except SQLAlchemyError as ex:
            self.log(f'could not load configured network interface: {ex}')

        pernic = psutil.net_io_counters(pernic=True)
        io = pernic.get(iface)
        if io:
            iface_dir = f'{self.host_dir}/interface-{iface}'
            self._ensure_rrd(f'{iface_dir}/if_octets.rrd', ['DS:rx:DERIVE:120:0:U', 'DS:tx:DERIVE:120:0:U'])
            self._update_rrd(f'{iface_dir}/if_octets.rrd', [io.bytes_recv, io.bytes_sent])

    def run(self):
        if not self.enabled:
            return

        self._write_dump1090()
        self._write_dump978()
        self._write_system()


def rrd_data_collection_job():
    with current_app.app_context():
        try:
            writer = RrdWriter()
            writer.run()
        except FileNotFoundError:
            logging.error('[rrd_writer] rrdtool not found on PATH')
        except Exception as ex:
            logging.error('[rrd_writer] unexpected failure', exc_info=ex)
