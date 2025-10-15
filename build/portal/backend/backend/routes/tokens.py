import logging
from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token, create_refresh_token, get_jwt_identity, jwt_required
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError
from werkzeug.security import check_password_hash
from backend.models import db, User
from backend.auth import validate_role
from sqlalchemy import select

tokens = Blueprint('tokens', __name__)

# Create Flask-RESTX namespace for authentication
auth_ns = Namespace('token', description='Authentication operations')

# Define API models for documentation
login_model = auth_ns.model('LoginRequest', {
    'email': restx_fields.String(required=True, description='User email address', example='admin@example.com'),
    'password': restx_fields.String(required=True, description='User password', example='password123')
})

token_response_model = auth_ns.model('TokenResponse', {
    'access_token': restx_fields.String(required=True, description='JWT access token'),
    'refresh_token': restx_fields.String(required=True, description='JWT refresh token'),
    'user': restx_fields.Nested(auth_ns.model('User', {
        'id': restx_fields.Integer(description='User ID'),
        'name': restx_fields.String(description='User name'),
        'email': restx_fields.String(description='User email'),
        'role': restx_fields.String(description='User role (Admin/User)')
    }))
})

refresh_response_model = auth_ns.model('RefreshResponse', {
    'access_token': restx_fields.String(required=True, description='New JWT access token')
})

error_model = auth_ns.model('Error', {
    'msg': restx_fields.String(required=True, description='Error message')
})


class LoginRequestSchema(Schema):
    email = fields.Email(required=True)
    password = fields.String(required=True)


@auth_ns.route('/login')
class LoginResource(Resource):
    @auth_ns.expect(login_model, validate=True)
    @auth_ns.marshal_with(token_response_model, code=200)
    @auth_ns.response(400, 'Invalid request data', error_model)
    @auth_ns.response(401, 'Invalid credentials', error_model)
    @auth_ns.doc('authenticate_user')
    def post(self):
        """Authenticate user and return JWT tokens"""
        try:
            payload = LoginRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Invalid request data', 'errors': err.messages}, 400
        
        email = payload['email']
        password = payload['password']
        
        # Find user by email
        user = db.session.execute(select(User).filter_by(email=email)).scalar_one_or_none()
        
        if not user:
            return {'msg': 'Invalid credentials'}, 401
        
        # For development/testing, we'll do a simple password check
        # In production, you should use hashed passwords
        if user.password != password:
            return {'msg': 'Invalid credentials'}, 401
        
        # Ensure user has a valid role
        if not user.role or not validate_role(user.role):
            user.role = 'Admin' if user.administrator == 1 else 'User'
        
        # Create tokens with user email as identity
        access_token = create_access_token(
            identity=user.email,
            additional_claims={'role': user.role, 'user_id': user.id}
        )
        refresh_token = create_refresh_token(
            identity=user.email,
            additional_claims={'role': user.role, 'user_id': user.id}
        )
        
        return {
            'access_token': access_token, 
            'refresh_token': refresh_token,
            'user': {
                'id': user.id,
                'name': user.name,
                'email': user.email,
                'role': user.role
            }
        }, 200





@auth_ns.route('/refresh')
class RefreshResource(Resource):
    @auth_ns.marshal_with(refresh_response_model, code=200)
    @auth_ns.response(401, 'Token refresh failed', error_model)
    @auth_ns.doc('refresh_token', security='Bearer')
    @jwt_required(refresh=True)
    def post(self):
        """Refresh access token using refresh token"""
        try:
            current_user_email = get_jwt_identity()
            user = db.session.execute(select(User).filter_by(email=current_user_email)).scalar_one_or_none()
            
            if not user:
                return {'msg': 'User not found'}, 401
            
            # Ensure user has a valid role
            if not user.role or not validate_role(user.role):
                user.role = 'Admin' if user.administrator == 1 else 'User'
            
            access_token = create_access_token(
                identity=user.email,
                additional_claims={'role': user.role, 'user_id': user.id}
            )
            
            return {'access_token': access_token}, 200
            
        except Exception as e:
            logging.error(f"Error refreshing token: {e}")
            return {'msg': 'Token refresh failed'}, 401


