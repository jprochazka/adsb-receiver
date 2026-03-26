import os
import yaml

from datetime import timedelta
from flask import Flask, jsonify, redirect
from flask_apscheduler import APScheduler
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_migrate import Migrate
from flask_restx import Api
from backend.jobs.dump1090_data_collection import dump1090_data_collection_job
from backend.jobs.maintenance import maintenance_job
from backend.jobs.dump978_data_collection import dump978_data_collection_job
from backend.jobs.rrd_data_collection import rrd_data_collection_job
from backend.routes.graphs import graphs, graphs_ns
from backend.routes.acars import acars, acars_flight_ns, acars_flights_ns, acars_messages_ns, acars_stations_ns
from backend.routes.aircraft import aircraft, aircraft_ns
from backend.routes.blog import blog, blog_ns
from backend.routes.dump1090 import flights, flights_ns, flight_ns
from backend.routes.dump978 import uat, uat_flights_ns, uat_flight_ns
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

    CORS(app, resources={r"/api/*": {"origins": "*"}})

    @app.route('/')
    def index():
        return redirect('/api/docs/')

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
    api.add_namespace(graphs_ns)
    api.add_namespace(auth_ns)
    api.add_namespace(users_ns)
    api.add_namespace(aircraft_ns)
    api.add_namespace(flight_ns)
    api.add_namespace(flights_ns)
    api.add_namespace(uat_flight_ns)
    api.add_namespace(uat_flights_ns)
    api.add_namespace(acars_flight_ns)
    api.add_namespace(acars_flights_ns)
    api.add_namespace(acars_messages_ns)
    api.add_namespace(acars_stations_ns)
    api.add_namespace(blog_ns)
    api.add_namespace(system_ns)
    api.add_namespace(link_ns)
    api.add_namespace(links_ns)
    api.add_namespace(notification_ns)
    api.add_namespace(notifications_ns)
    api.add_namespace(setting_ns)
    api.add_namespace(settings_ns)

    # Load database configuration from yaml only if SQLALCHEMY_DATABASE_URI is
    # not already set (e.g. passed directly via test_config).
    if not app.config.get('SQLALCHEMY_DATABASE_URI'):
        with open("config.yml") as f:
            config = yaml.safe_load(f)
        db_config = config['database']
        if db_config['use'].lower() == 'mysql':
            mysql_config = db_config['mysql']
            app.config['SQLALCHEMY_DATABASE_URI'] = f"mysql://{mysql_config['user']}:{mysql_config['password']}@{mysql_config['host']}/{mysql_config['database']}"
        elif db_config['use'].lower() == 'postgresql':
            pg_config = db_config['postgresql']
            app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{pg_config['user']}:{pg_config['password']}@{pg_config['host']}/{pg_config['database']}"
        elif db_config['use'].lower() == 'sqlite':
            app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(app.instance_path, 'adsbportal.sqlite3')}"
        else:
            raise ValueError(
                f"Unsupported database type: '{db_config['use']}'. Must be sqlite, mysql, or postgresql."
            )

    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    if not app.config.get('JWT_SECRET_KEY'):
        with open("config.yml") as f:
            _security_config = yaml.safe_load(f)
        jwt_secret = _security_config.get('security', {}).get('jwt_secret_key', '')
        if not jwt_secret or jwt_secret == 'CHANGE_THIS_BEFORE_RUNNING':
            raise ValueError(
                "JWT secret key has not been set. Update 'security.jwt_secret_key' in config.yml."
            )
        app.config["JWT_SECRET_KEY"] = jwt_secret
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=1)
    app.config["JWT_REFRESH_TOKEN_EXPIRES"] = timedelta(days=30)
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

    app.register_blueprint(graphs)
    app.register_blueprint(acars)
    app.register_blueprint(aircraft)
    app.register_blueprint(blog)
    app.register_blueprint(flights)
    app.register_blueprint(uat)
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
    scheduler.add_job(id = 'dump1090_data_collection', func=dump1090_data_collection_job, trigger="interval", seconds=15)
    scheduler.add_job(id = 'dump978_data_collection', func=dump978_data_collection_job, trigger="interval", seconds=15)
    scheduler.add_job(id = 'rrd_data_collection', func=rrd_data_collection_job, trigger="interval", seconds=30)
    scheduler.add_job(id = 'maintenance', func=maintenance_job, trigger="cron", hour=0)
    scheduler.init_app(app)
    #scheduler.start()


    # /API/DOCS
    # Flask-RESTX automatically provides documentation at /api/docs/
    
    
    # INIT_APP
    
    # Initialize SQLAlchemy and Alembic migrations
    db.init_app(app)
    Migrate(app, db)
    
    return app