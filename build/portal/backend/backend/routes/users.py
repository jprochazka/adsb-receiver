import logging
from datetime import datetime, timezone

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError
from werkzeug.security import generate_password_hash
from backend.models import BlogComment, db, User
from backend.auth import require_admin, require_user_or_admin, validate_role
from backend.routes.common import QueryParamError, get_stripped_arg, parse_bool_arg, parse_pagination
from sqlalchemy import delete, select, func

users = Blueprint('users', __name__)

# Create Flask-RESTX namespace for user management
users_ns = Namespace('users', description='User management operations')

# Define API models for documentation
user_model = users_ns.model('User', {
    'id': restx_fields.Integer(description='User ID'),
    'name': restx_fields.String(description='User name'),
    'email': restx_fields.String(description='User email address'),
    'role': restx_fields.String(description='User role (Admin/User)'),
    'locked': restx_fields.Boolean(description='Whether the account is locked'),
    'created_at': restx_fields.String(description='Registration date (ISO 8601)'),
    'administrator': restx_fields.Integer(description='Administrator flag (0/1) for backward compatibility')
})

create_user_model = users_ns.model('CreateUserRequest', {
    'name': restx_fields.String(required=True, description='User full name', example='John Doe'),
    'email': restx_fields.String(required=True, description='User email address', example='john@example.com'),
    'password': restx_fields.String(required=True, description='User password', example='securepassword123'),
    'role': restx_fields.String(description='User role (Admin/User)', example='User'),
    'administrator': restx_fields.Boolean(description='Administrator flag (true/false) for backward compatibility', example=False)
})

update_user_model = users_ns.model('UpdateUserRequest', {
    'name': restx_fields.String(required=True, description='User full name', example='John Doe Updated'),
    'email': restx_fields.String(description='User email address', example='john@example.com'),
    'password': restx_fields.String(description='New password (optional)', example='newsecurepassword123'),
    'role': restx_fields.String(description='User role (Admin/User)', example='User'),
    'administrator': restx_fields.Boolean(description='Administrator flag (true/false) for backward compatibility', example=False)
})

users_list_model = users_ns.model('UsersList', {
    'users': restx_fields.List(restx_fields.Nested(user_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of users returned'),
    'total': restx_fields.Integer(description='Total number of users'),
    'all_total': restx_fields.Integer(description='Total number of matching users across all statuses'),
    'active_total': restx_fields.Integer(description='Total number of matching unlocked users'),
    'locked_total': restx_fields.Integer(description='Total number of matching locked users')
})

user_response_model = users_ns.model('UserResponse', {
    'msg': restx_fields.String(description='Response message'),
    'user': restx_fields.Nested(user_model)
})

error_model = users_ns.model('Error', {
    'msg': restx_fields.String(required=True, description='Error message')
})


class CreateUserRequestSchema(Schema):
    name = fields.String(required=True)
    email = fields.Email(required=True)
    password = fields.String(required=True)
    administrator = fields.Boolean()  # Keep for backward compatibility
    role = fields.String()  # New role field

class UpdateUserRequestSchema(Schema):
    name = fields.String(required=True)
    email = fields.Email()
    password = fields.String(required=True)
    administrator = fields.Boolean()  # Keep for backward compatibility
    role = fields.String()  # New role field


def _role_and_administrator_from_payload(payload):
    role = payload.get('role', 'User')
    if not validate_role(role):
        return None, None, {'msg': 'Invalid role. Must be Admin or User'}

    administrator = 1 if role == 'Admin' else 0
    if 'administrator' in payload:
        administrator = 1 if payload['administrator'] else 0
        role = 'Admin' if administrator == 1 else 'User'

    return role, administrator, None


def _public_user_dict(user):
    data = user.to_dict()
    data.pop('password', None)
    return data


def _can_access_user(current_user, user_id):
    return current_user.role == 'Admin' or current_user.id == user_id


def _apply_user_updates(user, payload, current_user):
    user.name = payload['name']
    if 'email' in payload:
        user.email = payload['email']
    if 'password' in payload:
        user.password = generate_password_hash(payload['password'])

    if 'role' in payload and validate_role(payload['role']):
        if current_user.role != 'Admin':
            return {'msg': 'Only admins can change user roles'}, 403
        user.role = payload['role']
        user.administrator = 1 if payload['role'] == 'Admin' else 0

    if 'administrator' in payload and current_user.role == 'Admin':
        user.administrator = 1 if payload['administrator'] else 0
        user.role = 'Admin' if payload['administrator'] else 'User'

    return None, None


def _updated_user_response(user):
    return {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'role': user.role,
        'administrator': user.administrator,
    }


def _select_comment_replacement_user_id(current_user, user_id):
    if current_user and current_user.id != user_id:
        return current_user.id

    replacement_user = db.session.execute(
        select(User)
        .where(User.id != user_id)
        .order_by(User.id.asc())
    ).scalar_one_or_none()
    return replacement_user.id if replacement_user else None


def _split_comments_by_replies(comments):
    comments_with_replies = [comment for comment in comments if comment.replies]
    comments_without_replies = [comment for comment in comments if not comment.replies]
    return comments_with_replies, comments_without_replies


def _delete_or_reassign_authored_comments(comments, replacement_user_id):
    comments_with_replies, comments_without_replies = _split_comments_by_replies(comments)
    if comments_with_replies and replacement_user_id is None:
        return {'msg': 'Cannot delete this user because no replacement user is available for authored comments'}, 400

    for comment in comments_without_replies:
        db.session.delete(comment)

    for comment in comments_with_replies:
        if not comment.deleted:
            comment.deleted = True
            comment.deleted_at = datetime.now(timezone.utc)
        comment.user_id = replacement_user_id

    return None, None


def _apply_user_filters(statement, search_query, locked_value=None):
    filtered_statement = statement
    if search_query:
        pattern = f'%{search_query}%'
        filtered_statement = filtered_statement.where(
            User.name.ilike(pattern) | User.email.ilike(pattern)
        )
    if locked_value is not None:
        filtered_statement = filtered_statement.where(User.locked.is_(locked_value))
    return filtered_statement


def _user_list_totals(search_query):
    return {
        'total': db.session.execute(select(func.count()).select_from(User)).scalar(),
        'all_total': db.session.execute(
            _apply_user_filters(select(func.count()).select_from(User), search_query)
        ).scalar(),
        'active_total': db.session.execute(
            _apply_user_filters(select(func.count()).select_from(User), search_query, locked_value=False)
        ).scalar(),
        'locked_total': db.session.execute(
            _apply_user_filters(select(func.count()).select_from(User), search_query, locked_value=True)
        ).scalar(),
    }


def _serialize_users(users):
    return [_public_user_dict(user) for user in users]


@users_ns.route('/create')
class UserCreateResource(Resource):
    @users_ns.expect(create_user_model, validate=True)
    @users_ns.marshal_with(user_response_model, code=201)
    @users_ns.response(400, 'Invalid request data', error_model)
    @users_ns.response(401, 'Unauthorized - authentication required', error_model)
    @users_ns.response(403, 'Forbidden - admin role required', error_model)
    @users_ns.doc('create_user', security='Bearer')
    @require_admin()
    def post(self):
        """Create a new user (Admin only)"""
        try:
            payload = CreateUserRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Invalid request data', 'errors': err.messages}, 400
        
        role, administrator, error = _role_and_administrator_from_payload(payload)
        if error:
            return error, 400

        try:
            # Check if user already exists
            existing_user = db.session.execute(select(User).filter_by(email=payload['email'])).scalar_one_or_none()
            if existing_user:
                return {'msg': 'User with this email already exists'}, 400
            
            new_user = User(
                name=payload['name'],
                email=payload['email'],
                password=generate_password_hash(payload['password']),
                administrator=administrator,
                role=role
            )
            
            db.session.add(new_user)
            db.session.commit()
            
            return {
                'msg': 'User created successfully',
                'user': new_user.to_dict()
            }, 201
            
        except Exception as ex:
            db.session.rollback()
            logging.error('Error encountered while trying to create user', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


class RegisterUserRequestSchema(Schema):
    name = fields.String(required=True)
    email = fields.Email(required=True)
    password = fields.String(required=True)


register_user_model = users_ns.model('RegisterUserRequest', {
    'name': restx_fields.String(required=True, description='Full name', example='Jane Doe'),
    'email': restx_fields.String(required=True, description='Email address', example='jane@example.com'),
    'password': restx_fields.String(required=True, description='Password', example='securepassword123')
})


@users_ns.route('/register')
class UserRegisterResource(Resource):
    @users_ns.expect(register_user_model, validate=True)
    @users_ns.marshal_with(user_response_model, code=201)
    @users_ns.response(400, 'Invalid request data or email already in use', error_model)
    @users_ns.response(500, 'Internal server error', error_model)
    @users_ns.doc('register_user')
    def post(self):
        """Register a new user account (no authentication required)"""
        try:
            payload = RegisterUserRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Invalid request data', 'errors': err.messages}, 400

        if not payload.get('name', '').strip():
            return {'msg': 'Name is required'}, 400
        if len(payload.get('password', '')) < 8:
            return {'msg': 'Password must be at least 8 characters'}, 400

        try:
            existing = db.session.execute(select(User).filter_by(email=payload['email'])).scalar_one_or_none()
            if existing:
                return {'msg': 'An account with that email address already exists'}, 400

            new_user = User(
                name=payload['name'].strip(),
                email=payload['email'],
                password=generate_password_hash(payload['password']),
                administrator=0,
                role='User'
            )
            db.session.add(new_user)
            db.session.commit()

            return {'msg': 'Account created successfully', 'user': new_user.to_dict()}, 201

        except Exception as ex:
            db.session.rollback()
            logging.error('Error encountered while trying to register user', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@users_ns.route('/user/<int:user_id>')
class UserResource(Resource):
    @users_ns.marshal_with(user_model, code=200)
    @users_ns.response(403, 'Access denied', error_model)
    @users_ns.response(404, 'User not found', error_model)
    @users_ns.response(401, 'Unauthorized - authentication required', error_model)
    @users_ns.response(500, 'Internal server error', error_model)
    @users_ns.doc('get_user', security='Bearer')
    @require_user_or_admin()
    def get(self, user_id):
        """Get user details (User can get their own, Admin can get any)"""
        from backend.auth import get_current_user
        
        try:
            current_user = get_current_user()
            
            if not _can_access_user(current_user, user_id):
                return {'msg': 'Access denied. You can only access your own data'}, 403
            
            user = db.session.get(User, user_id)
            
            if not user:
                return {'msg': 'User not found'}, 404
                
            return _public_user_dict(user), 200
            
        except Exception as ex:
            logging.error(f"Error encountered while trying to get user with ID {user_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @users_ns.expect(update_user_model, validate=True)
    @users_ns.marshal_with(user_response_model, code=200)
    @users_ns.response(400, 'Invalid request data', error_model)
    @users_ns.response(403, 'Access denied', error_model)
    @users_ns.response(404, 'User not found', error_model)
    @users_ns.response(401, 'Unauthorized - authentication required', error_model)
    @users_ns.response(500, 'Internal server error', error_model)
    @users_ns.doc('update_user', security='Bearer')
    @require_user_or_admin()
    def put(self, user_id):
        """Update user details (User can update their own, Admin can update any)"""
        from backend.auth import get_current_user
        
        try:
            payload = UpdateUserRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Invalid request data', 'errors': err.messages}, 400

        try:
            current_user = get_current_user()
            user = db.session.get(User, user_id)
            
            if not user:
                return {'msg': 'User not found'}, 404
            
            if not _can_access_user(current_user, user_id):
                return {'msg': 'Access denied. You can only update your own data'}, 403

            error, status = _apply_user_updates(user, payload, current_user)
            if error:
                return error, status

            db.session.commit()
            
            return {
                'msg': 'User updated successfully',
                'user': _updated_user_response(user)
            }, 200
            
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to put user with ID {user_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @users_ns.response(200, 'User deleted successfully')
    @users_ns.response(404, 'User not found', error_model)
    @users_ns.response(401, 'Unauthorized - authentication required', error_model)
    @users_ns.response(403, 'Forbidden - admin role required', error_model)
    @users_ns.response(500, 'Internal server error', error_model)
    @users_ns.doc('delete_user', security='Bearer')
    @require_admin()
    def delete(self, user_id):
        """Delete a user (Admin only)"""
        from backend.auth import get_current_user

        try:
            user = db.session.get(User, user_id)
            
            if not user:
                return {'msg': 'User not found'}, 404

            current_user = get_current_user()

            replacement_user_id = _select_comment_replacement_user_id(current_user, user_id)
            authored_comments = db.session.execute(
                select(BlogComment).where(BlogComment.user_id == user_id)
            ).scalars().all()
            error, status = _delete_or_reassign_authored_comments(authored_comments, replacement_user_id)
            if error:
                return error, status

            db.session.execute(delete(User).where(User.id == user_id))
            db.session.commit()
            
            return {'msg': 'User deleted successfully'}, 200
            
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to delete user with ID {user_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


lock_model = users_ns.model('LockUserRequest', {
    'locked': restx_fields.Boolean(required=True, description='True to lock the account, false to unlock')
})


@users_ns.route('/user/<int:user_id>/lock')
class UserLockResource(Resource):
    @users_ns.expect(lock_model, validate=True)
    @users_ns.response(200, 'Lock state updated')
    @users_ns.response(400, 'Cannot lock your own account', error_model)
    @users_ns.response(401, 'Unauthorized - authentication required', error_model)
    @users_ns.response(403, 'Forbidden - admin role required', error_model)
    @users_ns.response(404, 'User not found', error_model)
    @users_ns.response(500, 'Internal server error', error_model)
    @users_ns.doc('lock_user', security='Bearer')
    @require_admin()
    def put(self, user_id):
        """Lock or unlock a user account (Admin only)"""
        from backend.auth import get_current_user
        try:
            current_user = get_current_user()
            if current_user.id == user_id:
                return {'msg': 'You cannot lock your own account'}, 400

            user = db.session.get(User, user_id)
            if not user:
                return {'msg': 'User not found'}, 404

            user.locked = bool(request.json.get('locked', False))
            db.session.commit()

            action = 'locked' if user.locked else 'unlocked'
            return {'msg': f'User account {action} successfully'}, 200

        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error locking/unlocking user {user_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@users_ns.route('/users')
class UsersListResource(Resource):
    @users_ns.marshal_with(users_list_model, code=200)
    @users_ns.response(400, 'Invalid parameters', error_model)
    @users_ns.response(401, 'Unauthorized - authentication required', error_model)
    @users_ns.response(403, 'Forbidden - admin role required', error_model)
    @users_ns.response(500, 'Internal server error', error_model)
    @users_ns.doc('list_users', security='Bearer', 
                  params={
                      'offset': {'description': 'Pagination offset', 'type': 'integer', 'default': 0},
                      'limit': {'description': 'Results per page (max 100)', 'type': 'integer', 'default': 50},
                      'q': {'description': 'Optional name/email search query', 'type': 'string'},
                      'locked': {'description': 'Optional locked filter (true/false)', 'type': 'boolean'}
                  })
    @require_admin()
    def get(self):
        """Get all users (Admin only)"""
        try:
            offset, limit = parse_pagination(
                request.args,
                default_limit=50,
                max_limit=100,
                error_message='Invalid offset or limit parameters',
            )
            locked_filter = parse_bool_arg(request.args, 'locked', error_message='Invalid locked parameter')
        except QueryParamError as ex:
            return {'msg': str(ex)}, 400

        search_query = get_stripped_arg(request.args, 'q')

        try:
            totals = _user_list_totals(search_query)
            users_result = db.session.execute(
                _apply_user_filters(select(User), search_query, locked_value=locked_filter)
                .order_by(User.locked.asc(), User.created_at.desc())
                .offset(offset)
                .limit(limit)
            )
            users_data = _serialize_users(users_result.scalars())

            return {
                'users': users_data,
                'offset': offset,
                'limit': limit,
                'count': len(users_data),
                'total': totals['total'],
                'all_total': totals['all_total'],
                'active_total': totals['active_total'],
                'locked_total': totals['locked_total']
            }, 200
            
        except Exception as ex:
            logging.error(f"Error encountered while trying to get users", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


