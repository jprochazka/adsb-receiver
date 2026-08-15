import os
import pytest
import tempfile
from unittest.mock import patch

from backend import create_app


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _yaml_config(db_type):
    """Return a minimal config structure as yaml.safe_load would produce."""
    return {
        'database': {
            'use': db_type,
            'mysql': {
                'host': '127.0.0.1',
                'user': 'testuser',
                'password': 'testpass',
                'database': 'testdb',
            },
            'postgresql': {
                'host': '127.0.0.1',
                'user': 'testuser',
                'password': 'testpass',
                'database': 'testdb',
            },
        },
        'acars': {'database': 'instance/adsbportal.sqlite3'},
        'security': {'jwt_secret_key': 'test-jwt-secret'},
    }


# ---------------------------------------------------------------------------
# DB URI branch tests
# The yaml branch is skipped when SQLALCHEMY_DATABASE_URI is already set, so
# these tests patch yaml and omit a pre-set URI to exercise each code path.
# ---------------------------------------------------------------------------

@patch('backend.config_loader.yaml.safe_load')
def test_create_app_sets_sqlite_uri(mock_yaml):
    mock_yaml.return_value = _yaml_config('sqlite')
    app = create_app({'TESTING': True})
    assert 'sqlite' in app.config['SQLALCHEMY_DATABASE_URI']


@patch('backend.config_loader.yaml.safe_load')
def test_create_app_sets_mysql_uri(mock_yaml):
    mock_yaml.return_value = _yaml_config('mysql')
    app = create_app({'TESTING': True})
    uri = app.config['SQLALCHEMY_DATABASE_URI']
    assert uri.startswith('mysql://')
    assert 'testuser' in uri
    assert 'testdb' in uri


@patch('backend.config_loader.yaml.safe_load')
def test_create_app_sets_postgresql_uri(mock_yaml):
    mock_yaml.return_value = _yaml_config('postgresql')
    app = create_app({'TESTING': True})
    uri = app.config['SQLALCHEMY_DATABASE_URI']
    assert uri.startswith('postgresql://')
    assert 'testuser' in uri
    assert 'testdb' in uri


@patch('backend.config_loader.yaml.safe_load')
def test_create_app_invalid_database_use_raises(mock_yaml):
    mock_yaml.return_value = _yaml_config('oracle')
    # Don't pass SQLALCHEMY_DATABASE_URI so the yaml branch runs
    with pytest.raises(ValueError, match="Unsupported database type"):
        create_app({'TESTING': True})


# ---------------------------------------------------------------------------
# Alembic smoke tests
# ---------------------------------------------------------------------------

def _make_migrate_app(db_url):
    """Create a minimal Flask app wired to db_url for migration testing."""
    return create_app({
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': db_url,
        'JWT_SECRET_KEY': 'test-jwt-secret',
    })


def test_create_all_creates_expected_tables():
    """Initial schema setup should create all model tables without running migrations."""
    from sqlalchemy import inspect
    from backend.models import db

    with tempfile.TemporaryDirectory() as tmpdir:
        db_url = f"sqlite:///{tmpdir}/test.sqlite3"
        app = _make_migrate_app(db_url)

        with app.app_context():
            db.create_all()
            tables = set(inspect(db.engine).get_table_names())

    expected = {
        'blog_posts',
        'dump1090_aircraft', 'dump1090_flights', 'dump1090_positions',
        'dump978_aircraft', 'dump978_flights', 'dump978_positions',
        'links', 'notifications', 'settings', 'users',
    }
    assert expected.issubset(tables)


def test_create_all_is_idempotent():
    """Creating the initial schema should be safe on a fresh database and repeatable."""
    from backend.models import db

    with tempfile.TemporaryDirectory() as tmpdir:
        db_url = f"sqlite:///{tmpdir}/test.sqlite3"
        app = _make_migrate_app(db_url)

        with app.app_context():
            db.create_all()
            db.drop_all()
            db.create_all()


# ---------------------------------------------------------------------------
# data.sql portability guard
# ---------------------------------------------------------------------------

def test_data_sql_has_no_mysql_backticks():
    """data.sql must not use MySQL backtick quoting (incompatible with PostgreSQL)."""
    data_sql_path = os.path.join(os.path.dirname(__file__), 'data.sql')
    with open(data_sql_path) as fh:
        content = fh.read()
    assert '`' not in content, (
        "data.sql contains MySQL backtick quoting — use plain identifiers instead"
    )
