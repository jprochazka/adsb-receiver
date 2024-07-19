from flask_jwt_extended import create_access_token

# POST /blog/post

def test_post_blog_post_200(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'title': 'Title Five',
            'author': 'User Two',
            'content': 'Content for blog post five.'
        }
        response = client.post('/api/blog/post', headers=request_headers, json=request_json)
        assert response.status_code == 201

def test_post_blog_post_401(client):
    request_json = {
        'title': 'Title Five',
        'author': 'User Two',
        'content': 'Content for blog post five.'
    }
    response = client.post('/api/blog/post', json=request_json)
    assert response.status_code == 401

def test_post_blog_post_400_missing_title(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'author': 'User Two',
            'content': 'Content for blog post five.'
        }
        response = client.post('/api/blog/post', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_blog_post_400_missing_author(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'title': 'Title Five',
            'content': 'Content for blog post five.'
        }
        response = client.post('/api/blog/post', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_post_blog_post_400_missing_content(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'title': 'Title Five',
            'author': 'User Two',
        }
        response = client.post('/api/blog/post', headers=request_headers, json=request_json)
        assert response.status_code == 400

# DELETE /blog/post/{id}

def test_delete_blog_post_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/blog/post/2', headers=request_headers)
        assert response.status_code == 204

def test_delete_blog_post_401(client):
        response = client.delete('/api/blog/post/2')
        assert response.status_code == 401

def test_delete_blog_post_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/blog/post/5', headers=request_headers)
        assert response.status_code == 404

# GET /blog/post/{id}

def test_get_blog_post_200(client):
    response = client.get('/api/blog/post/3')
    assert response.status_code == 200
    assert response.json['id'] == 3
    assert response.json['title'] == "Title Three"
    assert response.json['date'] == "2024-07-05 15:00:03"
    assert response.json['author'] == "User Three"
    assert response.json['content'] == "Content for blog post three."

def test_get_blog_post_404(client):
    response = client.get('/api/blog/post/5')
    assert response.status_code == 404

# PUT /blog/post/{id}

def test_put_blog_post_204(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'title': 'Updated Title One',
            'content': 'Updated content for blog post one.'
        }
        response = client.put('/api/blog/post/1', headers=request_headers, json=request_json)
    assert response.status_code == 204

def test_put_blog_post_401(client):
    request_json = {
        'title': 'Updated Title One',
        'content': 'Updated content for blog post one.'
    }
    response = client.put('/api/blog/post/1', json=request_json)
    assert response.status_code == 401

def test_put_blog_post_400_missing_title(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'Updated content for blog post one.'
        }
        response = client.put('/api/blog/post/1', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_blog_post_400_missing_content(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'title': 'Updated Title One'
        }
        response = client.put('/api/blog/post/1', headers=request_headers, json=request_json)
        assert response.status_code == 400

def test_put_blog_post_404(client, app):
    with app.app_context():
        access_token = create_access_token(identity="developer")
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'title': 'Updated Title five', 
            'content': 'Updated content for blog post five.'
        }
        response = client.put('/api/blog/post/5', headers=request_headers, json=request_json)
        assert response.status_code == 404

# GET /blog/posts

def test_get_blog_post_200(client):
    response = client.get('/api/blog/posts')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 25
    assert response.json['count'] == 4
    assert response.json['blog_posts'][0]['id'] == 4
    assert response.json['blog_posts'][0]['title'] == "Title Four"
    assert response.json['blog_posts'][0]['date'] == "2024-07-06 16:30:04"
    assert response.json['blog_posts'][0]['author'] == "User Two"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post four."
    assert response.json['blog_posts'][1]['id'] == 3
    assert response.json['blog_posts'][1]['title'] == "Title Three"
    assert response.json['blog_posts'][1]['date'] == "2024-07-05 15:00:03"
    assert response.json['blog_posts'][1]['author'] == "User Three"
    assert response.json['blog_posts'][1]['content'] == "Content for blog post three."
    assert response.json['blog_posts'][2]['id'] == 2
    assert response.json['blog_posts'][2]['title'] == "Title Two"
    assert response.json['blog_posts'][2]['date'] == "2024-07-04 14:30:02"
    assert response.json['blog_posts'][2]['author'] == "User One"
    assert response.json['blog_posts'][2]['content'] == "Content for blog post two."
    assert response.json['blog_posts'][3]['id'] == 1
    assert response.json['blog_posts'][3]['title'] == "Title One"
    assert response.json['blog_posts'][3]['date'] == "2024-07-03 13:00:01"
    assert response.json['blog_posts'][3]['author'] == "User One"
    assert response.json['blog_posts'][3]['content'] == "Content for blog post one."

def test_get_blog_post_200_offset(client):
    response = client.get('/api/blog/posts?offset=2')
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 25
    assert response.json['count'] == 2
    assert response.json['blog_posts'][0]['id'] == 2
    assert response.json['blog_posts'][0]['title'] == "Title Two"
    assert response.json['blog_posts'][0]['date'] == "2024-07-04 14:30:02"
    assert response.json['blog_posts'][0]['author'] == "User One"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post two."
    assert response.json['blog_posts'][1]['id'] == 1
    assert response.json['blog_posts'][1]['title'] == "Title One"
    assert response.json['blog_posts'][1]['date'] == "2024-07-03 13:00:01"
    assert response.json['blog_posts'][1]['author'] == "User One"
    assert response.json['blog_posts'][1]['content'] == "Content for blog post one."


def test_get_blog_post_200_limit(client):
    response = client.get('/api/blog/posts?limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['blog_posts'][0]['id'] == 4
    assert response.json['blog_posts'][0]['title'] == "Title Four"
    assert response.json['blog_posts'][0]['date'] == "2024-07-06 16:30:04"
    assert response.json['blog_posts'][0]['author'] == "User Two"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post four."

def test_get_blog_post_200_offset_and_limit(client):
    response = client.get('/api/blog/posts?offset=1&limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['blog_posts'][0]['id'] == 3
    assert response.json['blog_posts'][0]['title'] == "Title Three"
    assert response.json['blog_posts'][0]['date'] == "2024-07-05 15:00:03"
    assert response.json['blog_posts'][0]['author'] == "User Three"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post three."

def test_get_blog_post_400_offset_less_than_0(client):
    response = client.get('/api/blog/posts?offset=-1')
    assert response.status_code == 400

def test_get_blog_post_400_limit_less_than_0(client):
    response = client.get('/api/blog/posts?limit=-1')
    assert response.status_code == 400

def test_get_blog_post_400_limit_greater_than_100(client):
    response = client.get('/api/blog/posts?limit=101')
    assert response.status_code == 400