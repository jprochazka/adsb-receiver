#!/usr/bin/env python3
"""
legacy_portal_discover.py — read-only discovery and export tool for the
legacy PHP ADS-B Portal.

Usage:
    python3 legacy_portal_discover.py --root /var/www/html

Reads the old portal's settings.class.php, detects the storage driver, counts
importable records, and emits a single JSON blob to stdout. The installer
(portal.sh) pipes this output to determine whether to offer an import prompt.

This tool NEVER writes to the legacy source. It only reads.

Exit codes:
    0  — success (JSON written to stdout; found=true or found=false)
    1  — unrecoverable error (stderr has details)
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Settings parser
# ---------------------------------------------------------------------------

SETTINGS_FILENAME = os.path.join("classes", "settings.class.php")

# Old settings whose values are worth importing into the new portal.
SETTINGS_ALLOWLIST = {
    "days_to_save",
    "purge_older_data",
    "timeZone",
    "advancedMapCenterLatitude",
    "advancedMapCenterLongitude",
    "siteName",
    "enableBlog",
    "enableLinks",
    "enableDump1090",
    "enableDump978",
    "enableFlights",
    "enableWebNotifications",
    "measurementRange",
    "measurementTemperature",
    "measurementBandwidth",
    "hideNavbarAndFooter",
    "googleMapsApiKey",
    "enableAcars",
    "acarsserv_database",
}

# Mapping from old setting name to new setting name where they differ.
SETTINGS_RENAME = {
    "networkInterface": "graphs_network_interface",
}


def parse_settings_php(root: str) -> dict:
    """
    Parse constants from <root>/classes/settings.class.php.
    Returns a dict with keys: driver, database, host, username, prefix.
    Raises FileNotFoundError if the file is absent.
    """
    path = os.path.join(root, SETTINGS_FILENAME)
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        content = fh.read()

    def _extract(key: str, default: str = "") -> str:
        # Match:  const db_key = 'value';
        m = re.search(
            rf"const\s+{re.escape(key)}\s*=\s*'([^']*)'", content, re.IGNORECASE
        )
        return m.group(1) if m else default

    driver = _extract("db_driver", "xml")
    database = _extract("db_database")
    host = _extract("db_host")
    username = _extract("db_username")
    prefix = _extract("db_prefix") or "adsb_"

    # SQLite: old installer stored the full file path in db_host when db_database was empty.
    if driver == "sqlite" and not database and host:
        database = host
        host = ""

    return {
        "driver": driver,
        "database": database,
        "host": host,
        "username": username,
        "prefix": prefix,
    }


# ---------------------------------------------------------------------------
# XML discovery helpers
# ---------------------------------------------------------------------------

XML_FILES = {
    "administrators": "administrators.xml",
    "blog_posts":     "blogPosts.xml",
    "notifications":  "flightNotifications.xml",
    "links":          "links.xml",
    "settings":       "settings.xml",
}

# Root element tag -> record element tag for each file.
XML_RECORD_TAGS = {
    "administrators": "administrator",
    "blogPosts":      "blogPost",
    "flights":        "flight",
    "links":          "link",
    "settings":       "setting",
}


def _count_xml(path: str) -> int:
    """Return the number of child elements in an XML file, or 0 on error."""
    try:
        tree = ET.parse(path)
        return len(list(tree.getroot()))
    except Exception:
        return 0


def discover_xml(root: str) -> dict:
    """
    Discover legacy XML data files under <root>/data/.
    Returns counts dict and a list of xml_files dicts.
    """
    data_dir = os.path.join(root, "data")
    xml_files = {}
    counts = {}

    for key, filename in XML_FILES.items():
        full_path = os.path.join(data_dir, filename)
        exists = os.path.isfile(full_path)
        xml_files[key] = full_path if exists else None
        counts[key] = _count_xml(full_path) if exists else 0

    return {"xml_files": xml_files, "counts": counts}


# ---------------------------------------------------------------------------
# SQLite discovery helpers
# ---------------------------------------------------------------------------


def _sqlite_table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone()
    return bool(row and row[0])


def _sqlite_count(conn: sqlite3.Connection, table: str) -> int:
    try:
        return conn.execute(f"SELECT COUNT(*) FROM [{table}]").fetchone()[0]
    except Exception:
        return 0


def discover_sqlite(database_path: str, prefix: str) -> dict:
    """
    Open a legacy SQLite database read-only and count rows in each importable table.
    Returns counts dict.
    """
    if not os.path.isfile(database_path):
        return {"error": f"SQLite file not found: {database_path}", "counts": {}}

    uri = f"file:{database_path}?mode=ro"
    try:
        conn = sqlite3.connect(uri, uri=True)
    except sqlite3.OperationalError as exc:
        return {"error": str(exc), "counts": {}}

    tables = ["administrators", "aircraft", "blogPosts", "flights",
              "links", "flightNotifications", "positions", "settings"]
    counts = {}
    for table in tables:
        full_name = f"{prefix}{table}"
        if _sqlite_table_exists(conn, full_name):
            counts[table] = _sqlite_count(conn, full_name)
        else:
            counts[table] = None  # None = table absent (old install may be missing it)

    conn.close()
    return {"counts": counts}


# ---------------------------------------------------------------------------
# MySQL / PostgreSQL discovery helpers
# ---------------------------------------------------------------------------


def _sql_count_mysql(host: str, username: str, password: str,
                     database: str, table: str) -> int | None:
    try:
        import MySQLdb  # type: ignore
        conn = MySQLdb.connect(host=host, user=username, passwd=password,
                               db=database, connect_timeout=5)
        cur = conn.cursor()
        cur.execute(f"SELECT COUNT(*) FROM `{table}`")
        count = cur.fetchone()[0]
        conn.close()
        return count
    except Exception:
        return None


def _sql_count_pgsql(host: str, username: str, password: str,
                     database: str, table: str) -> int | None:
    try:
        import psycopg2  # type: ignore
        conn = psycopg2.connect(host=host, user=username, password=password,
                                dbname=database, connect_timeout=5)
        cur = conn.cursor()
        cur.execute(f'SELECT COUNT(*) FROM "{table}"')
        row = cur.fetchone()
        count = row[0] if row else 0
        conn.close()
        return count
    except Exception:
        return None


def discover_sql(driver: str, host: str, username: str, password: str,
                 database: str, prefix: str) -> dict:
    """Count rows in each importable legacy SQL table for mysql/pgsql drivers."""
    tables = ["administrators", "aircraft", "blogPosts", "flights",
              "links", "flightNotifications", "positions", "settings"]
    counts = {}
    count_fn = _sql_count_mysql if driver == "mysql" else _sql_count_pgsql

    for table in tables:
        full_name = f"{prefix}{table}"
        counts[table] = count_fn(host, username, password, database, full_name)

    return {"counts": counts}


# ---------------------------------------------------------------------------
# Settings export helper (read-only)
# ---------------------------------------------------------------------------


def export_settings_xml(xml_path: str) -> list[dict]:
    """Read settings from legacy XML and return allow-listed name/value pairs."""
    if not xml_path or not os.path.isfile(xml_path):
        return []
    try:
        tree = ET.parse(xml_path)
    except Exception:
        return []

    results = []
    for setting in tree.getroot():
        name_el = setting.find("name")
        value_el = setting.find("value")
        if name_el is None or value_el is None:
            continue
        old_name = (name_el.text or "").strip()
        value = (value_el.text or "").strip()
        new_name = SETTINGS_RENAME.get(old_name, old_name)
        if new_name in SETTINGS_ALLOWLIST or old_name in SETTINGS_RENAME:
            results.append({"name": new_name, "value": value, "source_name": old_name})
    return results


def export_settings_sqlite(conn: sqlite3.Connection, prefix: str) -> list[dict]:
    """Read settings from legacy SQLite and return allow-listed name/value pairs."""
    table = f"{prefix}settings"
    if not _sqlite_table_exists(conn, table):
        return []
    rows = conn.execute(f"SELECT name, value FROM [{table}]").fetchall()
    results = []
    for old_name, value in rows:
        new_name = SETTINGS_RENAME.get(old_name, old_name)
        if new_name in SETTINGS_ALLOWLIST or old_name in SETTINGS_RENAME:
            results.append({"name": new_name, "value": value or "", "source_name": old_name})
    return results


# ---------------------------------------------------------------------------
# Main discovery entry point
# ---------------------------------------------------------------------------


def _has_importable_data(counts: dict) -> bool:
    """Return True if at least one table/file has at least one row."""
    return any(v is not None and v > 0 for v in counts.values())


def discover(root: str, db_password: str = "") -> dict:
    """
    Full discovery pass for a legacy portal root.

    Returns a result dict ready for JSON serialisation:
        found        bool
        root         str
        driver       str
        database     str
        host         str
        username     str
        prefix       str
        importable   bool
        counts       dict
        xml_files    dict | None
        settings     list[dict]   (allow-listed settings ready to import)
        error        str | None
        discovered_at str (ISO-8601 UTC)
    """
    result: dict = {
        "found": False,
        "root": root,
        "driver": "",
        "database": "",
        "host": "",
        "username": "",
        "prefix": "adsb_",
        "importable": False,
        "counts": {},
        "xml_files": None,
        "settings": [],
        "error": None,
        "discovered_at": datetime.now(timezone.utc).isoformat(),
    }

    settings_path = os.path.join(root, SETTINGS_FILENAME)
    if not os.path.isfile(settings_path):
        result["error"] = f"settings.class.php not found at {settings_path}"
        return result

    try:
        cfg = parse_settings_php(root)
    except Exception as exc:
        result["error"] = f"Failed to parse settings.class.php: {exc}"
        return result

    result.update({
        "found": True,
        "driver": cfg["driver"],
        "database": cfg["database"],
        "host": cfg["host"],
        "username": cfg["username"],
        "prefix": cfg["prefix"],
    })

    driver = cfg["driver"]

    if driver == "xml":
        xml_info = discover_xml(root)
        result["counts"] = xml_info["counts"]
        result["xml_files"] = xml_info["xml_files"]
        settings_xml_path = xml_info["xml_files"].get("settings")
        if settings_xml_path:
            result["settings"] = export_settings_xml(settings_xml_path)

    elif driver == "sqlite":
        sql_info = discover_sqlite(cfg["database"], cfg["prefix"])
        result["counts"] = sql_info.get("counts", {})
        if "error" in sql_info:
            result["error"] = sql_info["error"]
        else:
            uri = f"file:{cfg['database']}?mode=ro"
            try:
                conn = sqlite3.connect(uri, uri=True)
                result["settings"] = export_settings_sqlite(conn, cfg["prefix"])
                conn.close()
            except Exception:
                pass

    elif driver in ("mysql", "pgsql", "postgresql"):
        sql_info = discover_sql(
            driver, cfg["host"], cfg["username"], db_password,
            cfg["database"], cfg["prefix"]
        )
        result["counts"] = sql_info.get("counts", {})

    else:
        result["error"] = f"Unknown legacy driver: {driver!r}"

    result["importable"] = _has_importable_data(result["counts"])
    return result


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Discover and report on a legacy PHP ADS-B Portal installation."
    )
    parser.add_argument(
        "--root", required=True,
        help="Path to the legacy portal document root (contains classes/settings.class.php)."
    )
    parser.add_argument(
        "--db-password", default="",
        help="Database password for MySQL/PostgreSQL discovery (optional; not logged)."
    )
    parser.add_argument(
        "--pretty", action="store_true",
        help="Pretty-print JSON output."
    )
    args = parser.parse_args()

    result = discover(args.root, db_password=args.db_password)
    indent = 2 if args.pretty else None
    print(json.dumps(result, indent=indent))
    return 0


if __name__ == "__main__":
    sys.exit(main())
