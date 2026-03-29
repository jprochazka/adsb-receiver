from tests.conftest import create_admin_token, create_user_token
from backend.models import db, Setting

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
