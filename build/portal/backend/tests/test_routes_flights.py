# GET /api/flight/{flight}

def test_get_flight_200(client):
    response = client.get('/api/flight/FLT0001')
    assert response.status_code == 200
    assert response.json['id'] == 1
    assert response.json['aircraft'] == 1
    assert response.json['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['last_seen'] == "2024-06-17 01:11:01"

def test_get_flight_404(client):
    response = client.get('/api/flight/FLT0000')
    assert response.status_code == 404

# GET /api/flight/{flight}/positions

def test_get_flight_positions_200(client):
    response = client.get('/api/flight/FLT0005/positions')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 500
    assert response.json['count'] == 4
    assert response.json['positions'][0]['id'] == 11
    assert response.json['positions'][0]['flight'] == 4
    assert response.json['positions'][0]['aircraft'] == 5
    assert response.json['positions'][0]['time'] == '2024-06-17 05:55:05'
    assert response.json['positions'][0]['message'] == 323
    assert response.json['positions'][0]['squawk'] == 1317
    assert response.json['positions'][0]['latitude'] == 41.774163
    assert response.json['positions'][0]['longitude'] == -83.827344
    assert response.json['positions'][0]['track'] == 91
    assert response.json['positions'][0]['altitude'] == 36475
    assert response.json['positions'][0]['verticle_rate'] == 832
    assert response.json['positions'][0]['speed'] == 486
    assert response.json['positions'][1]['id'] == 12
    assert response.json['positions'][1]['flight'] == 4
    assert response.json['positions'][1]['aircraft'] == 5
    assert response.json['positions'][1]['time'] == '2024-07-17 05:50:20'
    assert response.json['positions'][1]['message'] == 340
    assert response.json['positions'][1]['squawk'] == 1317
    assert response.json['positions'][1]['latitude'] == 41.773837
    assert response.json['positions'][1]['longitude'] == -83.788828
    assert response.json['positions'][1]['track'] == 91
    assert response.json['positions'][1]['altitude'] == 36625
    assert response.json['positions'][1]['verticle_rate'] == 960
    assert response.json['positions'][1]['speed'] == 487
    assert response.json['positions'][2]['id'] == 13
    assert response.json['positions'][2]['flight'] == 4
    assert response.json['positions'][2]['aircraft'] == 5
    assert response.json['positions'][2]['time'] == '2024-07-17 05:50:35'
    assert response.json['positions'][2]['message'] == 417
    assert response.json['positions'][2]['squawk'] == 1317
    assert response.json['positions'][2]['latitude'] == 41.773464
    assert response.json['positions'][2]['longitude'] == -83.749737
    assert response.json['positions'][2]['track'] == 91
    assert response.json['positions'][2]['altitude'] == 36825
    assert response.json['positions'][2]['verticle_rate'] == 768
    assert response.json['positions'][2]['speed'] == 487
    assert response.json['positions'][3]['id'] == 14
    assert response.json['positions'][3]['flight'] == 4
    assert response.json['positions'][3]['aircraft'] == 5
    assert response.json['positions'][3]['time'] == '2024-07-17 05:50:55'
    assert response.json['positions'][3]['message'] == 504
    assert response.json['positions'][3]['squawk'] == 1317
    assert response.json['positions'][3]['latitude'] == 41.772903
    assert response.json['positions'][3]['longitude'] == -83.690727
    assert response.json['positions'][3]['track'] == 91
    assert response.json['positions'][3]['altitude'] == 37225
    assert response.json['positions'][3]['verticle_rate'] == 1216
    assert response.json['positions'][3]['speed'] == 484

def test_get_flight_404(client):
    response = client.get('/api/flight/FLT0000/positions')
    assert response.status_code == 404

# GET /api/flights

def test_get_flights_200(client):
    response = client.get('/api/flights')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 50
    assert response.json['count'] == 4
    assert response.json['flights'][0]['id'] == 4
    assert response.json['flights'][0]['aircraft'] == 5
    assert response.json['flights'][0]['flight'] == "FLT0005"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 04:40:44"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 04:44:04"
    assert response.json['flights'][1]['id'] == 3
    assert response.json['flights'][1]['aircraft'] == 3
    assert response.json['flights'][1]['flight'] == "FLT0003"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 03:33:03"
    assert response.json['flights'][2]['id'] == 2
    assert response.json['flights'][2]['aircraft'] == 2
    assert response.json['flights'][2]['flight'] == "FLT0002"
    assert response.json['flights'][2]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['flights'][2]['last_seen'] == "2024-06-17 02:22:02"
    assert response.json['flights'][3]['id'] == 1
    assert response.json['flights'][3]['aircraft'] == 1
    assert response.json['flights'][3]['flight'] == "FLT0001"
    assert response.json['flights'][3]['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['flights'][3]['last_seen'] == "2024-06-17 01:11:01"
    
def test_get_flights_200_offset(client):
    response = client.get('/api/flights?offset=2')
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 50
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 2
    assert response.json['flights'][0]['aircraft'] == 2
    assert response.json['flights'][0]['flight'] == "FLT0002"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 02:22:02"
    assert response.json['flights'][1]['id'] == 1
    assert response.json['flights'][1]['aircraft'] == 1
    assert response.json['flights'][1]['flight'] == "FLT0001"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 01:11:01"

def test_get_flights_200_limit(client):
    response = client.get('/api/flights?limit=2')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 2
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 4
    assert response.json['flights'][0]['aircraft'] == 5
    assert response.json['flights'][0]['flight'] == "FLT0005"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 04:40:44"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 04:44:04"
    assert response.json['flights'][1]['id'] == 3
    assert response.json['flights'][1]['aircraft'] == 3
    assert response.json['flights'][1]['flight'] == "FLT0003"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 03:33:03"

def test_get_flights_200_offset_and_limit(client):
    response = client.get('/api/flights?offset=1&limit=2')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 2
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 3
    assert response.json['flights'][0]['aircraft'] == 3
    assert response.json['flights'][0]['flight'] == "FLT0003"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 03:33:03"
    assert response.json['flights'][1]['id'] == 2
    assert response.json['flights'][1]['aircraft'] == 2
    assert response.json['flights'][1]['flight'] == "FLT0002"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 02:22:02"

def test_get_flights_400_offset_less_than_0(client):
    response = client.get('/api/flights?offset=-1')
    assert response.status_code == 400

def test_get_flights_400_limit_less_than_0(client):
    response = client.get('/api/flights?limit=-1')
    assert response.status_code == 400

def test_get_flights_400_limit_greater_than_100(client):
    response = client.get('/api/flights?limit=101')
    assert response.status_code == 400

# GET /api/flights/count

def test_get_flights_count(client):
    response = client.get('/api/flights/count')
    assert response.status_code == 200
    assert response.json["flights"] == 4