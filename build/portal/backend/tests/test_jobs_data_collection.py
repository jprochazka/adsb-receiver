import pytest
import json
import logging
from urllib.error import URLError
from unittest.mock import patch, MagicMock
from datetime import datetime, timezone
from backend import create_app
from backend.models import db, Aircraft, Flight, Position, Dump978Flight
from backend.jobs.dump1090_data_collection import DataProcessor
from backend.jobs.dump978_data_collection import UatDataProcessor

TEST_NOW = datetime(2022, 1, 1, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture
def app():
    """Create and configure test app"""
    app = create_app({
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:',
        'SQLALCHEMY_TRACK_MODIFICATIONS': False,
        'JWT_SECRET_KEY': 'test-secret-key',
    })

    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()


@pytest.fixture
def processor():
    """Create DataProcessor instance"""
    return DataProcessor()


class TestDataProcessor:
    """Test data collection processor"""

    def test_log_method(self, processor, caplog):
        """Test logging functionality"""
        test_message = "Test log message"
        with caplog.at_level(logging.INFO):
            processor.log(test_message)

        assert test_message in caplog.text
        assert 'dump1090_data_collection' in caplog.text

    @patch('backend.jobs.dump1090_data_collection.urlopen')
    def test_read_json_success(self, mock_urlopen, processor):
        """Test successful JSON reading from dump1090"""
        mock_response = MagicMock()
        mock_data = {
            "now": 1640995200.0,
            "aircraft": [
                {
                    "hex": "abc123",
                    "flight": "TST123  ",
                    "lat": 40.7128,
                    "lon": -74.0060,
                    "altitude": 30000,
                    "track": 180,
                    "speed": 450
                }
            ]
        }
        mock_response.read.return_value = json.dumps(mock_data).encode()
        mock_urlopen.return_value = mock_response
        
        with patch('json.load', return_value=mock_data):
            result = processor.read_json()
            
        assert result == mock_data
        assert len(result["aircraft"]) == 1
        assert result["aircraft"][0]["hex"] == "abc123"

    @patch('backend.jobs.dump1090_data_collection.urlopen')
    @patch('backend.jobs.dump1090_data_collection.logging.error')
    def test_read_json_failure(self, mock_logging, mock_urlopen, processor):
        """Test JSON reading failure handling"""
        mock_urlopen.side_effect = URLError('Connection failed')
        
        result = processor.read_json()
        
        assert result is None
        mock_logging.assert_called_once()

    @patch.object(DataProcessor, 'read_json')
    @patch.object(DataProcessor, 'process_aircraft')
    def test_process_all_aircraft_success(self, mock_process_aircraft, mock_read_json, processor):
        """Test processing all aircraft successfully"""
        mock_data = {
            "aircraft": [
                {"hex": "abc123", "flight": "TST123"},
                {"hex": "def456", "flight": "TST456"}
            ]
        }
        mock_read_json.return_value = mock_data
        mock_process_aircraft.return_value = 1  # Mock aircraft_id
        
        processor.process_all_aircraft(TEST_NOW)
        
        assert mock_process_aircraft.call_count == 2

    @patch.object(DataProcessor, 'read_json')
    def test_process_all_aircraft_no_data(self, mock_read_json, processor, caplog):
        """Test processing when no aircraft data available"""
        mock_data = {"aircraft": []}
        mock_read_json.return_value = mock_data

        with caplog.at_level(logging.INFO):
            processor.process_all_aircraft(TEST_NOW)

        assert "no aircraft data to process" in caplog.text

    @patch.object(DataProcessor, 'process_flight')
    def test_process_aircraft_new_aircraft(self, mock_process_flight, processor, app):
        """Test processing a new aircraft"""
        with app.app_context():
            aircraft_data = {
                "hex": "abc123",
                "flight": "TST123  "
            }
            
            # Ensure no existing aircraft
            existing = Aircraft.query.filter_by(icao="abc123").first()
            assert existing is None
            
            result = processor.process_aircraft(aircraft_data, TEST_NOW)
            
            # Should create new aircraft
            new_aircraft = Aircraft.query.filter_by(icao="abc123").first()
            assert new_aircraft is not None
            assert new_aircraft.icao == "abc123"
            assert result == new_aircraft.id
            
            mock_process_flight.assert_called_once_with(new_aircraft.id, aircraft_data, TEST_NOW)

    @patch.object(DataProcessor, 'process_positions')
    def test_process_aircraft_existing_aircraft(self, mock_process_positions, processor, app):
        """Test processing an existing aircraft"""
        with app.app_context():
            # Create existing aircraft
            existing_aircraft = Aircraft(
                icao="abc123",
                first_seen="2022-01-01 10:00:00",
                last_seen="2022-01-01 10:00:00"
            )
            db.session.add(existing_aircraft)
            db.session.commit()
            
            aircraft_data = {
                "hex": "abc123",
                "lat": 40.7128,
                "lon": -74.0060
            }
            
            result = processor.process_aircraft(aircraft_data, TEST_NOW)
            
            # Should update existing aircraft's last_seen
            updated_aircraft = Aircraft.query.filter_by(icao="abc123").first()
            assert updated_aircraft is not None
            assert result == existing_aircraft.id
            
            mock_process_positions.assert_called_once_with(existing_aircraft.id, None, aircraft_data, TEST_NOW)

    @patch('backend.jobs.dump1090_data_collection.Aircraft')
    @patch('backend.jobs.dump1090_data_collection.logging.error')
    def test_process_aircraft_database_error(self, mock_logging, mock_aircraft, processor, app):
        """Test aircraft processing with database error"""
        with app.app_context():
            aircraft_data = {"hex": "abc123"}
            
            # Mock Aircraft.query to raise an exception
            mock_aircraft.query.filter_by.side_effect = Exception("Database error")
            
            result = processor.process_aircraft(aircraft_data, TEST_NOW)
            
            assert result is None
            mock_logging.assert_called()

    @patch('backend.jobs.aircraft_data_collection.get_opensky_classification', return_value=(None, None, None))
    @patch.object(DataProcessor, 'process_positions')
    def test_process_flight_new_flight(self, mock_process_positions, _mock_opensky, processor, app):
        """Test processing a new flight"""
        with app.app_context():
            aircraft_id = 1
            aircraft_data = {
                "hex": "abc123",
                "flight": "TST123  ",
                "category": "A7",
                "type": "adsb_icao"
            }
            
            # Ensure no existing flight
            existing = Flight.query.filter_by(flight="TST123").first()
            assert existing is None
            
            processor.process_flight(aircraft_id, aircraft_data, TEST_NOW)
            
            # Should create new flight
            new_flight = Flight.query.filter_by(flight="TST123").first()
            assert new_flight is not None
            assert new_flight.flight == "TST123"
            assert new_flight.aircraft == aircraft_id
            assert new_flight.aircraft_class == 'helicopter'
            assert new_flight.emitter_category == 'A7'
            assert new_flight.message_type == 'adsb_icao'
            
            mock_process_positions.assert_called_once_with(aircraft_id, new_flight.id, aircraft_data, TEST_NOW)

    @patch('backend.jobs.aircraft_data_collection.get_opensky_classification', return_value=('helicopter', 'opensky', 'high'))
    @patch.object(DataProcessor, 'process_positions')
    def test_process_flight_prefers_opensky_classification(self, mock_process_positions, _mock_opensky, processor, app):
        """When OpenSky provides a class, it should override heuristic mapping."""
        with app.app_context():
            aircraft_id = 1
            aircraft_data = {
                "hex": "abc123",
                "flight": "TST124  ",
                "category": "A3",
                "type": "adsb_icao"
            }

            processor.process_flight(aircraft_id, aircraft_data, TEST_NOW)

            flight = Flight.query.filter_by(flight="TST124").first()
            assert flight is not None
            assert flight.aircraft_class == 'helicopter'

            mock_process_positions.assert_called_once_with(aircraft_id, flight.id, aircraft_data, TEST_NOW)

    @patch.object(DataProcessor, 'process_positions')
    def test_process_flight_existing_flight(self, mock_process_positions, processor, app):
        """Test processing an existing flight"""
        with app.app_context():
            # Create existing flight
            existing_flight = Flight(
                aircraft=1,
                flight="TST123",
                first_seen="2022-01-01 10:00:00",
                last_seen="2022-01-01 10:00:00"
            )
            db.session.add(existing_flight)
            db.session.commit()
            
            aircraft_id = 1
            aircraft_data = {
                "hex": "abc123",
                "flight": "TST123  "
            }
            
            processor.process_flight(aircraft_id, aircraft_data, TEST_NOW)
            
            # Should update existing flight's last_seen
            updated_flight = Flight.query.filter_by(flight="TST123").first()
            assert updated_flight is not None
            
            mock_process_positions.assert_called_once_with(aircraft_id, existing_flight.id, aircraft_data, TEST_NOW)

    @patch('backend.jobs.dump1090_data_collection.Flight')
    @patch('backend.jobs.dump1090_data_collection.logging.error')
    def test_process_flight_database_error(self, mock_logging, mock_flight, processor, app):
        """Test flight processing with database error"""
        with app.app_context():
            aircraft_id = 1
            aircraft_data = {"hex": "abc123", "flight": "TST123"}
            
            # Mock Flight.query to raise an exception
            mock_flight.query.filter_by.side_effect = Exception("Database error")
            
            processor.process_flight(aircraft_id, aircraft_data, TEST_NOW)
            
            mock_logging.assert_called()

    def test_process_positions_with_coordinates(self, processor, app):
        """Test processing positions with valid coordinates"""
        with app.app_context():
            aircraft_id = 1
            flight_id = 1
            aircraft_data = {
                "hex": "abc123",
                "lat": 40.7128,
                "lon": -74.0060,
                "alt_baro": 30000,
                "track": 180,
                "gs": 450,
                "baro_rate": 0,
                "messages": 12345
            }
            
            processor.process_positions(aircraft_id, flight_id, aircraft_data, TEST_NOW)
            
            # Should create new position
            new_position = Position.query.filter_by(flight=flight_id, message=12345).first()
            assert new_position is not None
            assert new_position.latitude == 40.7128
            assert new_position.longitude == -74.0060
            assert new_position.aircraft == aircraft_id

    def test_process_positions_without_coordinates(self, processor, app, caplog):
        """Test processing positions without coordinates"""
        with app.app_context():
            aircraft_id = 1
            flight_id = 1
            aircraft_data = {
                "hex": "abc123",
                "altitude": 30000
                # Missing required lat/lon/alt_baro/gs/track/baro_rate
            }

            with caplog.at_level(logging.INFO):
                processor.process_positions(aircraft_id, flight_id, aircraft_data, TEST_NOW)

            # Should not create any position
            positions = Position.query.filter_by(flight=flight_id).all()
            assert len(positions) == 0

            # Should log that data is not present
            assert "is not present" in caplog.text

    @patch('backend.jobs.dump1090_data_collection.Position')
    @patch('backend.jobs.dump1090_data_collection.logging.error')
    def test_process_positions_database_error(self, mock_logging, mock_position, processor, app):
        """Test position processing with database error"""
        with app.app_context():
            aircraft_id = 1
            flight_id = 1
            aircraft_data = {
                "hex": "abc123",
                "lat": 40.7128,
                "lon": -74.0060,
                "alt_baro": 30000,
                "track": 180,
                "gs": 450,
                "baro_rate": 0,
                "messages": 12345
            }
            
            # Mock Position.query to raise an exception
            mock_position.query.filter_by.side_effect = Exception("Database error")
            
            processor.process_positions(aircraft_id, flight_id, aircraft_data, TEST_NOW)
            
            mock_logging.assert_called()

    def test_invalid_aircraft_data(self, processor):
        """Test processing with invalid aircraft data"""
        invalid_data = None
        
        with pytest.raises((AttributeError, TypeError)):
            processor.process_aircraft(invalid_data, TEST_NOW)

    def test_missing_hex_in_aircraft_data(self, processor):
        """Test processing aircraft data without hex field"""
        aircraft_data = {"flight": "TST123"}
        
        with pytest.raises(KeyError):
            processor.process_aircraft(aircraft_data, TEST_NOW)

    @patch.object(DataProcessor, 'log')
    def test_verbose_logging(self, mock_log, processor):
        """Test that all major operations are logged"""
        with patch.object(processor, 'read_json', return_value={"aircraft": []}):
            processor.process_all_aircraft(TEST_NOW)
            
        # Should log the no data message (read_json log is mocked out)
        assert mock_log.call_count >= 1
        # Verify the specific log message
        mock_log.assert_called_with('There is no aircraft data to process at this time')

    @patch('backend.jobs.aircraft_data_collection.get_opensky_classification', return_value=('uav', 'opensky', 'high'))
    @patch.object(UatDataProcessor, 'process_positions')
    def test_uat_process_flight_prefers_opensky_classification(self, mock_process_positions, _mock_opensky, app):
        """UAT ingest should honor OpenSky class when available."""
        with app.app_context():
            processor = UatDataProcessor()
            aircraft_id = 1
            aircraft_data = {
                "hex": "uat123",
                "flight": "UAT001  ",
                "category": "A3",
                "type": "uat_icao"
            }

            processor.process_flight(aircraft_id, aircraft_data)

            new_flight = Dump978Flight.query.filter_by(flight="UAT001").first()
            assert new_flight is not None
            assert new_flight.aircraft_class == 'uav'
            mock_process_positions.assert_called_once_with(aircraft_id, new_flight.id, aircraft_data)
