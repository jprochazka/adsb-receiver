"""
Seed the development database with realistic data for debugging.

Usage:
    cd build/portal/backend
    source .venv/bin/activate
    python seed_dev_data.py
"""

import math
import random
from datetime import datetime, timedelta, timezone

from backend import create_app
from backend.models import db

app = create_app()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
NOW = datetime.now(timezone.utc)
DAY = timedelta(days=1)
HOUR = timedelta(hours=1)
MINUTE = timedelta(minutes=1)


def ts(dt: datetime) -> str:
    """Format a datetime as the string format used by the flight tables."""
    return dt.strftime('%Y-%m-%d %H:%M:%S')


def _generate_track(
    start_lat: float,
    start_lon: float,
    heading: int,
    start_alt: int,
    n_points: int,
    dt_start: datetime,
    interval_s: int = 15,
    speed: int = 420,
) -> list[dict]:
    """Return a list of position dicts along a straight-ish path."""
    positions = []
    lat, lon, alt = start_lat, start_lon, start_alt
    rad = math.radians(heading)
    for i in range(n_points):
        # ~0.004 deg ≈ 0.25 nm per tick at mid-latitudes
        lat += math.cos(rad) * 0.004
        lon += math.sin(rad) * 0.006
        alt += random.randint(-200, 200)
        vr = random.choice([0, 0, 64, -64, 128, -128, 256, -256])
        positions.append({
            'time': ts(dt_start + timedelta(seconds=i * interval_s)),
            'message': random.randint(100, 15000),
            'squawk': random.choice([1200, 1200, 1200, 4523, 6721, 7500, 2341]),
            'latitude': round(lat, 6),
            'longitude': round(lon, 6),
            'track': heading + random.randint(-3, 3),
            'altitude': max(500, alt),
            'vertical_rate': vr,
            'speed': speed + random.randint(-10, 10),
        })
    return positions


# Realistic ICAO hex codes and callsigns
# ~75% real ICAO hex codes (will resolve photos on planespotters.net)
# Real aircraft
_ADSB_ICAOS = [
    'A0A08D',  # N7172B  - Cessna 172
    'A1B8DE',  # N2092F  - Piper PA-28
    'A52542',  # N407FX  - FedEx Cessna 208
    'A7E4CB',  # N606NK  - Spirit A320
    'A9D6B4',  # N737WH  - Boeing 737
    'AB2F6E',  # N810UA  - United 737
    'ACBA8E',  # N934DL  - Delta MD-88
    'A03BC8',  # N30401  - United 737 MAX
    'A193F5',  # N187US  - American A321
    'A39D42',  # N339NB  - Delta A319
    'A4D3F1',  # N469WN  - Southwest 737
    'A641E0',  # N534JB  - JetBlue A320
    'A80D2F',  # N615QX  - Horizon DHC-8
    'A98EC6',  # N719AN  - American 777
    'ABDE8E',  # N929VA  - Alaska A321neo
    # Non-real ICAOs (will fallback to type icon)
    'F00001',
    'F00002',
    'F00003',
    'F00004',
    'F00005',
]

# Real GA N-number ICAOs for UAT
_UAT_ICAOS = [
    'A00732',  # N10CX  - Cessna 150
    'A05261',  # N33JP  - Piper PA-32
    'A0F1E2',  # Non-real fallback
    'A08533',  # N51GL  - Beechcraft A36
    'A10A24',  # N1234  - Mooney M20
]

_CALLSIGNS = [
    'AAL123', 'UAL456', 'DAL789', 'SWA321', 'JBU654',
    'SKW987', 'ASA111', 'FFT222', 'NKS333', 'ENY444',
    'RPA555', 'AWI666', 'CPZ777', 'FDX888', 'UPS999',
    'N12345', 'N67890', 'N24680', 'N13579', 'N11223',
]

_CLASSES = [
    'large', 'large', 'large', 'large',
    'small', 'small', 'small',
    'heavy', 'heavy',
    'rotorcraft',
    'unknown',
]

_EMITTER_CATS = ['A1', 'A2', 'A3', 'A4', 'A5', 'B1', 'B2', None]

# Lat/lon around a central US point (NE Ohio-ish)
CENTER_LAT, CENTER_LON = 41.4, -81.8

# Password hash for "password123" (scrypt)
_PW = (
    'scrypt:32768:8:1$XEoHeG2EFi3HHRrA$'
    'de86ac818697150f33adece666e5a6e31d703180467dc0c1d5b69bdc7ca3f330'
    '137d554a08e32054b81989753a4bd4fef72869373e46364052fab79e57f7e41e'
)

# ---------------------------------------------------------------------------
# Seed
# ---------------------------------------------------------------------------
with app.app_context():
    # Wipe existing data
    meta = db.metadata
    with db.engine.begin() as conn:
        for table in reversed(meta.sorted_tables):
            conn.execute(table.delete())

    # ---- Users ----
    db.session.execute(db.text(
        "INSERT INTO users (name, email, password, administrator, role, locked, created_at) VALUES"
        " ('Admin User',   'admin@adsbreceiver.local',   :pw, 1, 'Admin', 0, :t1),"
        " ('Regular User',  'user@adsbreceiver.local',    :pw, 0, 'User',  0, :t2),"
        " ('Another User',  'another@adsbreceiver.local', :pw, 0, 'User',  0, :t3),"
        " ('Locked User',   'locked@adsbreceiver.local',  :pw, 0, 'User',  1, :t4)"
    ), {
        'pw': _PW,
        't1': ts(NOW - 90 * DAY),
        't2': ts(NOW - 60 * DAY),
        't3': ts(NOW - 30 * DAY),
        't4': ts(NOW - 10 * DAY),
    })

    # ---- Settings (all 44 used by the frontend) ----
    settings = [
        # Navigation
        ('flights_nav_enabled',  'true'),
        ('acars_nav_enabled',    'true'),
        ('blog_nav_enabled',     'true'),
        ('links_nav_enabled',    'true'),
        ('info_nav_enabled',     'true'),
        ('map_nav_enabled',      'true'),
        # Live map
        ('live_map_enabled',     'true'),
        ('live_map_refresh_ms',  '5000'),
        ('live_map_center_lat',  str(CENTER_LAT)),
        ('live_map_center_lon',  str(CENTER_LON)),
        ('live_map_default_zoom', '8'),
        ('live_map_trail_points', '20'),
        ('live_map_show_all_seen', 'true'),
        ('live_map_spider_overlay_enabled', 'true'),
        ('live_map_center_icon_enabled', 'true'),
        ('live_map_distance_rings_enabled', 'true'),
        ('live_map_distance_ring_compass_lines_enabled', 'true'),
        ('live_map_distance_ring_count', '4'),
        ('live_map_distance_ring_interval_miles', '25'),
        ('live_map_theoretical_range_enabled', 'false'),
        ('live_map_theoretical_range_json', ''),
        ('live_map_json_url', 'http://127.0.0.1/dump1090/data/aircraft.json'),
        ('live_map_json_url_dump978', 'http://127.0.0.1/dump978/data/aircraft.json'),
        ('live_map_custom_presets', '[]'),
        # Feeder/map links
        ('map_dump1090_enabled',  'true'),
        ('map_dump978_enabled',   'true'),
        ('map_adsbx_enabled',     'true'),
        ('map_pfclient_enabled',  'false'),
        ('map_links_order',       'dump1090,dump978,adsbx,pfclient'),
        # Info/devices page
        ('info_system_enabled',   'true'),
        ('info_graphs_enabled',   'true'),
        ('info_stats_enabled',    'true'),
        ('graphs_measurement_range', 'imperialNautical'),
        ('graphs_measurement_temperature', 'imperial'),
        ('graphs_network_interface', 'eth0'),
        ('graphs_refresh_interval_ms', '15000'),
        ('graphs_dump1090_enabled', 'true'),
        ('graphs_dump978_enabled',  'false'),
        # Flights page
        ('all_tab_enabled',  'true'),
        ('adsb_tab_enabled', 'true'),
        ('uat_tab_enabled',  'true'),
        # Maintenance
        ('purge_older_data', 'true'),
        ('days_to_save',     '30'),
        ('notification_lookback_minutes', '30'),
    ]
    for name, value in settings:
        db.session.execute(
            db.text("INSERT INTO settings (name, value) VALUES (:n, :v)"),
            {'n': name, 'v': value},
        )

    # ---- Links ----
    links = [
        ('FlightAware',    'https://flightaware.com',    1),
        ('FlightRadar24',  'https://flightradar24.com',  2),
        ('ADS-B Exchange', 'https://adsbexchange.com',   3),
        ('OpenSky Network','https://opensky-network.org', 4),
        ('Planespotters',  'https://planespotters.net',  5),
    ]
    for name, addr, order in links:
        db.session.execute(
            db.text("INSERT INTO links (name, address, sort_order) VALUES (:n, :a, :o)"),
            {'n': name, 'a': addr, 'o': order},
        )

    # ---- Blog posts ----
    blog_data = [
        ('Receiver Installation Complete',
         'News', 'update,receiver,hardware',
         'The ADS-B receiver hardware has been installed and is now operational. '
         'We are using a FlightAware Pro Stick Plus with the included 1090 MHz bandpass filter, '
         'connected to a Raspberry Pi 4 running the latest receiver software. Initial reception '
         'range is approximately 200 nautical miles at altitude.'),
        ('Antenna Upgrade — DPD FA-11 Installed',
         'Maintenance', 'antenna,hardware,upgrade',
         'Upgraded from the basic whip antenna to a DPD Productions FA-11 ADS-B antenna. '
         'Mounted at 30 feet AGL on a steel mast. Early results show a 40% increase in '
         'message rate and improved range to the east where terrain was previously blocking.'),
        ('Portal Software Deployed',
         'Updates', 'portal,software,feature',
         'The ADS-B Portal web interface is now live. Features include real-time aircraft '
         'tracking on an interactive map, historical flight data, blog, and system monitoring. '
         'Built with Angular and Flask for responsive performance on the Pi.'),
        ('Monthly Stats — March 2026',
         'News', 'stats,monthly,report',
         'March 2026 reception summary:\n\n'
         '- Total aircraft tracked: 14,823\n'
         '- Total flights logged: 28,456\n'
         '- Max simultaneous aircraft: 87\n'
         '- Average message rate: 412 msg/s\n'
         '- Best range: 247 NM (southwest)\n\n'
         'Performance continues to improve after the antenna upgrade.'),
        ('Added UAT 978 MHz Support',
         'Updates', 'uat,978,feature,upgrade',
         'A second SDR dongle has been installed to receive UAT 978 MHz signals. This captures '
         'traffic from general aviation aircraft equipped with UAT ADS-B Out transponders, '
         'as well as TIS-B and ADS-R rebroadcasts. The portal now shows both ADS-B and UAT traffic.'),
        ('Thunderstorm Season Preparation',
         'Maintenance', 'maintenance,antenna,weather',
         'With thunderstorm season approaching, the antenna mast has been fitted with a proper '
         'lightning arrestor and ground rod. The coax run uses a PolyPhaser IS-50NX-C2 inline '
         'surge protector. All connections have been weatherproofed with self-amalgamating tape.'),
        ('New Flight Classification Feature',
         'Announcements', 'feature,classification,opensky',
         'Aircraft are now automatically classified by type using the OpenSky Network aircraft '
         'database. Each flight displays its classification (large, small, heavy, rotorcraft, etc.) '
         'along with a confidence indicator. This helps identify interesting traffic at a glance.'),
        ('System Performance Tuning',
         'Maintenance', 'performance,tuning,software',
         'Performed several optimizations to reduce CPU and memory usage on the Raspberry Pi:\n\n'
         '- Moved OpenSky classification data into the database (saves ~300 MB RAM)\n'
         '- Added database indexes on frequently-queried flight columns\n'
         '- Tuned dump1090-fa gain settings for optimal signal-to-noise ratio\n\n'
         'Overall CPU usage dropped from 45% to 28% average.'),
        ('Interesting Catch — Military Traffic',
         'News', 'military,interesting,tracking',
         'Spotted some interesting military traffic today. A KC-135R Stratotanker (hex A4D3F1) '
         'was conducting refueling tracks at FL280 about 150 NM to the southwest. Also picked up '
         'a C-17 Globemaster III on approach to a nearby air base. Screenshots saved for the '
         'flight history page.'),
        ('Receiver Uptime Milestone — 100 Days',
         'Announcements', 'milestone,uptime,receiver',
         'The receiver has now been running continuously for 100 days without interruption. '
         'Total stats since initial installation:\n\n'
         '- Flights logged: 89,234\n'
         '- Positions recorded: 12,456,789\n'
         '- Unique aircraft seen: 4,567\n'
         '- Average uptime: 99.97%\n\n'
         'The Raspberry Pi 4 with active cooling has been rock solid.'),
        ('Planned Downtime for SD Card Upgrade',
         'Maintenance', 'maintenance,hardware,downtime',
         'Scheduling brief downtime this weekend to swap the 32 GB SD card for a 128 GB model. '
         'This will give more room for historical flight data and RRD graphs. The migration process '
         'should take about 30 minutes. A full backup will be taken before the swap.'),
        ('Hidden Draft Post',
         'News', 'draft',
         'This post is not visible to the public. It is a draft being worked on.'),
    ]
    for i, (title, category, tags, content) in enumerate(blog_data):
        visible = 0 if i == len(blog_data) - 1 else 1  # last one is draft
        db.session.execute(
            db.text(
                "INSERT INTO blog_posts (title, date, author, content, visible, tags, category) "
                "VALUES (:title, :date, :author, :content, :visible, :tags, :category)"
            ),
            {
                'title': title,
                'date': ts(NOW - (len(blog_data) - i) * 3 * DAY),
                'author': ['Admin User', 'Regular User', 'Another User'][i % 3],
                'content': content,
                'visible': visible,
                'tags': tags,
                'category': category,
            },
        )

    # ---- Blog comments (threaded) ----
    blog_comments = [
        # post_id, user_id, parent_id, content, minutes_after_post, edited, deleted
        (1, 2, None, 'Great to see the receiver up and running! What kind of range are you getting?', 120, False, False),
        (1, 1, 1, 'Thanks! Seeing about 200 NM at higher altitudes, around 120 NM at lower levels.', 180, False, False),
        (1, 3, 1, 'Very nice setup. Have you considered a cavity filter for better selectivity?', 240, False, False),
        (1, 1, 3, 'Good idea, I will look into that. The FA Pro Stick has a built-in filter but a dedicated cavity filter might help.', 300, True, False),
        (3, 2, None, 'The portal looks fantastic! Love the real-time map feature.', 60, False, False),
        (3, 3, 5, 'Agreed, really clean interface. Is the source code available?', 90, False, False),
        (4, 3, None, 'Impressive numbers for March! The antenna upgrade clearly made a difference.', 45, False, False),
        (4, 2, 7, 'Would be interesting to see month-over-month comparisons.', 60, False, False),
        (7, 2, None, 'The classification feature is a great addition. Makes scrolling through flights much more informative.', 30, False, False),
        (9, 1, None, 'Added screenshots of the KC-135 to the flight detail page.', 15, False, False),
        (9, 3, 10, 'Very cool catch! Do you see military traffic often?', 45, False, False),
        (9, 1, 11, 'A few times a week usually. There is a reserve base about 80 NM away.', 60, False, False),
        # A deleted comment
        (10, 2, None, 'This comment was deleted by the user.', 30, False, True),
    ]
    for post_id, user_id, parent_id, content, mins, edited, deleted in blog_comments:
        edited_at = ts(NOW - (12 - post_id) * 3 * DAY + timedelta(minutes=mins + 30)) if edited else None
        deleted_at = ts(NOW - (12 - post_id) * 3 * DAY + timedelta(minutes=mins + 10)) if deleted else None
        db.session.execute(
            db.text(
                "INSERT INTO blog_comments "
                "(blog_post_id, user_id, parent_comment_id, content, created_at, edited, edited_at, deleted, deleted_at) "
                "VALUES (:post, :user, :parent, :content, :created, :edited, :edited_at, :deleted, :deleted_at)"
            ),
            {
                'post': post_id,
                'user': user_id,
                'parent': parent_id,
                'content': content,
                'created': ts(NOW - (12 - post_id) * 3 * DAY + timedelta(minutes=mins)),
                'edited': 1 if edited else 0,
                'edited_at': edited_at,
                'deleted': 1 if deleted else 0,
                'deleted_at': deleted_at,
            },
        )

    # ---- ADS-B Aircraft, Flights & Positions ----
    # Create 20 aircraft
    for icao in _ADSB_ICAOS:
        first = NOW - timedelta(days=random.randint(5, 60))
        last = first + timedelta(hours=random.randint(1, 48))
        db.session.execute(
            db.text("INSERT INTO dump1090_aircraft (icao, first_seen, last_seen) VALUES (:i, :f, :l)"),
            {'i': icao, 'f': ts(first), 'l': ts(last)},
        )

    # Create flights spread across recent days with realistic data
    aircraft_id = 1
    flight_records = []
    for i, callsign in enumerate(_CALLSIGNS):
        ac_id = (i % len(_ADSB_ICAOS)) + 1
        days_ago = random.randint(0, 25)
        hour = random.randint(0, 23)
        first_seen = NOW - timedelta(days=days_ago, hours=hour)
        duration = timedelta(minutes=random.randint(20, 180))
        last_seen = first_seen + duration
        cls = _CLASSES[i % len(_CLASSES)]
        ecat = _EMITTER_CATS[i % len(_EMITTER_CATS)]
        ignore = 1 if callsign == 'N12345' else 0  # one ignored flight

        db.session.execute(
            db.text(
                "INSERT INTO dump1090_flights "
                "(aircraft, flight, first_seen, last_seen, emitter_category, message_type, aircraft_class, ignore_on_purge) "
                "VALUES (:ac, :fl, :fs, :ls, :ec, :mt, :cl, :ig)"
            ),
            {
                'ac': ac_id,
                'fl': callsign,
                'fs': ts(first_seen),
                'ls': ts(last_seen),
                'ec': ecat,
                'mt': 'adsb_icao',
                'cl': cls,
                'ig': ignore,
            },
        )
        flight_records.append((i + 1, ac_id, first_seen, callsign))

    # Positions for each flight — 15-40 points along a track
    for flight_id, ac_id, dt_start, callsign in flight_records:
        heading = random.randint(0, 359)
        start_lat = CENTER_LAT + random.uniform(-1.5, 1.5)
        start_lon = CENTER_LON + random.uniform(-2.0, 2.0)
        start_alt = random.choice([3500, 8000, 18000, 28000, 35000, 38000, 41000])
        n_pts = random.randint(15, 40)
        speed = random.randint(120, 500)

        positions = _generate_track(start_lat, start_lon, heading, start_alt, n_pts, dt_start, speed=speed)
        for pos in positions:
            db.session.execute(
                db.text(
                    "INSERT INTO dump1090_positions "
                    "(flight, aircraft, time, message, squawk, latitude, longitude, track, altitude, vertical_rate, speed) "
                    "VALUES (:fl, :ac, :t, :m, :sq, :lat, :lon, :tr, :alt, :vr, :sp)"
                ),
                {
                    'fl': flight_id,
                    'ac': ac_id,
                    't': pos['time'],
                    'm': pos['message'],
                    'sq': pos['squawk'],
                    'lat': pos['latitude'],
                    'lon': pos['longitude'],
                    'tr': pos['track'],
                    'alt': pos['altitude'],
                    'vr': pos['vertical_rate'],
                    'sp': pos['speed'],
                },
            )

    # ---- Flight Comments (ADS-B) ----
    flight_comments = [
        (1, 1, 'Interesting flight path — looked like a holding pattern over CAVVS intersection.'),
        (1, 2, 'I noticed that too, probably weather-related diversion.'),
        (3, 1, 'Heavy traffic, Boeing 777 based on the hex code.'),
        (5, 3, 'This one was squawking 7500 briefly — false alarm according to FlightAware.'),
        (5, 1, 'Good catch! I saw the squawk change back to 1200 after about 2 minutes.'),
        (8, 2, 'Very low altitude pass, was very loud from the ground!'),
    ]
    for flight_id, user_id, content in flight_comments:
        db.session.execute(
            db.text(
                "INSERT INTO dump1090_flight_comments "
                "(flight_id, user_id, content, created_at, edited, edited_at) "
                "VALUES (:fl, :u, :c, :t, 0, NULL)"
            ),
            {
                'fl': flight_id,
                'u': user_id,
                'c': content,
                't': ts(NOW - timedelta(days=random.randint(0, 10), hours=random.randint(0, 12))),
            },
        )

    # ---- UAT Aircraft, Flights & Positions ----
    for icao in _UAT_ICAOS:
        first = NOW - timedelta(days=random.randint(5, 30))
        last = first + timedelta(hours=random.randint(1, 12))
        db.session.execute(
            db.text("INSERT INTO dump978_aircraft (icao, first_seen, last_seen) VALUES (:i, :f, :l)"),
            {'i': icao, 'f': ts(first), 'l': ts(last)},
        )

    uat_callsigns = ['N901GA', 'N442SP', 'N78KL', 'N210PP', 'N55XR']
    uat_flight_records = []
    for i, callsign in enumerate(uat_callsigns):
        days_ago = random.randint(0, 15)
        first_seen = NOW - timedelta(days=days_ago, hours=random.randint(6, 18))
        last_seen = first_seen + timedelta(minutes=random.randint(30, 120))
        cls = random.choice(['small', 'small', 'small', 'rotorcraft', 'unknown'])
        ecat = random.choice(['A1', 'B1', None])
        db.session.execute(
            db.text(
                "INSERT INTO dump978_flights "
                "(aircraft, flight, first_seen, last_seen, emitter_category, message_type, aircraft_class, ignore_on_purge) "
                "VALUES (:ac, :fl, :fs, :ls, :ec, :mt, :cl, 0)"
            ),
            {
                'ac': i + 1,
                'fl': callsign,
                'fs': ts(first_seen),
                'ls': ts(last_seen),
                'ec': ecat,
                'mt': 'uat',
                'cl': cls,
            },
        )
        uat_flight_records.append((i + 1, i + 1, first_seen))

    for flight_id, ac_id, dt_start in uat_flight_records:
        heading = random.randint(0, 359)
        start_lat = CENTER_LAT + random.uniform(-0.5, 0.5)
        start_lon = CENTER_LON + random.uniform(-0.8, 0.8)
        n_pts = random.randint(10, 25)
        positions = _generate_track(start_lat, start_lon, heading, random.randint(1500, 6000), n_pts, dt_start, speed=random.randint(80, 180))
        for pos in positions:
            db.session.execute(
                db.text(
                    "INSERT INTO dump978_positions "
                    "(flight, aircraft, time, message, squawk, latitude, longitude, track, altitude, vertical_rate, speed) "
                    "VALUES (:fl, :ac, :t, :m, :sq, :lat, :lon, :tr, :alt, :vr, :sp)"
                ),
                {
                    'fl': flight_id,
                    'ac': ac_id,
                    't': pos['time'],
                    'm': pos['message'],
                    'sq': pos['squawk'],
                    'lat': pos['latitude'],
                    'lon': pos['longitude'],
                    'tr': pos['track'],
                    'alt': pos['altitude'],
                    'vr': pos['vertical_rate'],
                    'sp': pos['speed'],
                },
            )

    # ---- UAT Flight Comments ----
    db.session.execute(
        db.text(
            "INSERT INTO dump978_flight_comments "
            "(flight_id, user_id, content, created_at, edited, edited_at) VALUES "
            "(:fl, :u, :c, :t, 0, NULL)"
        ),
        {
            'fl': 1, 'u': 2,
            'c': 'Local Cessna 172 doing pattern work at the county airport.',
            't': ts(NOW - timedelta(days=2)),
        },
    )

    # ---- Notifications ----
    # Recent notifications (within lookback window for the alert bar)
    for callsign in ['AAL123', 'DAL789', 'N901GA']:
        db.session.execute(
            db.text("INSERT INTO notifications (flight) VALUES (:f)"),
            {'f': callsign},
        )

    # ---- OpenSky sample data (using real ICAOs from above) ----
    opensky_data = [
        ('A0A08D', 'small', 'high'),
        ('A1B8DE', 'small', 'medium'),
        ('A52542', 'small', 'high'),
        ('A7E4CB', 'large', 'high'),
        ('A9D6B4', 'large', 'high'),
        ('AB2F6E', 'large', 'high'),
        ('ACBA8E', 'large', 'medium'),
        ('A03BC8', 'large', 'high'),
        ('A193F5', 'large', 'high'),
        ('A39D42', 'large', 'high'),
        ('A4D3F1', 'large', 'high'),
        ('A641E0', 'large', 'high'),
        ('A80D2F', 'small', 'medium'),
        ('A98EC6', 'heavy', 'high'),
        ('ABDE8E', 'large', 'high'),
        ('A00732', 'small', 'high'),
        ('A05261', 'small', 'medium'),
        ('A08533', 'small', 'high'),
        ('A10A24', 'small', 'medium'),
    ]
    for icao, cls, conf in opensky_data:
        db.session.execute(
            db.text("INSERT INTO opensky_aircraft (icao24, aircraft_class, confidence) VALUES (:i, :c, :cf)"),
            {'i': icao, 'c': cls, 'cf': conf},
        )

    db.session.commit()

    # Summary
    counts = {}
    for table in meta.sorted_tables:
        result = db.session.execute(db.text(f"SELECT COUNT(*) FROM {table.name}"))
        counts[table.name] = result.scalar()

    print("\n=== Development database seeded ===\n")
    for name, count in sorted(counts.items()):
        print(f"  {name:.<40} {count:>6}")
    total_positions = counts.get('dump1090_positions', 0) + counts.get('dump978_positions', 0)
    print(f"\n  Total positions .................... {total_positions:>6}")
    print(f"\n  Login: admin@adsbreceiver.local / password123")
    print(f"         user@adsbreceiver.local  / password123\n")
