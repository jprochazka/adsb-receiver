from backend import create_app

def test_config():
    assert not create_app().testing
    assert create_app({'TESTING': True}).testing

def test_api_docs(client):
    response = client.get('/api/docs')
    assert b'adsb_receiver_api_v1_oas3.yaml' in response.data