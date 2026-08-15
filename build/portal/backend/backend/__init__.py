import importlib.util
import logging
import os
from datetime import timedelta
from pathlib import Path

from flask import Flask, jsonify, redirect, request
from flask_apscheduler import APScheduler
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_migrate import Migrate
from flask_restx import Api
from backend.jobs.dump1090_data_collection import dump1090_data_collection_job
from backend.jobs.maintenance import maintenance_job
from backend.jobs.dump978_data_collection import dump978_data_collection_job
from backend.jobs.rrd_data_collection import rrd_data_collection_job
from backend.jobs.x_alert import x_alert_job
from backend.routes.graphs import graphs, graphs_ns
from backend.routes.acars import acars, acars_ns
from backend.routes.blog import blog, blog_ns
from backend.routes.dump1090 import flights, adsb_ns
from backend.routes.dump978 import uat, uat_ns
from backend.routes.links import links, links_ns
from backend.routes.live import live_ns
from backend.routes.notifications import notifications, notifications_ns
from backend.routes.settings import settings, setting_ns
from backend.routes.devices import devices, devices_ns
from backend.routes.dumpvdl2 import dumpvdl2, dumpvdl2_ns
from backend.routes.tokens import tokens, auth_ns
from backend.routes.users import users, users_ns
from backend.routes.x_alert import x_alert_ns
from backend.models import db
from backend.auth import validate_current_user
from backend.config_loader import get_database_config, get_security_config, load_portal_config

from werkzeug.middleware.proxy_fix import ProxyFix

BACKEND_VERSION = os.environ.get('PORTAL_BACKEND_VERSION', 'v3.0.0')


def create_app(test_config=None):
    app = Flask(__name__)
    app.config['PORTAL_BACKEND_VERSION'] = BACKEND_VERSION

    _load_app_config(app, test_config)
    _ensure_instance_path(app)
    _configure_json(app)
    _configure_cors(app)
    _register_index_route(app)

    api = _create_api(app)
    _register_api_namespaces(api)

    _configure_database(app)
    _configure_jwt(app)
    _protect_scheduler_api(app)
    _register_blueprints(app)
    _configure_scheduler(app)
    _init_extensions(app)

    # Apply ProxyFix so Flask sees real client IPs behind Nginx
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)

    return app


def _load_app_config(app, test_config):
    if test_config is None:
        app.config.from_pyfile('config.py', silent=True)
    else:
        app.config.from_mapping(test_config)


def _ensure_instance_path(app):
    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass


def _configure_json(app):
    app.json.sort_keys = False


def _configure_cors(app):
    configured_origins = os.environ.get('PORTAL_CORS_ORIGINS', '')
    origins = [origin.strip() for origin in configured_origins.split(',') if origin.strip()]
    if origins:
        CORS(app, resources={r"/api/*": {"origins": origins}})


def _register_index_route(app):
    @app.route('/')
    def index():
        return redirect('/api/docs/')


def _create_api(app):
    docs_enabled = os.environ.get('PORTAL_API_DOCS_ENABLED', 'true').lower() in ('1', 'true', 'yes')
    return Api(
        app,
        version=BACKEND_VERSION,
        title='ADS-B Receiver Portal API',
        description='A comprehensive API for managing ADS-B receiver data, flights, and system administration',
        doc='/api/docs/' if docs_enabled else False,
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


def _register_api_namespaces(api):
    api.add_namespace(graphs_ns)
    api.add_namespace(auth_ns)
    api.add_namespace(users_ns)
    api.add_namespace(adsb_ns)
    api.add_namespace(uat_ns)
    api.add_namespace(acars_ns)
    api.add_namespace(blog_ns)
    api.add_namespace(devices_ns)
    api.add_namespace(dumpvdl2_ns)
    api.add_namespace(links_ns)
    api.add_namespace(live_ns)
    api.add_namespace(notifications_ns)
    api.add_namespace(setting_ns)
    api.add_namespace(x_alert_ns)


def _configure_database(app):
    # Load database configuration from yaml only if SQLALCHEMY_DATABASE_URI is
    # not already set (e.g. passed directly via test_config).
    db_config = get_database_config()
    if not app.config.get('SQLALCHEMY_DATABASE_URI'):
        if db_config['use'].lower() == 'mysql':
            mysql_config = db_config['mysql']
            app.config['SQLALCHEMY_DATABASE_URI'] = (
                f"mysql://{mysql_config['user']}:{mysql_config['password']}"
                f"@{mysql_config['host']}/{mysql_config['database']}"
            )
        elif db_config['use'].lower() == 'postgresql':
            pg_config = db_config['postgresql']
            app.config['SQLALCHEMY_DATABASE_URI'] = (
                f"postgresql://{pg_config['user']}:{pg_config['password']}"
                f"@{pg_config['host']}/{pg_config['database']}"
            )
        elif db_config['use'].lower() == 'sqlite':
            app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(app.instance_path, 'adsbportal.sqlite3')}"
        else:
            raise ValueError(
                f"Unsupported database type: '{db_config['use']}'. Must be sqlite, mysql, or postgresql."
            )

    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    if db_config['use'].lower() == 'mysql':
        app.config['SQLALCHEMY_POOL_RECYCLE'] = 3600


def _configure_jwt(app):
    if not app.config.get('JWT_SECRET_KEY'):
        security_config = get_security_config(load_portal_config())
        jwt_secret = security_config.get('jwt_secret_key', '')
        if not jwt_secret or jwt_secret == 'CHANGE_THIS_BEFORE_RUNNING':
            raise ValueError(
                "JWT secret key has not been set. Update 'security.jwt_secret_key' in config.yml."
            )
        app.config["JWT_SECRET_KEY"] = jwt_secret

    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=1)
    app.config["JWT_REFRESH_TOKEN_EXPIRES"] = timedelta(days=30)
    jwt = JWTManager(app)

    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        return jsonify({'msg': 'Token has expired'}), 401

    @jwt.invalid_token_loader
    def invalid_token_callback(error):
        return jsonify({'msg': 'Invalid token'}), 401

    @jwt.unauthorized_loader
    def missing_token_callback(error):
        return jsonify({'msg': 'Authorization token is required'}), 401


def _protect_scheduler_api(app):
    @app.before_request
    def protect_scheduler_api():
        if not request.path.startswith('/api/scheduler'):
            return None
        if request.method == 'OPTIONS':
            return None

        try:
            _, auth_error = validate_current_user('Admin')
            if auth_error:
                return jsonify(auth_error[0]), auth_error[1]
        except Exception:
            return jsonify({'msg': 'Invalid token'}), 401

        return None


def _register_blueprints(app):
    app.register_blueprint(graphs)
    app.register_blueprint(acars)
    app.register_blueprint(blog)
    app.register_blueprint(flights)
    app.register_blueprint(uat)
    app.register_blueprint(links)
    app.register_blueprint(notifications)
    app.register_blueprint(settings)
    app.register_blueprint(devices)
    app.register_blueprint(dumpvdl2)
    app.register_blueprint(tokens)
    app.register_blueprint(users)


def _configure_scheduler(app):
    app.config["SCHEDULER_API_ENABLED"] = True
    app.config["SCHEDULER_API_PREFIX"] = "/api/scheduler"
    scheduler = APScheduler()
    scheduler.add_job(id='dump1090_data_collection', func=dump1090_data_collection_job, trigger="interval", seconds=15)
    scheduler.add_job(id='dump978_data_collection', func=dump978_data_collection_job, trigger="interval", seconds=15)
    scheduler.add_job(id='rrd_data_collection', func=rrd_data_collection_job, trigger="interval", seconds=30)
    scheduler.add_job(id='maintenance', func=maintenance_job, trigger="cron", hour=0)
    scheduler.add_job(id='x_alert', func=x_alert_job, trigger="interval", seconds=15, max_instances=1, coalesce=True)
    scheduler.init_app(app)
    # scheduler.start()


def _database_driver_available(database_uri):
    if not database_uri:
        return True
    if database_uri.startswith('mysql'):
        return importlib.util.find_spec('MySQLdb') is not None or importlib.util.find_spec('mysqlclient') is not None
    if database_uri.startswith('postgresql'):
        return importlib.util.find_spec('psycopg2') is not None or importlib.util.find_spec('psycopg2_binary') is not None
    return True


def _init_extensions(app):
    database_uri = app.config.get('SQLALCHEMY_DATABASE_URI', '')
    if _database_driver_available(database_uri):
        db.init_app(app)
    else:
        logging.warning(
            'Skipping SQLAlchemy initialization for %s because the required database driver is not installed. '
            'Install the driver before using database-backed features.',
            database_uri,
        )

    @app.teardown_appcontext
    def _shutdown_sqlalchemy(exc):
        db.session.remove()
        database_uri = app.config.get('SQLALCHEMY_DATABASE_URI', '')
        if database_uri.startswith('sqlite') and ':memory:' not in database_uri:
            try:
                if hasattr(db, 'engine') and db.engine is not None:
                    db.engine.dispose()
            except Exception:
                pass

    migrations_dir = Path(__file__).resolve().parents[1] / 'migrations'
    Migrate(app, db, directory=str(migrations_dir))
