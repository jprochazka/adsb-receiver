import pytest
import io
import os
from urllib.error import URLError

from tests.conftest import create_admin_token, create_user_token
from backend.models import db, Setting
from backend.routes import settings as settings_routes

# PUT /setting/{id}

def test_put_setting_200(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'setting_three',
            'value': 'Updated Setting Three'
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)
    assert response.status_code == 200

def test_put_setting_401(client):
    request_json = {
        'name': 'setting_three',
        'value': 'Updated Setting Three'
    }
    response = client.put('/api/setting', json=request_json)
    assert response.status_code == 401

def test_put_setting_400_missing_name(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'value': 'New Value Two'
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_setting_400_missing_value(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'setting_two'
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_setting_404(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'setting_four',
            'value': 'Updated Setting Four'
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)
        assert response.status_code == 404# GET /setting

def test_get_links_200(client):
    response = client.get('/api/setting/setting_three')
    assert response.status_code == 200
    assert response.json['id'] == 3
    assert response.json['name'] == "setting_three"
    assert response.json['value'] == "Value Three"

def test_get_link_404(client):
    response = client.get('/api/setting/setting_four')
    assert response.status_code == 404


def test_get_live_map_custom_presets_200(client, app):
    with app.app_context():
        existing = db.session.query(Setting).filter_by(name='live_map_custom_presets').first()
        if not existing:
            db.session.add(Setting(
                name='live_map_custom_presets',
                value='[{"label":"Home","refreshMs":2500,"centerLat":39,"centerLon":-95,"zoom":7,"trailPoints":40}]'
            ))
            db.session.commit()

    response = client.get('/api/setting/live_map_custom_presets')
    assert response.status_code == 200
    assert response.json['name'] == 'live_map_custom_presets'
    assert 'Home' in response.json['value']


def test_put_live_map_custom_presets_200(client, app):
    with app.app_context():
        existing = db.session.query(Setting).filter_by(name='live_map_custom_presets').first()
        if not existing:
            db.session.add(Setting(name='live_map_custom_presets', value='[]'))
            db.session.commit()

        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'live_map_custom_presets',
            'value': '[{"label":"Deleted Slot","refreshMs":5000,"centerLat":20,"centerLon":0,"zoom":3,"trailPoints":20}]'
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)

    assert response.status_code == 200

    with app.app_context():
        saved = db.session.query(Setting).filter_by(name='live_map_custom_presets').first()
        assert saved is not None
        assert 'Deleted Slot' in saved.value


def _ensure_setting(name: str, value: str):
    existing = db.session.query(Setting).filter_by(name=name).first()
    if not existing:
        db.session.add(Setting(name=name, value=value))
        db.session.commit()


@pytest.mark.parametrize(
    "setting_name,default_value",
    [
        ("live_map_spider_overlay_enabled", "true"),
        ("live_map_center_icon_enabled", "true"),
        ("live_map_distance_rings_enabled", "false"),
        ("live_map_distance_ring_compass_lines_enabled", "true"),
        ("live_map_distance_ring_count", "4"),
        ("live_map_distance_ring_interval_miles", "25"),
        ("live_map_theoretical_range_enabled", "false"),
        ("live_map_theoretical_range_json", ""),
    ],
)
def test_get_new_live_map_settings_200(client, app, setting_name, default_value):
    with app.app_context():
        _ensure_setting(setting_name, default_value)

    response = client.get(f'/api/setting/{setting_name}')

    assert response.status_code == 200
    assert response.json['name'] == setting_name


@pytest.mark.parametrize(
    "setting_name,new_value",
    [
        ("live_map_spider_overlay_enabled", "false"),
        ("live_map_center_icon_enabled", "false"),
        ("live_map_distance_rings_enabled", "true"),
        ("live_map_distance_ring_compass_lines_enabled", "false"),
        ("live_map_distance_ring_count", "6"),
        ("live_map_distance_ring_interval_miles", "40"),
        ("live_map_theoretical_range_enabled", "true"),
        ("live_map_theoretical_range_json", "{\"type\":\"FeatureCollection\",\"features\":[]}"),
    ],
)
def test_put_new_live_map_settings_200(client, app, setting_name, new_value):
    with app.app_context():
        _ensure_setting(setting_name, "")

        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': setting_name,
            'value': new_value
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)

        saved = db.session.query(Setting).filter_by(name=setting_name).first()

    assert response.status_code == 200
    assert saved is not None
    assert saved.value == new_value


def test_get_opensky_aircraft_database_status_404_when_missing(client):
    response = client.get('/api/setting/opensky-aircraft-database')
    assert response.status_code == 404
    assert response.json['installed'] is False


def test_post_opensky_aircraft_database_update_401_without_token(client):
    response = client.post('/api/setting/opensky-aircraft-database/update')
    assert response.status_code == 401


def test_post_opensky_aircraft_database_update_403_for_non_admin(client, app):
    with app.app_context():
        access_token = create_user_token()

    response = client.post(
        '/api/setting/opensky-aircraft-database/update',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert response.status_code == 403


def test_post_opensky_aircraft_database_update_200(client, app, tmp_path, monkeypatch):
    opensky_dir = tmp_path / 'opensky'
    db_path = opensky_dir / settings_routes.OPENSKY_DB_FILE
    metadata_path = opensky_dir / settings_routes.OPENSKY_METADATA_FILE
    notice_path = opensky_dir / settings_routes.OPENSKY_NOTICE_FILE

    monkeypatch.setattr(settings_routes, '_opensky_db_dir', lambda: str(opensky_dir))
    monkeypatch.setattr(settings_routes, '_opensky_db_path', lambda: str(db_path))
    monkeypatch.setattr(settings_routes, '_opensky_metadata_path', lambda: str(metadata_path))
    monkeypatch.setattr(settings_routes, '_opensky_notice_path', lambda: str(notice_path))

    csv_bytes = b"icao24,registration,typecode\nabc123,N123AB,C172\n"

    class _FakeResponse(io.BytesIO):
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            self.close()
            return False

    monkeypatch.setattr(settings_routes, 'urlopen', lambda req, timeout=60: _FakeResponse(csv_bytes))

    with app.app_context():
        access_token = create_admin_token()

    response = client.post(
        '/api/setting/opensky-aircraft-database/update',
        headers={'Authorization': f'Bearer {access_token}'},
    )

    assert response.status_code == 200
    assert response.json['installed'] is True
    assert response.json['license_name'] == settings_routes.OPENSKY_LICENSE_NAME
    assert os.path.exists(db_path)
    assert os.path.exists(metadata_path)
    assert os.path.exists(notice_path)

    with open(db_path, 'rb') as handle:
        assert handle.read() == csv_bytes

    with open(metadata_path, 'r', encoding='utf-8') as handle:
        metadata = handle.read()
        assert settings_routes.OPENSKY_DB_URL in metadata
        assert settings_routes.OPENSKY_LICENSE_URL in metadata

    status_response = client.get('/api/setting/opensky-aircraft-database')
    assert status_response.status_code == 200
    assert status_response.json['installed'] is True


def test_post_opensky_aircraft_database_update_502_on_download_error(client, app, monkeypatch):
    monkeypatch.setattr(settings_routes, 'urlopen', lambda req, timeout=60: (_ for _ in ()).throw(URLError('network down')))

    with app.app_context():
        access_token = create_admin_token()

    response = client.post(
        '/api/setting/opensky-aircraft-database/update',
        headers={'Authorization': f'Bearer {access_token}'},
    )

    assert response.status_code == 502
    assert response.json['msg'] == 'Unable to download OpenSky aircraft database'
    assert response.json['source_url'] == settings_routes.OPENSKY_DB_URL
    assert response.json['license_name'] == settings_routes.OPENSKY_LICENSE_NAME
