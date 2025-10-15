import os
import pytest
import tempfile

from backend import create_app
from backend.models import db

# Read and execute test data SQL (converted to SQLAlchemy operations)
with open(os.path.join(os.path.dirname(__file__), 'data.sql'), 'rb') as f:
    _data_sql = f.read().decode('utf8')

@pytest.fixture(scope="function")
def app():
    """Create and configure test app with SQLAlchemy"""
    app = create_app({
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:',
        'SQLALCHEMY_TRACK_MODIFICATIONS': False
    })

    with app.app_context():
        # Create all tables
        db.create_all()
        
        # Execute the raw SQL for test data using SQLAlchemy 2.0 syntax
        try:
            with db.engine.begin() as connection:  # Use begin() for automatic transaction management
                # Split the SQL by statements and execute them individually
                statements = [stmt.strip() for stmt in _data_sql.split(';') if stmt.strip()]
                for statement in statements:
                    if statement:  # Make sure statement is not empty
                        connection.execute(db.text(statement))

        except Exception as e:
            print(f"Error loading test data: {e}")
            # If there are issues with the raw SQL, we'll continue without test data
            pass
        
        yield app
        
        # Clean up
        db.drop_all()

@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def runner(app):
    return app.test_cli_runner()


# Helper functions for creating JWT tokens with proper application context
def create_admin_token(app=None):
    """Create admin token within proper application context"""
    from flask_jwt_extended import create_access_token
    
    if app:
        with app.app_context():
            return create_access_token(
                identity="noreply@email-one.com",
                additional_claims={'role': 'Admin', 'user_id': 1}
            )
    else:
        return create_access_token(
            identity="noreply@email-one.com",
            additional_claims={'role': 'Admin', 'user_id': 1}
        )


def create_user_token(app=None):
    """Create user token within proper application context"""
    from flask_jwt_extended import create_access_token
    
    if app:
        with app.app_context():
            return create_access_token(
                identity="noreply@email-two.com",
                additional_claims={'role': 'User', 'user_id': 2}
            )
    else:
        return create_access_token(
            identity="noreply@email-two.com",
            additional_claims={'role': 'User', 'user_id': 2}
        )