from backend import create_app

def test_config():
    assert not create_app().testing
    assert create_app({'TESTING': True}).testing

def test_api_docs(client):
    # Test Flask-RESTX API documentation endpoint
    response = client.get('/api/docs/')
    assert response.status_code == 200
    # Check for Swagger UI content
    assert b'swagger-ui' in response.data or b'redoc' in response.data