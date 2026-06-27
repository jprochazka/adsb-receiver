import hashlib
import json
import logging
import os
import tempfile

from datetime import datetime, timezone
from shutil import copyfileobj
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from flask import Blueprint, current_app, request
from flask_jwt_extended import verify_jwt_in_request
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError
from backend.models import db, Setting
from backend.auth import get_current_user, require_admin
from backend.opensky_classification import import_opensky_csv
from sqlalchemy import select

settings = Blueprint('settings', __name__)

# Create Flask-RESTX namespaces for settings management
setting_ns = Namespace('setting', description='Individual setting management')

# Define API models for documentation - shared across namespaces
setting_model = setting_ns.model('Setting', {
    'name': restx_fields.String(description='Setting name'),
    'value': restx_fields.String(description='Setting value')
})

update_setting_model = setting_ns.model('UpdateSetting', {
    'name': restx_fields.String(required=True, description='Setting name to update'),
    'value': restx_fields.String(required=True, description='New setting value')
})

opensky_database_model = setting_ns.model('OpenSkyAircraftDatabase', {
    'installed': restx_fields.Boolean(description='Whether the OpenSky aircraft database has been downloaded locally'),
    'db_path': restx_fields.String(description='Absolute path to local aircraft database CSV file'),
    'metadata_path': restx_fields.String(description='Absolute path to local metadata JSON file'),
    'notice_path': restx_fields.String(description='Absolute path to local license notice text file'),
    'size_bytes': restx_fields.Integer(description='Local file size in bytes'),
    'sha256': restx_fields.String(description='SHA-256 checksum of local CSV file'),
    'downloaded_at': restx_fields.String(description='UTC ISO-8601 timestamp when the database was downloaded'),
    'source_url': restx_fields.String(description='Source URL used to download the CSV'),
    'license_name': restx_fields.String(description='Data license name'),
    'license_url': restx_fields.String(description='Data license URL'),
    'attribution': restx_fields.String(description='Required attribution text for OpenSky data')
})

api_version_model = setting_ns.model('ApiVersion', {
    'version': restx_fields.String(description='Backend API version string')
})

OPENSKY_DB_URL = 'https://opensky-network.org/datasets/metadata/aircraftDatabase.csv'
OPENSKY_DB_FILE = 'aircraftDatabase.csv'
OPENSKY_METADATA_FILE = 'aircraftDatabase.metadata.json'
OPENSKY_NOTICE_FILE = 'LICENSE-ODbL-OpenSky.txt'
OPENSKY_LICENSE_NAME = 'Open Database License (ODbL) v1.0'
OPENSKY_LICENSE_URL = 'https://opendatacommons.org/licenses/odbl/'
OPENSKY_ATTRIBUTION = 'Contains information from OpenSky Network aircraft database (ODbL v1.0).'

_PUBLIC_SETTING_PREFIXES = (
    'live_map_',
    'graphs_',
    'info_',
    'map_',
    'flights_',
    'acars_',
    'blog_',
    'links_',
    'all_tab_',
    'adsb_tab_',
    'uat_tab_',
)


def _is_public_setting_name(name: str) -> bool:
    return any(name.startswith(prefix) for prefix in _PUBLIC_SETTING_PREFIXES)


def _require_admin_setting_read():
    try:
        verify_jwt_in_request()
        current_user = get_current_user()

        if not current_user:
            return {'msg': 'User not found'}, 401
        if current_user.locked:
            return {'msg': 'Account is locked'}, 403
        if not current_user.is_admin():
            return {'msg': 'Admin access required'}, 403
        return None
    except Exception:
        return {'msg': 'Invalid token'}, 401


def _opensky_db_dir() -> str:
    return os.path.join(current_app.instance_path, 'opensky')


def _opensky_db_path() -> str:
    return os.path.join(_opensky_db_dir(), OPENSKY_DB_FILE)


def _opensky_metadata_path() -> str:
    return os.path.join(_opensky_db_dir(), OPENSKY_METADATA_FILE)


def _opensky_notice_path() -> str:
    return os.path.join(_opensky_db_dir(), OPENSKY_NOTICE_FILE)


def _sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(8192), b''):
            digest.update(chunk)
    return digest.hexdigest()


def _notice_text() -> str:
    return (
        'OpenSky Network Aircraft Database\n'
        f'Source: {OPENSKY_DB_URL}\n'
        f'License: {OPENSKY_LICENSE_NAME}\n'
        f'License URL: {OPENSKY_LICENSE_URL}\n'
        f'Attribution: {OPENSKY_ATTRIBUTION}\n'
    )


def _read_metadata(path: str):
    if not os.path.exists(path):
        return None

    try:
        with open(path, 'r', encoding='utf-8') as handle:
            return json.load(handle)
    except Exception as ex:
        logging.error('Failed reading OpenSky metadata', exc_info=ex)
        return None


def _build_opensky_status() -> dict:
    db_path = _opensky_db_path()
    metadata_path = _opensky_metadata_path()
    metadata = _read_metadata(metadata_path) or {}
    installed = os.path.exists(db_path)

    return {
        'installed': installed,
        'size_bytes': metadata.get('size_bytes') if installed else None,
        'sha256': metadata.get('sha256') if installed else None,
        'downloaded_at': metadata.get('downloaded_at') if installed else None,
        'source_url': metadata.get('source_url', OPENSKY_DB_URL),
        'license_name': OPENSKY_LICENSE_NAME,
        'license_url': OPENSKY_LICENSE_URL,
        'attribution': OPENSKY_ATTRIBUTION,
    }


def _write_metadata_and_notice(csv_path: str) -> dict:
    metadata_path = _opensky_metadata_path()
    notice_path = _opensky_notice_path()

    metadata = {
        'file_name': OPENSKY_DB_FILE,
        'source_url': OPENSKY_DB_URL,
        'license_name': OPENSKY_LICENSE_NAME,
        'license_url': OPENSKY_LICENSE_URL,
        'attribution': OPENSKY_ATTRIBUTION,
        'size_bytes': os.path.getsize(csv_path),
        'sha256': _sha256_file(csv_path),
        'downloaded_at': datetime.now(timezone.utc).isoformat(),
    }

    with open(metadata_path, 'w', encoding='utf-8') as handle:
        json.dump(metadata, handle, indent=2)

    with open(notice_path, 'w', encoding='utf-8') as handle:
        handle.write(_notice_text())

    return metadata

class UpdateSettingRequestSchema(Schema):
    name = fields.String(required=True)
    value = fields.String(required=True)


@setting_ns.route('')
class SettingResource(Resource):
    @setting_ns.expect(update_setting_model)
    @setting_ns.response(200, 'Setting updated successfully')
    @setting_ns.response(400, 'Bad request - validation error')
    @setting_ns.response(404, 'Setting not found')
    @setting_ns.response(401, 'Unauthorized - authentication required')
    @setting_ns.response(403, 'Forbidden - admin role required')
    @setting_ns.response(500, 'Internal server error')
    @setting_ns.doc('update_setting', security='Bearer')
    @require_admin()
    def put(self):
        """Update a setting value (Admin only)"""
        try:
            payload = UpdateSettingRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Validation error', 'errors': err.messages}, 400

        try:
            setting = db.session.execute(select(Setting).filter_by(name=payload['name'])).scalar_one_or_none()
            
            if not setting:
                return {'msg': 'Setting not found'}, 404
                
            setting.value = payload['value']
            db.session.commit()
            return {'msg': 'Setting updated successfully'}, 200
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to put setting named {payload['name']}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@setting_ns.route('/<string:name>')
class SettingByNameResource(Resource):
    @setting_ns.response(200, 'Setting retrieved successfully', setting_model)
    @setting_ns.response(401, 'Unauthorized')
    @setting_ns.response(404, 'Setting not found')
    @setting_ns.response(500, 'Internal server error')
    @setting_ns.doc('get_setting_by_name')
    def get(self, name):
        """Get setting value by name"""
        if not _is_public_setting_name(name):
            auth_error = _require_admin_setting_read()
            if auth_error:
                return auth_error

        try:
            setting = db.session.execute(select(Setting).filter_by(name=name)).scalar_one_or_none()
            
            if not setting:
                return {'msg': 'Setting not found'}, 404
                
            return setting.to_dict(), 200
        except Exception as ex:
            logging.error(f"Error encountered while trying to get setting named {name}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@setting_ns.route('/opensky-aircraft-database')
class OpenSkyAircraftDatabaseStatusResource(Resource):
    @setting_ns.response(200, 'OpenSky aircraft database status', opensky_database_model)
    @setting_ns.response(404, 'OpenSky aircraft database not installed')
    @setting_ns.doc('get_opensky_aircraft_database_status')
    def get(self):
        """Get local OpenSky aircraft database status and license metadata"""
        try:
            status = _build_opensky_status()
            if not status['installed']:
                return {'msg': 'OpenSky aircraft database is not installed', **status}, 404
            return status, 200
        except Exception as ex:
            logging.error('Error while reading OpenSky database status', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@setting_ns.route('/opensky-aircraft-database/update')
class OpenSkyAircraftDatabaseUpdateResource(Resource):
    @setting_ns.response(200, 'OpenSky aircraft database downloaded successfully', opensky_database_model)
    @setting_ns.response(401, 'Unauthorized - authentication required')
    @setting_ns.response(403, 'Forbidden - admin role required')
    @setting_ns.response(502, 'Failed to download OpenSky aircraft database')
    @setting_ns.response(500, 'Internal server error')
    @setting_ns.doc('update_opensky_aircraft_database', security='Bearer')
    @require_admin()
    def post(self):
        """Download or refresh local OpenSky aircraft database (Admin only)"""
        db_dir = _opensky_db_dir()
        final_path = _opensky_db_path()
        tmp_path = None

        try:
            os.makedirs(db_dir, exist_ok=True)
            request = Request(OPENSKY_DB_URL, headers={'User-Agent': 'adsb-receiver-portal/1.0'})

            with urlopen(request, timeout=60) as response:
                with tempfile.NamedTemporaryFile(dir=db_dir, delete=False) as tmp_handle:
                    tmp_path = tmp_handle.name
                    copyfileobj(response, tmp_handle)

            os.replace(tmp_path, final_path)
            tmp_path = None

            _write_metadata_and_notice(final_path)
            count = import_opensky_csv()
            logging.info('OpenSky CSV imported into database: %d classified aircraft', count)
            return _build_opensky_status(), 200

        except (HTTPError, URLError, TimeoutError) as ex:
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)
            logging.error('Failed downloading OpenSky aircraft database', exc_info=ex)
            return {
                'msg': 'Unable to download OpenSky aircraft database',
                'source_url': OPENSKY_DB_URL,
                'license_name': OPENSKY_LICENSE_NAME,
                'license_url': OPENSKY_LICENSE_URL,
                'attribution': OPENSKY_ATTRIBUTION,
            }, 502

        except Exception as ex:
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)
            logging.error('Unexpected error while updating OpenSky aircraft database', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@setting_ns.route('/api-version')
class ApiVersionResource(Resource):
    @setting_ns.response(200, 'Backend API version', api_version_model)
    @setting_ns.doc('get_api_version')
    def get(self):
        """Get backend API version"""
        version = current_app.config.get('PORTAL_BACKEND_VERSION', 'v3.0.0')
        return {'version': version}, 200


