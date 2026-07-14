from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timezone

db = SQLAlchemy()


def _isoformat_or_none(value):
    return value.isoformat() if value else None


def _split_tags(raw_tags):
    return [tag.strip() for tag in (raw_tags or '').split(',') if tag.strip()]


def _category_or_uncategorized(category):
    return (category or '').strip() or 'Uncategorized'


def _comment_user_dict(user, fallback_user_id):
    return {
        'id': user.id if user else fallback_user_id,
        'name': user.name if user else None,
    }


def _deleted_comment_user_dict():
    return {
        'id': None,
        'name': None,
    }


class SerializableMixin:
    def serialize(self):
        return self.to_dict()


class Aircraft(SerializableMixin, db.Model):
    __tablename__ = 'dump1090_aircraft'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    icao = db.Column(db.String(8), nullable=False, index=True)
    first_seen = db.Column(db.String(32), nullable=False)
    last_seen = db.Column(db.String(32))

    # Relationships
    flights = db.relationship('Flight', back_populates='aircraft_ref')
    positions = db.relationship('Position', back_populates='aircraft_ref')

    def to_dict(self):
        return {
            'id': self.id,
            'icao': self.icao,
            'first_seen': self.first_seen,
            'last_seen': self.last_seen
        }


class BlogPost(SerializableMixin, db.Model):
    __tablename__ = 'blog_posts'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    title = db.Column(db.String(255), nullable=False)
    date = db.Column(db.String(16), nullable=False)
    author = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=False)
    visible = db.Column(db.Boolean, nullable=False, default=True)
    tags = db.Column(db.Text, nullable=True, default='')
    category = db.Column(db.String(100), nullable=True, default='')

    comments = db.relationship(
        'BlogComment',
        back_populates='blog_post',
        cascade='all, delete-orphan',
        order_by='BlogComment.created_at.asc()'
    )

    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'date': self.date,
            'author': self.author,
            'content': self.content,
            'visible': self.visible,
            'tags': _split_tags(self.tags),
            'category': _category_or_uncategorized(self.category)
        }


class BlogComment(SerializableMixin, db.Model):
    __tablename__ = 'blog_comments'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    blog_post_id = db.Column(db.Integer, db.ForeignKey('blog_posts.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    parent_comment_id = db.Column(db.Integer, db.ForeignKey('blog_comments.id'), nullable=True, index=True)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), index=True)
    edited = db.Column(db.Boolean, nullable=False, default=False)
    edited_at = db.Column(db.DateTime, nullable=True)
    deleted = db.Column(db.Boolean, nullable=False, default=False)
    deleted_at = db.Column(db.DateTime, nullable=True)

    blog_post = db.relationship('BlogPost', back_populates='comments')
    user = db.relationship('User', back_populates='blog_comments')
    parent = db.relationship('BlogComment', remote_side=[id], back_populates='replies')
    replies = db.relationship(
        'BlogComment',
        back_populates='parent',
        cascade='all, delete-orphan',
        order_by='BlogComment.created_at.asc()',
        single_parent=True,
    )

    def to_dict(self):
        is_deleted = self.deleted
        return {
            'id': self.id,
            'blog_post_id': self.blog_post_id,
            'user_id': None if is_deleted else self.user_id,
            'parent_comment_id': self.parent_comment_id,
            'content': '[deleted]' if is_deleted else self.content,
            'created_at': _isoformat_or_none(self.created_at),
            'edited': self.edited,
            'edited_at': _isoformat_or_none(self.edited_at),
            'deleted': self.deleted,
            'deleted_at': _isoformat_or_none(self.deleted_at),
            'user': _deleted_comment_user_dict() if is_deleted else _comment_user_dict(self.user, self.user_id),
        }


class Notification(SerializableMixin, db.Model):
    __tablename__ = 'notifications'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    flight = db.Column(db.String(20), nullable=False)

    user = db.relationship('User', back_populates='notifications')

    __table_args__ = (db.UniqueConstraint('user_id', 'flight', name='uq_notifications_user_flight'),)

    def to_dict(self):
        return {
            'id': self.id,
            'flight': self.flight
        }


class Flight(SerializableMixin, db.Model):
    __tablename__ = 'dump1090_flights'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    aircraft = db.Column(db.Integer, db.ForeignKey('dump1090_aircraft.id'), nullable=False)
    flight = db.Column(db.String(20), nullable=False, index=True)
    first_seen = db.Column(db.String(32), nullable=False, index=True)
    last_seen = db.Column(db.String(32), index=True)
    emitter_category = db.Column(db.String(4), nullable=True)
    message_type = db.Column(db.String(32), nullable=True)
    aircraft_class = db.Column(db.String(32), nullable=False, default='unknown', server_default='unknown', index=True)
    ignore_on_purge = db.Column(db.Boolean, nullable=False, default=False, server_default=db.text('0'))

    # Relationships
    aircraft_ref = db.relationship('Aircraft', back_populates='flights')
    positions = db.relationship('Position', back_populates='flight_ref')
    comments = db.relationship('FlightComment', back_populates='flight_ref', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'aircraft': self.aircraft,
            'flight': self.flight,
            'first_seen': self.first_seen,
            'last_seen': self.last_seen,
            'emitter_category': self.emitter_category,
            'message_type': self.message_type,
            'aircraft_class': self.aircraft_class,
            'ignore_on_purge': self.ignore_on_purge,
        }


class Link(SerializableMixin, db.Model):
    __tablename__ = 'links'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(255), nullable=False)
    address = db.Column(db.String(512), nullable=False)
    sort_order = db.Column(db.Integer, nullable=False, default=0)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'address': self.address,
            'sort_order': self.sort_order
        }


class Position(SerializableMixin, db.Model):
    __tablename__ = 'dump1090_positions'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    flight = db.Column(db.Integer, db.ForeignKey('dump1090_flights.id'), nullable=False)
    aircraft = db.Column(db.Integer, db.ForeignKey('dump1090_aircraft.id'), nullable=False)
    time = db.Column(db.String(32), nullable=False)
    message = db.Column(db.Integer, nullable=False)
    squawk = db.Column(db.Integer)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    track = db.Column(db.Integer, nullable=False)
    altitude = db.Column(db.Integer, nullable=False)
    vertical_rate = db.Column('vertical_rate', db.Integer, nullable=False)
    speed = db.Column(db.Integer)

    # Relationships
    aircraft_ref = db.relationship('Aircraft', back_populates='positions')
    flight_ref = db.relationship('Flight', back_populates='positions')

    def to_dict(self):
        return {
            'id': self.id,
            'flight': self.flight,
            'aircraft': self.aircraft,
            'time': self.time,
            'message': self.message,
            'squawk': self.squawk,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'track': self.track,
            'altitude': self.altitude,
            'vertical_rate': self.vertical_rate,
            'speed': self.speed
        }


class Setting(SerializableMixin, db.Model):
    __tablename__ = 'settings'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    value = db.Column(db.Text, nullable=False)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'value': self.value
        }


class User(SerializableMixin, db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(255), nullable=False, unique=True)
    password = db.Column(db.String(255))
    administrator = db.Column(db.Integer, default=0)  # Keep for backward compatibility
    role = db.Column(db.String(20), default='User')  # New role field with Admin/User values
    locked = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))

    blog_comments = db.relationship('BlogComment', back_populates='user')
    flight_comments = db.relationship('FlightComment', back_populates='user')
    uat_flight_comments = db.relationship('UatFlightComment', back_populates='user')
    notifications = db.relationship('Notification', back_populates='user', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'administrator': self.administrator,
            'role': self.role,
            'locked': self.locked,
            'created_at': _isoformat_or_none(self.created_at),
        }

    def has_role(self, role):
        """Check if user has a specific role"""
        return self.role == role

    def is_admin(self):
        """Check if user is an admin"""
        return self.role == 'Admin' or self.administrator == 1


class Dump978Aircraft(SerializableMixin, db.Model):
    __tablename__ = 'dump978_aircraft'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    icao = db.Column(db.String(8), nullable=False, index=True)
    first_seen = db.Column(db.String(32), nullable=False)
    last_seen = db.Column(db.String(32))

    # Relationships
    flights = db.relationship('Dump978Flight', back_populates='aircraft_ref')
    positions = db.relationship('Dump978Position', back_populates='aircraft_ref')

    def to_dict(self):
        return {
            'id': self.id,
            'icao': self.icao,
            'first_seen': self.first_seen,
            'last_seen': self.last_seen
        }


class Dump978Flight(SerializableMixin, db.Model):
    __tablename__ = 'dump978_flights'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    aircraft = db.Column(db.Integer, db.ForeignKey('dump978_aircraft.id'), nullable=False)
    flight = db.Column(db.String(20), nullable=False, index=True)
    first_seen = db.Column(db.String(32), nullable=False, index=True)
    last_seen = db.Column(db.String(32), index=True)
    emitter_category = db.Column(db.String(4), nullable=True)
    message_type = db.Column(db.String(32), nullable=True)
    aircraft_class = db.Column(db.String(32), nullable=False, default='unknown', server_default='unknown', index=True)
    ignore_on_purge = db.Column(db.Boolean, nullable=False, default=False, server_default=db.text('0'))

    # Relationships
    aircraft_ref = db.relationship('Dump978Aircraft', back_populates='flights')
    positions = db.relationship('Dump978Position', back_populates='flight_ref')
    comments = db.relationship('UatFlightComment', back_populates='flight_ref', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'aircraft': self.aircraft,
            'flight': self.flight,
            'first_seen': self.first_seen,
            'last_seen': self.last_seen,
            'emitter_category': self.emitter_category,
            'message_type': self.message_type,
            'aircraft_class': self.aircraft_class,
            'ignore_on_purge': self.ignore_on_purge,
        }


class Dump978Position(SerializableMixin, db.Model):
    __tablename__ = 'dump978_positions'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    flight = db.Column(db.Integer, db.ForeignKey('dump978_flights.id'), nullable=True)
    aircraft = db.Column(db.Integer, db.ForeignKey('dump978_aircraft.id'), nullable=False)
    time = db.Column(db.String(32), nullable=False)
    message = db.Column(db.Integer, nullable=True)
    squawk = db.Column(db.Integer)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    track = db.Column(db.Integer, nullable=False)
    altitude = db.Column(db.Integer, nullable=False)
    vertical_rate = db.Column('vertical_rate', db.Integer, nullable=False)
    speed = db.Column(db.Integer)

    # Relationships
    aircraft_ref = db.relationship('Dump978Aircraft', back_populates='positions')
    flight_ref = db.relationship('Dump978Flight', back_populates='positions')

    def to_dict(self):
        return {
            'id': self.id,
            'flight': self.flight,
            'aircraft': self.aircraft,
            'time': self.time,
            'message': self.message,
            'squawk': self.squawk,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'track': self.track,
            'altitude': self.altitude,
            'vertical_rate': self.vertical_rate,
            'speed': self.speed
        }


class OpenSkyAircraft(db.Model):
    __tablename__ = 'opensky_aircraft'

    icao24 = db.Column(db.String(8), primary_key=True)
    aircraft_class = db.Column(db.String(32), nullable=False)
    confidence = db.Column(db.String(8), nullable=False)


class FlightComment(SerializableMixin, db.Model):
    __tablename__ = 'dump1090_flight_comments'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    flight_id = db.Column(db.Integer, db.ForeignKey('dump1090_flights.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), index=True)
    edited = db.Column(db.Boolean, nullable=False, default=False)
    edited_at = db.Column(db.DateTime, nullable=True)

    flight_ref = db.relationship('Flight', back_populates='comments')
    user = db.relationship('User', back_populates='flight_comments')

    def to_dict(self):
        return {
            'id': self.id,
            'flight_id': self.flight_id,
            'user_id': self.user_id,
            'content': self.content,
            'created_at': _isoformat_or_none(self.created_at),
            'edited': self.edited,
            'edited_at': _isoformat_or_none(self.edited_at),
            'user': _comment_user_dict(self.user, self.user_id),
        }


class UatFlightComment(SerializableMixin, db.Model):
    __tablename__ = 'dump978_flight_comments'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    flight_id = db.Column(db.Integer, db.ForeignKey('dump978_flights.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), index=True)
    edited = db.Column(db.Boolean, nullable=False, default=False)
    edited_at = db.Column(db.DateTime, nullable=True)

    flight_ref = db.relationship('Dump978Flight', back_populates='comments')
    user = db.relationship('User', back_populates='uat_flight_comments')

    def to_dict(self):
        return {
            'id': self.id,
            'flight_id': self.flight_id,
            'user_id': self.user_id,
            'content': self.content,
            'created_at': _isoformat_or_none(self.created_at),
            'edited': self.edited,
            'edited_at': _isoformat_or_none(self.edited_at),
            'user': _comment_user_dict(self.user, self.user_id),
        }