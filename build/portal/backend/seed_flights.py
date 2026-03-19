#!/usr/bin/env python3
"""
Seed the ADS-B portal database with multi-track flight test data.

Strategy:
  - ONE flights row per callsign (required by the positions endpoint which uses
    scalar_one_or_none on Flight.flight).
  - Multiple position batches per flight, separated by > 2-hour time gaps.
  - The Angular frontend splits tracks on any gap > TRACK_GAP_HOURS (2 h), so
    the multi-day jumps between batches create visually distinct coloured tracks.
  - One flight (AAL789) has only a single batch → single track on the map.
  - Positions are recorded every 5 seconds with a smooth sinusoidal heading
    variation, giving naturally curved paths.
"""

import sqlite3
import math
from datetime import datetime, timedelta

DB_PATH = 'instance/adsbportal.sqlite3'


def gen_segment(start_lat, start_lon, start_hdg, start_dt,
                duration_min=15, turn_amp=0.35, speed_kmh=840,
                alt_ft=35000, squawk=2000):
    """
    Generate positions every 5 s for one continuous flight segment.

    The heading follows a sinusoidal perturbation so the path curves
    smoothly rather than travelling in a dead-straight line.
    """
    pts = []
    lat  = float(start_lat)
    lon  = float(start_lon)
    hdg  = float(start_hdg) % 360.0
    alt  = float(alt_ft)
    steps = int(duration_min * 60 / 5)
    kts   = int(speed_kmh * 0.539957)   # km/h → knots

    for i in range(steps):
        t = start_dt + timedelta(seconds=i * 5)

        # Smooth, gently-oscillating heading change
        hdg = (hdg + turn_amp * math.sin(i * 0.06)) % 360.0

        r = math.radians(hdg)
        # Ground distance per 5-second step → degrees
        d = (speed_kmh / 3600.0 * 5.0) / 111.0
        lat += d * math.cos(r)
        lon += d * math.sin(r) / max(math.cos(math.radians(lat)), 0.01)

        # Mild altitude oscillation (±~1 000 ft over the segment)
        vr  = int(math.sin(i * 0.10) * 256)   # ft/min vertical rate
        alt += vr / 60.0 * 5.0

        pts.append((
            t.strftime('%Y-%m-%d %H:%M:%S'),  # 0  time
            round(lat, 6),                    # 1  latitude
            round(lon, 6),                    # 2  longitude
            int(hdg) % 360,                   # 3  track (degrees)
            int(alt),                         # 4  altitude (ft)
            vr,                               # 5  vertical_rate (ft/min)
            kts,                              # 6  speed (knots)
            squawk,                           # 7  squawk
        ))

    return pts


# ---------------------------------------------------------------------------
# Flight definitions
#
# Each entry:  (icao, callsign, [segment, ...])
# Each segment: (lat, lon, heading, datetime, dur_min, turn_amp,
#                speed_kmh, alt_ft, squawk)
#
# Segments within the same flight are separated by multi-day gaps so the
# frontend's 2-hour threshold will always split them into distinct tracks.
# ---------------------------------------------------------------------------
FLIGHTS = [
    # --- UAL123 : three separate sightings → three coloured tracks ---
    ('A1B2C3', 'UAL123', [
        (41.98, -87.90,  95, datetime(2024,  1, 15,  8,  0,  0), 15,  0.40, 820, 35000, 2341),
        (42.36, -71.00, 275, datetime(2024,  3,  8, 14, 30,  0), 15, -0.35, 810, 37000, 4521),
        (39.86,-104.67,  48, datetime(2024,  8, 22, 10, 15,  0), 15,  0.30, 840, 33000, 3301),
    ]),

    # --- DAL456 : two separate sightings → two coloured tracks ---
    ('D4E5F6', 'DAL456', [
        (33.64, -84.43, 178, datetime(2024,  2, 10,  9,  0,  0), 15,  0.30, 810, 36000, 1234),
        (25.79, -80.29, 322, datetime(2024,  6, 17, 16, 45,  0), 15, -0.28, 800, 38000, 2156),
    ]),

    # --- AAL789 : single sighting → single track only (the "except for one") ---
    ('G7H8I9', 'AAL789', [
        (47.44,-122.31, 138, datetime(2024,  4,  5, 11,  0,  0), 15,  0.15, 760, 32000, 3412),
    ]),

    # --- SWA321 : three separate sightings → three coloured tracks ---
    ('J1K2L3', 'SWA321', [
        (36.08,-115.15,  62, datetime(2024,  5,  1,  7,  0,  0), 15,  0.45, 780, 31000, 1560),
        (32.84, -96.85, 202, datetime(2024,  7, 14, 13, 30,  0), 15, -0.38, 790, 33000, 4320),
        (29.99, -90.26,  87, datetime(2024, 11,  3,  9, 45,  0), 15,  0.32, 800, 35000, 2240),
    ]),
]


def main():
    conn = sqlite3.connect(DB_PATH)
    cur  = conn.cursor()

    total_pos = 0

    for icao, callsign, segments in FLIGHTS:
        overall_first = segments[0][3].strftime('%Y-%m-%d %H:%M:%S')
        last_seg      = segments[-1]
        overall_last  = (last_seg[3] + timedelta(minutes=last_seg[4])).strftime('%Y-%m-%d %H:%M:%S')

        # Insert aircraft (skip if already present)
        cur.execute('SELECT id FROM aircraft WHERE icao = ?', (icao,))
        row = cur.fetchone()
        if row:
            aircraft_id = row[0]
        else:
            cur.execute(
                'INSERT INTO aircraft (icao, first_seen, last_seen) VALUES (?, ?, ?)',
                (icao, overall_first, overall_last),
            )
            aircraft_id = cur.lastrowid

        # ONE flights row per callsign (the positions endpoint requires this)
        cur.execute(
            'SELECT id FROM flights WHERE flight = ? AND aircraft = ?',
            (callsign, aircraft_id),
        )
        row = cur.fetchone()
        if row:
            flight_id = row[0]
        else:
            cur.execute(
                'INSERT INTO flights (aircraft, flight, first_seen, last_seen) VALUES (?, ?, ?, ?)',
                (aircraft_id, callsign, overall_first, overall_last),
            )
            flight_id = cur.lastrowid

        # Insert position batches — time gaps between batches become track breaks
        msg_counter = 1
        for seg in segments:
            lat, lon, hdg, start_dt, dur, turn, spd, alt, sq = seg
            pts = gen_segment(lat, lon, hdg, start_dt, dur, turn, spd, alt, sq)
            for p in pts:
                cur.execute(
                    'INSERT INTO positions '
                    '(flight, aircraft, time, message, squawk, '
                    ' latitude, longitude, track, altitude, vertical_rate, speed) '
                    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    (flight_id, aircraft_id,
                     p[0],          # time
                     msg_counter,   # message
                     p[7],          # squawk
                     p[1],          # latitude
                     p[2],          # longitude
                     p[3],          # track
                     p[4],          # altitude
                     p[5],          # vertical_rate
                     p[6]),         # speed
                )
                msg_counter += 1
            total_pos += len(pts)
            print(f'  {callsign}  {start_dt.date()}  {len(pts):4d} positions')

    conn.commit()
    conn.close()
    print(f'\nDone — {total_pos} total positions inserted.')


if __name__ == '__main__':
    main()
