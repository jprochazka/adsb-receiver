from backend import create_app

_TEST_CONFIG = {
    'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:',
    'JWT_SECRET_KEY': 'test-secret-key',
}

def test_config():
    assert not create_app(_TEST_CONFIG).testing
    assert create_app({**_TEST_CONFIG, 'TESTING': True}).testing

def test_api_docs(client):
    # Test Flask-RESTX API documentation endpoint
    response = client.get('/api/docs/')
    assert response.status_code == 200
    # Check for Swagger UI content
    assert b'swagger-ui' in response.data or b'redoc' in response.data


def test_api_docs_can_be_disabled(monkeypatch):
    monkeypatch.setenv('PORTAL_API_DOCS_ENABLED', 'false')
    app = create_app({**_TEST_CONFIG, 'TESTING': True})

    response = app.test_client().get('/api/docs/')

    assert response.status_code == 404