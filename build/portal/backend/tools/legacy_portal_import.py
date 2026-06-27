#!/usr/bin/env python3
"""
legacy_portal_import.py — import normalized legacy PHP ADS-B Portal data into
the new Flask/SQLAlchemy portal database.

Usage:
    python3 legacy_portal_import.py \\
        --config /path/to/config.yml \\
        --root /legacy/portal/root \\
        [--db-password PASSWORD] \\
        [--dry-run]

The tool:
  1. Runs discovery (via legacy_portal_discover) to read source data.
  2. Backs up the target database before writing anything.
  3. Imports in FK-safe order:
       users -> settings -> blog_posts -> links -> notifications
       -> dump1090_aircraft -> dump1090_flights -> dump1090_positions
  4. Skips duplicate rows (by natural key) and logs them.
  5. Remaps old aircraft/flight integer IDs to new IDs.
  6. Rolls back the entire import on any fatal error.
  7. Prints a JSON summary to stdout.

Exit codes:
  0  success
  1  fatal error (stderr has details)
"""

import argparse
import json
import os
import re
import shutil
import sqlite3
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

import yaml

# ---------------------------------------------------------------------------
# Make discover importable from sibling directory.
# ---------------------------------------------------------------------------
_TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_TOOLS_DIR))
import legacy_portal_discover as lpd  # noqa: E402

# ---------------------------------------------------------------------------
# Config / DB URL helpers
# ---------------------------------------------------------------------------

def _load_config(config_path: str) -> dict:
    with open(config_path, "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def _build_sqlalchemy_url(config: dict, db_password_override: str = "") -> str:
    """Return a SQLAlchemy URL string from config.yml database section."""
    db_cfg = config.get("database", {})
    driver = db_cfg.get("use", "sqlite").lower()

    if driver == "sqlite":
        # Default SQLite path mirrors the Flask app convention.
        instance_dir = Path(config.get("_instance_dir", "instance"))
        sqlite_path = instance_dir / "adsbportal.sqlite3"
        return f"sqlite:///{sqlite_path}"

    if driver == "mysql":
        c = db_cfg.get("mysql", {})
        pw = db_password_override or c.get("password", "")
        return (
            f"mysql+mysqldb://{c['user']}:{pw}"
            f"@{c['host']}/{c['database']}?charset=utf8mb4"
        )

    if driver in ("postgresql", "postgres"):
        c = db_cfg.get("postgresql", {})
        pw = db_password_override or c.get("password", "")
        return f"postgresql+psycopg2://{c['user']}:{pw}@{c['host']}/{c['database']}"

    raise ValueError(f"Unsupported database driver in config: {driver!r}")


def _sqlite_path_from_url(url: str) -> str | None:
    """Extract the file path from a sqlite:/// URL, or None."""
    m = re.match(r"sqlite:///(.+)", url)
    return m.group(1) if m else None


# ---------------------------------------------------------------------------
# Backup helpers
# ---------------------------------------------------------------------------

def _backup_sqlite(db_path: str) -> str | None:
    """
    Copy an existing SQLite file to a timestamped .bak path.
    Returns the backup path, or None if source didn't exist.
    """
    if not os.path.isfile(db_path):
        return None
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup_path = f"{db_path}.bak.{ts}"
    shutil.copy2(db_path, backup_path)
    return backup_path


# ---------------------------------------------------------------------------
# Source data readers (XML + SQLite)
# ---------------------------------------------------------------------------

def _xml_records(xml_path: str | None, record_tag: str) -> list[ET.Element]:
    if not xml_path or not os.path.isfile(xml_path):
        return []
    try:
        tree = ET.parse(xml_path)
        return [el for el in tree.getroot() if el.tag == record_tag]
    except Exception:
        return []


def _text(el: ET.Element, tag: str, default: str = "") -> str:
    child = el.find(tag)
    return (child.text or default).strip() if child is not None else default


def _sqlite_rows(db_path: str, prefix: str, table: str,
                 columns: list[str]) -> list[dict]:
    """Fetch rows from a legacy SQLite table as list-of-dicts. Read-only."""
    full_table = f"{prefix}{table}"
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        col_str = ", ".join(f"[{c}]" for c in columns)
        rows = conn.execute(f"SELECT {col_str} FROM [{full_table}]").fetchall()
        conn.close()
        return [dict(r) for r in rows]
    except Exception:
        return []


# ---------------------------------------------------------------------------
# Datetime normalisation
# ---------------------------------------------------------------------------

def _iso(value: str | None) -> str:
    """Convert legacy datetime strings to ISO-8601. Returns empty string on failure."""
    if not value:
        return ""
    value = str(value).strip()
    # Already ISO-8601 with T separator
    if "T" in value:
        return value
    # MySQL/SQLite datetime: '2023-01-15 10:30:00' -> '2023-01-15T10:30:00'
    return value.replace(" ", "T", 1)


# ---------------------------------------------------------------------------
# Import: independent tables
# ---------------------------------------------------------------------------

def _import_users_xml(conn: sqlite3.Connection, xml_files: dict,
                      dry_run: bool, now_str: str) -> dict:
    records = _xml_records(xml_files.get("administrators"), "administrator")
    imported = skipped = failed = 0
    for el in records:
        email = _text(el, "email")
        if not email:
            failed += 1
            continue
        name = _text(el, "name") or email
        password = _text(el, "password")
        existing = conn.execute(
            "SELECT id FROM users WHERE email = ?", (email,)
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute(
                """INSERT INTO users
                   (name, email, password, administrator, role, locked, created_at)
                   VALUES (?, ?, ?, 1, 'Admin', 0, ?)""",
                (name, email, password, now_str),
            )
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


def _import_users_sqlite(conn: sqlite3.Connection, src_path: str, prefix: str,
                          dry_run: bool, now_str: str) -> dict:
    rows = _sqlite_rows(src_path, prefix, "administrators",
                        ["id", "name", "email", "login", "password"])
    imported = skipped = failed = 0
    for row in rows:
        email = (row.get("email") or "").strip()
        if not email:
            failed += 1
            continue
        existing = conn.execute(
            "SELECT id FROM users WHERE email = ?", (email,)
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute(
                """INSERT INTO users
                   (name, email, password, administrator, role, locked, created_at)
                   VALUES (?, ?, ?, 1, 'Admin', 0, ?)""",
                (row.get("name") or email,
                 email,
                 row.get("password") or "",
                 now_str),
            )
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


def _import_settings(conn: sqlite3.Connection, settings: list[dict],
                     dry_run: bool) -> dict:
    """Import allow-listed settings. Skip if name already exists."""
    imported = skipped = 0
    for s in settings:
        name = s.get("name", "").strip()
        value = s.get("value", "")
        if not name:
            continue
        existing = conn.execute(
            "SELECT id FROM settings WHERE name = ?", (name,)
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute(
                "INSERT INTO settings (name, value) VALUES (?, ?)", (name, value)
            )
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": 0}


def _import_blog_xml(conn: sqlite3.Connection, xml_files: dict,
                     dry_run: bool) -> dict:
    records = _xml_records(xml_files.get("blog_posts"), "blogPost")
    imported = skipped = failed = 0
    for el in records:
        title = _text(el, "title")
        date = _text(el, "date")
        author = _text(el, "author")
        contents = _text(el, "contents")
        if not title:
            failed += 1
            continue
        existing = conn.execute(
            "SELECT id FROM blog_posts WHERE title = ? AND date = ? AND author = ?",
            (title, date, author),
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute(
                """INSERT INTO blog_posts
                   (title, date, author, content, visible, tags, category)
                   VALUES (?, ?, ?, ?, 1, '', '')""",
                (title, date, author, contents),
            )
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


def _import_blog_sqlite(conn: sqlite3.Connection, src_path: str, prefix: str,
                         dry_run: bool) -> dict:
    rows = _sqlite_rows(src_path, prefix, "blogPosts",
                        ["id", "title", "date", "author", "contents"])
    imported = skipped = failed = 0
    for row in rows:
        title = (row.get("title") or "").strip()
        if not title:
            failed += 1
            continue
        date = str(row.get("date") or "")
        author = str(row.get("author") or "")
        existing = conn.execute(
            "SELECT id FROM blog_posts WHERE title = ? AND date = ? AND author = ?",
            (title, date, author),
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute(
                """INSERT INTO blog_posts
                   (title, date, author, content, visible, tags, category)
                   VALUES (?, ?, ?, ?, 1, '', '')""",
                (title, date, author, str(row.get("contents") or "")),
            )
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


def _import_links_xml(conn: sqlite3.Connection, xml_files: dict,
                      dry_run: bool) -> dict:
    records = _xml_records(xml_files.get("links"), "link")
    imported = skipped = failed = 0
    for i, el in enumerate(records):
        name = _text(el, "name")
        address = _text(el, "address")
        if not name or not address:
            failed += 1
            continue
        existing = conn.execute(
            "SELECT id FROM links WHERE address = ?", (address,)
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute(
                "INSERT INTO links (name, address, sort_order) VALUES (?, ?, ?)",
                (name, address, i),
            )
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


def _import_links_sqlite(conn: sqlite3.Connection, src_path: str, prefix: str,
                          dry_run: bool) -> dict:
    rows = _sqlite_rows(src_path, prefix, "links", ["id", "name", "address"])
    imported = skipped = failed = 0
    for i, row in enumerate(rows):
        name = (row.get("name") or "").strip()
        address = (row.get("address") or "").strip()
        if not name or not address:
            failed += 1
            continue
        existing = conn.execute(
            "SELECT id FROM links WHERE address = ?", (address,)
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute(
                "INSERT INTO links (name, address, sort_order) VALUES (?, ?, ?)",
                (name, address, i),
            )
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


def _import_notifications_xml(conn: sqlite3.Connection, xml_files: dict,
                               dry_run: bool) -> dict:
    records = _xml_records(xml_files.get("notifications"), "flight")
    imported = skipped = failed = 0
    for el in records:
        flight = _text(el, "flight").strip()
        if not flight:
            failed += 1
            continue
        existing = conn.execute(
            "SELECT id FROM notifications WHERE flight = ?", (flight,)
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute("INSERT INTO notifications (flight) VALUES (?)", (flight,))
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


def _import_notifications_sqlite(conn: sqlite3.Connection, src_path: str,
                                  prefix: str, dry_run: bool) -> dict:
    rows = _sqlite_rows(src_path, prefix, "flightNotifications", ["id", "flight"])
    imported = skipped = failed = 0
    for row in rows:
        flight = (row.get("flight") or "").strip()
        if not flight:
            failed += 1
            continue
        existing = conn.execute(
            "SELECT id FROM notifications WHERE flight = ?", (flight,)
        ).fetchone()
        if existing:
            skipped += 1
            continue
        if not dry_run:
            conn.execute("INSERT INTO notifications (flight) VALUES (?)", (flight,))
        imported += 1
    return {"imported": imported, "skipped": skipped, "failed": failed}


# ---------------------------------------------------------------------------
# Import: aircraft / flights / positions (FK remapping required)
# ---------------------------------------------------------------------------

def _import_aircraft_sqlite(conn: sqlite3.Connection, src_path: str, prefix: str,
                              dry_run: bool) -> tuple[dict, dict]:
    """
    Returns (counts, old_id -> new_id map).
    """
    rows = _sqlite_rows(src_path, prefix, "aircraft",
                        ["id", "icao", "firstSeen", "lastSeen"])
    imported = skipped = failed = 0
    id_map: dict[int, int] = {}

    for row in rows:
        icao = (row.get("icao") or "").strip().upper()
        if not icao or len(icao) > 8:
            failed += 1
            continue
        first_seen = _iso(str(row.get("firstSeen") or ""))
        last_seen = _iso(str(row.get("lastSeen") or ""))
        if not first_seen:
            failed += 1
            continue

        existing = conn.execute(
            "SELECT id FROM dump1090_aircraft WHERE icao = ?", (icao,)
        ).fetchone()
        if existing:
            id_map[row["id"]] = existing[0]
            skipped += 1
            continue

        if not dry_run:
            cur = conn.execute(
                """INSERT INTO dump1090_aircraft (icao, first_seen, last_seen)
                   VALUES (?, ?, ?)""",
                (icao, first_seen, last_seen),
            )
            new_id = cur.lastrowid
        else:
            new_id = -1  # placeholder for dry-run
        old_id = row.get("id")
        if old_id is not None:
            id_map[int(old_id)] = new_id if new_id is not None else -1
        imported += 1

    return {"imported": imported, "skipped": skipped, "failed": failed}, id_map


def _import_flights_sqlite(conn: sqlite3.Connection, src_path: str, prefix: str,
                            aircraft_map: dict[int, int],
                            dry_run: bool) -> tuple[dict, dict]:
    """
    Returns (counts, old_flight_id -> new_flight_id map).
    """
    rows = _sqlite_rows(src_path, prefix, "flights",
                        ["id", "aircraft", "flight", "firstSeen", "lastSeen"])
    imported = skipped = failed = 0
    id_map: dict[int, int] = {}

    for row in rows:
        old_flight_id_src = row.get("id")
        old_aircraft_id_src = row.get("aircraft")
        new_aircraft_id = aircraft_map.get(int(old_aircraft_id_src)) if old_aircraft_id_src is not None else None
        if new_aircraft_id is None or new_aircraft_id < 0:
            failed += 1
            continue

        flight_name = (row.get("flight") or "").strip()
        first_seen = _iso(str(row.get("firstSeen") or ""))
        last_seen = _iso(str(row.get("lastSeen") or ""))
        if not flight_name or not first_seen:
            failed += 1
            continue

        existing = conn.execute(
            """SELECT id FROM dump1090_flights
               WHERE flight = ? AND aircraft = ? AND first_seen = ?""",
            (flight_name, new_aircraft_id, first_seen),
        ).fetchone()
        if existing:
            id_map[row["id"]] = existing[0]
            skipped += 1
            continue

        if not dry_run:
            cur = conn.execute(
                """INSERT INTO dump1090_flights
                   (aircraft, flight, first_seen, last_seen,
                    emitter_category, message_type, aircraft_class, ignore_on_purge)
                   VALUES (?, ?, ?, ?, NULL, NULL, 'unknown', 0)""",
                (new_aircraft_id, flight_name, first_seen, last_seen),
            )
            new_id = cur.lastrowid
        else:
            new_id = -1
        if old_flight_id_src is not None:
            id_map[int(old_flight_id_src)] = new_id if new_id is not None else -1
        imported += 1

    return {"imported": imported, "skipped": skipped, "failed": failed}, id_map


def _import_positions_sqlite(conn: sqlite3.Connection, src_path: str, prefix: str,
                              aircraft_map: dict[int, int],
                              flight_map: dict[int, int],
                              dry_run: bool) -> dict:
    rows = _sqlite_rows(src_path, prefix, "positions", [
        "id", "flight", "aircraft", "time", "message",
        "squawk", "latitude", "longitude", "track", "altitude",
        "verticleRate", "speed",
    ])
    imported = skipped = failed = 0

    for row in rows:
        old_flight_id = row.get("flight")
        old_aircraft_id = row.get("aircraft")

        # Skip rows with NULL flight (can't satisfy NOT NULL FK on new schema).
        if old_flight_id is None:
            failed += 1
            continue

        new_flight_id = flight_map.get(int(old_flight_id))
        new_aircraft_id = aircraft_map.get(int(old_aircraft_id)) if old_aircraft_id is not None else None
        if new_flight_id is None or new_aircraft_id is None:
            failed += 1
            continue
        if new_flight_id < 0 or new_aircraft_id < 0:
            # dry-run placeholder — still count as imported
            imported += 1
            continue

        time_val = _iso(str(row.get("time") or ""))
        lat = row.get("latitude")
        lon = row.get("longitude")
        if not time_val or lat is None or lon is None:
            failed += 1
            continue

        # Validate coordinate ranges.
        try:
            lat = float(lat)
            lon = float(lon)
        except (TypeError, ValueError):
            failed += 1
            continue
        if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            failed += 1
            continue

        if not dry_run:
            conn.execute(
                """INSERT INTO dump1090_positions
                   (flight, aircraft, time, message, squawk,
                    latitude, longitude, track, altitude, vertical_rate, speed)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    new_flight_id, new_aircraft_id, time_val,
                    row.get("message") or 0,
                    row.get("squawk"),
                    lat, lon,
                    row.get("track") or 0,
                    row.get("altitude") or 0,
                    row.get("verticleRate") or 0,
                    row.get("speed"),
                ),
            )
        imported += 1

    return {"imported": imported, "skipped": skipped, "failed": failed}


# ---------------------------------------------------------------------------
# Main import orchestrator
# ---------------------------------------------------------------------------

def run_import(
    config_path: str,
    legacy_root: str,
    db_password: str = "",
    dry_run: bool = False,
) -> dict:
    """
    Orchestrate the full legacy import.

    Returns a summary dict:
        success, dry_run, backup_path, tables: {table: {imported,skipped,failed}}, error
    """
    summary: dict = {
        "success": False,
        "dry_run": dry_run,
        "backup_path": None,
        "tables": {},
        "error": None,
        "imported_at": datetime.now(timezone.utc).isoformat(),
    }

    # 1. Discover source data.
    discovery = lpd.discover(legacy_root, db_password=db_password)
    if not discovery["found"]:
        summary["error"] = f"Legacy portal not found at {legacy_root!r}: {discovery.get('error')}"
        return summary
    if not discovery["importable"]:
        summary["error"] = "Legacy portal found but contains no importable data."
        return summary

    driver = discovery["driver"]
    prefix = discovery["prefix"]
    xml_files = discovery.get("xml_files") or {}
    settings_list = discovery.get("settings") or []

    # 2. Load config and build target DB URL.
    try:
        config = _load_config(config_path)
        # Resolve instance dir relative to config file.
        config["_instance_dir"] = str(Path(config_path).parent / "instance")
        target_url = _build_sqlalchemy_url(config, db_password_override="")
    except Exception as exc:
        summary["error"] = f"Config error: {exc}"
        return summary

    # 3. Backup target SQLite if applicable.
    sqlite_path = _sqlite_path_from_url(target_url)
    if sqlite_path and os.path.isfile(sqlite_path) and not dry_run:
        backup = _backup_sqlite(sqlite_path)
        summary["backup_path"] = backup

    # 4. Open target connection.
    if not target_url.startswith("sqlite:///"):
        summary["error"] = (
            "Only SQLite target is supported in this tool version. "
            "MySQL/PostgreSQL support requires the Flask app context."
        )
        return summary

    assert sqlite_path is not None  # narrowed above
    try:
        target_conn = sqlite3.connect(sqlite_path)
        target_conn.execute("PRAGMA foreign_keys = ON")
    except Exception as exc:
        summary["error"] = f"Cannot open target DB: {exc}"
        return summary

    now_str = datetime.now(timezone.utc).isoformat()

    # 5. Import in FK-safe order inside a transaction.
    try:
        with target_conn:
            # Users
            if driver == "xml":
                summary["tables"]["users"] = _import_users_xml(
                    target_conn, xml_files, dry_run, now_str)
            elif driver == "sqlite":
                summary["tables"]["users"] = _import_users_sqlite(
                    target_conn, discovery["database"], prefix, dry_run, now_str)

            # Settings (allow-list already applied by discover)
            summary["tables"]["settings"] = _import_settings(
                target_conn, settings_list, dry_run)

            # Blog posts
            if driver == "xml":
                summary["tables"]["blog_posts"] = _import_blog_xml(
                    target_conn, xml_files, dry_run)
            elif driver == "sqlite":
                summary["tables"]["blog_posts"] = _import_blog_sqlite(
                    target_conn, discovery["database"], prefix, dry_run)

            # Links
            if driver == "xml":
                summary["tables"]["links"] = _import_links_xml(
                    target_conn, xml_files, dry_run)
            elif driver == "sqlite":
                summary["tables"]["links"] = _import_links_sqlite(
                    target_conn, discovery["database"], prefix, dry_run)

            # Notifications
            if driver == "xml":
                summary["tables"]["notifications"] = _import_notifications_xml(
                    target_conn, xml_files, dry_run)
            elif driver == "sqlite":
                summary["tables"]["notifications"] = _import_notifications_sqlite(
                    target_conn, discovery["database"], prefix, dry_run)

            # Aircraft / flights / positions (SQLite source only for now)
            if driver == "sqlite":
                aircraft_counts, aircraft_map = _import_aircraft_sqlite(
                    target_conn, discovery["database"], prefix, dry_run)
                summary["tables"]["dump1090_aircraft"] = aircraft_counts

                flight_counts, flight_map = _import_flights_sqlite(
                    target_conn, discovery["database"], prefix, aircraft_map, dry_run)
                summary["tables"]["dump1090_flights"] = flight_counts

                summary["tables"]["dump1090_positions"] = _import_positions_sqlite(
                    target_conn, discovery["database"], prefix,
                    aircraft_map, flight_map, dry_run)

        summary["success"] = True

    except Exception as exc:
        summary["error"] = f"Import failed and was rolled back: {exc}"
    finally:
        target_conn.close()

    return summary


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Import legacy PHP ADS-B Portal data into the new portal database."
    )
    parser.add_argument(
        "--config", required=True,
        help="Path to the new portal config.yml."
    )
    parser.add_argument(
        "--root", required=True,
        help="Path to the legacy portal document root."
    )
    parser.add_argument(
        "--db-password", default="",
        help="Database password for legacy MySQL/PostgreSQL source (not logged)."
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Discover and validate without writing any data."
    )
    parser.add_argument(
        "--pretty", action="store_true",
        help="Pretty-print JSON summary output."
    )
    args = parser.parse_args()

    result = run_import(
        config_path=args.config,
        legacy_root=args.root,
        db_password=args.db_password,
        dry_run=args.dry_run,
    )
    indent = 2 if args.pretty else None
    print(json.dumps(result, indent=indent))
    return 0 if result["success"] else 1


if __name__ == "__main__":
    sys.exit(main())
