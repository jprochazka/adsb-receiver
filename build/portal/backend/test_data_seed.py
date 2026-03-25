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

Also seeds:
  - Users and settings into the main portal database.
  - A separate acarsdec.sqlite database (in the same instance/ folder)
    with ACARS stations, flights, and messages to exercise the /api/acars/* endpoints.
"""

import sqlite3
import math
from datetime import datetime, timedelta

DB_PATH       = 'instance/adsbportal.sqlite3'
ACARS_DB_PATH = 'instance/acarsdec.sqlite'


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


USERS = [
    # (name, email, password, administrator, role)
    ('Admin User',   'admin@example.com',     'admin123', 1, 'Admin'),
    ('Regular User', 'user@example.com',       'user123',  0, 'User'),
    ('Test Admin',   'testadmin@example.com',  'test123',  1, 'Admin'),
]

LINKS = [
    # (name, address)
    ('ADS-B Exchange',    'https://www.adsbexchange.com'),
    ('FlightAware',       'https://www.flightaware.com'),
    ('FlightRadar24',     'https://www.flightradar24.com'),
    ('OpenSky Network',   'https://opensky-network.org'),
    ('Plane Finder',      'https://planefinder.net'),
]

SETTINGS = [
    # (name, value)
    ('graphs_measurement_range',       'imperialNautical'),
    ('graphs_measurement_temperature', 'imperial'),
    ('graphs_network_interface',       'eth0'),
    ('graphs_dump1090_enabled',        'true'),
    ('graphs_dump978_enabled',         'false'),
    ('flights_nav_enabled',            'true'),
    ('blog_nav_enabled',               'true'),
    ('links_nav_enabled',              'true'),
    ('info_nav_enabled',               'true'),
    ('info_system_enabled',            'true'),
    ('info_graphs_enabled',            'true'),
    ('map_nav_enabled',                'true'),
    ('map_dump1090_enabled',           'true'),
    ('map_dump978_enabled',            'true'),
    ('map_adsbx_enabled',              'true'),
    ('map_pfclient_enabled',           'false'),
]


# ---------------------------------------------------------------------------
# dump978 / UAT flight definitions
#
# UAT aircraft are typically lower-altitude general-aviation aircraft.
# Key differences from dump1090:
#   - flight (callsign) may be absent → stored as NULL
#   - message count may be absent     → stored as NULL
#   - lower speed (~120-180 kts) and altitude (~2 000-12 000 ft)
#
# Each entry: (icao, callsign_or_None, [segment, ...])
# ---------------------------------------------------------------------------
UAT_FLIGHTS = [
    # --- N123AB : two sightings with full callsign and message counts ---
    ('A1B2C3', 'N123AB', [
        (41.98, -87.90,  90, datetime(2024,  2, 10,  9,  0,  0), 12, 0.20, 180, 4500, 1200),
        (42.30, -88.50, 270, datetime(2024,  5, 22, 15,  0,  0), 12, -0.18, 175, 5000, 1400),
    ]),

    # --- N456CD : single sighting with callsign ---
    ('D4E5F6', 'N456CD', [
        (39.86, -104.67, 135, datetime(2024,  3, 15, 10, 30,  0), 10, 0.15, 150, 8500, 3300),
    ]),

    # --- N789EF : single sighting, no callsign (flight=NULL) and no messages ---
    ('G7H8I9', None, [
        (33.64,  -84.43, 200, datetime(2024,  4, 20,  8,  0,  0), 8, 0.10, 130, 3000, None),
    ]),

    # --- N246BG : two sightings, callsign present but messages absent ---
    ('J1K2L3', 'N246BG', [
        (47.44, -122.31,  50, datetime(2024,  6,  5, 11,  0,  0), 10, 0.25, 160, 6500, 4512),
        (47.10, -121.80, 230, datetime(2024,  9,  1, 14,  0,  0), 10, -0.22, 155, 7000, 4600),
    ]),
]


# ---------------------------------------------------------------------------
# ACARS seed data
# ---------------------------------------------------------------------------

ACARS_STATIONS = [
    # (IdStation, IpAddr)
    ('ACARS-1', '192.168.1.10'),
    ('ACARS-2', '192.168.1.11'),
]

# Each entry: (Registration, FlightNumber, StartTime, messages)
# messages:   list of (offset_seconds, channel, error, signal_lvl,
#                      mode, ack, label, block_no, mess_no, txt)
ACARS_FLIGHTS = [
    ('N12345', 'UAL123', datetime(2024, 1, 15, 8, 0, 0), [
        (0,   1, 0, -45, '2', 'Y', 'H1', 'A', '001', 'POSRPT /POS 41.98N 087.90W 35000FT 450KTS'),
        (30,  1, 0, -46, '2', 'Y', 'Q0', 'B', '002', ''),
        (60,  2, 0, -44, '2', 'N', '5Z', 'A', '003', 'ACARS TEST MESSAGE FROM UAL123'),
        (90,  1, 1, -50, '2', 'Y', 'H1', 'B', '004', 'POSRPT /POS 42.10N 087.50W 35100FT 448KTS'),
        (120, 2, 0, -43, '2', 'Y', '_d', 'A', '005', 'ATIS INFO DELTA WIND 270/12 VIS 10'),
    ]),
    ('N67890', 'DAL456', datetime(2024, 2, 10, 9, 0, 0), [
        (0,   1, 0, -41, '2', 'Y', 'H1', 'A', '001', 'POSRPT /POS 33.64N 084.43W 36000FT 460KTS'),
        (45,  2, 0, -42, '2', 'N', 'Q0', 'B', '002', ''),
        (90,  1, 0, -44, '2', 'Y', 'SA', 'A', '003', 'METAR KATL 101200Z 25010KT 10SM FEW050 28/15'),
        (135, 1, 0, -43, '2', 'Y', 'H1', 'B', '004', 'POSRPT /POS 25.90N 080.40W 36200FT 459KTS'),
    ]),
    ('N24680', 'AAL789', datetime(2024, 4, 5, 11, 0, 0), [
        (0,   1, 0, -47, '2', 'Y', 'H1', 'A', '001', 'POSRPT /POS 47.44N 122.31W 32000FT 440KTS'),
        (60,  2, 0, -48, '2', 'Y', '30', 'A', '002', 'CREW REQUEST: GATE CHANGE AT DESTINATION'),
        (120, 1, 0, -46, '2', 'N', 'H1', 'B', '003', 'POSRPT /POS 47.55N 122.10W 32100FT 441KTS'),
    ]),
    ('N13579', 'SWA321', datetime(2024, 5, 1, 7, 0, 0), [
        (0,   2, 0, -40, '2', 'Y', 'H1', 'A', '001', 'POSRPT /POS 36.08N 115.15W 31000FT 435KTS'),
        (30,  2, 0, -41, '2', 'Y', 'Q0', 'A', '002', ''),
        (60,  1, 0, -42, '2', 'Y', 'SQ', 'B', '003', 'SQUAWK 1560 ASSIGNED'),
        (90,  2, 1, -51, '2', 'N', 'H1', 'A', '004', 'POSRPT /POS 36.20N 114.90W 31100FT 434KTS'),
        (120, 1, 0, -40, '2', 'Y', '5Z', 'B', '005', 'ACARS DATALINK CHECK OK'),
        (150, 2, 0, -41, '2', 'Y', 'H1', 'A', '006', 'POSRPT /POS 36.35N 114.65W 31200FT 436KTS'),
    ]),
    # A flight with many messages — useful for testing pagination
    ('N99999', 'TST001', datetime(2024, 6, 1, 12, 0, 0), [
        (i * 20, (i % 2) + 1, 0, -42 - (i % 5),
         '2', 'Y' if i % 3 else 'N', 'H1', chr(65 + (i % 26)), f'{i + 1:03d}',
         f'TEST MESSAGE {i + 1:03d} FROM TST001 AT OFFSET {i * 20}S')
        for i in range(30)
    ]),
]


def seed_acars():
    conn = sqlite3.connect(ACARS_DB_PATH)
    cur  = conn.cursor()

    # Create schema matching the acarsdec SQLite output
    cur.executescript("""
        CREATE TABLE IF NOT EXISTS Flights (
            FlightID     integer primary key,
            Registration char(7),
            FlightNumber char(6),
            StartTime    datetime,
            LastTime     datetime,
            NbMessages   integer
        );
        CREATE INDEX IF NOT EXISTS FlightsFlightNumber ON Flights(FlightNumber);
        CREATE INDEX IF NOT EXISTS FlightsRegistration  ON Flights(Registration);
        CREATE TRIGGER IF NOT EXISTS MessDel
            BEFORE DELETE ON Flights FOR EACH ROW
            BEGIN DELETE FROM Messages WHERE FlightID = old.FlightID; END;
        CREATE TABLE IF NOT EXISTS Stations (
            StID      integer primary key,
            IdStation varchar,
            IpAddr    varchar
        );
        CREATE TABLE IF NOT EXISTS Messages (
            MessageID integer primary key,
            FlightID  integer not null,
            Time      datetime,
            StID      integer,
            Channel   integer,
            Error     integer,
            SignalLvl integer,
            Mode      char,
            Ack       char,
            Label     char(2),
            BlockNo   char,
            MessNo    char(4),
            Txt       varchar(250)
        );
    """)

    # Stations
    for st_id, (id_station, ip_addr) in enumerate(ACARS_STATIONS, start=1):
        cur.execute(
            'INSERT OR IGNORE INTO Stations (StID, IdStation, IpAddr) VALUES (?, ?, ?)',
            (st_id, id_station, ip_addr),
        )
    print(f'  ACARS stations : {len(ACARS_STATIONS)}')

    total_msgs = 0
    for reg, flt_no, start_dt, messages in ACARS_FLIGHTS:
        last_dt = start_dt + timedelta(seconds=messages[-1][0])

        cur.execute(
            'SELECT FlightID FROM Flights WHERE Registration = ? AND FlightNumber = ?',
            (reg, flt_no),
        )
        row = cur.fetchone()
        if row:
            flight_id = row[0]
        else:
            cur.execute(
                'INSERT INTO Flights '
                '(Registration, FlightNumber, StartTime, LastTime, NbMessages) '
                'VALUES (?, ?, ?, ?, ?)',
                (reg, flt_no,
                 start_dt.strftime('%Y-%m-%d %H:%M:%S'),
                 last_dt.strftime('%Y-%m-%d %H:%M:%S'),
                 len(messages)),
            )
            flight_id = cur.lastrowid

        for offset, channel, error, signal_lvl, mode, ack, label, block_no, mess_no, txt in messages:
            msg_time = start_dt + timedelta(seconds=offset)
            st_id    = (channel % len(ACARS_STATIONS)) + 1
            cur.execute(
                'INSERT INTO Messages '
                '(FlightID, Time, StID, Channel, Error, SignalLvl, '
                ' Mode, Ack, Label, BlockNo, MessNo, Txt) '
                'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                (flight_id, msg_time.strftime('%Y-%m-%d %H:%M:%S'),
                 st_id, channel, error, signal_lvl,
                 mode, ack, label, block_no, mess_no, txt),
            )
        total_msgs += len(messages)
        print(f'  ACARS {flt_no:6s} ({reg})  {len(messages):3d} messages')

    conn.commit()
    conn.close()
    print(f'  ACARS total    : {total_msgs} messages across {len(ACARS_FLIGHTS)} flights')


def seed_portal_db():
    """Seed users and settings into the main portal database."""
    conn = sqlite3.connect(DB_PATH)
    cur  = conn.cursor()

    for name, email, password, administrator, role in USERS:
        cur.execute('SELECT id FROM users WHERE email = ?', (email,))
        if not cur.fetchone():
            cur.execute(
                'INSERT INTO users (name, email, password, administrator, role) '
                'VALUES (?, ?, ?, ?, ?)',
                (name, email, password, administrator, role),
            )
    print(f'  Users          : {len(USERS)}')

    for name, value in SETTINGS:
        cur.execute('SELECT id FROM settings WHERE name = ?', (name,))
        if not cur.fetchone():
            cur.execute(
                'INSERT INTO settings (name, value) VALUES (?, ?)',
                (name, value),
            )
    print(f'  Settings       : {len(SETTINGS)}')

    for name, address in LINKS:
        cur.execute('SELECT id FROM links WHERE name = ?', (name,))
        if not cur.fetchone():
            cur.execute(
                'INSERT INTO links (name, address) VALUES (?, ?)',
                (name, address),
            )
    print(f'  Links          : {len(LINKS)}')

    conn.commit()
    conn.close()


def seed_dump978():
    """Seed dump978_aircraft, dump978_flights, and dump978_positions tables."""
    conn = sqlite3.connect(DB_PATH)
    cur  = conn.cursor()

    total_pos = 0

    for icao, callsign, segments in UAT_FLIGHTS:
        overall_first = segments[0][3].strftime('%Y-%m-%d %H:%M:%S')
        last_seg      = segments[-1]
        overall_last  = (last_seg[3] + timedelta(minutes=last_seg[4])).strftime('%Y-%m-%d %H:%M:%S')

        # Insert aircraft (skip if already present)
        cur.execute('SELECT id FROM dump978_aircraft WHERE icao = ?', (icao,))
        row = cur.fetchone()
        if row:
            aircraft_id = row[0]
        else:
            cur.execute(
                'INSERT INTO dump978_aircraft (icao, first_seen, last_seen) VALUES (?, ?, ?)',
                (icao, overall_first, overall_last),
            )
            aircraft_id = cur.lastrowid

        # Insert a flights row only when a callsign is present
        if callsign is not None:
            cur.execute(
                'SELECT id FROM dump978_flights WHERE flight = ? AND aircraft = ?',
                (callsign, aircraft_id),
            )
            row = cur.fetchone()
            if row:
                flight_id = row[0]
            else:
                cur.execute(
                    'INSERT INTO dump978_flights (aircraft, flight, first_seen, last_seen) '
                    'VALUES (?, ?, ?, ?)',
                    (aircraft_id, callsign, overall_first, overall_last),
                )
                flight_id = cur.lastrowid
        else:
            flight_id = None

        # Insert position batches
        msg_counter = 1
        for seg in segments:
            lat, lon, hdg, start_dt, dur, turn, spd, alt, sq = seg
            pts = gen_segment(lat, lon, hdg, start_dt, dur, turn, spd, alt, sq)
            for p in pts:
                # UAT positions may have NULL flight and NULL message
                msg_val = msg_counter if sq is not None else None
                cur.execute(
                    'INSERT INTO dump978_positions '
                    '(flight, aircraft, time, message, squawk, '
                    ' latitude, longitude, track, altitude, vertical_rate, speed) '
                    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    (flight_id, aircraft_id,
                     p[0],      # time
                     msg_val,   # message (nullable)
                     p[7],      # squawk
                     p[1],      # latitude
                     p[2],      # longitude
                     p[3],      # track
                     p[4],      # altitude
                     p[5],      # vertical_rate
                     p[6]),     # speed
                )
                if msg_val is not None:
                    msg_counter += 1
            total_pos += len(pts)
            label = callsign or '(no callsign)'
            print(f'  dump978  {label:12s}  {start_dt.date()}  {len(pts):4d} positions')

    conn.commit()
    conn.close()
    print(f'  dump978 total : {total_pos} positions')


def main():
    print('Seeding users and settings ...')
    seed_portal_db()

    conn = sqlite3.connect(DB_PATH)
    cur  = conn.cursor()

    total_pos = 0

    for icao, callsign, segments in FLIGHTS:
        overall_first = segments[0][3].strftime('%Y-%m-%d %H:%M:%S')
        last_seg      = segments[-1]
        overall_last  = (last_seg[3] + timedelta(minutes=last_seg[4])).strftime('%Y-%m-%d %H:%M:%S')

        # Insert aircraft (skip if already present)
        cur.execute('SELECT id FROM dump1090_aircraft WHERE icao = ?', (icao,))
        row = cur.fetchone()
        if row:
            aircraft_id = row[0]
        else:
            cur.execute(
                'INSERT INTO dump1090_aircraft (icao, first_seen, last_seen) VALUES (?, ?, ?)',
                (icao, overall_first, overall_last),
            )
            aircraft_id = cur.lastrowid

        # ONE flights row per callsign (the positions endpoint requires this)
        cur.execute(
            'SELECT id FROM dump1090_flights WHERE flight = ? AND aircraft = ?',
            (callsign, aircraft_id),
        )
        row = cur.fetchone()
        if row:
            flight_id = row[0]
        else:
            cur.execute(
                'INSERT INTO dump1090_flights (aircraft, flight, first_seen, last_seen) VALUES (?, ?, ?, ?)',
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
                    'INSERT INTO dump1090_positions '
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
    print(f'\nDone — {total_pos} dump1090 positions inserted.')

    print('\nSeeding dump978 database ...')
    seed_dump978()

    print('\nSeeding ACARS database ...')
    seed_acars()
    print('\nAll done.')


if __name__ == '__main__':
    main()
