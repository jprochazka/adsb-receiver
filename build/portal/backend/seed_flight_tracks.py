#!/usr/bin/env python3
"""Seed development flight track data with realistic, type-aware manoeuvres.

This script rewrites *all* flight position rows in the development SQLite
database so each track:
- is at least 150 statute miles long (great-circle distance covered),
- contains sharp turns whose rate matches the aircraft class (rotorcraft
  can bank far harder than a heavy jet),
- has the ``track`` column at first and last position equal to the
  instantaneous heading, so start/end points face the correct direction,
- uses a per-second sample cadence for smooth OpenLayers rendering.
"""

from __future__ import annotations

import math
import random
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta
from statistics import mean

from backend import create_app

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SAMPLE_SECONDS = 1
TRACK_LENGTH_MILES = 150.0
MILES_TO_NM = 0.868976
TRACK_LENGTH_NM = TRACK_LENGTH_MILES * MILES_TO_NM
EARTH_RADIUS_NM = 3440.065


# ---------------------------------------------------------------------------
# Per-aircraft-class profiles
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class AircraftProfile:
    """Flight-dynamics envelope for a category of aircraft."""
    speed_min_kts: float
    speed_max_kts: float
    max_turn_rate_deg_s: float   # peak sustained turn rate
    sharp_turn_rate_deg_s: float  # aggressive manoeuvre bursts
    cruise_alt_min: int
    cruise_alt_max: int


PROFILES: dict[str, AircraftProfile] = {
    # Large airliners – limited by passenger comfort and structural limits
    'large': AircraftProfile(
        speed_min_kts=280, speed_max_kts=460,
        max_turn_rate_deg_s=1.8, sharp_turn_rate_deg_s=3.0,
        cruise_alt_min=28000, cruise_alt_max=41000,
    ),
    # Heavy widebodies – even less agile
    'heavy': AircraftProfile(
        speed_min_kts=300, speed_max_kts=480,
        max_turn_rate_deg_s=1.5, sharp_turn_rate_deg_s=2.5,
        cruise_alt_min=32000, cruise_alt_max=43000,
    ),
    # Small GA / turboprops
    'small': AircraftProfile(
        speed_min_kts=90, speed_max_kts=210,
        max_turn_rate_deg_s=3.0, sharp_turn_rate_deg_s=6.0,
        cruise_alt_min=2000, cruise_alt_max=12000,
    ),
    # Rotorcraft – very agile
    'rotorcraft': AircraftProfile(
        speed_min_kts=60, speed_max_kts=160,
        max_turn_rate_deg_s=6.0, sharp_turn_rate_deg_s=12.0,
        cruise_alt_min=500, cruise_alt_max=6000,
    ),
    # Fallback
    'unknown': AircraftProfile(
        speed_min_kts=200, speed_max_kts=400,
        max_turn_rate_deg_s=2.0, sharp_turn_rate_deg_s=3.5,
        cruise_alt_min=15000, cruise_alt_max=35000,
    ),
}


def _profile_for(aircraft_class: str) -> AircraftProfile:
    return PROFILES.get(aircraft_class, PROFILES['unknown'])


# ---------------------------------------------------------------------------
# Turn-phase builder – creates a sequence of legs with sharp turns suited
# to the aircraft type.  Each flight gets a unique, deterministic pattern.
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class Phase:
    duration_s: int
    turn_rate_deg_s: float


def _build_phases(profile: AircraftProfile, flight_id: int) -> list[Phase]:
    """Generate a repeatable but varied leg/turn pattern for *flight_id*.

    The pattern alternates straight legs with 2-4 sharp turns so the
    overall track has visible direction changes on a map.
    """
    rng = random.Random(flight_id * 7 + 31)

    phases: list[Phase] = []
    n_turns = rng.randint(3, 5)

    for i in range(n_turns):
        # Straight leg -------------------------------------------------------
        straight_s = rng.randint(180, 500)
        phases.append(Phase(straight_s, 0.0))

        # Sharp turn ---------------------------------------------------------
        # Alternate direction, but let the RNG flip occasionally.
        direction = 1.0 if (i % 2 == 0) else -1.0
        if rng.random() < 0.3:
            direction *= -1.0

        # Use the *sharp* turn rate most of the time so the turns are visible.
        use_sharp = rng.random() < 0.7
        rate = profile.sharp_turn_rate_deg_s if use_sharp else profile.max_turn_rate_deg_s
        rate *= direction

        # Turn for 15-50 degrees of heading change (duration = delta / rate).
        turn_degrees = rng.uniform(35.0, 110.0)
        turn_s = max(4, int(turn_degrees / abs(rate)))
        phases.append(Phase(turn_s, rate))

    # Final straight leg
    phases.append(Phase(rng.randint(200, 500), 0.0))

    return phases


# ---------------------------------------------------------------------------
# Geodesic helpers
# ---------------------------------------------------------------------------

def direct_geodesic(lat_deg: float, lon_deg: float, bearing_deg: float, distance_nm: float) -> tuple[float, float]:
    lat1 = math.radians(lat_deg)
    lon1 = math.radians(lon_deg)
    brng = math.radians(bearing_deg)
    ang = distance_nm / EARTH_RADIUS_NM

    lat2 = math.asin(
        math.sin(lat1) * math.cos(ang) + math.cos(lat1) * math.sin(ang) * math.cos(brng)
    )
    lon2 = lon1 + math.atan2(
        math.sin(brng) * math.sin(ang) * math.cos(lat1),
        math.cos(ang) - math.sin(lat1) * math.sin(lat2),
    )
    lon2 = (lon2 + math.pi) % (2 * math.pi) - math.pi
    return math.degrees(lat2), math.degrees(lon2)


def gc_distance_nm(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dlat = p2 - p1
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return EARTH_RADIUS_NM * c


def wrap_heading(h: float) -> float:
    return h % 360.0


# ---------------------------------------------------------------------------
# Track generator
# ---------------------------------------------------------------------------

def _speed_knots(profile: AircraftProfile, flight_id: int, t_seconds: int) -> float:
    """Deterministic speed with gentle sinusoidal wobble."""
    mid = (profile.speed_min_kts + profile.speed_max_kts) / 2.0
    half_range = (profile.speed_max_kts - profile.speed_min_kts) / 2.0
    base = mid + (flight_id % 7 - 3) * (half_range * 0.15)
    wobble = half_range * 0.08 * math.sin(t_seconds / 150.0 + flight_id % 5)
    return max(profile.speed_min_kts, min(profile.speed_max_kts, base + wobble))


def generate_track(
    flight_id: int,
    aircraft_id: int,
    aircraft_class: str,
    start_time: datetime,
    start_lat: float,
    start_lon: float,
    initial_heading: float,
    start_message: int,
) -> tuple[list[tuple], int, float]:
    """Build one track of >= 150 statute miles with type-appropriate turns.

    Returns (position_rows, next_message, final_heading, path_nm).
    """
    profile = _profile_for(aircraft_class)
    phases = _build_phases(profile, flight_id)

    points: list[tuple] = []
    t = start_time
    lat, lon = start_lat, start_lon
    heading = initial_heading
    msg = start_message

    phase_i = 0
    phase_elapsed = 0
    elapsed = 0
    total_nm = 0.0

    cruise_alt = profile.cruise_alt_min + (
        (flight_id * 37) % (profile.cruise_alt_max - profile.cruise_alt_min + 1)
    )

    while total_nm < TRACK_LENGTH_NM:
        phase = phases[phase_i % len(phases)]
        heading = wrap_heading(heading + phase.turn_rate_deg_s * SAMPLE_SECONDS)

        speed = _speed_knots(profile, flight_id, elapsed)
        step_nm = speed * (SAMPLE_SECONDS / 3600.0)
        lat, lon = direct_geodesic(lat, lon, heading, step_nm)
        total_nm += step_nm

        altitude = cruise_alt + int(900 * math.sin(elapsed / 130.0)) + int(400 * math.cos(elapsed / 47.0))
        vertical_rate = int(160 * math.sin(elapsed / 33.0))
        squawk = 1200 + ((flight_id * 23 + elapsed) % 6400)

        points.append((
            flight_id,
            aircraft_id,
            t.strftime('%Y-%m-%d %H:%M:%S'),
            msg,
            squawk,
            lat,
            lon,
            int(round(heading)) % 360,
            altitude,
            vertical_rate,
            speed,
        ))

        msg += 1
        elapsed += SAMPLE_SECONDS
        t += timedelta(seconds=SAMPLE_SECONDS)
        phase_elapsed += SAMPLE_SECONDS
        if phase_elapsed >= phase.duration_s:
            phase_i += 1
            phase_elapsed = 0

    return points, msg, heading, total_nm


# ---------------------------------------------------------------------------
# Reseed all flights
# ---------------------------------------------------------------------------

def reseed_flights(conn: sqlite3.Connection, flights_table: str, aircraft_table: str, pos_table: str) -> dict:
    """Delete existing positions for every flight and replace with realistic tracks."""
    flights = conn.execute(
        f"SELECT id, aircraft, flight, aircraft_class FROM {flights_table} ORDER BY id"
    ).fetchall()

    if not flights:
        return {'flights': 0}

    next_msg = int(conn.execute(
        f"SELECT COALESCE(MAX(message), 0) AS m FROM {pos_table}"
    ).fetchone()['m'] or 0) + 1

    stats_points: list[int] = []
    stats_distance: list[float] = []
    stats_max_turn: list[float] = []

    for flight in flights:
        flight_id = flight['id']
        aircraft_id = flight['aircraft']
        aircraft_class = flight['aircraft_class'] or 'unknown'

        # Deterministic start position near NE Ohio
        base_lat = 41.37 + ((flight_id % 13) - 6) * 0.03
        base_lon = -82.10 + ((flight_id % 15) - 7) * 0.035
        heading0 = (24 + (flight_id * 29) % 300) % 360
        start_time = datetime(2026, 4, 2, 6, 0, 0) + timedelta(minutes=flight_id * 7)

        points, next_msg, final_heading, path_nm = generate_track(
            flight_id,
            aircraft_id,
            aircraft_class,
            start_time,
            base_lat,
            base_lon,
            heading0,
            next_msg,
        )

        # Delete old positions and insert new
        conn.execute(f'DELETE FROM {pos_table} WHERE flight = ?', (flight_id,))
        conn.executemany(
            f'INSERT INTO {pos_table}'
            f' (flight, aircraft, time, message, squawk, latitude, longitude,'
            f'  track, altitude, vertical_rate, speed)'
            f' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            points,
        )

        # Update first/last seen
        first_seen = points[0][2]
        last_seen = points[-1][2]
        conn.execute(
            f'UPDATE {flights_table} SET first_seen=?, last_seen=? WHERE id=?',
            (first_seen, last_seen, flight_id),
        )
        conn.execute(
            f'UPDATE {aircraft_table} SET last_seen=? WHERE id=?',
            (last_seen, aircraft_id),
        )

        # Stats
        start_pt = (points[0][5], points[0][6])
        end_pt = (points[-1][5], points[-1][6])
        profile = _profile_for(aircraft_class)

        stats_points.append(len(points))
        stats_distance.append(path_nm / MILES_TO_NM)  # path length in statute miles
        stats_max_turn.append(profile.sharp_turn_rate_deg_s)

    return {
        'flights': len(flights),
        'avg_points_per_flight': round(mean(stats_points), 1),
        'min_track_miles': round(min(stats_distance), 1),
        'avg_track_miles': round(mean(stats_distance), 1),
        'max_sharp_turn_deg_s': round(max(stats_max_turn), 1),
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    app = create_app()
    uri = app.config['SQLALCHEMY_DATABASE_URI']
    if not uri.startswith('sqlite:///'):
        raise SystemExit(f'Expected sqlite database URI, got: {uri}')

    db_path = uri.replace('sqlite:///', '', 1)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    with conn:
        adsb = reseed_flights(
            conn,
            flights_table='dump1090_flights',
            aircraft_table='dump1090_aircraft',
            pos_table='dump1090_positions',
        )
        uat = reseed_flights(
            conn,
            flights_table='dump978_flights',
            aircraft_table='dump978_aircraft',
            pos_table='dump978_positions',
        )

    conn.close()

    print('Flight tracks reseeded with type-aware turns (>= 150 mi each).')
    print(f'  ADS-B: {adsb}')
    print(f'  UAT:   {uat}')
    print(f'  Database: {db_path}')


if __name__ == '__main__':
    main()
