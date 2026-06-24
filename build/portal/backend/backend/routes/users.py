import logging
from datetime import datetime, timezone

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError
from werkzeug.security import generate_password_hash
from backend.models import BlogComment, db, User
from backend.auth import require_admin, require_user_or_admin, validate_role
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
        
        # Validate role if provided
        role = payload.get('role', 'User')
        if not validate_role(role):
            return {'msg': 'Invalid role. Must be Admin or User'}, 400
        
        # Set administrator field based on role for backward compatibility
        administrator = 1 if role == 'Admin' else 0
        if 'administrator' in payload:
            administrator = 1 if payload['administrator'] else 0
            role = 'Admin' if administrator == 1 else 'User'
        
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
            
            # Users can only access their own data, admins can access any
            if current_user.role != 'Admin' and current_user.id != user_id:
                return {'msg': 'Access denied. You can only access your own data'}, 403
            
            user = db.session.get(User, user_id)
            
            if not user:
                return {'msg': 'User not found'}, 404
                
            # Don't include password in response
            data = user.to_dict()
            data.pop('password', None)
            return data, 200
            
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
            
            # Users can only update their own data, admins can update any
            if current_user.role != 'Admin' and current_user.id != user_id:
                return {'msg': 'Access denied. You can only update your own data'}, 403
            
            # Update basic fields
            user.name = payload['name']
            if 'email' in payload:
                user.email = payload['email']
            if 'password' in payload:
                user.password = generate_password_hash(payload['password'])
            
            # Only admins can change roles
            if 'role' in payload and validate_role(payload['role']):
                if current_user.role == 'Admin':
                    user.role = payload['role']
                    user.administrator = 1 if payload['role'] == 'Admin' else 0
                else:
                    return {'msg': 'Only admins can change user roles'}, 403
            
            # Handle backward compatibility with administrator field
            if 'administrator' in payload and current_user.role == 'Admin':
                user.administrator = 1 if payload['administrator'] else 0
                user.role = 'Admin' if payload['administrator'] else 'User'
            
            db.session.commit()
            
            return {
                'msg': 'User updated successfully',
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email,
                    'role': user.role,
                    'administrator': user.administrator
                }
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

            # Preserve comment threads when a user is removed by soft-deleting
            # authored comments and reassigning ownership to another existing user.
            replacement_user_id = None
            if current_user and current_user.id != user_id:
                replacement_user_id = current_user.id
            else:
                replacement_user = db.session.execute(
                    select(User)
                    .where(User.id != user_id)
                    .order_by(User.id.asc())
                ).scalar_one_or_none()
                if replacement_user:
                    replacement_user_id = replacement_user.id

            authored_comments = db.session.execute(
                select(BlogComment).where(BlogComment.user_id == user_id)
            ).scalars().all()

            comments_with_replies = [comment for comment in authored_comments if comment.replies]
            comments_without_replies = [comment for comment in authored_comments if not comment.replies]

            if comments_with_replies and replacement_user_id is None:
                return {'msg': 'Cannot delete this user because no replacement user is available for authored comments'}, 400

            # Leaf comments can be removed outright.
            for comment in comments_without_replies:
                db.session.delete(comment)

            # Preserve threaded comments by soft-deleting and reassigning to a replacement user.
            for comment in comments_with_replies:
                if not comment.deleted:
                    comment.deleted = True
                    comment.deleted_at = datetime.now(timezone.utc)
                comment.user_id = replacement_user_id
                
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
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=50, type=int)
        locked_param = request.args.get('locked')
        search_query = (request.args.get('q') or '').strip()

        if offset < 0 or limit < 1 or limit > 100:
            return {'msg': 'Invalid offset or limit parameters'}, 400

        locked_filter = None
        if locked_param is not None:
            normalized_locked = locked_param.strip().lower()
            if normalized_locked not in {'true', 'false'}:
                return {'msg': 'Invalid locked parameter'}, 400
            locked_filter = normalized_locked == 'true'

        try:
            def apply_filters(statement, locked_value=None):
                filtered_statement = statement
                if search_query:
                    pattern = f"%{search_query}%"
                    filtered_statement = filtered_statement.where(
                        User.name.ilike(pattern) | User.email.ilike(pattern)
                    )
                if locked_value is not None:
                    filtered_statement = filtered_statement.where(User.locked.is_(locked_value))
                return filtered_statement

            total = db.session.execute(select(func.count()).select_from(User)).scalar()
            all_total = db.session.execute(
                apply_filters(select(func.count()).select_from(User))
            ).scalar()
            active_total = db.session.execute(
                apply_filters(select(func.count()).select_from(User), locked_value=False)
            ).scalar()
            locked_total = db.session.execute(
                apply_filters(select(func.count()).select_from(User), locked_value=True)
            ).scalar()

            users_result = db.session.execute(
                apply_filters(select(User), locked_value=locked_filter)
                .order_by(User.locked.asc(), User.created_at.desc())
                .offset(offset)
                .limit(limit)
            )
            users_data = []
            
            for user in users_result.scalars():
                user_dict = user.to_dict()
                user_dict.pop('password', None)  # Don't include passwords in response
                users_data.append(user_dict)
            
            return {
                'users': users_data,
                'offset': offset,
                'limit': limit,
                'count': len(users_data),
                'total': total,
                'all_total': all_total,
                'active_total': active_total,
                'locked_total': locked_total
            }, 200
            
        except Exception as ex:
            logging.error(f"Error encountered while trying to get users", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


