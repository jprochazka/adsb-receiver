"""
Tests for build/portal/backend/tools/legacy_portal_discover.py

Covers:
- parse_settings_php: xml, sqlite (host-as-path fallback), mysql
- discover_xml: counts, xml_files dict, settings export
- discover_sqlite: counts, read-only
- export_settings_xml: allow-list filtering and rename mapping
- export_settings_sqlite: allow-list filtering and rename mapping
- discover(): full integration for xml root, sqlite root, missing root
- _has_importable_data helper
"""

import json
import os
import shutil
import sqlite3
import sys
import tempfile

import pytest

# Allow importing the tool directly without installing it as a package.
TOOL_DIR = os.path.join(os.path.dirname(__file__), "..", "tools")
sys.path.insert(0, os.path.abspath(TOOL_DIR))

import legacy_portal_discover as lpd  # noqa: E402

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures", "legacy_portal")
XML_FIXTURE  = os.path.join(FIXTURES_DIR, "xml_data")
SQLITE_FIXTURE = os.path.join(FIXTURES_DIR, "sqlite_data")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_settings_php(tmpdir: str, driver: str, database: str = "",
                       host: str = "", username: str = "",
                       prefix: str = "adsb_") -> str:
    """Write a minimal settings.class.php into tmpdir/classes/ and return tmpdir."""
    classes_dir = os.path.join(tmpdir, "classes")
    os.makedirs(classes_dir, exist_ok=True)
    content = f"""<?php
    class settings {{
        const db_driver   = '{driver}';
        const db_database = '{database}';
        const db_username = '{username}';
        const db_password = '';
        const db_host     = '{host}';
        const db_prefix   = '{prefix}';
    }}
?>
"""
    path = os.path.join(classes_dir, "settings.class.php")
    with open(path, "w") as fh:
        fh.write(content)
    return tmpdir


# ---------------------------------------------------------------------------
# parse_settings_php
# ---------------------------------------------------------------------------

class TestParseSettingsPhp:
    def test_xml_driver(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_settings_php(tmp, driver="xml")
            cfg = lpd.parse_settings_php(tmp)
        assert cfg["driver"] == "xml"
        assert cfg["prefix"] == "adsb_"

    def test_sqlite_host_fallback(self):
        """Old sqlite installs store the file path in db_host with empty db_database."""
        with tempfile.TemporaryDirectory() as tmp:
            make_settings_php(tmp, driver="sqlite", host="/var/www/html/data/portal.sqlite")
            cfg = lpd.parse_settings_php(tmp)
        assert cfg["driver"] == "sqlite"
        assert cfg["database"] == "/var/www/html/data/portal.sqlite"
        assert cfg["host"] == ""

    def test_sqlite_explicit_database(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_settings_php(tmp, driver="sqlite", database="/path/to/portal.sqlite")
            cfg = lpd.parse_settings_php(tmp)
        assert cfg["database"] == "/path/to/portal.sqlite"

    def test_mysql_driver(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_settings_php(tmp, driver="mysql", database="adsbdb",
                               host="127.0.0.1", username="adsbuser")
            cfg = lpd.parse_settings_php(tmp)
        assert cfg["driver"] == "mysql"
        assert cfg["database"] == "adsbdb"
        assert cfg["host"] == "127.0.0.1"
        assert cfg["username"] == "adsbuser"

    def test_missing_file_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            with pytest.raises(FileNotFoundError):
                lpd.parse_settings_php(tmp)

    def test_custom_prefix(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_settings_php(tmp, driver="xml", prefix="portal_")
            cfg = lpd.parse_settings_php(tmp)
        assert cfg["prefix"] == "portal_"

    def test_default_prefix_when_empty(self):
        """When db_prefix constant is present but empty, default to 'adsb_'."""
        with tempfile.TemporaryDirectory() as tmp:
            classes_dir = os.path.join(tmp, "classes")
            os.makedirs(classes_dir)
            with open(os.path.join(classes_dir, "settings.class.php"), "w") as fh:
                fh.write("<?php class settings { const db_driver = 'xml'; const db_prefix = ''; } ?>")
            cfg = lpd.parse_settings_php(tmp)
        assert cfg["prefix"] == "adsb_"


# ---------------------------------------------------------------------------
# discover_xml
# ---------------------------------------------------------------------------

class TestDiscoverXml:
    def test_counts_from_fixture(self):
        info = lpd.discover_xml(XML_FIXTURE)
        counts = info["counts"]
        assert counts["administrators"] == 1
        assert counts["blog_posts"] == 2
        assert counts["notifications"] == 1
        assert counts["links"] == 1
        assert counts["settings"] == 6

    def test_xml_files_dict_populated(self):
        info = lpd.discover_xml(XML_FIXTURE)
        assert info["xml_files"]["administrators"] is not None
        assert os.path.isfile(info["xml_files"]["administrators"])

    def test_missing_data_dir_counts_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            info = lpd.discover_xml(tmp)
        assert all(v == 0 for v in info["counts"].values())

    def test_malformed_xml_counts_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            data_dir = os.path.join(tmp, "data")
            os.makedirs(data_dir)
            with open(os.path.join(data_dir, "administrators.xml"), "w") as fh:
                fh.write("NOT XML AT ALL <<<")
            info = lpd.discover_xml(tmp)
        assert info["counts"]["administrators"] == 0


# ---------------------------------------------------------------------------
# export_settings_xml
# ---------------------------------------------------------------------------

class TestExportSettingsXml:
    def test_allowlisted_names_included(self):
        path = os.path.join(XML_FIXTURE, "data", "settings.xml")
        settings = lpd.export_settings_xml(path)
        names = {s["name"] for s in settings}
        assert "siteName" in names
        assert "timeZone" in names
        assert "advancedMapCenterLatitude" in names
        assert "advancedMapCenterLongitude" in names

    def test_non_allowlisted_excluded(self):
        path = os.path.join(XML_FIXTURE, "data", "settings.xml")
        settings = lpd.export_settings_xml(path)
        names = {s["name"] for s in settings}
        # 'version' is not in the allow-list
        assert "version" not in names

    def test_rename_applied(self):
        path = os.path.join(XML_FIXTURE, "data", "settings.xml")
        settings = lpd.export_settings_xml(path)
        names = {s["name"] for s in settings}
        # networkInterface -> graphs_network_interface
        assert "graphs_network_interface" in names
        assert "networkInterface" not in names

    def test_missing_file_returns_empty(self):
        result = lpd.export_settings_xml("/nonexistent/settings.xml")
        assert result == []


# ---------------------------------------------------------------------------
# discover_sqlite
# ---------------------------------------------------------------------------

class TestDiscoverSqlite:
    def test_counts_from_fixture(self):
        db_path = os.path.join(SQLITE_FIXTURE, "portal.sqlite")
        info = lpd.discover_sqlite(db_path, "adsb_")
        counts = info["counts"]
        assert counts["administrators"] == 1
        assert counts["aircraft"] == 2
        assert counts["blogPosts"] == 1
        assert counts["flights"] == 1
        assert counts["positions"] == 1
        assert counts["links"] == 1
        assert counts["flightNotifications"] == 1
        assert counts["settings"] == 8

    def test_missing_file_returns_error(self):
        info = lpd.discover_sqlite("/nonexistent/portal.sqlite", "adsb_")
        assert "error" in info
        assert info["counts"] == {}

    def test_absent_table_returns_none(self):
        """A table that doesn't exist in an older DB should count as None."""
        with tempfile.TemporaryDirectory() as tmp:
            db_path = os.path.join(tmp, "minimal.sqlite")
            conn = sqlite3.connect(db_path)
            conn.execute("CREATE TABLE adsb_administrators (id INTEGER PRIMARY KEY, name TEXT)")
            conn.execute("INSERT INTO adsb_administrators (name) VALUES ('test')")
            conn.commit()
            conn.close()
            info = lpd.discover_sqlite(db_path, "adsb_")
        assert info["counts"]["administrators"] == 1
        # blogPosts table doesn't exist -> None
        assert info["counts"]["blogPosts"] is None


# ---------------------------------------------------------------------------
# export_settings_sqlite
# ---------------------------------------------------------------------------

class TestExportSettingsSqlite:
    def _conn(self):
        db_path = os.path.join(SQLITE_FIXTURE, "portal.sqlite")
        return sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)

    def test_allowlisted_names_present(self):
        conn = self._conn()
        settings = lpd.export_settings_sqlite(conn, "adsb_")
        conn.close()
        names = {s["name"] for s in settings}
        assert "siteName" in names
        assert "days_to_save" in names
        assert "purge_older_data" in names

    def test_version_excluded(self):
        conn = self._conn()
        settings = lpd.export_settings_sqlite(conn, "adsb_")
        conn.close()
        assert not any(s["name"] == "version" for s in settings)

    def test_rename_applied(self):
        conn = self._conn()
        settings = lpd.export_settings_sqlite(conn, "adsb_")
        conn.close()
        names = {s["name"] for s in settings}
        assert "graphs_network_interface" in names


# ---------------------------------------------------------------------------
# _has_importable_data
# ---------------------------------------------------------------------------

class TestHasImportableData:
    def test_true_when_any_positive(self):
        assert lpd._has_importable_data({"a": 0, "b": 1, "c": None}) is True

    def test_false_when_all_zero_or_none(self):
        assert lpd._has_importable_data({"a": 0, "b": None, "c": 0}) is False

    def test_false_on_empty(self):
        assert lpd._has_importable_data({}) is False


# ---------------------------------------------------------------------------
# discover() integration
# ---------------------------------------------------------------------------

class TestDiscover:
    def test_xml_root_found_and_importable(self):
        result = lpd.discover(XML_FIXTURE)
        assert result["found"] is True
        assert result["driver"] == "xml"
        assert result["importable"] is True
        assert result["counts"]["administrators"] == 1
        assert result["counts"]["blog_posts"] == 2
        assert result["error"] is None

    def test_xml_settings_exported(self):
        result = lpd.discover(XML_FIXTURE)
        names = {s["name"] for s in result["settings"]}
        assert "siteName" in names
        assert "graphs_network_interface" in names
        assert "version" not in names

    def test_sqlite_root_found_and_importable(self):
        # The fixture settings.class.php uses a placeholder host path.
        # We patch it with the real DB path using a temp copy.
        with tempfile.TemporaryDirectory() as tmp:
            db_path = os.path.join(SQLITE_FIXTURE, "portal.sqlite")
            # Copy fixture DB to tmp
            real_db = os.path.join(tmp, "portal.sqlite")
            shutil.copy2(db_path, real_db)
            # Write a settings.class.php pointing at the real path
            make_settings_php(tmp, driver="sqlite", host=real_db)
            result = lpd.discover(tmp)
        assert result["found"] is True
        assert result["driver"] == "sqlite"
        assert result["importable"] is True
        assert result["counts"]["administrators"] == 1
        assert result["counts"]["aircraft"] == 2
        assert result["error"] is None

    def test_missing_root_not_found(self):
        result = lpd.discover("/nonexistent/path")
        assert result["found"] is False
        assert result["error"] is not None

    def test_unreadable_settings_not_found(self):
        with tempfile.TemporaryDirectory() as tmp:
            classes_dir = os.path.join(tmp, "classes")
            os.makedirs(classes_dir)
            # Write a settings file with no constants at all
            with open(os.path.join(classes_dir, "settings.class.php"), "w") as fh:
                fh.write("<?php // empty ?>")
            result = lpd.discover(tmp)
        # found=True but driver defaults to xml, importable=False (no data files)
        assert result["found"] is True
        assert result["driver"] == "xml"
        assert result["importable"] is False

    def test_json_serialisable(self):
        result = lpd.discover(XML_FIXTURE)
        # Should not raise
        serialised = json.dumps(result)
        parsed = json.loads(serialised)
        assert parsed["found"] is True
