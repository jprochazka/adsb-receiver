from tests.conftest import create_admin_token, create_user_token

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
