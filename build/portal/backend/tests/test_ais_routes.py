from backend.models import Setting
from tests.conftest import create_admin_token


def test_live_ais_returns_paginated_envelope(client):
    response = client.get('/api/ais/live')

    assert response.status_code == 200
    payload = response.get_json()
    assert set(('items', 'total', 'offset', 'limit')).issubset(payload)


def test_target_search_rejects_invalid_pagination(client):
    response = client.get('/api/ais/targets?offset=invalid')

    assert response.status_code == 400
    assert 'offset' in response.get_json()['msg']


def test_ais_settings_requires_admin(client):
    response = client.get('/api/ais/settings')

    assert response.status_code == 401


def test_admin_can_update_ais_settings(app, client):
    token = create_admin_token(app)
    response = client.put(
        '/api/ais/settings',
        headers={'Authorization': f'Bearer {token}'},
        json={'ais_map_enabled': 'false'},
    )

    assert response.status_code == 200
    with app.app_context():
        setting = Setting.query.filter_by(name='ais_map_enabled').one()
        assert setting.value == 'false'


def test_purge_requires_explicit_confirmation(app, client):
    token = create_admin_token(app)
    response = client.post(
        '/api/ais/purge',
        headers={'Authorization': f'Bearer {token}'},
        json={'confirm': False},
    )

    assert response.status_code == 400
