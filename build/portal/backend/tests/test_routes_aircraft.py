# GET /api/aircraft/{icao}

def test_get_aircraft_200(client):
    response = client.get('/api/aircraft/icao01')
    assert response.status_code == 200
    assert response.json['id'] == 1
    assert response.json['icao'] == "icao01"
    assert response.json['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['last_seen'] == "2024-06-17 01:11:01"

def test_get_aircraft_404(client):
    response = client.get('/api/aircraft/icao00')
    assert response.status_code == 404

# GET /api/aircraft/{icao}/positions

def test_get_aircraft_positions_200(client):
    response = client.get('/api/aircraft/icao05/positions')
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

def test_get_aircraft_404(client):
    response = client.get('/api/aircraft/icao00/positions')
    assert response.status_code == 404

# GET /api/aircraft

def test_get_aircraft_200(client):
    response = client.get('/api/aircraft')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 50
    assert response.json['count'] == 5
    assert response.json['aircraft'][0]['id'] == 5
    assert response.json['aircraft'][0]['icao'] == "icao05"
    assert response.json['aircraft'][0]['first_seen'] == "2024-07-17 05:50:55"
    assert response.json['aircraft'][0]['last_seen'] == "2024-06-17 05:55:05"
    assert response.json['aircraft'][1]['id'] == 4
    assert response.json['aircraft'][1]['icao'] == "icao04"
    assert response.json['aircraft'][1]['first_seen'] == "2024-07-17 04:40:44"
    assert response.json['aircraft'][1]['last_seen'] == "2024-06-17 04:44:04"
    assert response.json['aircraft'][2]['id'] == 3
    assert response.json['aircraft'][2]['icao'] == "icao03"
    assert response.json['aircraft'][2]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['aircraft'][2]['last_seen'] == "2024-06-17 03:33:03"
    assert response.json['aircraft'][3]['id'] == 2
    assert response.json['aircraft'][3]['icao'] == "icao02"
    assert response.json['aircraft'][3]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['aircraft'][3]['last_seen'] == "2024-06-17 02:22:02"
    assert response.json['aircraft'][4]['id'] == 1
    assert response.json['aircraft'][4]['icao'] == "icao01"
    assert response.json['aircraft'][4]['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['aircraft'][4]['last_seen'] == "2024-06-17 01:11:01"

def test_get_aircraft_200_offset(client):
    response = client.get('/api/aircraft?offset=2')
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 50
    assert response.json['count'] == 3
    assert response.json['aircraft'][0]['id'] == 3
    assert response.json['aircraft'][0]['icao'] == "icao03"
    assert response.json['aircraft'][0]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['aircraft'][0]['last_seen'] == "2024-06-17 03:33:03"
    assert response.json['aircraft'][1]['id'] == 2
    assert response.json['aircraft'][1]['icao'] == "icao02"
    assert response.json['aircraft'][1]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['aircraft'][1]['last_seen'] == "2024-06-17 02:22:02"
    assert response.json['aircraft'][2]['id'] == 1
    assert response.json['aircraft'][2]['icao'] == "icao01"
    assert response.json['aircraft'][2]['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['aircraft'][2]['last_seen'] == "2024-06-17 01:11:01"

def test_get_aircraft_200_limit(client):
    response = client.get('/api/aircraft?limit=2')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 2
    assert response.json['count'] == 2
    assert response.json['aircraft'][0]['id'] == 5
    assert response.json['aircraft'][0]['icao'] == "icao05"
    assert response.json['aircraft'][0]['first_seen'] == "2024-07-17 05:50:55"
    assert response.json['aircraft'][0]['last_seen'] == "2024-06-17 05:55:05"
    assert response.json['aircraft'][1]['id'] == 4
    assert response.json['aircraft'][1]['icao'] == "icao04"
    assert response.json['aircraft'][1]['first_seen'] == "2024-07-17 04:40:44"
    assert response.json['aircraft'][1]['last_seen'] == "2024-06-17 04:44:04"

def test_get_aircraft_200_offset_and_limit(client):
    response = client.get('/api/aircraft?offset=1&limit=2')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 2
    assert response.json['count'] == 2
    assert response.json['aircraft'][0]['id'] == 4
    assert response.json['aircraft'][0]['icao'] == "icao04"
    assert response.json['aircraft'][0]['first_seen'] == "2024-07-17 04:40:44"
    assert response.json['aircraft'][0]['last_seen'] == "2024-06-17 04:44:04"
    assert response.json['aircraft'][1]['id'] == 3
    assert response.json['aircraft'][1]['icao'] == "icao03"
    assert response.json['aircraft'][1]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['aircraft'][1]['last_seen'] == "2024-06-17 03:33:03"

def test_get_aircraft_400_offset_less_than_0(client):
    response = client.get('/api/aircraft?offset=-1')
    assert response.status_code == 400

def test_get_aircraft_400_limit_less_than_0(client):
    response = client.get('/api/aircraft?limit=-1')
    assert response.status_code == 400

def test_get_aircraft_400_limit_greater_than_100(client):
    response = client.get('/api/aircraft?limit=101')
    assert response.status_code == 400

# GET /api/aircraft/count

def test_get_aircraft_count(client):
    response = client.get('/api/aircraft/count')
    assert response.status_code == 200
    assert response.json["aircraft"] == 5