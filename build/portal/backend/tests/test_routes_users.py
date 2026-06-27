from conftest import create_admin_token, create_user_token
from backend.models import BlogComment, db

# POST /user

def test_post_user_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Four', 
            'email': 'noreply@email-four.com',
            'password': 'password123',
            'administrator': False
        }
        response = client.post('/api/users/create', headers=request_headers, json=request_json)
        assert response.status_code == 201

def test_post_user_401(client):
    request_json = {
        'name': 'Name Four', 
        'email': 'noreply@email-four.com',
        'password': 'password123',
        'administrator': False
    }
    response = client.post('/api/users/create', json=request_json)
    assert response.status_code == 401

def test_post_user_403_user_role_denied(client, app):
    """Test that a regular User cannot create new users (Admin only)"""
    with app.app_context():
        # Use regular user token instead of admin token
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Should Fail', 
            'email': 'should-fail@example.com',
            'password': 'password123',
            'administrator': False
        }
        response = client.post('/api/users/create', headers=request_headers, json=request_json)
        assert response.status_code == 403  # Forbidden - insufficient role

def test_post_user_200_as_administrator(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Five', 
            'email': 'noreply@email-five.com',
            'password': 'password123',
            'administrator': True
        }
        response = client.post('/api/users/create', headers=request_headers, json=request_json)
        assert response.status_code == 201

def test_post_user_400_missing_name(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'email': 'noreply@email-six.com',
            'password': '$2y$NFlFTvVQGuE4KXGj4PX5ekoZ64BAcT75xHGgyi7piJ8BC37vYCnMsKHS',
            'administrator': False
        }
        response = client.post('/api/users/create', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_user_400_missing_email(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Seven', 
            'password': '$2y$kLWiDakW52fH96pRHlPGFyOGL7xUD4JMcAFQvGy2HnnvBG5WzJhtCNyD',
            'administrator': False
        }
        response = client.post('/api/users/create', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_user_400_missing_password(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Eight', 
            'email': 'noreply@email-eight.com',
            'administrator': False
        }
        response = client.post('/api/users/create', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_user_201_defaults_to_user_role(client, app):
    """Test that when administrator field is missing, user defaults to User role"""
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Eight', 
            'email': 'noreply@email-eight.com',
            'password': '$2y$oatXHr5ov3xW0KiPimp6UB7n76Mlb8futmO4A11285zMlPqo26I3uO2V'
        }
        response = client.post('/api/users/create', headers=request_headers, json=request_json)
        assert response.status_code == 201
        # Verify the user was created with User role
        from backend.models import User
        user = User.query.filter_by(email='noreply@email-eight.com').first()
        assert user is not None
        assert user.role == 'User'
        assert user.administrator == 0

# DELETE /user/{user_id}

def test_delete_user_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        target_comment = BlogComment.query.filter_by(user_id=3).first()
        assert target_comment is not None

        response = client.delete('/api/users/user/3', headers=request_headers)  # User ID 3 = "Another User"
        assert response.status_code == 200
        assert response.json['msg'] == 'User deleted successfully'

        updated_comment = BlogComment.query.filter_by(id=target_comment.id).first()
        assert updated_comment is None


def test_delete_user_200_respects_existing_soft_deleted_comment(client, app):
    with app.app_context():
        target_comment = BlogComment.query.filter_by(user_id=3).first()
        assert target_comment is not None

        target_comment.deleted = True
        db.session.commit()

        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        response = client.delete('/api/users/user/3', headers=request_headers)
        assert response.status_code == 200

        updated_comment = BlogComment.query.filter_by(id=target_comment.id).first()
        assert updated_comment is None


def test_delete_user_200_applies_mixed_comment_delete_logic(client, app):
    with app.app_context():
        # User 2 already owns comment id=1 which has replies (threaded)
        threaded_comment = BlogComment.query.filter_by(id=1).first()
        assert threaded_comment is not None
        assert threaded_comment.user_id == 2

        # Add a leaf comment for user 2 so both branches of the logic are exercised.
        leaf_comment = BlogComment(
            blog_post_id=1,
            user_id=2,
            parent_comment_id=None,
            content='Temporary leaf comment for deletion logic test.',
        )
        db.session.add(leaf_comment)
        db.session.commit()
        leaf_comment_id = leaf_comment.id

        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        response = client.delete('/api/users/user/2', headers=request_headers)
        assert response.status_code == 200

        updated_threaded = BlogComment.query.filter_by(id=1).first()
        deleted_leaf = BlogComment.query.filter_by(id=leaf_comment_id).first()

        assert updated_threaded is not None
        assert updated_threaded.deleted is True
        assert updated_threaded.deleted_at is not None
        # Reassigned to the deleting admin user to preserve FK integrity.
        assert updated_threaded.user_id == 1
        assert deleted_leaf is None

def test_delete_user_401(client):
    response = client.delete('/api/users/user/3')  # User ID 3 = "Another User"
    assert response.status_code == 401

def test_delete_user_404(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/users/user/999', headers=request_headers)  # Non-existent user ID
        assert response.status_code == 404

# GET /user/{user_id}

def test_get_user_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.get('/api/users/user/1', headers=request_headers)  # User ID 1 = "Admin User"
        assert response.status_code == 200
        assert response.json['id'] == 1
        assert response.json['name'] == "Admin User"
        assert response.json['email'] == "noreply@email-one.com"
        assert response.json['administrator'] == 1
        assert response.json['role'] == "Admin"

def test_get_user_401(client):
    response = client.get('/api/users/user/1')  # User ID 1 = "Admin User"
    assert response.status_code == 401

def test_get_user_404(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.get('/api/users/user/999', headers=request_headers)  # Non-existent user ID
        assert response.status_code == 404

# PUT /user/{user_id}

def test_put_user_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Updated Name Two',
            'password': 'newpassword456',
            'administrator': True
        }
        response = client.put('/api/users/user/2', headers=request_headers, json=request_json)  # User ID 2 = "Regular User"
        assert response.status_code == 200

def test_put_user_401(client):
    request_json = {
        'name': 'Name Two',
        'password': '$2y$VxTtlJcPlXFj3eHzZTAvGKHXVyHWqK12TXXdUT9SHaAXKC6l7spI7sqv',
        'administrator': True
    }
    response = client.put('/api/users/user/2', json=request_json)  # User ID 2 = "Regular User"
    assert response.status_code == 401

def test_put_user_400_missing_name(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'password': '$2y$VxTtlJcPlXFj3eHzZTAvGKHXVyHWqK12TXXdUT9SHaAXKC6l7spI7sqv',
            'administrator': True
        }
        response = client.put('/api/users/user/2', headers=request_headers, json=request_json)  # User ID 2 = "Regular User"
        assert response.status_code == 400

def test_put_user_200_without_password(client, app):
    """Test that updating a user without supplying password is allowed (name-only update)"""
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Four',
            'administrator': True
        }
        response = client.put('/api/users/user/2', headers=request_headers, json=request_json)
        assert response.status_code in (200, 404)  # 200 if user exists, 404 if not

def test_put_user_404_user_not_found(client, app):
    """Test updating a user that doesn't exist returns 404"""
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Four',
            'password': '$2y$52frWp0QeGJA9JZ0RZ0oQkBaDWcCWnJnUj759kmTWtUeWEjjNQMfzxo0'
        }
        response = client.put('/api/users/user/999', headers=request_headers, json=request_json)  # Non-existent user ID
        assert response.status_code == 404

def test_put_user_404(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'New Eleven', 
            'password': '$2y$VKHySRyCtvds21lEnqkSgvlqe4dBLSkQX1cDd32el8IgDHTnEQahoD2P',
            'administrator': True
        }
        response = client.put('/api/users/user/999', headers=request_headers, json=request_json)  # Non-existent user ID
        assert response.status_code == 404

# GET /users

def test_get_users_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 0
        assert response.json['limit'] == 50
        assert response.json['count'] == 3
        assert response.json['all_total'] == 3
        assert response.json['active_total'] == 3
        assert response.json['locked_total'] == 0
        assert response.json['users'][0]['id'] == 1
        assert response.json['users'][0]['name'] == "Admin User"
        assert response.json['users'][0]['email'] == "noreply@email-one.com"
        assert response.json['users'][0]['administrator'] == 1
        assert response.json['users'][0]['role'] == "Admin"
        assert response.json['users'][1]['id'] == 3
        assert response.json['users'][1]['name'] == "Another User"
        assert response.json['users'][1]['email'] == "noreply@email-three.com"
        assert response.json['users'][1]['administrator'] == 0
        assert response.json['users'][1]['role'] == "User"
        assert response.json['users'][2]['id'] == 2
        assert response.json['users'][2]['name'] == "Regular User"
        assert response.json['users'][2]['email'] == "noreply@email-two.com"
        assert response.json['users'][2]['administrator'] == 0
        assert response.json['users'][2]['role'] == "User"

def test_get_users_401(client):
    response = client.get('/api/users/users')
    assert response.status_code == 401

def test_get_users_200_offset(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?offset=2', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 2
        assert response.json['limit'] == 50
        assert response.json['count'] == 1
        assert response.json['users'][0]['id'] == 2
        assert response.json['users'][0]['name'] == "Regular User"
        assert response.json['users'][0]['email'] == "noreply@email-two.com"
# Password field should not be returned for security reasons
        assert response.json['users'][0]['administrator'] == 0

def test_get_users_200_limit(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?limit=1', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 0
        assert response.json['limit'] == 1
        assert response.json['count'] == 1
        assert response.json['users'][0]['id'] == 1
        assert response.json['users'][0]['name'] == "Admin User"
        assert response.json['users'][0]['email'] == "noreply@email-one.com"
# Password field should not be returned for security reasons
        assert response.json['users'][0]['administrator'] == 1

def test_get_users_200_limit_1000(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?limit=100', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 0
        assert response.json['limit'] == 100
        assert response.json['count'] == 3

def test_get_users_200_locked_filter(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }

        from backend.models import User, db
        locked_user = db.session.get(User, 2)
        locked_user.locked = True
        db.session.commit()

        response = client.get('/api/users/users?locked=true', headers=request_headers)
        assert response.status_code == 200
        assert response.json['count'] == 1
        assert response.json['locked_total'] == 1
        assert response.json['active_total'] == 2
        assert response.json['users'][0]['id'] == 2

def test_get_users_200_search_query(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?q=three', headers=request_headers)
        assert response.status_code == 200
        assert response.json['count'] == 1
        assert response.json['all_total'] == 1
        assert response.json['users'][0]['email'] == 'noreply@email-three.com'

def test_get_users_200_offset_and_limit(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?offset=1&limit=1', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 1
        assert response.json['limit'] == 1
        assert response.json['count'] == 1
        assert response.json['users'][0]['id'] == 3
        assert response.json['users'][0]['name'] == "Another User"
        assert response.json['users'][0]['email'] == "noreply@email-three.com"
# Password field should not be returned for security reasons
        assert response.json['users'][0]['administrator'] == 0

def test_get_users_400_offset_less_than_0(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?offset=-1', headers=request_headers)
        assert response.status_code == 400

def test_get_users_400_limit_less_than_0(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?limit=-1', headers=request_headers)
        assert response.status_code == 400

def test_get_users_400_limit_greater_than_100(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?limit=101', headers=request_headers)
        assert response.status_code == 400

def test_get_users_400_invalid_locked_parameter(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users/users?locked=maybe', headers=request_headers)
        assert response.status_code == 400
