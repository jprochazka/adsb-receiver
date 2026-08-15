from unittest.mock import patch

import pytest

from conftest import create_admin_token, create_user_token


@pytest.fixture
def admin_headers(app):
    token = create_admin_token(app)
    return {'Authorization': 'Bearer ' + token}


@pytest.fixture
def user_headers(app):
    token = create_user_token(app)
    return {'Authorization': 'Bearer ' + token}


def test_get_config_requires_admin(client, user_headers):
    assert client.get('/api/dumpvdl2/config').status_code == 401
    assert client.get('/api/dumpvdl2/config', headers=user_headers).status_code == 403


def test_get_config_returns_service_state_and_frequencies(
    client, admin_headers, tmp_path, monkeypatch
):
    config_path = tmp_path / 'dumpvdl2'
    config_path.write_text(
        'DUMPVDL2_DEVICE="0"\n'
        'DUMPVDL2_FREQUENCIES="136.100M 136.975M"\n',
        encoding='utf-8',
    )
    monkeypatch.setenv('DUMPVDL2_CONFIG_PATH', str(config_path))

    with patch(
        'backend.routes.dumpvdl2._service_active',
        side_effect=lambda service: service == 'dumpvdl2.service',
    ):
        response = client.get('/api/dumpvdl2/config', headers=admin_headers)

    assert response.status_code == 200
    assert response.get_json() == {
        'installed': True,
        'active': True,
        'ingest_active': False,
        'frequencies': [136.1, 136.975],
    }


def test_put_config_validates_frequency_range(client, admin_headers):
    response = client.put(
        '/api/dumpvdl2/config',
        headers=admin_headers,
        json={'frequencies': [117.9]},
    )

    assert response.status_code == 400
    assert 'between 118.0 and 137.0 MHz' in response.get_json()['msg']


def test_put_config_applies_sorted_unique_frequencies(
    client, admin_headers, tmp_path, monkeypatch
):
    config_path = tmp_path / 'dumpvdl2'
    config_path.write_text(
        'DUMPVDL2_FREQUENCIES="136.100M"\n',
        encoding='utf-8',
    )
    monkeypatch.setenv('DUMPVDL2_CONFIG_PATH', str(config_path))

    with patch('backend.routes.dumpvdl2._apply_frequencies') as apply_frequencies, \
         patch('backend.routes.dumpvdl2._service_active', return_value=True):
        response = client.put(
            '/api/dumpvdl2/config',
            headers=admin_headers,
            json={'frequencies': [136.975, 136.1, 136.975]},
        )

    assert response.status_code == 200
    apply_frequencies.assert_called_once_with([136.1, 136.975])


def test_put_config_reports_missing_helper(client, admin_headers):
    with patch(
        'backend.routes.dumpvdl2._apply_frequencies',
        side_effect=FileNotFoundError,
    ):
        response = client.put(
            '/api/dumpvdl2/config',
            headers=admin_headers,
            json={'frequencies': [136.975]},
        )

    assert response.status_code == 503
