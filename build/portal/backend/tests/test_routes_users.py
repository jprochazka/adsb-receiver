from flask_jwt_extended import create_access_token

# POST /user

def test_post_user_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Four', 
            'email': 'noreply@email-four.com',
            'password': '$2y$LFLCJxrho1eGVPp9p9ygc5fuK1XWzLWS6nsWVJvJNbtZOeMVkuBJzTXG',
            'administrator': False
        }
        response = client.post('/api/user', headers=request_headers, json=request_json)
        assert response.status_code == 201

def test_post_user_401(client):
    request_json = {
        'name': 'Name Four', 
        'email': 'noreply@email-four.com',
        'password': '$2y$LFLCJxrho1eGVPp9p9ygc5fuK1XWzLWS6nsWVJvJNbtZOeMVkuBJzTXG',
        'administrator': False
    }
    response = client.post('/api/user', json=request_json)
    assert response.status_code == 401

def test_post_user_200_as_administrator(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Five', 
            'email': 'noreply@email-five.com',
            'password': '$2y$fqVywEatbLgW8p5QMiLVwyxc1fBcHw9nB7x2MEJ0QRo8QHlQccwvbW1S',
            'administrator': 1
        }
        response = client.post('/api/user', headers=request_headers, json=request_json)
        assert response.status_code == 201

def test_post_user_400_missing_name(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'email': 'noreply@email-six.com',
            'password': '$2y$NFlFTvVQGuE4KXGj4PX5ekoZ64BAcT75xHGgyi7piJ8BC37vYCnMsKHS',
            'administrator': 0
        }
        response = client.post('/api/user', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_user_400_missing_email(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Seven', 
            'password': '$2y$kLWiDakW52fH96pRHlPGFyOGL7xUD4JMcAFQvGy2HnnvBG5WzJhtCNyD',
            'administrator': 0
        }
        response = client.post('/api/user', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_user_400_missing_password(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Eight', 
            'email': 'noreply@email-eight.com',
            'administrator': 0
        }
        response = client.post('/api/user', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_user_400_missing_administrator(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Eight', 
            'email': 'noreply@email-eight.com',
            'password': '$2y$oatXHr5ov3xW0KiPimp6UB7n76Mlb8futmO4A11285zMlPqo26I3uO2V'
        }
        response = client.post('/api/user', headers=request_headers, json=request_json)
        assert response.status_code == 400

# DELETE /user/{email}

def test_delete_user_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/user/noreply@email-three.com', headers=request_headers)
        assert response.status_code == 204

def test_delete_user_401(client):
    response = client.delete('/api/user/noreply@email-three.com')
    assert response.status_code == 401

def test_delete_user_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/user/noreply@email-four.com', headers=request_headers)
        assert response.status_code == 404

# GET /user/{email}

def test_get_user_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.get('/api/user/noreply@email-one.com', headers=request_headers)
        assert response.status_code == 200
        assert response.json['id'] == 1
        assert response.json['name'] == "Name One"
        assert response.json['email'] == "noreply@email-one.com"
        assert response.json['password'] == "$2y$0htWdxS7PxTvIwJNo2COJ7Rywgif4En0TmJbDvrjLRfWZOBX526yJUKW"
        assert response.json['administrator'] == 1

def test_get_user_401(client):
    response = client.get('/api/user/noreply@email-one.com')
    assert response.status_code == 401

def test_get_user_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.get('/api/user/noreply@email-four.com', headers=request_headers)
        assert response.status_code == 404

# PUT /user/{email}

def test_put_user_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Two',
            'password': '$2y$VxTtlJcPlXFj3eHzZTAvGKHXVyHWqK12TXXdUT9SHaAXKC6l7spI7sqv',
            'administrator': 1
        }
        response = client.put('/api/user/noreply@email-two.com', headers=request_headers, json=request_json)
    assert response.status_code == 204

def test_put_user_401(client):
    request_json = {
        'name': 'Name Two',
        'password': '$2y$VxTtlJcPlXFj3eHzZTAvGKHXVyHWqK12TXXdUT9SHaAXKC6l7spI7sqv',
        'administrator': 1
    }
    response = client.put('/api/user/noreply@email-two.com', json=request_json)
    assert response.status_code == 401

def test_put_user_400_missing_name(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'password': '$2y$VxTtlJcPlXFj3eHzZTAvGKHXVyHWqK12TXXdUT9SHaAXKC6l7spI7sqv',
            'administrator': 1
        }
        response = client.put('/api/user/noreply@email-two.com', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_user_400_missing_password(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Four',
            'administrator': 1
        }
        response = client.put('/api/user/noreply@notregistered.com', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_user_400_missing_administrator(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'Name Four',
            'password': '$2y$52frWp0QeGJA9JZ0RZ0oQkBaDWcCWnJnUj759kmTWtUeWEjjNQMfzxo0'
        }
        response = client.put('/api/user/noreply@notregistered.com', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_user_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'name': 'New Eleven', 
            'password': '$2y$VKHySRyCtvds21lEnqkSgvlqe4dBLSkQX1cDd32el8IgDHTnEQahoD2P',
            'administrator': 1
        }
        response = client.put('/api/user/noreply@notregistered.com', headers=request_headers, json=request_json)
        assert response.status_code == 404

# GET /users

def test_get_users_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 0
        assert response.json['limit'] == 50
        assert response.json['count'] == 3
        assert response.json['users'][0]['id'] == 1
        assert response.json['users'][0]['name'] == "Name One"
        assert response.json['users'][0]['email'] == "noreply@email-one.com"
        assert response.json['users'][0]['password'] == "$2y$0htWdxS7PxTvIwJNo2COJ7Rywgif4En0TmJbDvrjLRfWZOBX526yJUKW"
        assert response.json['users'][0]['administrator'] == 1
        assert response.json['users'][1]['id'] == 3
        assert response.json['users'][1]['name'] == "Name Three"
        assert response.json['users'][1]['email'] == "noreply@email-three.com"
        assert response.json['users'][1]['password'] == "$2y$7jiYNNoUa1zNu6dCLxv2mIurCG8nuDgOeUCeCPO9pkjiQ1zr8jfTzdEe"
        assert response.json['users'][1]['administrator'] == 0
        assert response.json['users'][2]['id'] == 2
        assert response.json['users'][2]['name'] == "Name Two"
        assert response.json['users'][2]['email'] == "noreply@email-two.com"
        assert response.json['users'][2]['password'] == "$2y$ui7QK047JldTekx828J2rfSVQ7N5yo6ETQIYGoBqpfFRbNr3EvWzQzt6"
        assert response.json['users'][2]['administrator'] == 0

def test_get_users_401(client):
    response = client.get('/api/users')
    assert response.status_code == 401

def test_get_users_200_offset(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users?offset=2', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 2
        assert response.json['limit'] == 50
        assert response.json['count'] == 1
        assert response.json['users'][0]['id'] == 2
        assert response.json['users'][0]['name'] == "Name Two"
        assert response.json['users'][0]['email'] == "noreply@email-two.com"
        assert response.json['users'][0]['password'] == "$2y$ui7QK047JldTekx828J2rfSVQ7N5yo6ETQIYGoBqpfFRbNr3EvWzQzt6"
        assert response.json['users'][0]['administrator'] == 0

def test_get_users_200_limit(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users?limit=1', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 0
        assert response.json['limit'] == 1
        assert response.json['count'] == 1
        assert response.json['users'][0]['id'] == 1
        assert response.json['users'][0]['name'] == "Name One"
        assert response.json['users'][0]['email'] == "noreply@email-one.com"
        assert response.json['users'][0]['password'] == "$2y$0htWdxS7PxTvIwJNo2COJ7Rywgif4En0TmJbDvrjLRfWZOBX526yJUKW"
        assert response.json['users'][0]['administrator'] == 1

def test_get_users_200_offset_and_limit(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users?offset=1&limit=1', headers=request_headers)
        assert response.status_code == 200
        assert response.json['offset'] == 1
        assert response.json['limit'] == 1
        assert response.json['count'] == 1
        assert response.json['users'][0]['id'] == 3
        assert response.json['users'][0]['name'] == "Name Three"
        assert response.json['users'][0]['email'] == "noreply@email-three.com"
        assert response.json['users'][0]['password'] == "$2y$7jiYNNoUa1zNu6dCLxv2mIurCG8nuDgOeUCeCPO9pkjiQ1zr8jfTzdEe"
        assert response.json['users'][0]['administrator'] == 0

def test_get_users_400_offset_less_than_0(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users?offset=-1', headers=request_headers)
        assert response.status_code == 400

def test_get_users_400_limit_less_than_0(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users?limit=-1', headers=request_headers)
        assert response.status_code == 400

def test_get_users_400_limit_greater_than_100(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': f"Bearer {access_token}",
            'accept': 'application/json'
        }
        response = client.get('/api/users?limit=101', headers=request_headers)
        assert response.status_code == 400