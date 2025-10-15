import os
import yaml

from datetime import timedelta
from flask import Flask, jsonify
from flask_apscheduler import APScheduler
from flask_jwt_extended import JWTManager
from flask_restx import Api
from backend.jobs.data_collection import data_collection_job
from backend.jobs.maintenance import maintenance_job
from backend.routes.aircraft import aircraft, aircraft_ns
from backend.routes.blog import blog, blog_ns
from backend.routes.flights import flights, flights_ns, flight_ns
from backend.routes.links import links, links_ns, link_ns
from backend.routes.notifications import notifications, notification_ns, notifications_ns
from backend.routes.settings import settings, setting_ns, settings_ns
from backend.routes.system import system, system_ns
from backend.routes.tokens import tokens, auth_ns
from backend.routes.users import users, users_ns
from backend.models import db

def create_app(test_config=None):
    app = Flask(__name__)
    
    if test_config is None:
        app.config.from_pyfile('config.py', silent=True)
    else:
        app.config.from_mapping(test_config)

    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

    app.json.sort_keys = False

    # Initialize Flask-RESTX API documentation
    api = Api(
        app,
        version='1.0',
        title='ADSB Receiver Portal API',
        description='A comprehensive API for managing ADSB receiver data, flights, and system administration',
        doc='/api/docs/',
        prefix='/api',
        authorizations={
            'Bearer': {
                'type': 'apiKey',
                'in': 'header',
                'name': 'Authorization',
                'description': 'JWT token. Format: Bearer <token>'
            }
        }
    )
    
    # Register API namespaces
    api.add_namespace(auth_ns)
    api.add_namespace(users_ns)
    api.add_namespace(aircraft_ns)
    api.add_namespace(flight_ns)
    api.add_namespace(flights_ns)
    api.add_namespace(blog_ns)
    api.add_namespace(system_ns)
    api.add_namespace(link_ns)
    api.add_namespace(links_ns)
    api.add_namespace(notification_ns)
    api.add_namespace(notifications_ns)
    api.add_namespace(setting_ns)
    api.add_namespace(settings_ns)

    # Load database configuration
    config = yaml.safe_load(open("config.yml"))
    
    # Configure SQLAlchemy based on database type
    db_config = config['database']
    if db_config['use'].lower() == 'mysql':
        mysql_config = db_config['mysql']
        app.config['SQLALCHEMY_DATABASE_URI'] = f"mysql://{mysql_config['user']}:{mysql_config['password']}@{mysql_config['host']}/{mysql_config['database']}"
    elif db_config['use'].lower() == 'postgresql':
        pg_config = db_config['postgresql']
        app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{pg_config['user']}:{pg_config['password']}@{pg_config['host']}/{pg_config['database']}"
    elif db_config['use'].lower() == 'sqlite':
        app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(app.instance_path, 'adsbportal.sqlite3')}"
    
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    app.config["JWT_SECRET_KEY"] = "CHANGE_THIS_IN_PRODUCTION"  # Change this!
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=1)
    app.config["JWT_REFRESH_TOKEN_EXPIRES"] = timedelta(days=365)
    jwt = JWTManager(app)
    
    # JWT Error handlers for better error messages
    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        return jsonify({'msg': 'Token has expired'}), 401
    
    @jwt.invalid_token_loader
    def invalid_token_callback(error):
        return jsonify({'msg': 'Invalid token'}), 401
    
    @jwt.unauthorized_loader
    def missing_token_callback(error):
        return jsonify({'msg': 'Authorization token is required'}), 401

    app.register_blueprint(aircraft)
    app.register_blueprint(blog)
    app.register_blueprint(flights)
    app.register_blueprint(links)
    app.register_blueprint(notifications)
    app.register_blueprint(settings)
    app.register_blueprint(system)
    app.register_blueprint(tokens)
    app.register_blueprint(users)


    # /API/SCHEDULER

    app.config["SCHEDULER_API_ENABLED"] = True
    app.config["SCHEDULER_API_PREFIX"] = "/api/scheduler"
    scheduler = APScheduler()
    scheduler.add_job(id = 'data_collection', func=data_collection_job, trigger="interval", seconds=15)
    scheduler.add_job(id = 'maintenance', func=maintenance_job, trigger="cron", hour=0)
    scheduler.init_app(app)
    #scheduler.start()


    # /API/DOCS
    # Flask-RESTX automatically provides documentation at /api/docs/
    
    
    # INIT_APP
    
    # Initialize SQLAlchemy
    db.init_app(app)
    
    # Add SQLAlchemy-based CLI commands
    @app.cli.command('init-db')
    def init_db_command():
        """Initialize the database with SQLAlchemy."""
        import click
        db.create_all()
        click.echo('Database initialized with SQLAlchemy.')
    
    return app