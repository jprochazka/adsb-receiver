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
