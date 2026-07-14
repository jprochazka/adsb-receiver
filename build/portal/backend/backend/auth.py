"""
Authentication and authorization utilities for role-based JWT authentication.
"""

from functools import wraps
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
from backend.models import db, User
from sqlalchemy import select

def get_current_user():
    """Get the current authenticated user from JWT token"""
    try:
        verify_jwt_in_request()
        current_user_email = get_jwt_identity()
        user = db.session.execute(select(User).filter_by(email=current_user_email)).scalar_one_or_none()
        return user
    except Exception:
        return None


def validate_current_user(required_role=None):
    """Validate the JWT and return the current unlocked database user."""
    verify_jwt_in_request()
    current_user_email = get_jwt_identity()
    current_user = db.session.execute(
        select(User).filter_by(email=current_user_email)
    ).scalar_one_or_none()

    if not current_user:
        return None, ({'msg': 'User not found'}, 401)
    if current_user.locked:
        return None, ({'msg': 'Account is locked'}, 403)
    if current_user.role not in ['User', 'Admin']:
        return None, ({'msg': 'User or Admin access required'}, 403)
    if required_role == 'Admin' and not current_user.is_admin():
        return None, ({'msg': 'Admin access required'}, 403)
    if required_role and required_role not in ['Admin', current_user.role]:
        return None, ({'msg': f'Access denied. {required_role} role required'}, 403)

    return current_user, None

def require_role(required_role):
    """
    Decorator to require a specific role for accessing an endpoint.
    Roles: 'Admin', 'User'
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            try:
                _, auth_error = validate_current_user(required_role)
                if auth_error:
                    return auth_error
            except Exception:
                return {'msg': 'Invalid token'}, 401
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator

def require_admin():
    """Decorator to require Admin role"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            try:
                _, auth_error = validate_current_user('Admin')
                if auth_error:
                    return auth_error
            except Exception as e:
                from werkzeug.exceptions import HTTPException
                if isinstance(e, HTTPException):
                    raise e
                return {'msg': 'Invalid token'}, 401
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator

def require_user_or_admin():
    """Decorator to require User or Admin role (any authenticated user)"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            try:
                _, auth_error = validate_current_user()
                if auth_error:
                    return auth_error
            except Exception as e:
                from werkzeug.exceptions import HTTPException
                if isinstance(e, HTTPException):
                    raise e
                return {'msg': 'Invalid token'}, 401
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator

def create_token_identity(user):
    """Create token identity with user info"""
    return {
        'email': user.email,
        'role': user.role,
        'user_id': user.id
    }

def validate_role(role):
    """Validate that a role is one of the allowed values"""
    allowed_roles = ['Admin', 'User']
    return role in allowed_roles