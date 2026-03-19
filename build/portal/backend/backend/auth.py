"""
Authentication and authorization utilities for role-based JWT authentication.
"""

from functools import wraps
from flask import jsonify
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request, get_jwt
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

def require_role(required_role):
    """
    Decorator to require a specific role for accessing an endpoint.
    Roles: 'Admin', 'User'
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            try:
                verify_jwt_in_request()
                current_user = get_current_user()
                
                if not current_user:
                    return {'msg': 'User not found'}, 401
                
                if current_user.role != required_role and current_user.role != 'Admin':
                    return {'msg': f'Access denied. {required_role} role required'}, 403
            except Exception as e:
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
                verify_jwt_in_request()
                current_user = get_current_user()
                
                if not current_user:
                    return {'msg': 'User not found'}, 401
                
                if not current_user.is_admin():
                    return {'msg': 'Admin access required'}, 403
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
                verify_jwt_in_request()
                current_user = get_current_user()
                
                if not current_user:
                    return {'msg': 'User not found'}, 401
                
                if current_user.role not in ['User', 'Admin']:
                    return {'msg': 'User or Admin access required'}, 403
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