import logging

from flask import request
from flask_restx import Namespace, Resource, fields as restx_fields
from sqlalchemy import select

from backend.auth import require_admin
from backend.jobs.x_alert import (
    SECRET_SETTING_NAMES,
    SETTING_DEFAULTS,
    ensure_x_alert_settings,
    execute_x_alert_cycle,
    get_x_alert_setting_values,
    get_x_alert_status,
)
from backend.models import Setting, db


x_alert_ns = Namespace('x-alert', description='X aircraft alert job management')

credentials_model = x_alert_ns.model('XAlertCredentials', {
    'api_key': restx_fields.Boolean(description='Whether an X API key is configured'),
    'api_secret': restx_fields.Boolean(description='Whether an X API secret is configured'),
    'access_token': restx_fields.Boolean(description='Whether an X access token is configured'),
    'access_secret': restx_fields.Boolean(description='Whether an X access secret is configured'),
})

config_fields = {
    name: restx_fields.String(description=f'Value for the {name} setting')
    for name in SETTING_DEFAULTS
    if name not in SECRET_SETTING_NAMES
}
config_fields['credentials'] = restx_fields.Nested(credentials_model)
x_alert_config_model = x_alert_ns.model('XAlertConfig', config_fields)

update_config_fields = {
    name: restx_fields.String(description=f'New value for the {name} setting')
    for name in SETTING_DEFAULTS
}
update_x_alert_config_model = x_alert_ns.model('UpdateXAlertConfig', update_config_fields)

x_alert_status_model = x_alert_ns.model('XAlertStatus', {
    'last_run': restx_fields.String(description='ISO 8601 timestamp of the last cycle'),
    'last_result': restx_fields.String(description='Result of the last cycle'),
    'last_error': restx_fields.String(description='Error from the last failed cycle'),
    'posted_since_start': restx_fields.Integer(description='Alerts posted since process start'),
    'suppressed_since_start': restx_fields.Integer(description='Alerts suppressed since process start'),
    'dump1090_status': restx_fields.String(description='Status of the dump1090 source'),
    'dump978_status': restx_fields.String(description='Status of the dump978 source'),
    'seen': restx_fields.Integer(description='Aircraft seen during the last cycle'),
    'eligible': restx_fields.Integer(description='Aircraft eligible during the last cycle'),
    'last_image_result': restx_fields.String(description='Result of the last map image attempt'),
    'last_image_at': restx_fields.String(description='ISO 8601 timestamp of the last map image attempt'),
})

x_alert_cycle_model = x_alert_ns.model('XAlertCycleResult', {
    'result': restx_fields.String(description='Cycle result'),
    'reason': restx_fields.String(description='Reason a cycle was skipped'),
    'error': restx_fields.String(description='Error from a failed cycle'),
    'seen': restx_fields.Integer(description='Aircraft seen during the cycle'),
    'eligible': restx_fields.Integer(description='Aircraft eligible during the cycle'),
    'posted': restx_fields.Integer(description='Alerts posted during the cycle'),
    'suppressed': restx_fields.Integer(description='Alerts suppressed during the cycle'),
    'failed': restx_fields.Integer(description='Alerts that failed during the cycle'),
    'messages': restx_fields.List(restx_fields.String, description='Generated alert messages'),
})


def _public_config(values: dict[str, str]) -> dict:
    result = {name: value for name, value in values.items() if name not in SECRET_SETTING_NAMES}
    result['credentials'] = {
        'api_key': bool(values['x_alert_x_api_key']),
        'api_secret': bool(values['x_alert_x_api_secret']),
        'access_token': bool(values['x_alert_x_access_token']),
        'access_secret': bool(values['x_alert_x_access_secret']),
    }
    return result


def _validate_config(values: dict[str, str]) -> str | None:
    try:
        poll_seconds = int(values['x_alert_poll_seconds'])
        latitude = values['x_alert_receiver_lat'].strip()
        longitude = values['x_alert_receiver_lon'].strip()
        parsed_latitude = float(latitude) if latitude else None
        parsed_longitude = float(longitude) if longitude else None
        radius = float(values['x_alert_radius_nm'])
        minimum_altitude = int(values['x_alert_min_altitude_ft'])
        maximum_altitude = int(values['x_alert_max_altitude_ft'])
        minimum_speed = int(values['x_alert_min_speed_kt'])
        cooldown = int(values['x_alert_cooldown_minutes'])
        image_width = int(values['x_alert_image_width'])
        image_height = int(values['x_alert_image_height'])
        image_points = int(values['x_alert_image_track_points_max'])
    except (KeyError, TypeError, ValueError):
        return 'One or more numeric settings are invalid'

    if poll_seconds < 15 or poll_seconds > 3600:
        return 'Poll interval must be between 15 and 3600 seconds'
    if parsed_latitude is not None and not -90 <= parsed_latitude <= 90:
        return 'Receiver latitude must be between -90 and 90'
    if parsed_longitude is not None and not -180 <= parsed_longitude <= 180:
        return 'Receiver longitude must be between -180 and 180'
    if not 0.1 <= radius <= 250:
        return 'Radius must be between 0.1 and 250 nautical miles'
    if minimum_altitude > maximum_altitude:
        return 'Minimum altitude cannot exceed maximum altitude'
    if minimum_speed < 0 or cooldown < 1:
        return 'Speed must be non-negative and cooldown must be at least one minute'
    if not 320 <= image_width <= 2048 or not 240 <= image_height <= 2048:
        return 'Image dimensions are outside the supported range'
    if not 2 <= image_points <= 1000:
        return 'Image track point limit must be between 2 and 1000'
    if values['x_alert_post_mode'] not in {'log-only', 'x-api'}:
        return 'Post mode must be log-only or x-api'
    return None


@x_alert_ns.route('/config')
class XAlertConfigResource(Resource):
    @x_alert_ns.response(200, 'X alert configuration retrieved successfully', x_alert_config_model)
    @x_alert_ns.response(401, 'Unauthorized - authentication required')
    @x_alert_ns.response(403, 'Forbidden - admin role required')
    @x_alert_ns.doc('get_x_alert_config', security='Bearer')
    @require_admin()
    def get(self):
        ensure_x_alert_settings()
        return _public_config(get_x_alert_setting_values()), 200

    @x_alert_ns.expect((update_x_alert_config_model, 'X alert settings to update. Omitted settings are unchanged.'))
    @x_alert_ns.response(200, 'X alert configuration updated successfully', x_alert_config_model)
    @x_alert_ns.response(400, 'Bad request - one or more settings are invalid')
    @x_alert_ns.response(401, 'Unauthorized - authentication required')
    @x_alert_ns.response(403, 'Forbidden - admin role required')
    @x_alert_ns.doc('update_x_alert_config', security='Bearer')
    @require_admin()
    def put(self):
        payload = request.get_json(silent=True) or {}
        ensure_x_alert_settings()
        current_values = get_x_alert_setting_values()
        updated_values = dict(current_values)

        for name in SETTING_DEFAULTS:
            if name not in payload:
                continue
            value = payload[name]
            if name in SECRET_SETTING_NAMES and (value is None or str(value) == ''):
                continue
            updated_values[name] = str(value).strip()

        validation_error = _validate_config(updated_values)
        if validation_error:
            return {'msg': validation_error}, 400

        rows = {
            row.name: row for row in db.session.execute(
                select(Setting).where(Setting.name.in_(SETTING_DEFAULTS))
            ).scalars()
        }
        for name, value in updated_values.items():
            rows[name].value = value
        db.session.commit()
        logging.info('[x_alert] Configuration updated by an administrator')
        return _public_config(updated_values), 200


@x_alert_ns.route('/status')
class XAlertStatusResource(Resource):
    @x_alert_ns.response(200, 'X alert status retrieved successfully', x_alert_status_model)
    @x_alert_ns.response(401, 'Unauthorized - authentication required')
    @x_alert_ns.response(403, 'Forbidden - admin role required')
    @x_alert_ns.doc('get_x_alert_status', security='Bearer')
    @require_admin()
    def get(self):
        return get_x_alert_status(), 200


@x_alert_ns.route('/dry-run')
class XAlertDryRunResource(Resource):
    @x_alert_ns.response(200, 'X alert dry run completed', x_alert_cycle_model)
    @x_alert_ns.response(401, 'Unauthorized - authentication required')
    @x_alert_ns.response(403, 'Forbidden - admin role required')
    @x_alert_ns.doc('dry_run_x_alert', security='Bearer')
    @require_admin()
    def post(self):
        logging.info('[x_alert] Manual dry run requested by an administrator')
        return execute_x_alert_cycle(dry_run=True, force=True), 200


@x_alert_ns.route('/send')
class XAlertSendResource(Resource):
    @x_alert_ns.response(200, 'X alert cycle completed', x_alert_cycle_model)
    @x_alert_ns.response(401, 'Unauthorized - authentication required')
    @x_alert_ns.response(403, 'Forbidden - admin role required')
    @x_alert_ns.response(502, 'X alert cycle failed', x_alert_cycle_model)
    @x_alert_ns.doc('send_x_alert', security='Bearer')
    @require_admin()
    def post(self):
        logging.info('[x_alert] Manual send requested by an administrator')
        result = execute_x_alert_cycle(force=True)
        return result, 200 if result.get('result') != 'failed' else 502