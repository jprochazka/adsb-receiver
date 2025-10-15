from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()


class Aircraft(db.Model):
    __tablename__ = 'aircraft'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    icao = db.Column(db.String(8), nullable=False, index=True)
    first_seen = db.Column(db.String(32), nullable=False)
    last_seen = db.Column(db.String(32))
    
    # Relationships
    flights = db.relationship('Flight', back_populates='aircraft_ref', lazy='dynamic')
    positions = db.relationship('Position', back_populates='aircraft_ref', lazy='dynamic')
    
    def to_dict(self):
        return {
            'id': self.id,
            'icao': self.icao,
            'first_seen': self.first_seen,
            'last_seen': self.last_seen
        }
    
    def serialize(self):
        return self.to_dict()


class BlogPost(db.Model):
    __tablename__ = 'blog_posts'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    title = db.Column(db.String(255), nullable=False)
    date = db.Column(db.String(32), nullable=False)
    author = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'date': self.date,
            'author': self.author,
            'content': self.content
        }
    
    def serialize(self):
        return self.to_dict()


class Notification(db.Model):
    __tablename__ = 'notifications'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    flight = db.Column(db.String(20), nullable=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'flight': self.flight
        }
    
    def serialize(self):
        return self.to_dict()


class Flight(db.Model):
    __tablename__ = 'flights'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    aircraft = db.Column(db.Integer, db.ForeignKey('aircraft.id'), nullable=False)
    flight = db.Column(db.String(20), nullable=False)
    first_seen = db.Column(db.String(32), nullable=False)
    last_seen = db.Column(db.String(32))
    
    # Relationships
    aircraft_ref = db.relationship('Aircraft', back_populates='flights')
    positions = db.relationship('Position', back_populates='flight_ref', lazy='dynamic')
    
    def to_dict(self):
        return {
            'id': self.id,
            'aircraft': self.aircraft,
            'flight': self.flight,
            'first_seen': self.first_seen,
            'last_seen': self.last_seen
        }
    
    def serialize(self):
        return self.to_dict()


class Link(db.Model):
    __tablename__ = 'links'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(255), nullable=False)
    address = db.Column(db.String(512), nullable=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'address': self.address
        }
    
    def serialize(self):
        return self.to_dict()


class Position(db.Model):
    __tablename__ = 'positions'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    flight = db.Column(db.Integer, db.ForeignKey('flights.id'), nullable=False)
    aircraft = db.Column(db.Integer, db.ForeignKey('aircraft.id'), nullable=False)
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
    
    def serialize(self):
        return self.to_dict()


class Setting(db.Model):
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
    
    def serialize(self):
        return self.to_dict()


class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(255), nullable=False, unique=True)
    password = db.Column(db.String(255))
    administrator = db.Column(db.Integer, default=0)  # Keep for backward compatibility
    role = db.Column(db.String(20), default='User')  # New role field with Admin/User values
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'password': self.password,
            'administrator': self.administrator,
            'role': self.role
        }
    
    def serialize(self):
        return self.to_dict()
    
    def has_role(self, role):
        """Check if user has a specific role"""
        return self.role == role
    
    def is_admin(self):
        """Check if user is an admin"""
        return self.role == 'Admin' or self.administrator == 1