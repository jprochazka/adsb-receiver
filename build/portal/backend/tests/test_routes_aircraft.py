# GET /api/aircraft/{icao}

def test_get_aircraft_200(client):
    response = client.get('/api/aircraft/icao01')
    assert response.status_code == 200
    assert response.json['aircraft']['id'] == 1
    assert response.json['aircraft']['icao'] == "icao01"
    assert response.json['aircraft']['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['aircraft']['last_seen'] == "2024-06-17 01:11:01"

def test_get_aircraft_404(client):
    response = client.get('/api/aircraft/icao00')
    assert response.status_code == 404

# GET /api/aircraft/{icao}/positions

def test_get_aircraft_200(client):
    response = client.get('/api/aircraft/icao00/positions')
    assert response.status_code == 200

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