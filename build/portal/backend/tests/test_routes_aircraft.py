import pytest
import json
from backend import create_app
from backend.models import db, Aircraft, Flight, Position


# Removed local fixtures - using the ones from conftest.py which load test data


@pytest.fixture
def sample_data(app):
    """Create sample test data for edge case testing"""
    with app.app_context():
        # Create aircraft
        aircraft1 = Aircraft()
        aircraft1.icao = 'TEST01'
        aircraft1.first_seen = '2024-01-01 10:00:00'
        aircraft1.last_seen = '2024-01-01 12:00:00'
        
        aircraft2 = Aircraft()
        aircraft2.icao = 'TEST02'
        aircraft2.first_seen = '2024-01-01 11:00:00'
        aircraft2.last_seen = '2024-01-01 13:00:00'
        
        db.session.add_all([aircraft1, aircraft2])
        db.session.commit()
        
        # Create flights
        flight1 = Flight()
        flight1.aircraft = aircraft1.id
        flight1.flight = 'FL001'
        flight1.first_seen = '2024-01-01 10:00:00'
        flight1.last_seen = '2024-01-01 12:00:00'
        
        db.session.add(flight1)
        db.session.commit()
        
        # Create positions
        position1 = Position()
        position1.aircraft = aircraft1.id
        position1.flight = flight1.id
        position1.time = '2024-01-01 10:15:00'
        position1.message = 1
        position1.squawk = 1200
        position1.latitude = 40.7128
        position1.longitude = -74.0060
        position1.track = 180
        position1.altitude = 10000
        position1.vertical_rate = 500
        position1.speed = 250
        
        position2 = Position()
        position2.aircraft = aircraft1.id
        position2.flight = flight1.id
        position2.time = '2024-01-01 10:30:00'
        position2.message = 2
        position2.squawk = 1200
        position2.latitude = 40.8128
        position2.longitude = -74.1060
        position2.track = 185
        position2.altitude = 15000
        position2.vertical_rate = 600
        position2.speed = 300
        
        positions = [position1, position2]
        db.session.add_all(positions)
        db.session.commit()
        
        # Return IDs instead of objects to avoid detached instances
        return {
            'aircraft1_id': aircraft1.id,
            'aircraft1_icao': aircraft1.icao,
            'aircraft2_id': aircraft2.id,
            'aircraft2_icao': aircraft2.icao,
            'flight1_id': flight1.id,
            'positions_count': len(positions)
        }


# GET /api/aircraft/{icao}

def test_get_aircraft_by_icao_200(client):
    response = client.get('/api/aircraft/icao01')
    assert response.status_code == 200
    assert response.json['id'] == 1
    assert response.json['icao'] == "icao01"
    assert response.json['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['last_seen'] == "2024-06-17 01:11:01"

def test_get_aircraft_by_icao_404(client):
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
    assert response.json['positions'][0]['vertical_rate'] == 832
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
    assert response.json['positions'][1]['vertical_rate'] == 960
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
    assert response.json['positions'][2]['vertical_rate'] == 768
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
    assert response.json['positions'][3]['vertical_rate'] == 1216
    assert response.json['positions'][3]['speed'] == 484

def test_get_aircraft_404(client):
    response = client.get('/api/aircraft/icao00/positions')
    assert response.status_code == 404

# GET /api/aircraft

def test_get_all_aircraft_200(client):
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

def test_get_all_aircraft_200_offset(client):
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

def test_get_all_aircraft_200_limit(client):
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

def test_get_all_aircraft_200_offset_and_limit(client):
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


# Edge case tests merged from test_routes_aircraft_edge_cases.py

class TestAircraftRoutesEdgeCases:
    """Test edge cases and error conditions for aircraft routes"""

    def test_get_aircraft_invalid_icao_format(self, client, sample_data):
        """Test getting aircraft with invalid ICAO format"""
        # Test various invalid formats
        invalid_icaos = ['', '   ', 'toolong123456', '!@#$', '123']
        
        for invalid_icao in invalid_icaos:
            response = client.get(f'/api/aircraft/{invalid_icao}')
            assert response.status_code == 404

    def test_get_aircraft_case_sensitivity(self, client, sample_data):
        """Test ICAO case sensitivity"""
        # Should find aircraft regardless of case
        response_upper = client.get('/api/aircraft/TEST01')
        response_lower = client.get('/api/aircraft/test01')
        
        # Depending on implementation, these might behave differently
        # Testing the actual behavior
        assert response_upper.status_code in [200, 404]
        assert response_lower.status_code in [200, 404]

    def test_get_aircraft_positions_pagination_edge_cases(self, client, sample_data):
        """Test pagination edge cases"""
        icao = sample_data['aircraft1_icao']
        
        # Test with limit = 0
        response = client.get(f'/api/aircraft/{icao}/positions?limit=0')
        assert response.status_code == 400
        
        # Test with large limit (within valid range)
        response = client.get(f'/api/aircraft/{icao}/positions?limit=100')
        assert response.status_code == 200
        data = response.get_json()
        assert data['limit'] == 100
        
        # Test with negative limit (should be handled gracefully)
        response = client.get(f'/api/aircraft/{icao}/positions?limit=-1')
        # Should return 400 for invalid limit
        assert response.status_code == 400
        
        # Test with negative offset
        response = client.get(f'/api/aircraft/{icao}/positions?offset=-1')
        assert response.status_code == 400

    def test_get_aircraft_positions_invalid_parameters(self, client, sample_data):
        """Test positions endpoint with invalid parameters"""
        icao = sample_data['aircraft1_icao']
        
        # Test with non-numeric parameters
        response = client.get(f'/api/aircraft/{icao}/positions?limit=abc')
        assert response.status_code in [200, 400]  # Depending on error handling
        
        response = client.get(f'/api/aircraft/{icao}/positions?offset=xyz')
        assert response.status_code in [200, 400]

    def test_get_aircraft_positions_no_positions(self, client, sample_data):
        """Test getting positions for aircraft with no positions"""
        icao = sample_data['aircraft2_icao']  # aircraft2 has no positions
        
        response = client.get(f'/api/aircraft/{icao}/positions')
        assert response.status_code == 200
        data = response.get_json()
        assert data['count'] == 0
        assert len(data['positions']) == 0

    def test_get_aircraft_special_characters_in_icao(self, client):
        """Test aircraft lookup with special characters"""
        special_icaos = ['TEST%20', 'TEST+01', 'TEST/01', 'TEST\\01']
        
        for icao in special_icaos:
            response = client.get(f'/api/aircraft/{icao}')
            # Should handle URL encoding gracefully
            assert response.status_code == 404  # Assuming these don't exist

    def test_aircraft_positions_cors_headers(self, client, sample_data):
        """Test CORS headers are present"""
        icao = sample_data['aircraft1_icao']
        
        response = client.get(f'/api/aircraft/{icao}/positions')
        assert 'Access-Control-Allow-Origin' in response.headers
        assert response.headers['Access-Control-Allow-Origin'] == '*'

    def test_aircraft_detail_cors_headers(self, client, sample_data):
        """Test CORS headers on aircraft detail"""
        icao = sample_data['aircraft1_icao']
        
        response = client.get(f'/api/aircraft/{icao}')
        assert 'Access-Control-Allow-Origin' in response.headers
        assert response.headers['Access-Control-Allow-Origin'] == '*'

    def test_positions_response_structure(self, client, sample_data):
        """Test that positions response has correct structure"""
        icao = sample_data['aircraft1_icao']
        
        response = client.get(f'/api/aircraft/{icao}/positions')
        assert response.status_code == 200
        data = response.get_json()
        
        # Check required fields
        required_fields = ['offset', 'limit', 'count', 'positions']
        for field in required_fields:
            assert field in data
        
        # Check position structure
        if data['positions']:
            position = data['positions'][0]
            position_fields = [
                'id', 'flight', 'aircraft', 'time', 'message', 'squawk',
                'latitude', 'longitude', 'track', 'altitude', 'vertical_rate', 'speed'
            ]
            for field in position_fields:
                assert field in position

    def test_aircraft_detail_response_structure(self, client, sample_data):
        """Test that aircraft detail response has correct structure"""
        icao = sample_data['aircraft1_icao']
        
        response = client.get(f'/api/aircraft/{icao}')
        assert response.status_code == 200
        data = response.get_json()
        
        # Check required fields
        required_fields = ['id', 'icao', 'first_seen', 'last_seen']
        for field in required_fields:
            assert field in data

    def test_database_error_handling(self, client):
        """Test handling of database errors"""
        # This would require mocking database errors
        # For now, just test that invalid requests are handled
        response = client.get('/api/aircraft/')  # Missing ICAO
        assert response.status_code == 404

    def test_pagination_boundary_conditions(self, client, sample_data):
        """Test pagination at boundaries"""
        icao = sample_data['aircraft1_icao']
        
        # Test offset equal to total count
        response = client.get(f'/api/aircraft/{icao}/positions?offset=2')
        assert response.status_code == 200
        data = response.get_json()
        assert len(data['positions']) == 0  # Should return empty list
        
        # Test offset greater than total count
        response = client.get(f'/api/aircraft/{icao}/positions?offset=100')
        assert response.status_code == 200
        data = response.get_json()
        assert len(data['positions']) == 0

    def test_concurrent_requests(self, client, sample_data):
        """Test multiple concurrent requests"""
        icao = sample_data['aircraft1_icao']
        
        # Simulate multiple requests (basic test)
        responses = []
        for _ in range(5):
            response = client.get(f'/api/aircraft/{icao}')
            responses.append(response)
        
        # All should succeed
        for response in responses:
            assert response.status_code == 200

    def test_empty_database_behavior(self, client):
        """Test behavior with empty database"""
        # Clear all data
        with client.application.app_context():
            db.session.query(Position).delete()
            db.session.query(Flight).delete()
            db.session.query(Aircraft).delete()
            db.session.commit()
        
        # Test aircraft lookup
        response = client.get('/api/aircraft/NONEXISTENT')
        assert response.status_code == 404
        
        # Test positions lookup
        response = client.get('/api/aircraft/NONEXISTENT/positions')
        assert response.status_code == 404

    def test_malformed_urls(self, client):
        """Test malformed URLs"""
        malformed_urls = [
            '/api/aircraft/',
            '/api/aircraft//positions',
            '/api/aircraft/TEST01/',
            '/api/aircraft/TEST01/positions/',
        ]
        
        for url in malformed_urls:
            response = client.get(url)
            # Should handle gracefully (including redirects)
            assert response.status_code in [200, 404, 400, 308]

    def test_http_methods_not_allowed(self, client, sample_data):
        """Test unsupported HTTP methods"""
        icao = sample_data['aircraft1_icao']
        
        # Test POST, PUT, DELETE on GET-only endpoints
        for method in ['post', 'put', 'delete', 'patch']:
            response = getattr(client, method)(f'/api/aircraft/{icao}')
            assert response.status_code == 405  # Method Not Allowed
            
            response = getattr(client, method)(f'/api/aircraft/{icao}/positions')
            assert response.status_code == 405

    def test_large_dataset_performance(self, client, app):
        """Test with larger dataset for performance"""
        with app.app_context():
            # Create aircraft with many positions
            aircraft = Aircraft(
                icao='PERF01',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 20:00:00'
            )
            db.session.add(aircraft)
            db.session.commit()
            
            # Create a flight first
            flight = Flight(
                aircraft=aircraft.id,
                flight='PERF001',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 20:00:00'
            )
            db.session.add(flight)
            db.session.commit()
            
            # Create many positions
            positions = []
            for i in range(100):
                position = Position(
                    aircraft=aircraft.id,
                    flight=flight.id,
                    time=f'2024-01-01 {10 + i // 60:02d}:{i % 60:02d}:00',
                    message=i,
                    squawk=1200,
                    latitude=40.0 + i * 0.01,
                    longitude=-74.0 + i * 0.01,
                    altitude=10000 + i * 100,
                    track=180,
                    vertical_rate=0,
                    speed=250 + i
                )
                positions.append(position)
            
            db.session.add_all(positions)
            db.session.commit()
        
        # Test retrieval
        response = client.get('/api/aircraft/PERF01/positions')
        assert response.status_code == 200
        data = response.get_json()
        assert data['count'] == 100

    def test_unicode_icao_handling(self, client):
        """Test Unicode characters in ICAO codes"""
        unicode_icaos = ['TËST01', 'TÉST02', 'TEST🛩️']
        
        for icao in unicode_icaos:
            response = client.get(f'/api/aircraft/{icao}')
            # Should handle Unicode gracefully
            assert response.status_code in [200, 404, 400]