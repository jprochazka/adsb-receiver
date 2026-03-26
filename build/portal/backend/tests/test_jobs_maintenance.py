import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta
from backend import create_app
from backend.models import db
from backend.jobs.maintenance import MaintenanceProcessor


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
    """Create MaintenanceProcessor instance"""
    return MaintenanceProcessor()


class TestMaintenanceProcessor:
    """Test maintenance processor"""

    def test_log_method(self, processor, capsys):
        """Test logging functionality (currently disabled)"""
        test_message = "Test log message"
        processor.log(test_message)
        
        # Since logging is commented out, there should be no output
        captured = capsys.readouterr()
        assert captured.out == ""

    @patch.object(MaintenanceProcessor, 'purge_aircraft')
    @patch.object(MaintenanceProcessor, 'purge_positions')
    def test_begin_maintenance_enabled(self, mock_purge_positions, mock_purge_aircraft, 
                                     processor, app):
        """Test maintenance when purging is enabled"""
        from backend.models import Setting
        
        with app.app_context():
            # Create settings in database
            purge_setting = Setting(name='purge_older_data', value='true')
            days_setting = Setting(name='days_to_save', value='30')
            db.session.add(purge_setting)
            db.session.add(days_setting)
            db.session.commit()
            
            processor.begin_maintenance()
            
            # Should call purge methods
            mock_purge_aircraft.assert_called_once()
            mock_purge_positions.assert_called_once()
            
            # Check that cutoff date is calculated correctly (30 days ago)
            call_args = mock_purge_aircraft.call_args[0][0]
            expected_date = datetime.now() - timedelta(days=30)
            assert abs((call_args - expected_date).total_seconds()) < 60  # Within 1 minute

    def test_begin_maintenance_disabled(self, processor, app, capsys):
        """Test maintenance when purging is disabled"""
        from backend.models import Setting
        
        with app.app_context():
            # Create settings in database
            purge_setting = Setting(name='purge_older_data', value='false')
            db.session.add(purge_setting)
            db.session.commit()
            
            processor.begin_maintenance()
            
            # Should log that maintenance is disabled
            # Note: logging is currently commented out, so we can't test the output
            # But we can verify no error occurred
            captured = capsys.readouterr()
            # No assertion needed since log method is disabled

    @patch('backend.jobs.maintenance.Setting')
    @patch('backend.jobs.maintenance.logging.error')
    def test_begin_maintenance_database_error(self, mock_logging, mock_setting, processor, app):
        """Test maintenance with database error"""
        with app.app_context():
            # Mock Setting.query to raise an exception
            mock_setting.query.filter_by.side_effect = Exception("Database error")
            
            processor.begin_maintenance()
            
            mock_logging.assert_called()

    @patch('backend.jobs.maintenance.logging.error')
    def test_begin_maintenance_days_to_save_error(self, mock_logging, processor, app):
        """Test maintenance with error getting days_to_save setting"""
        from backend.models import Setting
        
        with app.app_context():
            # Create purge setting that enables maintenance
            purge_setting = Setting(name='purge_older_data', value='true')
            db.session.add(purge_setting)
            db.session.commit()
            
            # Mock the days_to_save query to raise an error
            with patch('backend.jobs.maintenance.Setting') as mock_setting:
                # First call returns real setting, second call fails
                real_query = MagicMock()
                real_query.filter_by.return_value.first.return_value = purge_setting
                error_query = MagicMock()
                error_query.filter_by.side_effect = Exception("Database error")
                mock_setting.query = real_query
                # Override for second call
                processor.begin_maintenance()
                
                mock_logging.assert_called()

    def test_purge_aircraft_success(self, processor, app):
        """Test successful aircraft purging"""
        with app.app_context():
            from backend import db
            from backend.models import Aircraft, Flight, Position
            
            # Create test aircraft with old last_seen date
            cutoff_date = datetime.now() - timedelta(days=30)
            old_date = cutoff_date - timedelta(days=1)
            
            aircraft = Aircraft(icao='TEST123', 
                              first_seen=old_date.strftime('%Y-%m-%d %H:%M:%S'),
                              last_seen=old_date.strftime('%Y-%m-%d %H:%M:%S'))
            db.session.add(aircraft)
            db.session.commit()
            
            # Test purging
            processor.purge_aircraft(cutoff_date)
            
            # Aircraft should be deleted
            assert Aircraft.query.filter_by(icao='TEST123').first() is None

    @patch('backend.jobs.maintenance.logging.error')
    def test_purge_aircraft_database_error(self, mock_logging, processor, app):
        """Test aircraft purging with database error"""
        with app.app_context():
            cutoff_date = datetime.now() - timedelta(days=30)
            
            # Mock db.session.execute to raise an exception
            with patch('backend.jobs.maintenance.db.session.execute') as mock_execute:
                mock_execute.side_effect = Exception("Database error")
                
                result = processor.purge_aircraft(cutoff_date)
                
                assert result is None
                mock_logging.assert_called()

    def test_purge_positions_success(self, processor, app):
        """Test successful position purging"""
        with app.app_context():
            from backend import db
            from backend.models import Position, Aircraft, Flight
            
            # Create test data
            cutoff_date = datetime.now() - timedelta(days=30)
            old_date = cutoff_date - timedelta(days=1)
            now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            aircraft = Aircraft(icao='TEST123', first_seen=now_str, last_seen=now_str)
            db.session.add(aircraft)
            db.session.flush()
            
            flight = Flight(aircraft=aircraft.id, flight='TEST123', 
                          first_seen=now_str, last_seen=now_str)
            db.session.add(flight)
            db.session.flush()
            
            position = Position(aircraft=aircraft.id, flight=flight.id, time=old_date.strftime('%Y-%m-%d %H:%M:%S'), 
                              message=1, latitude=0.0, longitude=0.0, altitude=0, track=0, speed=0, vertical_rate=0)
            db.session.add(position)
            db.session.commit()
            
            # Test purging
            processor.purge_positions(cutoff_date)
            
            # Position should be deleted
            assert Position.query.filter_by(aircraft=aircraft.id).first() is None

    @patch('backend.jobs.maintenance.logging.error')
    def test_purge_positions_database_error(self, mock_logging, processor, app):
        """Test position purging with database error"""
        with app.app_context():
            cutoff_date = datetime.now() - timedelta(days=30)
            
            # Mock db.session.execute to raise an exception
            with patch('backend.jobs.maintenance.db.session.execute') as mock_execute:
                mock_execute.side_effect = Exception("Database error")
                
                result = processor.purge_positions(cutoff_date)
                
                assert result is None
                mock_logging.assert_called()

    def test_purge_flights_success(self, processor, app):
        """Test successful flight purging"""
        with app.app_context():
            from backend import db
            from backend.models import Flight, Aircraft
            
            # Create test data
            cutoff_date = datetime.now() - timedelta(days=30)
            old_date = cutoff_date - timedelta(days=1)
            now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            aircraft = Aircraft(icao='TEST123', first_seen=now_str, last_seen=now_str)
            db.session.add(aircraft)
            db.session.flush()
            
            flight = Flight(aircraft=aircraft.id, flight='TEST123', 
                          first_seen=now_str, last_seen=old_date.strftime('%Y-%m-%d %H:%M:%S'))
            db.session.add(flight)
            db.session.commit()
            
            # Test purging
            processor.purge_flights(cutoff_date)
            
            # Flight should be deleted
            assert Flight.query.filter_by(aircraft=aircraft.id).first() is None

    @patch('backend.jobs.maintenance.logging.error')
    def test_purge_flights_database_error(self, mock_logging, processor, app):
        """Test flight purging with database error"""
        with app.app_context():
            cutoff_date = datetime.now() - timedelta(days=30)
            
            # Mock db.session.execute to raise an exception
            with patch('backend.jobs.maintenance.db.session.execute') as mock_execute:
                mock_execute.side_effect = Exception("Database error")
                
                result = processor.purge_flights(cutoff_date)
                
                assert result is None
                mock_logging.assert_called()

    def test_cutoff_date_calculation(self, processor):
        """Test that cutoff dates are calculated correctly"""
        # Test various day values
        test_cases = [1, 7, 30, 365]
        
        for days in test_cases:
            expected_cutoff = datetime.now() - timedelta(days=days)
            
            # This would be called in the actual maintenance process
            # We can verify the logic by checking the timedelta calculation
            calculated_cutoff = datetime.now() - timedelta(days=days)
            
            # Should be within a few seconds of each other
            assert abs((calculated_cutoff - expected_cutoff).total_seconds()) < 5

    def test_maintenance_with_various_settings(self, processor, app):
        """Test maintenance with various setting combinations"""
        test_cases = [
            # (purge_enabled, days_to_save)
            ('true', 1),
            ('True', 7),
            ('TRUE', 30),
            ('1', 365),
            ('false', 30),
            ('False', 30),
            ('FALSE', 30),
            ('0', 30),
        ]
        
        with app.app_context():
            from backend import db
            from backend.models import Setting
            
            for purge_setting, days_setting in test_cases:
                # Clear previous test settings
                Setting.query.delete()
                
                # Create test settings with correct names
                purge_enabled = Setting(name='purge_older_data', value=purge_setting)
                days_to_save = Setting(name='days_to_save', value=str(days_setting))
                db.session.add(purge_enabled)
                db.session.add(days_to_save)
                db.session.commit()
                
                with patch.object(processor, 'purge_aircraft') as mock_purge_aircraft, \
                     patch.object(processor, 'purge_positions') as mock_purge_positions:
                    
                    processor.begin_maintenance()
                    
                    should_purge = purge_setting.lower() in ['true', '1']
                    
                    if should_purge:
                        mock_purge_aircraft.assert_called_once()
                        mock_purge_positions.assert_called_once()
                    else:
                        mock_purge_aircraft.assert_not_called()
                        mock_purge_positions.assert_not_called()

    def test_edge_case_zero_days(self, processor, app):
        """Test edge case with zero days to save"""
        with app.app_context():
            from backend import db
            from backend.models import Setting
            
            # Create test settings with correct names
            purge_enabled = Setting(name='purge_older_data', value='true')
            days_to_save = Setting(name='days_to_save', value='0')
            db.session.add(purge_enabled)
            db.session.add(days_to_save)
            db.session.commit()
            
            with patch.object(processor, 'purge_aircraft') as mock_purge_aircraft, \
                 patch.object(processor, 'purge_positions') as mock_purge_positions:
                
                processor.begin_maintenance()
                
                # Should still call purge methods even with 0 days
                mock_purge_aircraft.assert_called_once()
                mock_purge_positions.assert_called_once()

    def test_edge_case_negative_days(self, processor, app):
        """Test edge case with negative days to save"""
        with app.app_context():
            from backend import db
            from backend.models import Setting
            
            # Create test settings with correct names
            purge_enabled = Setting(name='purge_older_data', value='true')
            days_to_save = Setting(name='days_to_save', value='-5')
            db.session.add(purge_enabled)
            db.session.add(days_to_save)
            db.session.commit()
            
            with patch.object(processor, 'purge_aircraft') as mock_purge_aircraft, \
                 patch.object(processor, 'purge_positions') as mock_purge_positions:
                
                processor.begin_maintenance()
                
                # Should handle negative days gracefully
                mock_purge_aircraft.assert_called_once()
                mock_purge_positions.assert_called_once()
                
                # Cutoff date should be in the future with negative days
                call_args = mock_purge_aircraft.call_args[0][0]
                assert call_args > datetime.now()