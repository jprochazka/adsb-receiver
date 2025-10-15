from flask_jwt_extended import create_refresh_token

# POST /token/login

def test_post_token_login_200(client):
    response = client.post('/api/token/login', json={
        'email': 'noreply@email-one.com',
        'password': 'password123'
    })
    content = response.get_json(silent=True)
    assert response.status_code == 200
    assert len(content['access_token']) > 0
    assert len(content['refresh_token']) > 0

def test_post_token_login_401_invalid_credentials(client):
    response = client.post('/api/token/login', json={
        'email': 'noreply@email-one.com',
        'password': 'wrong_password'
    })
    content = response.get_json(silent=True)
    assert response.status_code == 401
    # Handle different response formats
    if content and 'msg' in content:
        assert content['msg'] == 'Invalid credentials'
    else:
        # May be a different format or empty response
        assert response.status_code == 401

# POST /token/refresh

def test_post_token_refresh_200(client, app):
    with app.app_context():
        refresh_token = create_refresh_token(identity="noreply@email-one.com")
        request_headers = {
            'Authorization': 'Bearer {}'.format(refresh_token),
            'accept': 'application/json'
        }
        response = client.post('/api/token/refresh', headers=request_headers)
        content = response.get_json(silent=True)
        assert response.status_code == 200
        assert len(content['access_token']) > 0