import os
import tempfile
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

from conftest import create_admin_token, create_user_token


@pytest.fixture
def acars_db():
    """Create a temporary ACARS SQLite database with test data."""
    fd, path = tempfile.mkstemp(suffix='.sqlite')
    engine = create_engine(f'sqlite:///{path}', connect_args={'check_same_thread': False})
    with engine.begin() as conn:
        conn.execute(text(
            "CREATE TABLE Flights ("
            "  FlightID INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  Registration TEXT,"
            "  FlightNumber TEXT,"
            "  StartTime TEXT,"
            "  LastTime TEXT,"
            "  NbMessages INTEGER DEFAULT 0"
            ")"
        ))
        conn.execute(text(
            "CREATE TABLE Messages ("
            "  MessageID INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  FlightID INTEGER,"
            "  Time TEXT,"
            "  StID INTEGER,"
            "  Channel INTEGER,"
            "  Error INTEGER,"
            "  SignalLvl REAL,"
            "  Mode TEXT,"
            "  Ack TEXT,"
            "  Label TEXT,"
            "  BlockNo TEXT,"
            "  MessNo TEXT,"
            "  Txt TEXT"
            ")"
        ))
        conn.execute(text(
            "INSERT INTO Flights (Registration, FlightNumber, StartTime, LastTime, NbMessages) "
            "VALUES ('N12345', 'AA100', '2026-01-01 10:00:00', '2026-01-01 12:00:00', 3)"
        ))
        conn.execute(text(
            "INSERT INTO Flights (Registration, FlightNumber, StartTime, LastTime, NbMessages) "
            "VALUES ('N67890', 'UA200', '2026-01-02 08:00:00', '2026-01-02 10:00:00', 1)"
        ))
        for i in range(3):
            conn.execute(text(
                "INSERT INTO Messages (FlightID, Time, StID, Channel, Error, SignalLvl, Mode, Ack, Label, BlockNo, MessNo, Txt) "
                "VALUES (1, :time, 1, 0, 0, -5.3, '2', '', 'H1', '1', :mno, 'test message')"
            ), {'time': f'2026-01-01 10:{i:02d}:00', 'mno': str(i)})
        conn.execute(text(
            "INSERT INTO Messages (FlightID, Time, StID, Channel, Error, SignalLvl, Mode, Ack, Label, BlockNo, MessNo, Txt) "
            "VALUES (2, '2026-01-02 08:00:00', 1, 0, 0, -4.0, '2', '', 'Q0', '1', '0', 'hello')"
        ))
    yield path, engine
    os.close(fd)
    os.unlink(path)


@pytest.fixture
def mock_acars_engine(acars_db):
    """Patch _get_acars_engine to return the temp ACARS engine, and
    patch centralized config reads inside _get_database_info to point to the temp file."""
    path, engine = acars_db
    with patch('backend.routes.acars._get_acars_engine', return_value=engine), \
         patch('backend.routes.acars.load_portal_config', return_value={'acars': {'database': path}}), \
         patch('backend.routes.acars.os.path.exists', return_value=True), \
         patch('backend.routes.acars.os.path.getsize', return_value=4096):
        yield


@pytest.fixture
def admin_headers(app):
    token = create_admin_token(app)
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture
def user_headers(app):
    token = create_user_token(app)
    return {'Authorization': f'Bearer {token}'}


class TestAcarsRoutes:
    """Test ACARS API routes."""

    # ---- /flights ----

    def test_get_flights(self, client, mock_acars_engine):
        response = client.get('/api/acars/flights')
        assert response.status_code == 200
        data = response.get_json()
        assert data['total'] == 2
        assert len(data['flights']) == 2
        assert data['flights'][0]['flight_number'] == 'UA200'  # ordered by LastTime DESC
        assert 'aircraft_class' in data['flights'][0]
        assert 'classification_source' in data['flights'][0]

    def test_get_flights_uses_opensky_classification_by_registration(self, client, mock_acars_engine):
        with patch('backend.routes.acars.get_opensky_classification_by_registration') as mock_lookup:
            mock_lookup.return_value = ('helicopter', 'opensky', 'high')

            response = client.get('/api/acars/flights')

        assert response.status_code == 200
        data = response.get_json()
        assert data['flights'][0]['aircraft_class'] == 'helicopter'
        assert data['flights'][0]['classification_source'] == 'opensky'
        assert data['flights'][0]['classification_confidence'] == 'high'

    def test_get_flights_pagination(self, client, mock_acars_engine):
        response = client.get('/api/acars/flights?offset=0&limit=1')
        assert response.status_code == 200
        data = response.get_json()
        assert data['count'] == 1
        assert data['total'] == 2
        assert data['limit'] == 1

    def test_get_flights_bad_offset(self, client, mock_acars_engine):
        response = client.get('/api/acars/flights?offset=-1')
        assert response.status_code == 400

    def test_get_flights_bad_limit(self, client, mock_acars_engine):
        response = client.get('/api/acars/flights?limit=0')
        assert response.status_code == 400

    def test_get_flights_limit_too_large(self, client, mock_acars_engine):
        response = client.get('/api/acars/flights?limit=101')
        assert response.status_code == 400

    def test_get_flights_limit_100(self, client, mock_acars_engine):
        response = client.get('/api/acars/flights?limit=100')
        assert response.status_code == 200
        data = response.get_json()
        assert data['limit'] == 100

    def test_get_flights_db_unavailable(self, client):
        with patch('backend.routes.acars._get_acars_engine', side_effect=OperationalError('', '', '')):
            response = client.get('/api/acars/flights')
            assert response.status_code == 503

    # ---- /flights/count ----

    def test_get_flights_count(self, client, mock_acars_engine):
        response = client.get('/api/acars/flights/count')
        assert response.status_code == 200
        data = response.get_json()
        assert data['flights'] == 2

    def test_get_flights_count_db_unavailable(self, client):
        with patch('backend.routes.acars._get_acars_engine', side_effect=OperationalError('', '', '')):
            response = client.get('/api/acars/flights/count')
            assert response.status_code == 503

    # ---- /flights/database ----

    def test_get_database_info(self, client, mock_acars_engine, admin_headers):
        response = client.get('/api/acars/flights/database', headers=admin_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert data['size'] == 4096

    def test_get_database_info_unavailable(self, client, admin_headers):
        with patch('backend.routes.acars.load_portal_config', return_value={'acars': {'database': '/nonexistent'}}), \
             patch('backend.routes.acars.os.path.exists', return_value=False):
            response = client.get('/api/acars/flights/database', headers=admin_headers)
            assert response.status_code == 503

    def test_get_database_info_requires_admin(self, client, user_headers):
        assert client.get('/api/acars/flights/database').status_code == 401
        assert client.get('/api/acars/flights/database', headers=user_headers).status_code == 403

    # ---- /flight/<id>/messages ----

    def test_get_flight_messages(self, client, mock_acars_engine):
        response = client.get('/api/acars/flight/1/messages')
        assert response.status_code == 200
        data = response.get_json()
        assert data['total'] == 3
        assert len(data['messages']) == 3
        assert data['messages'][0]['text'] == 'test message'

    def test_get_flight_messages_pagination(self, client, mock_acars_engine):
        response = client.get('/api/acars/flight/1/messages?offset=0&limit=2')
        assert response.status_code == 200
        data = response.get_json()
        assert data['count'] == 2
        assert data['total'] == 3

    def test_get_flight_messages_not_found(self, client, mock_acars_engine):
        response = client.get('/api/acars/flight/999/messages')
        assert response.status_code == 404

    def test_get_flight_messages_bad_params(self, client, mock_acars_engine):
        response = client.get('/api/acars/flight/1/messages?limit=101')
        assert response.status_code == 400

    def test_get_flight_messages_limit_100(self, client, mock_acars_engine):
        response = client.get('/api/acars/flight/1/messages?limit=100')
        assert response.status_code == 200
        data = response.get_json()
        assert data['limit'] == 100

    def test_get_flight_messages_db_unavailable(self, client):
        with patch('backend.routes.acars._get_acars_engine', side_effect=OperationalError('', '', '')):
            response = client.get('/api/acars/flight/1/messages')
            assert response.status_code == 503

    # ---- /messages/count ----

    def test_get_messages_count(self, client, mock_acars_engine):
        response = client.get('/api/acars/messages/count')
        assert response.status_code == 200
        data = response.get_json()
        assert data['messages'] == 4

    def test_get_messages_count_db_unavailable(self, client):
        with patch('backend.routes.acars._get_acars_engine', side_effect=OperationalError('', '', '')):
            response = client.get('/api/acars/messages/count')
            assert response.status_code == 503

    # ---- /flights/purge (DELETE, admin) ----

    def test_purge_requires_auth(self, client):
        response = client.delete('/api/acars/flights/purge?days=30')
        assert response.status_code == 401

    def test_purge_requires_admin(self, client, user_headers):
        response = client.delete('/api/acars/flights/purge?days=30', headers=user_headers)
        assert response.status_code == 403

    def test_purge_requires_days(self, client, admin_headers, mock_acars_engine):
        response = client.delete('/api/acars/flights/purge', headers=admin_headers)
        assert response.status_code == 400

    def test_purge_invalid_days(self, client, admin_headers, mock_acars_engine):
        response = client.delete('/api/acars/flights/purge?days=0', headers=admin_headers)
        assert response.status_code == 400

    def test_purge_success(self, client, admin_headers, mock_acars_engine):
        response = client.delete('/api/acars/flights/purge?days=1', headers=admin_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert 'deleted_flights' in data
        assert 'deleted_messages' in data

    def test_purge_db_unavailable(self, client, admin_headers):
        with patch('backend.routes.acars._get_acars_engine', side_effect=OperationalError('', '', '')):
            response = client.delete('/api/acars/flights/purge?days=30', headers=admin_headers)
            assert response.status_code == 503
