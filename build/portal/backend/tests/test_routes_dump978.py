from tests.conftest import create_admin_token, create_user_token

# GET /api/uat/flight/{flight}

def test_get_uat_flight_200(client):
    response = client.get('/api/uat/flight/UAT0001')
    assert response.status_code == 200
    assert response.json['id'] == 1
    assert response.json['aircraft'] == 1
    assert response.json['flight'] == 'UAT0001'
    assert response.json['first_seen'] == '2024-07-17 01:10:11'
    assert response.json['last_seen'] == '2024-06-17 01:11:01'
    assert response.json['icao'] == 'uicao01'

def test_get_uat_flight_404(client):
    response = client.get('/api/uat/flight/UAT0000')
    assert response.status_code == 404

# GET /api/uat/flight/{flight}/positions

def test_get_uat_flight_positions_200(client):
    response = client.get('/api/uat/flight/UAT0001/positions')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 500
    assert response.json['count'] == 2
    assert response.json['positions'][0]['id'] == 1
    assert response.json['positions'][0]['flight'] == 1
    assert response.json['positions'][0]['aircraft'] == 1
    assert response.json['positions'][0]['time'] == '2024-06-17 01:11:01'
    assert response.json['positions'][0]['message'] == 50
    assert response.json['positions'][0]['squawk'] == 6523
    assert response.json['positions'][0]['latitude'] == 42.649292
    assert response.json['positions'][0]['longitude'] == -84.960896
    assert response.json['positions'][0]['track'] == 98
    assert response.json['positions'][0]['altitude'] == 4000
    assert response.json['positions'][0]['vertical_rate'] == 0
    assert response.json['positions'][0]['speed'] == 120
    assert response.json['positions'][1]['id'] == 2
    assert response.json['positions'][1]['message'] == 75

def test_get_uat_flight_positions_404(client):
    response = client.get('/api/uat/flight/UAT0000/positions')
    assert response.status_code == 404

def test_get_uat_flight_positions_400_offset(client):
    response = client.get('/api/uat/flight/UAT0001/positions?offset=-1')
    assert response.status_code == 400

def test_get_uat_flight_positions_400_limit_too_low(client):
    response = client.get('/api/uat/flight/UAT0001/positions?limit=0')
    assert response.status_code == 400

def test_get_uat_flight_positions_400_limit_too_high(client):
    response = client.get('/api/uat/flight/UAT0001/positions?limit=1001')
    assert response.status_code == 400

# GET /api/uat/flights

def test_get_uat_flights_200(client):
    response = client.get('/api/uat/flights')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 50
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 2
    assert response.json['flights'][0]['icao'] == 'uicao02'
    assert response.json['flights'][0]['aircraft'] == 2
    assert response.json['flights'][0]['flight'] == 'UAT0002'
    assert response.json['flights'][0]['first_seen'] == '2024-07-17 02:20:22'
    assert response.json['flights'][0]['last_seen'] == '2024-06-17 02:22:02'
    assert response.json['flights'][1]['id'] == 1
    assert response.json['flights'][1]['icao'] == 'uicao01'
    assert response.json['flights'][1]['aircraft'] == 1
    assert response.json['flights'][1]['flight'] == 'UAT0001'
    assert response.json['flights'][1]['first_seen'] == '2024-07-17 01:10:11'
    assert response.json['flights'][1]['last_seen'] == '2024-06-17 01:11:01'

def test_get_uat_flights_200_offset(client):
    response = client.get('/api/uat/flights?offset=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 50
    assert response.json['count'] == 1
    assert response.json['flights'][0]['id'] == 1
    assert response.json['flights'][0]['flight'] == 'UAT0001'

def test_get_uat_flights_200_limit(client):
    response = client.get('/api/uat/flights?limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['flights'][0]['id'] == 2
    assert response.json['flights'][0]['flight'] == 'UAT0002'

def test_get_uat_flights_200_offset_and_limit(client):
    response = client.get('/api/uat/flights?offset=1&limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['flights'][0]['id'] == 1

def test_get_uat_flights_400_offset(client):
    response = client.get('/api/uat/flights?offset=-1')
    assert response.status_code == 400

def test_get_uat_flights_400_limit_too_low(client):
    response = client.get('/api/uat/flights?limit=0')
    assert response.status_code == 400

def test_get_uat_flights_400_limit_too_high(client):
    response = client.get('/api/uat/flights?limit=101')
    assert response.status_code == 400

# GET /api/uat/flights/count

def test_get_uat_flights_count(client):
    response = client.get('/api/uat/flights/count')
    assert response.status_code == 200
    assert response.json['flights'] == 2

# GET /api/uat/flights/search

def test_get_uat_flights_search_200(client):
    response = client.get('/api/uat/flights/search?q=UAT')
    assert response.status_code == 200
    assert response.json['count'] == 2

def test_get_uat_flights_search_200_single_result(client):
    response = client.get('/api/uat/flights/search?q=UAT0001')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['flights'][0]['flight'] == 'UAT0001'

def test_get_uat_flights_search_200_single_result_by_icao(client):
    response = client.get('/api/uat/flights/search?q=uicao01')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['flights'][0]['flight'] == 'UAT0001'
    assert response.json['flights'][0]['icao'] == 'uicao01'

def test_get_uat_flights_search_200_no_results(client):
    response = client.get('/api/uat/flights/search?q=NOMATCH')
    assert response.status_code == 200
    assert response.json['count'] == 0

def test_get_uat_flights_search_400_no_query(client):
    response = client.get('/api/uat/flights/search')
    assert response.status_code == 400

# DELETE /api/uat/flights/purge

def test_purge_uat_flights_401(client):
    response = client.delete('/api/uat/flights/purge?days=1')
    assert response.status_code == 401

def test_purge_uat_flights_403(client, app):
    with app.app_context():
        access_token = create_user_token()
    response = client.delete(
        '/api/uat/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 403

def test_purge_uat_flights_400_no_days(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/uat/flights/purge',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 400

def test_purge_uat_flights_400_days_zero(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/uat/flights/purge?days=0',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 400

def test_purge_uat_flights_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/uat/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 200
    assert 'deleted_flights' in response.json
    assert 'deleted_positions' in response.json
    assert 'cutoff_date' in response.json
