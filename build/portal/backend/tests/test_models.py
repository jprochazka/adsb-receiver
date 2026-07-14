import pytest
from datetime import datetime
from sqlalchemy.exc import IntegrityError
from backend import create_app
from backend.models import (
    db, Aircraft, Flight, Position, User, BlogPost,
    BlogComment, Link, Notification, Setting,
    Dump978Aircraft, Dump978Flight, Dump978Position,
    OpenSkyAircraft, FlightComment, UatFlightComment,
)


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


class TestModels:
    """Test SQLAlchemy models"""

    def test_aircraft_model_creation(self, app):
        """Test Aircraft model creation and serialization"""
        with app.app_context():
            aircraft = Aircraft()
            aircraft.icao = 'TEST01'
            aircraft.first_seen = '2024-01-01 10:00:00'
            aircraft.last_seen = '2024-01-01 12:00:00'
            
            db.session.add(aircraft)
            db.session.commit()
            
            assert aircraft.id is not None
            assert aircraft.icao == 'TEST01'
            
            # Test serialization
            serialized = aircraft.to_dict()
            assert serialized['icao'] == 'TEST01'
            assert serialized['first_seen'] == '2024-01-01 10:00:00'
            assert serialized['last_seen'] == '2024-01-01 12:00:00'

    def test_aircraft_model_relationships(self, app):
        """Test Aircraft model relationships"""
        with app.app_context():
            aircraft = Aircraft()
            aircraft.icao = 'TEST01'
            aircraft.first_seen = '2024-01-01 10:00:00'
            aircraft.last_seen = '2024-01-01 12:00:00'
            
            db.session.add(aircraft)
            db.session.commit()
            
            # Test flights relationship
            flight = Flight()
            flight.aircraft = aircraft.id
            flight.flight = 'FL001'
            flight.first_seen = '2024-01-01 10:00:00'
            flight.last_seen = '2024-01-01 12:00:00'
            
            db.session.add(flight)
            db.session.commit()
            
            assert len(list(aircraft.flights)) == 1
            assert list(aircraft.flights)[0].flight == 'FL001'
            
            # Test positions relationship
            position = Position()
            position.aircraft = aircraft.id
            position.flight = flight.id
            position.time = '2024-01-01 10:15:00'
            position.latitude = 40.7128
            position.longitude = -74.0060
            position.altitude = 10000
            position.message = 1
            position.track = 180
            position.vertical_rate = 500
            
            db.session.add(position)
            db.session.commit()
            
            assert len(list(aircraft.positions)) == 1
            assert list(aircraft.positions)[0].latitude == 40.7128

    def test_flight_model_creation(self, app):
        """Test Flight model creation and serialization"""
        with app.app_context():
            aircraft = Aircraft()
            aircraft.icao = 'TEST01'
            aircraft.first_seen = '2024-01-01 10:00:00'
            aircraft.last_seen = '2024-01-01 12:00:00'
            db.session.add(aircraft)
            db.session.commit()
            
            flight = Flight()
            flight.aircraft = aircraft.id
            flight.flight = 'FL001'
            flight.first_seen = '2024-01-01 10:00:00'
            flight.last_seen = '2024-01-01 12:00:00'
            
            db.session.add(flight)
            db.session.commit()
            
            assert flight.id is not None
            assert flight.flight == 'FL001'
            
            # Test serialization
            serialized = flight.to_dict()
            assert serialized['flight'] == 'FL001'
            assert serialized['aircraft'] == aircraft.id

    def test_position_model_creation(self, app):
        """Test Position model creation and serialization"""
        with app.app_context():
            aircraft = Aircraft(icao='TEST01', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            
            db.session.add(aircraft)
            db.session.commit()
            
            flight = Flight(aircraft=aircraft.id, flight='FL001', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            db.session.add(flight)
            db.session.commit()
            
            position = Position(
                aircraft=aircraft.id,
                flight=flight.id,
                time='2024-01-01 10:15:00',
                message=1,
                squawk=1200,
                latitude=40.7128,
                longitude=-74.0060,
                track=180,
                altitude=10000,
                vertical_rate=500,
                speed=250
            )
            
            db.session.add(position)
            db.session.commit()
            
            assert position.id is not None
            assert position.latitude == 40.7128
            
            # Test serialization
            serialized = position.serialize()
            assert serialized['latitude'] == 40.7128
            assert serialized['longitude'] == -74.0060
            assert serialized['altitude'] == 10000

    def test_user_model_creation(self, app):
        """Test User model creation and serialization"""
        with app.app_context():
            user = User(
                name='Test User',
                email='test@example.com',
                administrator=1
            )
            
            db.session.add(user)
            db.session.commit()
            
            assert user.id is not None
            assert user.name == 'Test User'
            assert user.email == 'test@example.com'
            assert user.administrator == 1
            
            # Test serialization
            serialized = user.serialize()
            assert serialized['name'] == 'Test User'
            assert serialized['email'] == 'test@example.com'
            assert serialized['administrator'] == 1

    def test_blogpost_model_creation(self, app):
        """Test BlogPost model creation and serialization"""
        with app.app_context():
            blog_post = BlogPost(
                title='Test Post',
                content='This is a test post.',
                author='Test User',
                date='2024-01-01'
            )
            
            db.session.add(blog_post)
            db.session.commit()
            
            assert blog_post.id is not None
            assert blog_post.title == 'Test Post'
            
            # Test serialization
            serialized = blog_post.serialize()
            assert serialized['title'] == 'Test Post'
            assert serialized['content'] == 'This is a test post.'

    def test_link_model_creation(self, app):
        """Test Link model creation and serialization"""
        with app.app_context():
            link = Link(
                name='Test Link',
                address='https://example.com'
            )
            
            db.session.add(link)
            db.session.commit()
            
            assert link.id is not None
            assert link.name == 'Test Link'
            assert link.address == 'https://example.com'
            
            # Test serialization
            serialized = link.serialize()
            assert serialized['name'] == 'Test Link'
            assert serialized['address'] == 'https://example.com'

    def test_notification_model_creation(self, app):
        """Test Notification model creation and serialization"""
        with app.app_context():
            notification = Notification(
                user_id=1,
                flight='FL001'
            )
            
            db.session.add(notification)
            db.session.commit()
            
            assert notification.id is not None
            assert notification.flight == 'FL001'
            
            # Test serialization
            serialized = notification.serialize()
            assert serialized['flight'] == 'FL001'

    def test_setting_model_creation(self, app):
        """Test Setting model creation and serialization"""
        with app.app_context():
            setting = Setting(
                name='test_setting',
                value='test_value'
            )
            
            db.session.add(setting)
            db.session.commit()
            
            assert setting.id is not None
            assert setting.name == 'test_setting'
            assert setting.value == 'test_value'
            
            # Test serialization
            serialized = setting.serialize()
            assert serialized['name'] == 'test_setting'
            assert serialized['value'] == 'test_value'

    def test_model_constraints(self, app):
        """Test model constraints and validation"""
        with app.app_context():
            # Test unique constraint on user email
            user1 = User(name='User 1', email='test@example.com')
            user2 = User(name='User 2', email='test@example.com')
            
            db.session.add(user1)
            db.session.commit()
            
            # Adding duplicate email should raise an error
            db.session.add(user2)
            with pytest.raises(IntegrityError):
                db.session.commit()

    def test_model_null_constraints(self, app):
        """Test null constraints"""
        with app.app_context():
            # Test required fields
            aircraft = Aircraft()
            # Missing required icao field should cause issues
            db.session.add(aircraft)
            # Depending on model definition, this might raise an error

    def test_model_foreign_key_constraints(self, app):
        """Test foreign key constraints (SQLite may not enforce by default)"""
        with app.app_context():
            # Create valid relationships
            aircraft = Aircraft(icao='TEST01', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()
            
            flight = Flight(
                aircraft=aircraft.id,
                flight='FL001',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 12:00:00'
            )
            
            db.session.add(flight)
            db.session.commit()
            
            # Test successful creation with valid foreign keys
            assert flight.id is not None

    def test_model_serialization_with_none_values(self, app):
        """Test model serialization with None values"""
        with app.app_context():
            aircraft = Aircraft(icao='TEST01', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()
            
            serialized = aircraft.to_dict()
            assert 'icao' in serialized
            # None values should be handled gracefully

    def test_model_string_representations(self, app):
        """Test string representations of models"""
        with app.app_context():
            aircraft = Aircraft(icao='TEST01')
            flight = Flight(flight='FL001')
            user = User(name='Test User', email='test@example.com')
            
            # Test that string representations don't crash
            str(aircraft)
            str(flight)
            str(user)

    def test_model_relationships_cascade(self, app):
        """Test cascade behavior in relationships"""
        with app.app_context():
            aircraft = Aircraft(icao='TEST01', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            db.session.add(aircraft)
            db.session.commit()
            
            flight = Flight(
                aircraft=aircraft.id,
                flight='FL001',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 12:00:00'
            )
            db.session.add(flight)
            db.session.commit()
            
            position = Position(
                aircraft=aircraft.id,
                flight=flight.id,
                time='2024-01-01 10:15:00',
                latitude=40.7128,
                longitude=-74.0060,
                altitude=10000,
                track=180,
                vertical_rate=0,
                message=1
            )
            db.session.add(position)
            db.session.commit()
            
            # Test that relationships are properly established
            assert len(list(aircraft.flights)) == 1
            assert len(list(aircraft.positions)) == 1
            assert len(list(flight.positions)) == 1

    def test_model_large_data_handling(self, app):
        """Test handling of large data"""
        with app.app_context():
            aircraft = Aircraft(
                icao='TEST01',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 12:00:00'
            )
            db.session.add(aircraft)
            db.session.commit()
            
            # Create flight first
            flight = Flight(
                aircraft=aircraft.id,
                flight='FL001',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 12:00:00'
            )
            db.session.add(flight)
            db.session.commit()
            
            # Create many positions
            positions = []
            for i in range(100):
                position = Position(
                    aircraft=aircraft.id,
                    flight=flight.id,
                    time=f'2024-01-01 10:{i:02d}:00',
                    latitude=40.0 + i * 0.01,
                    longitude=-74.0 + i * 0.01,
                    altitude=10000 + i * 100,
                    track=180,
                    vertical_rate=0,
                    message=i
                )
                positions.append(position)
            
            db.session.add_all(positions)
            db.session.commit()
            
            assert len(list(aircraft.positions)) == 100

    def test_model_datetime_handling(self, app):
        """Test datetime field handling"""
        with app.app_context():
            now = datetime.now().strftime('%Y-%m-%d')
            blog_post = BlogPost(
                title='Test Post',
                content='This is a test post.',
                author='Test Author',
                date=now
            )
            
            db.session.add(blog_post)
            db.session.commit()
            
            # Test that date is preserved
            assert blog_post.date == now
            
    def test_opensky_aircraft_model(self, app):
        """Test OpenSkyAircraft model creation"""
        with app.app_context():
            oa = OpenSkyAircraft(icao24='a00001', aircraft_class='airliner', confidence='high')
            db.session.add(oa)
            db.session.commit()

            fetched = db.session.get(OpenSkyAircraft, 'a00001')
            assert fetched is not None
            assert fetched.aircraft_class == 'airliner'
            assert fetched.confidence == 'high'

    def test_opensky_aircraft_primary_key(self, app):
        """Test OpenSkyAircraft uses icao24 as primary key"""
        with app.app_context():
            oa1 = OpenSkyAircraft(icao24='abc123', aircraft_class='helicopter', confidence='medium')
            db.session.add(oa1)
            db.session.commit()

            # Remove persisted instance from identity map to avoid SAWarning while
            # still verifying duplicate primary-key insert fails at commit time.
            db.session.expunge(oa1)

            # Inserting with same icao24 should conflict
            oa2 = OpenSkyAircraft(icao24='abc123', aircraft_class='glider', confidence='low')
            db.session.add(oa2)
            with pytest.raises(Exception):
                db.session.commit()

    def test_flight_comment_model(self, app):
        """Test FlightComment model creation and serialization"""
        with app.app_context():
            user = User(name='Commenter', email='commenter@test.com', role='User')
            db.session.add(user)
            db.session.commit()

            aircraft = Aircraft(icao='FC0001', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            db.session.add(aircraft)
            db.session.commit()

            flight = Flight(aircraft=aircraft.id, flight='FC100', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            db.session.add(flight)
            db.session.commit()

            comment = FlightComment(flight_id=flight.id, user_id=user.id, content='Great flight!')
            db.session.add(comment)
            db.session.commit()

            assert comment.id is not None
            assert comment.edited is False

            serialized = comment.to_dict()
            assert serialized['content'] == 'Great flight!'
            assert serialized['user']['name'] == 'Commenter'
            assert serialized['created_at'] is not None

    def test_flight_comment_cascade_delete(self, app):
        """Test FlightComment is deleted when parent Flight is deleted"""
        with app.app_context():
            user = User(name='Cascade', email='cascade@test.com')
            db.session.add(user)
            db.session.commit()

            aircraft = Aircraft(icao='CD0001', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            flight = Flight(aircraft=aircraft.id, flight='CD100', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            db.session.add(flight)
            db.session.commit()

            comment = FlightComment(flight_id=flight.id, user_id=user.id, content='Will be deleted')
            db.session.add(comment)
            db.session.commit()

            comment_id = comment.id
            db.session.delete(flight)
            db.session.commit()

            assert db.session.get(FlightComment, comment_id) is None

    def test_uat_flight_comment_model(self, app):
        """Test UatFlightComment model creation and serialization"""
        with app.app_context():
            user = User(name='UAT Commenter', email='uatcomment@test.com')
            db.session.add(user)
            db.session.commit()

            aircraft = Dump978Aircraft(icao='UAT001', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            flight = Dump978Flight(aircraft=aircraft.id, flight='UAT100', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            db.session.add(flight)
            db.session.commit()

            comment = UatFlightComment(flight_id=flight.id, user_id=user.id, content='Nice UAT track')
            db.session.add(comment)
            db.session.commit()

            serialized = comment.to_dict()
            assert serialized['content'] == 'Nice UAT track'
            assert serialized['user']['name'] == 'UAT Commenter'

    def test_blog_comment_model(self, app):
        """Test BlogComment model creation, serialization, and threading"""
        with app.app_context():
            user = User(name='Blog User', email='bloguser@test.com')
            db.session.add(user)
            db.session.commit()

            post = BlogPost(title='Test', content='Body', author='Author', date='2024-01-01')
            db.session.add(post)
            db.session.commit()

            parent = BlogComment(blog_post_id=post.id, user_id=user.id, content='Parent comment')
            db.session.add(parent)
            db.session.commit()

            reply = BlogComment(blog_post_id=post.id, user_id=user.id, content='Reply', parent_comment_id=parent.id)
            db.session.add(reply)
            db.session.commit()

            serialized = parent.to_dict()
            assert serialized['content'] == 'Parent comment'
            assert serialized['deleted'] is False

            reply_serialized = reply.to_dict()
            assert reply_serialized['parent_comment_id'] == parent.id

    def test_blog_comment_deleted_masking(self, app):
        """Test that deleted BlogComment masks user info and content"""
        with app.app_context():
            user = User(name='Deleted User', email='deleted@test.com')
            db.session.add(user)
            db.session.commit()

            post = BlogPost(title='Post', content='Body', author='A', date='2024-01-01')
            db.session.add(post)
            db.session.commit()

            comment = BlogComment(blog_post_id=post.id, user_id=user.id, content='Secret', deleted=True)
            db.session.add(comment)
            db.session.commit()

            serialized = comment.to_dict()
            assert serialized['content'] == '[deleted]'
            assert serialized['user_id'] is None
            assert serialized['user']['id'] is None
            assert serialized['user']['name'] is None

    def test_dump978_flight_model(self, app):
        """Test Dump978Flight model creation and serialization"""
        with app.app_context():
            aircraft = Dump978Aircraft(icao='D97801', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            flight = Dump978Flight(
                aircraft=aircraft.id,
                flight='D978FL',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 12:00:00',
                aircraft_class='helicopter',
            )
            db.session.add(flight)
            db.session.commit()

            assert flight.id is not None
            serialized = flight.to_dict()
            assert serialized['flight'] == 'D978FL'
            assert serialized['aircraft_class'] == 'helicopter'
            assert serialized['ignore_on_purge'] is False

    def test_model_boolean_handling(self, app):
        """Test boolean field handling"""
        with app.app_context():
            user = User(
                name='Test User',
                email='test@example.com',
                administrator=1
            )
            
            db.session.add(user)
            db.session.commit()
            
            assert user.administrator == 1
            
            # Test serialization of booleans
            serialized = user.serialize()
            assert serialized['administrator'] == 1

    def test_model_numeric_field_handling(self, app):
        """Test numeric field handling"""
        with app.app_context():
            aircraft = Aircraft(icao='TEST01', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            db.session.add(aircraft)
            db.session.commit()
            
            flight = Flight(
                aircraft=aircraft.id,
                flight='FL001',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 12:00:00'
            )
            db.session.add(flight)
            db.session.commit()
            
            position = Position(
                aircraft=aircraft.id,
                flight=flight.id,
                time='2024-01-01 10:15:00',
                latitude=40.123456789,  # High precision
                longitude=-74.987654321,
                altitude=35000,
                track=180,
                vertical_rate=0,
                speed=567,
                message=12345
            )
            
            db.session.add(position)
            db.session.commit()
            
            # Test that numeric precision is maintained
            assert position.latitude == 40.123456789
            assert position.longitude == -74.987654321

    def test_model_serialization_consistency(self, app):
        """Test that serialization is consistent across models"""
        with app.app_context():
            aircraft = Aircraft(icao='TEST01', first_seen='2024-01-01 10:00:00', last_seen='2024-01-01 12:00:00')
            user = User(name='Test User', email='test@example.com')
            link = Link(name='Test Link', address='https://example.com')
            
            db.session.add_all([aircraft, user, link])
            db.session.commit()
            
            # All models should have serialization methods
            aircraft_dict = aircraft.to_dict()
            user_dict = user.serialize()
            link_dict = link.serialize()
            
            # All should return dictionaries
            assert isinstance(aircraft_dict, dict)
            assert isinstance(user_dict, dict)
            assert isinstance(link_dict, dict)
            
            # All should include id field
            assert 'id' in aircraft_dict
            assert 'id' in user_dict
            assert 'id' in link_dict


class TestDump978Models:
    """Test SQLAlchemy models for dump978 / UAT data"""

    def test_dump978_aircraft_creation(self, app):
        """Test Dump978Aircraft model creation and serialization"""
        with app.app_context():
            aircraft = Dump978Aircraft(
                icao='UAT001',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 12:00:00',
            )
            db.session.add(aircraft)
            db.session.commit()

            assert aircraft.id is not None
            assert aircraft.icao == 'UAT001'
            d = aircraft.to_dict()
            assert d['icao'] == 'UAT001'
            assert d['first_seen'] == '2024-01-01 10:00:00'
            assert d['last_seen'] == '2024-01-01 12:00:00'

    def test_dump978_aircraft_nullable_last_seen(self, app):
        """last_seen may be NULL for aircraft still being tracked"""
        with app.app_context():
            aircraft = Dump978Aircraft(icao='UAT002', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()
            assert aircraft.last_seen is None
            assert aircraft.to_dict()['last_seen'] is None

    def test_dump978_flight_creation(self, app):
        """Test Dump978Flight model creation with FK to Dump978Aircraft"""
        with app.app_context():
            aircraft = Dump978Aircraft(icao='UAT001', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            flight = Dump978Flight(
                aircraft=aircraft.id,
                flight='N123AB',
                first_seen='2024-01-01 10:00:00',
                last_seen='2024-01-01 11:00:00',
            )
            db.session.add(flight)
            db.session.commit()

            assert flight.id is not None
            assert flight.flight == 'N123AB'
            d = flight.to_dict()
            assert d['aircraft'] == aircraft.id
            assert d['flight'] == 'N123AB'

    def test_dump978_flight_relationship(self, app):
        """Test Dump978Aircraft → Dump978Flight relationship"""
        with app.app_context():
            aircraft = Dump978Aircraft(icao='UAT001', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            flight = Dump978Flight(
                aircraft=aircraft.id,
                flight='N123AB',
                first_seen='2024-01-01 10:00:00',
            )
            db.session.add(flight)
            db.session.commit()

            assert len(list(aircraft.flights)) == 1
            assert list(aircraft.flights)[0].flight == 'N123AB'

    def test_dump978_position_creation_full(self, app):
        """Test Dump978Position with all fields populated"""
        with app.app_context():
            aircraft = Dump978Aircraft(icao='UAT001', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            flight = Dump978Flight(
                aircraft=aircraft.id,
                flight='N123AB',
                first_seen='2024-01-01 10:00:00',
            )
            db.session.add(flight)
            db.session.commit()

            position = Dump978Position(
                flight=flight.id,
                aircraft=aircraft.id,
                time='2024-01-01 10:15:00',
                message=42,
                squawk=1200,
                latitude=40.7128,
                longitude=-74.0060,
                track=180,
                altitude=5000,
                vertical_rate=100,
                speed=120,
            )
            db.session.add(position)
            db.session.commit()

            assert position.id is not None
            d = position.to_dict()
            assert d['flight'] == flight.id
            assert d['message'] == 42
            assert d['latitude'] == 40.7128

    def test_dump978_position_nullable_flight_and_message(self, app):
        """Dump978Position allows NULL flight and message (UAT aircraft without callsign)"""
        with app.app_context():
            aircraft = Dump978Aircraft(icao='UAT003', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            position = Dump978Position(
                flight=None,
                aircraft=aircraft.id,
                time='2024-01-01 10:15:00',
                message=None,
                latitude=40.7128,
                longitude=-74.0060,
                track=90,
                altitude=3000,
                vertical_rate=0,
            )
            db.session.add(position)
            db.session.commit()

            assert position.flight is None
            assert position.message is None
            d = position.to_dict()
            assert d['flight'] is None
            assert d['message'] is None

    def test_dump978_aircraft_positions_relationship(self, app):
        """Test Dump978Aircraft → Dump978Position relationship"""
        with app.app_context():
            aircraft = Dump978Aircraft(icao='UAT001', first_seen='2024-01-01 10:00:00')
            db.session.add(aircraft)
            db.session.commit()

            for i in range(3):
                pos = Dump978Position(
                    aircraft=aircraft.id,
                    time=f'2024-01-01 10:{i:02d}:00',
                    latitude=40.0 + i,
                    longitude=-74.0,
                    track=0,
                    altitude=5000,
                    vertical_rate=0,
                )
                db.session.add(pos)
            db.session.commit()

            assert len(list(aircraft.positions)) == 3
