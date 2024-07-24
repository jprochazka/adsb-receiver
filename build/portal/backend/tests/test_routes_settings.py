from flask_jwt_extended import create_access_token

# PUT /setting/{id}

def test_put_setting_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'setting_three',
            'value': 'Updated Setting Three'
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)
    assert response.status_code == 204

def test_put_setting_401(client):
    request_json = {
        'name': 'setting_three',
        'value': 'Updated Setting Three'
    }
    response = client.put('/api/setting', json=request_json)
    assert response.status_code == 401

def test_put_setting_400_missing_name(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
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
        access_token = create_access_token(identity="developer")
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
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'setting_four', 
            'value': 'Updated Setting Four'
        }
        response = client.put('/api/setting', headers=request_headers, json=request_json)
        assert response.status_code == 404

# GET /setting

def test_get_links_200(client):
    response = client.get('/api/setting/setting_three')
    assert response.status_code == 200
    assert response.json['id'] == 3
    assert response.json['name'] == "setting_three"
    assert response.json['value'] == "Value Three"

def test_get_link_404(client):
    response = client.get('/api/link/setting_four')
    assert response.status_code == 404

# GET /settings

def test_get_settings_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/settings', headers=request_headers)
        assert response.status_code == 200
        assert response.json[0]['id'] == 1
        assert response.json[0]['name'] == "setting_one"
        assert response.json[0]['value'] == "Value One"
        assert response.json[1]['id'] == 3
        assert response.json[1]['name'] == "setting_three"
        assert response.json[1]['value'] == "Value Three"
        assert response.json[2]['id'] == 2
        assert response.json[2]['name'] == "setting_two"
        assert response.json[2]['value'] == "Value Two"

def test_get_settings_401(client):
    response = client.get('/api/settings')
    assert response.status_code == 401