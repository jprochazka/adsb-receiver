from conftest import create_admin_token, create_user_token

# DELETE /notifications/{id}

def test_delete_notification_204(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/notifications/FLT0013', headers=request_headers)
        assert response.status_code == 204

def test_delete_notification_204_user(client, app):
    with app.app_context():
        access_token = create_user_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        create_response = client.post('/api/notifications/FLT0013', headers=request_headers)
        assert create_response.status_code == 201
        response = client.delete('/api/notifications/FLT0013', headers=request_headers)
        assert response.status_code == 204

        admin_token = create_admin_token(app)
        admin_response = client.get(
            '/api/notifications',
            headers={'Authorization': f'Bearer {admin_token}'},
        )
        assert [item['flight'] for item in admin_response.json['notifications']] == [
            'FLT0011', 'FLT0012', 'FLT0013'
        ]

def test_delete_notification_401(client):
    response = client.delete('/api/notifications/FLT0013')
    assert response.status_code == 401

def test_delete_notification_404(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/notifications/FLT0000', headers=request_headers)
        assert response.status_code == 404

# POST /notifications/{id}

def test_post_notification_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.post('/api/notifications/FLT0014', headers=request_headers)
        assert response.status_code == 201

def test_post_notification_200_user(client, app):
    with app.app_context():
        access_token = create_user_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.post('/api/notifications/FLT0014', headers=request_headers)
        assert response.status_code == 201

def test_post_notification_401(client):
    response = client.post('/api/notifications/FLT0014')
    assert response.status_code == 401

# GET /notifications

def test_get_notifications_200(client, app):
    with app.app_context():
        access_token = create_admin_token()
    response = client.get('/api/notifications',
                          headers={'Authorization': f'Bearer {access_token}'})
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 100
    assert response.json['count'] == 3
    assert response.json['notifications'][0]['id'] == 1
    assert response.json['notifications'][0]['flight'] == "FLT0011"
    assert response.json['notifications'][1]['id'] == 2
    assert response.json['notifications'][1]['flight'] == "FLT0012"
    assert response.json['notifications'][2]['id'] == 3
    assert response.json['notifications'][2]['flight'] == "FLT0013"

def test_get_notifications_200_offset(client, app):
    with app.app_context():
        access_token = create_admin_token()
    response = client.get('/api/notifications?offset=2',
                          headers={'Authorization': f'Bearer {access_token}'})
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 100
    assert response.json['count'] == 1
    assert response.json['notifications'][0]['id'] == 3
    assert response.json['notifications'][0]['flight'] == "FLT0013"

def test_get_notifications_200_limit(client, app):
    with app.app_context():
        access_token = create_admin_token()
    response = client.get('/api/notifications?limit=1',
                          headers={'Authorization': f'Bearer {access_token}'})
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['notifications'][0]['id'] == 1
    assert response.json['notifications'][0]['flight'] == "FLT0011"

def test_get_notifications_200_offset_and_limit(client, app):
    with app.app_context():
        access_token = create_admin_token()
    response = client.get('/api/notifications?offset=1&limit=1',
                          headers={'Authorization': f'Bearer {access_token}'})
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['notifications'][0]['id'] == 2
    assert response.json['notifications'][0]['flight'] == "FLT0012"

def test_get_notifications_400_offset_less_than_0(client, app):
    with app.app_context():
        access_token = create_admin_token()
    response = client.get('/api/notifications?offset=-1',
                          headers={'Authorization': f'Bearer {access_token}'})
    assert response.status_code == 400

def test_get_notifications_400_limit_less_than_0(client, app):
    with app.app_context():
        access_token = create_admin_token()
    response = client.get('/api/notifications?limit=-1',
                          headers={'Authorization': f'Bearer {access_token}'})
    assert response.status_code == 400

def test_get_notifications_400_limit_greater_than_1000(client, app):
    with app.app_context():
        access_token = create_admin_token()
    response = client.get('/api/notifications?limit=1001',
                          headers={'Authorization': f'Bearer {access_token}'})
    assert response.status_code == 400