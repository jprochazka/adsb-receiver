import logging

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError
from backend.models import db, Setting
from backend.auth import require_admin
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
    @setting_ns.response(404, 'Setting not found')
    @setting_ns.response(500, 'Internal server error')
    @setting_ns.doc('get_setting_by_name')
    def get(self, name):
        """Get setting value by name"""
        try:
            setting = db.session.execute(select(Setting).filter_by(name=name)).scalar_one_or_none()
            
            if not setting:
                return {'msg': 'Setting not found'}, 404
                
            return setting.to_dict(), 200
        except Exception as ex:
            logging.error(f"Error encountered while trying to get setting named {name}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


