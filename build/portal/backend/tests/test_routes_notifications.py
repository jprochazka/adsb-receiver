from flask_jwt_extended import create_access_token

# DELETE /notification/{id}

def test_delete_notification_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/notification/FLT0013', headers=request_headers)
        assert response.status_code == 204

def test_delete_notification_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/notification/FLT0000', headers=request_headers)
        assert response.status_code == 404

# POST /notification

def test_post_notification_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.post('/api/notification/FLT0014', headers=request_headers)
        assert response.status_code == 201

# GET /notifications

def test_get_notifications_200(client):
    response = client.get('/api/notifications')
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

def test_get_notifications_200_offset(client):
    response = client.get('/api/notifications?offset=2')
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 100
    assert response.json['count'] == 1
    assert response.json['notifications'][0]['id'] == 3
    assert response.json['notifications'][0]['flight'] == "FLT0013"

def test_get_notifications_200_limit(client):
    response = client.get('/api/notifications?limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['notifications'][0]['id'] == 1
    assert response.json['notifications'][0]['flight'] == "FLT0011"

def test_get_notifications_200_offset_and_limit(client):
    response = client.get('/api/notifications?offset=1&limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['notifications'][0]['id'] == 2
    assert response.json['notifications'][0]['flight'] == "FLT0012"

def test_get_notifications_400_offset_less_than_0(client):
    response = client.get('/api/notifications?offset=-1')
    assert response.status_code == 400

def test_get_notifications_400_limit_less_than_0(client):
    response = client.get('/api/notifications?limit=-1')
    assert response.status_code == 400

def test_get_notifications_400_limit_greater_than_1000(client):
    response = client.get('/api/notifications?limit=1001')
    assert response.status_code == 400