from unittest.mock import patch


def _fake_fetch(rrd_path: str, ds_name: str, cf: str, period: str):
    # Deterministic per-DS values used by multiple graph endpoint tests
    base = {
        'total': 10.0,
        'positions': 6.0,
        'value': 3.0,
        'rx': 1000.0,
        'tx': 200.0,
    }.get(ds_name, 1.0)
    return {100: base, 130: base + 1}


@patch('backend.routes.graphs._fetch_rrd', side_effect=_fake_fetch)
def test_get_dump1090_graph_200(mock_fetch, client):
    response = client.get('/api/graphs/dump1090/aircraft?period=1h')

    assert response.status_code == 200
    data = response.get_json()

    assert data['period'] == '1h'
    assert data['labels'] == [100, 130]
    assert len(data['datasets']) == 3
    assert data['datasets'][0]['label'] == 'total'
    assert data['datasets'][1]['label'] == 'positions'
    assert data['datasets'][2]['label'] == 'mlat'


@patch('backend.routes.graphs._fetch_rrd', side_effect=_fake_fetch)
def test_get_dump978_graph_200(mock_fetch, client):
    response = client.get('/api/graphs/dump978/aircraft?period=6h')

    assert response.status_code == 200
    data = response.get_json()

    assert data['period'] == '6h'
    assert data['labels'] == [100, 130]
    assert len(data['datasets']) == 3
    assert data['datasets'][0]['label'] == 'total'
    assert data['datasets'][1]['label'] == 'positions'
    assert data['datasets'][2]['label'] == 'with_callsign'


@patch('backend.routes.graphs._fetch_rrd', side_effect=_fake_fetch)
@patch('backend.routes.graphs._get_network_interface', return_value='eth0')
def test_get_system_network_graph_200(mock_iface, mock_fetch, client):
    response = client.get('/api/graphs/system/network?period=24h')

    assert response.status_code == 200
    data = response.get_json()

    assert data['period'] == '24h'
    assert data['labels'] == [100, 130]
    assert [d['label'] for d in data['datasets']] == ['rx', 'tx']


def test_get_graph_400_invalid_period(client):
    response = client.get('/api/graphs/dump1090/aircraft?period=365d')
    assert response.status_code == 400


def test_get_graph_404_invalid_metric(client):
    response = client.get('/api/graphs/dump1090/not-a-metric?period=1h')
    assert response.status_code == 404
