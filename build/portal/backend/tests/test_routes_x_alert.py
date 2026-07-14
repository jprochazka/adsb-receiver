from conftest import create_admin_token, create_user_token

from backend.models import Setting, db
from backend.routes import x_alert as x_alert_routes


def _headers(token):
    return {'Authorization': f'Bearer {token}'}


def test_config_requires_admin(client, app):
    with app.app_context():
        user_token = create_user_token()

    assert client.get('/api/x-alert/config').status_code == 401
    assert client.get('/api/x-alert/config', headers=_headers(user_token)).status_code == 403


def test_config_creates_defaults_and_masks_secrets(client, app):
    with app.app_context():
        admin_token = create_admin_token()

    response = client.get('/api/x-alert/config', headers=_headers(admin_token))

    assert response.status_code == 200
    assert response.json['x_alert_enabled'] == 'false'
    assert response.json['credentials']['api_key'] is False
    assert 'x_alert_x_api_key' not in response.json

    with app.app_context():
        assert db.session.query(Setting).filter_by(name='x_alert_enabled').one().value == 'false'


def test_config_update_persists_and_preserves_blank_secret(client, app):
    with app.app_context():
        admin_token = create_admin_token()

    initial = client.put('/api/x-alert/config', headers=_headers(admin_token), json={
        'x_alert_enabled': 'true',
        'x_alert_receiver_lat': '41.5',
        'x_alert_receiver_lon': '-83.5',
        'x_alert_x_api_key': 'secret-key',
    })
    preserved = client.put('/api/x-alert/config', headers=_headers(admin_token), json={
        'x_alert_radius_nm': '4.5',
        'x_alert_x_api_key': '',
    })

    assert initial.status_code == 200
    assert preserved.status_code == 200
    assert preserved.json['credentials']['api_key'] is True
    with app.app_context():
        assert db.session.query(Setting).filter_by(name='x_alert_radius_nm').one().value == '4.5'
        assert db.session.query(Setting).filter_by(name='x_alert_x_api_key').one().value == 'secret-key'


def test_config_rejects_invalid_coordinates(client, app):
    with app.app_context():
        admin_token = create_admin_token()

    response = client.put('/api/x-alert/config', headers=_headers(admin_token), json={
        'x_alert_receiver_lat': 'invalid',
    })

    assert response.status_code == 400


def test_manual_dry_run_is_admin_only(client, app, monkeypatch):
    with app.app_context():
        admin_token = create_admin_token()
        user_token = create_user_token()
    monkeypatch.setattr(
        x_alert_routes,
        'execute_x_alert_cycle',
        lambda **kwargs: {'result': 'success', 'dry_run': kwargs.get('dry_run')},
    )

    forbidden = client.post('/api/x-alert/dry-run', headers=_headers(user_token))
    response = client.post('/api/x-alert/dry-run', headers=_headers(admin_token))

    assert forbidden.status_code == 403
    assert response.status_code == 200
    assert response.json == {'result': 'success', 'dry_run': True}