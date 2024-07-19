from flask_jwt_extended import create_access_token

# POST /link

def test_post_link_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Link Four', 
            'address': 'https://adsbportal.com/four'
        }
        response = client.post('/api/link', headers=request_headers, json=request_json)
        assert response.status_code == 201

def test_post_link_400_missing_name(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'address': 'https://adsbportal.com/four'
        }
        response = client.post('/api/link', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_link_400_missing_address(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Link Four',
        }
        response = client.post('/api/link', headers=request_headers, json=request_json)
        assert response.status_code == 400

# DELETE /link/{id}

def test_delete_link_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/link/1', headers=request_headers)
        assert response.status_code == 204

def test_delete_link_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/link/4', headers=request_headers)
        assert response.status_code == 404

# GET /link/{id}

def test_get_link_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.get('/api/link/2', headers=request_headers)
        assert response.status_code == 200
        assert response.json['id'] == 2
        assert response.json['address'] == "https://adsbportal.com/two"

def test_get_user_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.get('/api/link/4', headers=request_headers)
        assert response.status_code == 404

# PUT /link/{id}

def test_put_link_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Link Three Updated',
            'address': 'https://adsbportal.com/three-updated'
        }
        response = client.put('/api/link/3', headers=request_headers, json=request_json)
    assert response.status_code == 204

def test_put_link_400_missing_name(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'address': 'https://adsbportal.com/three-updated'
        }
        response = client.put('/api/link/3', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_link_400_missing_address(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Link Three Updated'
        }
        response = client.put('/api/link/3', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_link_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Link Four Updated', 
            'address': 'https://adsbportal.com/four-updated'
        }
        response = client.put('/api/link/4', headers=request_headers, json=request_json)
        assert response.status_code == 404

# GET /links

def test_get_links_200(client):
    response = client.get('/api/links')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 50
    assert response.json['count'] == 3
    assert response.json['links'][0]['id'] == 1
    assert response.json['links'][0]['name'] == "Link One"
    assert response.json['links'][0]['address'] == "https://adsbportal.com/one"
    assert response.json['links'][1]['id'] == 3
    assert response.json['links'][1]['name'] == "Link Three"
    assert response.json['links'][1]['address'] == "https://adsbportal.com/three"
    assert response.json['links'][2]['id'] == 2
    assert response.json['links'][2]['name'] == "Link Two"
    assert response.json['links'][2]['address'] == "https://adsbportal.com/two"

def test_get_links_200_offset(client):
    response = client.get('/api/links?offset=2')
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 50
    assert response.json['count'] == 1
    assert response.json['links'][0]['id'] == 2
    assert response.json['links'][0]['name'] == "Link Two"
    assert response.json['links'][0]['address'] == "https://adsbportal.com/two"

def test_get_links_200_limit(client):
    response = client.get('/api/links?limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['links'][0]['id'] == 1
    assert response.json['links'][0]['name'] == "Link One"
    assert response.json['links'][0]['address'] == "https://adsbportal.com/one"

def test_get_links_200_offset_and_limit(client):
    response = client.get('/api/links?offset=1&limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['links'][0]['id'] == 3
    assert response.json['links'][0]['name'] == "Link Three"
    assert response.json['links'][0]['address'] == "https://adsbportal.com/three"

def test_get_links_400_offset_less_than_0(client):
    response = client.get('/api/links?offset=-1')
    assert response.status_code == 400

def test_get_links_400_limit_less_than_0(client):
    response = client.get('/api/links?limit=-1')
    assert response.status_code == 400

def test_get_links_400_limit_greater_than_100(client):
    response = client.get('/api/links?limit=101')
    assert response.status_code == 400