"""
Tests for build/portal/backend/tools/legacy_portal_import.py

Covers:
- run_import with XML source -> SQLite target (full path)
- run_import with SQLite source -> SQLite target (full path)
- dry-run mode (no rows written, no backup)
- duplicate skipping (idempotent re-run)
- FK remapping: aircraft -> flights -> positions
- backup creation when target exists
- missing legacy root returns error, success=False
- empty legacy source returns error, success=False
- coordinate validation: out-of-range positions skipped
"""

import json
import os
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path

import pytest
import yaml

TOOL_DIR = os.path.join(os.path.dirname(__file__), "..", "tools")
sys.path.insert(0, os.path.abspath(TOOL_DIR))

import legacy_portal_import as lpi  # noqa: E402

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures", "legacy_portal")
XML_FIXTURE   = os.path.join(FIXTURES_DIR, "xml_data")
SQLITE_FIXTURE = os.path.join(FIXTURES_DIR, "sqlite_data")
SQLITE_SRC_DB  = os.path.join(SQLITE_FIXTURE, "portal.sqlite")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

NEW_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password TEXT,
    administrator INTEGER DEFAULT 0,
    role TEXT DEFAULT 'User',
    locked INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS blog_posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    date TEXT NOT NULL,
    author TEXT NOT NULL,
    content TEXT NOT NULL,
    visible INTEGER NOT NULL DEFAULT 1,
    tags TEXT,
    category TEXT
);
CREATE TABLE IF NOT EXISTS links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    flight TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS dump1090_aircraft (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    icao TEXT NOT NULL,
    first_seen TEXT NOT NULL,
    last_seen TEXT
);
CREATE TABLE IF NOT EXISTS dump1090_flights (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    aircraft INTEGER NOT NULL,
    flight TEXT NOT NULL,
    first_seen TEXT NOT NULL,
    last_seen TEXT,
    emitter_category TEXT,
    message_type TEXT,
    aircraft_class TEXT NOT NULL DEFAULT 'unknown',
    ignore_on_purge INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (aircraft) REFERENCES dump1090_aircraft(id)
);
CREATE TABLE IF NOT EXISTS dump1090_positions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    flight INTEGER NOT NULL,
    aircraft INTEGER NOT NULL,
    time TEXT NOT NULL,
    message INTEGER NOT NULL,
    squawk INTEGER,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    track INTEGER NOT NULL,
    altitude INTEGER NOT NULL,
    vertical_rate INTEGER NOT NULL,
    speed INTEGER,
    FOREIGN KEY (flight) REFERENCES dump1090_flights(id),
    FOREIGN KEY (aircraft) REFERENCES dump1090_aircraft(id)
);
"""


def make_target_db(path: str) -> None:
    """Create a fresh target DB with the new portal schema."""
    conn = sqlite3.connect(path)
    conn.executescript(NEW_SCHEMA_SQL)
    conn.commit()
    conn.close()


def make_config_yml(tmpdir: str, db_path: str) -> str:
    """Write a minimal config.yml pointing at db_path and return its path."""
    config = {
        "database": {"use": "sqlite"},
        "_instance_dir": tmpdir,
    }
    # Override the instance dir so _build_sqlalchemy_url resolves to db_path.
    # We do this by writing a config that puts the DB at the standard name.
    # Simpler: patch _build_sqlalchemy_url by writing config with custom key.
    config_path = os.path.join(tmpdir, "config.yml")
    with open(config_path, "w") as fh:
        yaml.dump({"database": {"use": "sqlite"}}, fh)
    return config_path


def row_count(db_path: str, table: str) -> int:
    conn = sqlite3.connect(db_path)
    count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    conn.close()
    return count


# ---------------------------------------------------------------------------
# Fixture for a temp workspace with config + target DB
# ---------------------------------------------------------------------------

@pytest.fixture
def workspace(tmp_path):
    """
    Provides a dict with:
      config_path  — path to config.yml
      target_db    — path to the new portal SQLite DB
      tmpdir       — str path to temp dir
    """
    tmpdir = str(tmp_path)
    target_db = os.path.join(tmpdir, "adsbportal.sqlite3")
    make_target_db(target_db)

    # Write config.yml; use a monkeypatch-style approach: override
    # _build_sqlalchemy_url by writing an instance_dir that resolves correctly.
    config_path = os.path.join(tmpdir, "config.yml")
    with open(config_path, "w") as fh:
        yaml.dump({"database": {"use": "sqlite"}}, fh)

    # Monkeypatch _build_sqlalchemy_url to return our exact DB path.
    original = lpi._build_sqlalchemy_url

    def _patched(config, db_password_override=""):
        return f"sqlite:///{target_db}"

    lpi._build_sqlalchemy_url = _patched
    yield {"config_path": config_path, "target_db": target_db, "tmpdir": tmpdir}
    lpi._build_sqlalchemy_url = original


# ---------------------------------------------------------------------------
# Tests: XML source
# ---------------------------------------------------------------------------

class TestImportXmlSource:
    def test_users_imported(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        assert result["success"] is True
        assert result["tables"]["users"]["imported"] == 1
        assert result["tables"]["users"]["skipped"] == 0
        assert row_count(workspace["target_db"], "users") == 1

    def test_blog_posts_imported(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        assert result["tables"]["blog_posts"]["imported"] == 2
        assert row_count(workspace["target_db"], "blog_posts") == 2

    def test_links_imported(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        assert result["tables"]["links"]["imported"] == 1
        assert row_count(workspace["target_db"], "links") == 1

    def test_notifications_imported(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        assert result["tables"]["notifications"]["imported"] == 1
        assert row_count(workspace["target_db"], "notifications") == 1

    def test_settings_imported_and_allowlisted(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        imported = result["tables"]["settings"]["imported"]
        # siteName, timeZone, graphs_network_interface, advancedMapCenter* = 5 names
        assert imported >= 4
        conn = sqlite3.connect(workspace["target_db"])
        names = {r[0] for r in conn.execute("SELECT name FROM settings").fetchall()}
        conn.close()
        assert "version" not in names  # blocked by allow-list
        assert "siteName" in names

    def test_no_aircraft_tables_for_xml(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        # XML driver has no aircraft/flights/positions
        assert "dump1090_aircraft" not in result["tables"]

    def test_no_error(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        assert result["error"] is None


# ---------------------------------------------------------------------------
# Tests: SQLite source
# ---------------------------------------------------------------------------

class TestImportSqliteSource:
    def _make_src_root(self, tmp_path: Path, db_path: str) -> str:
        """Make a temp legacy root pointing at the given SQLite DB path."""
        src_root = str(tmp_path / "legacy_root")
        os.makedirs(os.path.join(src_root, "classes"), exist_ok=True)
        php = f"""<?php
    class settings {{
        const db_driver   = 'sqlite';
        const db_database = '';
        const db_username = '';
        const db_password = '';
        const db_host     = '{db_path}';
        const db_prefix   = 'adsb_';
    }}
?>
"""
        with open(os.path.join(src_root, "classes", "settings.class.php"), "w") as fh:
            fh.write(php)
        return src_root

    def test_users_imported(self, workspace, tmp_path):
        src_db = str(tmp_path / "src.sqlite")
        shutil.copy2(SQLITE_SRC_DB, src_db)
        src_root = self._make_src_root(tmp_path, src_db)
        result = lpi.run_import(workspace["config_path"], src_root)
        assert result["success"] is True
        assert result["tables"]["users"]["imported"] == 1
        assert row_count(workspace["target_db"], "users") == 1

    def test_aircraft_imported(self, workspace, tmp_path):
        src_db = str(tmp_path / "src.sqlite")
        shutil.copy2(SQLITE_SRC_DB, src_db)
        src_root = self._make_src_root(tmp_path, src_db)
        result = lpi.run_import(workspace["config_path"], src_root)
        assert result["tables"]["dump1090_aircraft"]["imported"] == 2
        assert row_count(workspace["target_db"], "dump1090_aircraft") == 2

    def test_flights_imported_with_remapped_fk(self, workspace, tmp_path):
        src_db = str(tmp_path / "src.sqlite")
        shutil.copy2(SQLITE_SRC_DB, src_db)
        src_root = self._make_src_root(tmp_path, src_db)
        result = lpi.run_import(workspace["config_path"], src_root)
        assert result["tables"]["dump1090_flights"]["imported"] == 1
        # Verify FK points at a valid new aircraft id
        conn = sqlite3.connect(workspace["target_db"])
        flt = conn.execute("SELECT aircraft FROM dump1090_flights LIMIT 1").fetchone()
        aircraft_ids = {r[0] for r in conn.execute("SELECT id FROM dump1090_aircraft").fetchall()}
        conn.close()
        assert flt[0] in aircraft_ids

    def test_positions_imported(self, workspace, tmp_path):
        src_db = str(tmp_path / "src.sqlite")
        shutil.copy2(SQLITE_SRC_DB, src_db)
        src_root = self._make_src_root(tmp_path, src_db)
        result = lpi.run_import(workspace["config_path"], src_root)
        assert result["tables"]["dump1090_positions"]["imported"] == 1
        assert row_count(workspace["target_db"], "dump1090_positions") == 1

    def test_blog_posts_imported(self, workspace, tmp_path):
        src_db = str(tmp_path / "src.sqlite")
        shutil.copy2(SQLITE_SRC_DB, src_db)
        src_root = self._make_src_root(tmp_path, src_db)
        result = lpi.run_import(workspace["config_path"], src_root)
        assert result["tables"]["blog_posts"]["imported"] == 1

    def test_no_error(self, workspace, tmp_path):
        src_db = str(tmp_path / "src.sqlite")
        shutil.copy2(SQLITE_SRC_DB, src_db)
        src_root = self._make_src_root(tmp_path, src_db)
        result = lpi.run_import(workspace["config_path"], src_root)
        assert result["error"] is None


# ---------------------------------------------------------------------------
# Tests: dry-run
# ---------------------------------------------------------------------------

class TestDryRun:
    def test_no_rows_written(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE, dry_run=True)
        assert result["success"] is True
        assert result["dry_run"] is True
        assert row_count(workspace["target_db"], "users") == 0
        assert row_count(workspace["target_db"], "blog_posts") == 0

    def test_counts_still_reported(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE, dry_run=True)
        assert result["tables"]["users"]["imported"] == 1
        assert result["tables"]["blog_posts"]["imported"] == 2

    def test_no_backup_created(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE, dry_run=True)
        assert result["backup_path"] is None


# ---------------------------------------------------------------------------
# Tests: idempotency / duplicate skipping
# ---------------------------------------------------------------------------

class TestIdempotency:
    def test_second_run_skips_all(self, workspace):
        lpi.run_import(workspace["config_path"], XML_FIXTURE)
        result2 = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        assert result2["success"] is True
        assert result2["tables"]["users"]["skipped"] == 1
        assert result2["tables"]["blog_posts"]["skipped"] == 2
        assert result2["tables"]["links"]["skipped"] == 1

    def test_row_count_stable_after_second_run(self, workspace):
        lpi.run_import(workspace["config_path"], XML_FIXTURE)
        count_after_first = row_count(workspace["target_db"], "users")
        lpi.run_import(workspace["config_path"], XML_FIXTURE)
        count_after_second = row_count(workspace["target_db"], "users")
        assert count_after_first == count_after_second


# ---------------------------------------------------------------------------
# Tests: backup
# ---------------------------------------------------------------------------

class TestBackup:
    def test_backup_created_when_target_exists(self, workspace):
        # Pre-populate so target file exists.
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        # Second run should produce a backup of the now-populated DB.
        result2 = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        assert result2["backup_path"] is not None
        assert os.path.isfile(result2["backup_path"])


# ---------------------------------------------------------------------------
# Tests: error cases
# ---------------------------------------------------------------------------

class TestErrorCases:
    def test_missing_legacy_root(self, workspace):
        result = lpi.run_import(workspace["config_path"], "/nonexistent/root")
        assert result["success"] is False
        assert result["error"] is not None

    def test_empty_legacy_xml_root(self, workspace, tmp_path):
        # Create a portal root with settings.class.php but empty data dir.
        empty_root = str(tmp_path / "empty_portal")
        os.makedirs(os.path.join(empty_root, "classes"))
        os.makedirs(os.path.join(empty_root, "data"))
        with open(os.path.join(empty_root, "classes", "settings.class.php"), "w") as fh:
            fh.write("<?php class settings { const db_driver='xml'; const db_prefix='adsb_'; } ?>")
        result = lpi.run_import(workspace["config_path"], empty_root)
        assert result["success"] is False
        assert "no importable data" in (result.get("error") or "").lower()

    def test_result_is_json_serialisable(self, workspace):
        result = lpi.run_import(workspace["config_path"], XML_FIXTURE)
        serialised = json.dumps(result)
        parsed = json.loads(serialised)
        assert parsed["success"] is True


# ---------------------------------------------------------------------------
# Tests: coordinate validation in positions
# ---------------------------------------------------------------------------

class TestPositionValidation:
    def _make_src_with_bad_position(self, tmp_path: Path) -> str:
        """SQLite source with one good and one out-of-range position."""
        db_path = str(tmp_path / "bad_pos.sqlite")
        conn = sqlite3.connect(db_path)
        conn.executescript("""
            CREATE TABLE adsb_administrators (id INTEGER PRIMARY KEY, name TEXT, email TEXT, login TEXT, password TEXT, token TEXT);
            CREATE TABLE adsb_aircraft (id INTEGER PRIMARY KEY, icao TEXT, firstSeen TEXT, lastSeen TEXT);
            CREATE TABLE adsb_flights (id INTEGER PRIMARY KEY, aircraft INTEGER, flight TEXT, firstSeen TEXT, lastSeen TEXT);
            CREATE TABLE adsb_positions (id INTEGER PRIMARY KEY, flight INTEGER, aircraft INTEGER, time TEXT,
                message INTEGER, squawk INTEGER, latitude REAL, longitude REAL,
                track INTEGER, altitude INTEGER, verticleRate INTEGER, speed INTEGER);
            CREATE TABLE adsb_blogPosts (id INTEGER PRIMARY KEY, title TEXT, date TEXT, author TEXT, contents TEXT);
            CREATE TABLE adsb_links (id INTEGER PRIMARY KEY, name TEXT, address TEXT);
            CREATE TABLE adsb_flightNotifications (id INTEGER PRIMARY KEY, flight TEXT);
            CREATE TABLE adsb_settings (id INTEGER PRIMARY KEY, name TEXT, value TEXT);
        """)
        conn.execute("INSERT INTO adsb_aircraft VALUES (1,'A1B2C3','2023-01-01T10:00:00','2023-01-01T10:30:00')")
        conn.execute("INSERT INTO adsb_flights VALUES (1,1,'UAL123','2023-01-01T10:00:00','2023-01-01T10:30:00')")
        # Good position
        conn.execute("INSERT INTO adsb_positions VALUES (1,1,1,'2023-01-01T10:05:00',1,NULL,40.71,-74.00,90,35000,0,450)")
        # Bad latitude (>90)
        conn.execute("INSERT INTO adsb_positions VALUES (2,1,1,'2023-01-01T10:06:00',1,NULL,999.0,-74.00,90,35000,0,450)")
        conn.execute("INSERT INTO adsb_settings VALUES (1,'siteName','Test')")
        conn.commit()
        conn.close()

        src_root = str(tmp_path / "src_root")
        os.makedirs(os.path.join(src_root, "classes"))
        with open(os.path.join(src_root, "classes", "settings.class.php"), "w") as fh:
            fh.write(f"<?php class settings {{ const db_driver='sqlite'; const db_host='{db_path}'; const db_prefix='adsb_'; }} ?>")
        return src_root

    def test_invalid_coordinate_skipped(self, workspace, tmp_path):
        src_root = self._make_src_with_bad_position(tmp_path)
        result = lpi.run_import(workspace["config_path"], src_root)
        assert result["success"] is True
        pos = result["tables"]["dump1090_positions"]
        assert pos["imported"] == 1
        assert pos["failed"] == 1
        assert row_count(workspace["target_db"], "dump1090_positions") == 1
