#!/usr/bin/env python3
"""Seed development flight track data with realistic turn rates.

This script targets TYPE flights in the development SQLite database and rewrites
position rows so each track:
- starts near a local origin (close-by starts),
- does not continue from the previous track end,
- uses smooth turns with bounded heading change per sample.
"""

from __future__ import annotations

import math
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta
from statistics import mean

from backend import create_app

SAMPLE_SECONDS = 1
TRACKS_PER_FLIGHT = 3
TRACK_GAP_HOURS = 3
TRACK_LENGTH_MILES = 150.0
MILES_TO_NM = 0.868976
TRACK_LENGTH_NM = TRACK_LENGTH_MILES * MILES_TO_NM
EARTH_RADIUS_NM = 3440.065


@dataclass(frozen=True)
class Phase:
    duration_s: int
    turn_rate_deg_s: float


# Turn rates are kept near standard-rate turns; short bursts can be slightly higher.
PHASES = [
    Phase(420, 0.0),
    Phase(34, 1.8),    # +61.2 deg
    Phase(340, 0.0),
    Phase(44, -1.7),   # -74.8 deg
    Phase(360, 0.0),
    Phase(30, 1.6),    # +48.0 deg
    Phase(310, 0.0),
    Phase(24, -1.6),   # -38.4 deg
    Phase(300, 0.0),
]


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


def wrap_heading(heading_deg: float) -> float:
    return heading_deg % 360.0


def minimal_heading_delta(new_heading: float, old_heading: float) -> float:
    return ((new_heading - old_heading + 180.0) % 360.0) - 180.0


def speed_knots(flight_id: int, track_index: int, t_seconds: int) -> float:
    base = 305 + (flight_id % 7) * 16 + track_index * 8
    wobble = 14.0 * math.sin((t_seconds / 150.0) + (flight_id % 5))
    return max(240.0, min(460.0, base + wobble))


def generate_track_points(
    flight_id: int,
    aircraft_id: int,
    start_time: datetime,
    start_lat: float,
    start_lon: float,
    initial_heading: float,
    start_message: int,
    track_index: int,
) -> tuple[list[tuple], int, tuple[float, float], tuple[float, float], float]:
    points = []
    t = start_time
    lat = start_lat
    lon = start_lon
    heading = initial_heading
    msg = start_message

    phase_i = 0
    phase_elapsed = 0
    elapsed = 0
    total_nm = 0.0
    max_turn_rate = 0.0

    while total_nm < TRACK_LENGTH_NM:
        phase = PHASES[phase_i]
        heading = wrap_heading(heading + phase.turn_rate_deg_s * SAMPLE_SECONDS)

        speed = speed_knots(flight_id, track_index, elapsed)
        step_nm = speed * (SAMPLE_SECONDS / 3600.0)
        lat, lon = direct_geodesic(lat, lon, heading, step_nm)
        total_nm += step_nm

        altitude = (
            4200
            + track_index * 1100
            + int(900 * math.sin(elapsed / 130.0))
            + int(400 * math.cos(elapsed / 47.0))
        )
        vertical_rate = int(160 * math.sin(elapsed / 33.0))
        squawk = 1200 + ((flight_id * 23 + track_index * 31 + elapsed) % 6400)

        points.append(
            (
                flight_id,
                aircraft_id,
                t.strftime("%Y-%m-%d %H:%M:%S"),
                msg,
                squawk,
                lat,
                lon,
                int(round(heading)) % 360,
                altitude,
                vertical_rate,
                speed,
            )
        )

        max_turn_rate = max(max_turn_rate, abs(phase.turn_rate_deg_s))

        msg += 1
        elapsed += SAMPLE_SECONDS
        t += timedelta(seconds=SAMPLE_SECONDS)

        phase_elapsed += SAMPLE_SECONDS
        if phase_elapsed >= phase.duration_s:
            phase_i = (phase_i + 1) % len(PHASES)
            phase_elapsed = 0

    return points, msg, (start_lat, start_lon), (lat, lon), max_turn_rate


def reseed_type_flights(conn: sqlite3.Connection, flights_table: str, aircraft_table: str, pos_table: str) -> dict:
    flights = conn.execute(
        f"SELECT id, aircraft, flight FROM {flights_table} WHERE flight LIKE 'TYPE%' ORDER BY id"
    ).fetchall()

    next_msg = int(conn.execute(f"SELECT COALESCE(MAX(message), 0) AS m FROM {pos_table}").fetchone()["m"] or 0) + 1

    points_per_flight = []
    max_start_sep_values = []
    end_to_next_start_values = []
    max_step_turn_values = []

    for flight in flights:
        flight_id = flight["id"]
        aircraft_id = flight["aircraft"]

        base_lat = 41.37 + ((flight_id % 13) - 6) * 0.03
        base_lon = -82.10 + ((flight_id % 15) - 7) * 0.035
        heading0 = (24 + (flight_id * 29) % 300) % 360
        first_track_time = datetime(2026, 4, 2, 8, 0, 0) + timedelta(minutes=flight_id * 5)

        all_points = []
        track_starts = []
        track_ends = []
        flight_max_step_turn = 0.0

        for track_i in range(TRACKS_PER_FLIGHT):
            t0 = first_track_time + timedelta(hours=track_i * TRACK_GAP_HOURS)

            # Keep starts close by for the same flight, but independent of previous ends.
            offset_bearing = (flight_id * 17 + track_i * 121) % 360
            offset_nm = 1.0 + track_i * 1.1
            start_lat, start_lon = direct_geodesic(base_lat, base_lon, offset_bearing, offset_nm)
            initial_heading = wrap_heading(heading0 + track_i * 7)

            points, next_msg, start_pt, end_pt, max_turn_rate = generate_track_points(
                flight_id,
                aircraft_id,
                t0,
                start_lat,
                start_lon,
                initial_heading,
                next_msg,
                track_i,
            )
            all_points.extend(points)
            track_starts.append(start_pt)
            track_ends.append(end_pt)
            flight_max_step_turn = max(flight_max_step_turn, max_turn_rate)

        conn.execute(f"DELETE FROM {pos_table} WHERE flight = ?", (flight_id,))
        conn.executemany(
            f"""
            INSERT INTO {pos_table}
            (flight, aircraft, time, message, squawk, latitude, longitude, track, altitude, vertical_rate, speed)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            all_points,
        )

        points_per_flight.append(len(all_points))
        max_step_turn_values.append(flight_max_step_turn)

        first_seen = all_points[0][2]
        last_seen = all_points[-1][2]
        conn.execute(
            f"UPDATE {flights_table} SET first_seen=?, last_seen=? WHERE id=?",
            (first_seen, last_seen, flight_id),
        )
        conn.execute(
            f"UPDATE {aircraft_table} SET last_seen=? WHERE id=?",
            (last_seen, aircraft_id),
        )

        pair_dists = []
        for i in range(len(track_starts)):
            for j in range(i + 1, len(track_starts)):
                pair_dists.append(gc_distance_nm(*track_starts[i], *track_starts[j]))
        if pair_dists:
            max_start_sep_values.append(max(pair_dists))

        for i in range(len(track_ends) - 1):
            end_to_next_start_values.append(gc_distance_nm(*track_ends[i], *track_starts[i + 1]))

    return {
        "flights": len(flights),
        "avg_points_per_flight": round(mean(points_per_flight), 1) if points_per_flight else 0.0,
        "avg_max_start_separation_nm": round(mean(max_start_sep_values), 2) if max_start_sep_values else 0.0,
        "max_start_separation_nm": round(max(max_start_sep_values), 2) if max_start_sep_values else 0.0,
        "avg_end_to_next_start_jump_nm": round(mean(end_to_next_start_values), 2) if end_to_next_start_values else 0.0,
        "min_end_to_next_start_jump_nm": round(min(end_to_next_start_values), 2) if end_to_next_start_values else 0.0,
        "max_turn_rate_deg_per_sec": round(max(max_step_turn_values), 2) if max_step_turn_values else 0.0,
    }


def main() -> None:
    app = create_app()
    uri = app.config["SQLALCHEMY_DATABASE_URI"]
    if not uri.startswith("sqlite:///"):
        raise SystemExit(f"Expected sqlite database URI, got: {uri}")

    db_path = uri.replace("sqlite:///", "", 1)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    with conn:
        adsb_stats = reseed_type_flights(
            conn,
            flights_table="dump1090_flights",
            aircraft_table="dump1090_aircraft",
            pos_table="dump1090_positions",
        )
        uat_stats = reseed_type_flights(
            conn,
            flights_table="dump978_flights",
            aircraft_table="dump978_aircraft",
            pos_table="dump978_positions",
        )

    conn.close()

    print("Reseed complete: TYPE tracks now use turn-rate-limited heading changes.")
    print("ADS-B:", adsb_stats)
    print("UAT:", uat_stats)
    print(f"Sample cadence: {SAMPLE_SECONDS}s | Track length target: {TRACK_LENGTH_MILES} miles")
    print(f"Database: {db_path}")


if __name__ == "__main__":
    main()
