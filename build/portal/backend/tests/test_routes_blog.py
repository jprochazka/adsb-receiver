from tests.conftest import create_admin_token, create_another_user_token, create_user_token
from backend.models import BlogComment, db, User

# POST /blog/post

def test_post_blog_post_200(client, app):
    with app.app_context():
        access_token = create_admin_token()
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
        access_token = create_admin_token()
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
        access_token = create_admin_token()
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
        access_token = create_admin_token()
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
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/blog/post/2', headers=request_headers)
        assert response.status_code == 204


def test_delete_blog_post_204_removes_related_comments(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        assert db.session.query(BlogComment).filter_by(blog_post_id=1).count() == 3

        response = client.delete('/api/blog/post/1', headers=request_headers)

        assert response.status_code == 204
        assert db.session.query(BlogComment).filter_by(blog_post_id=1).count() == 0

def test_delete_blog_post_401(client):
        response = client.delete('/api/blog/post/2')
        assert response.status_code == 401

def test_delete_blog_post_404(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        response = client.delete('/api/blog/post/11', headers=request_headers)
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
    response = client.get('/api/blog/post/11')
    assert response.status_code == 404

# PUT /blog/post/{id}

def test_put_blog_post_204(client, app):
    with app.app_context():
        access_token = create_admin_token()
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
        access_token = create_admin_token()
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
        access_token = create_admin_token()
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
        access_token = create_admin_token(app)
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'title': 'Updated Title Eleven',
            'content': 'Updated content for blog post eleven.'
        }
        response = client.put('/api/blog/post/11', headers=request_headers, json=request_json)
        assert response.status_code == 404

# GET /blog/posts

def test_get_blog_posts_200(client):
    response = client.get('/api/blog/posts')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 25
    assert response.json['count'] == 10
    assert response.json['blog_posts'][0]['id'] == 10
    assert response.json['blog_posts'][0]['title'] == "Title Ten"
    assert response.json['blog_posts'][0]['date'] == "2024-07-12 14:00:00"
    assert response.json['blog_posts'][0]['author'] == "User Three"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post ten."
    assert response.json['blog_posts'][1]['id'] == 9
    assert response.json['blog_posts'][1]['title'] == "Title Nine"
    assert response.json['blog_posts'][1]['date'] == "2024-07-11 13:00:00"
    assert response.json['blog_posts'][1]['author'] == "User Two"
    assert response.json['blog_posts'][1]['content'] == "Content for blog post nine."
    assert response.json['blog_posts'][2]['id'] == 8
    assert response.json['blog_posts'][2]['title'] == "Title Eight"
    assert response.json['blog_posts'][2]['date'] == "2024-07-10 12:00:00"
    assert response.json['blog_posts'][2]['author'] == "User One"
    assert response.json['blog_posts'][2]['content'] == "Content for blog post eight."
    assert response.json['blog_posts'][3]['id'] == 7
    assert response.json['blog_posts'][3]['title'] == "Title Seven"
    assert response.json['blog_posts'][3]['date'] == "2024-07-09 11:00:00"
    assert response.json['blog_posts'][3]['author'] == "User Three"
    assert response.json['blog_posts'][3]['content'] == "Content for blog post seven."

def test_get_blog_posts_200_offset(client):
    response = client.get('/api/blog/posts?offset=2')
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 25
    assert response.json['count'] == 8
    assert response.json['blog_posts'][0]['id'] == 8
    assert response.json['blog_posts'][0]['title'] == "Title Eight"
    assert response.json['blog_posts'][0]['date'] == "2024-07-10 12:00:00"
    assert response.json['blog_posts'][0]['author'] == "User One"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post eight."
    assert response.json['blog_posts'][1]['id'] == 7
    assert response.json['blog_posts'][1]['title'] == "Title Seven"
    assert response.json['blog_posts'][1]['date'] == "2024-07-09 11:00:00"
    assert response.json['blog_posts'][1]['author'] == "User Three"
    assert response.json['blog_posts'][1]['content'] == "Content for blog post seven."


def test_get_blog_posts_200_limit(client):
    response = client.get('/api/blog/posts?limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['blog_posts'][0]['id'] == 10
    assert response.json['blog_posts'][0]['title'] == "Title Ten"
    assert response.json['blog_posts'][0]['date'] == "2024-07-12 14:00:00"
    assert response.json['blog_posts'][0]['author'] == "User Three"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post ten."

def test_get_blog_posts_200_offset_and_limit(client):
    response = client.get('/api/blog/posts?offset=1&limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['blog_posts'][0]['id'] == 9
    assert response.json['blog_posts'][0]['title'] == "Title Nine"
    assert response.json['blog_posts'][0]['date'] == "2024-07-11 13:00:00"
    assert response.json['blog_posts'][0]['author'] == "User Two"
    assert response.json['blog_posts'][0]['content'] == "Content for blog post nine."

def test_get_blog_posts_400_offset_less_than_0(client):
    response = client.get('/api/blog/posts?offset=-1')
    assert response.status_code == 400

def test_get_blog_posts_400_limit_less_than_0(client):
    response = client.get('/api/blog/posts?limit=-1')
    assert response.status_code == 400

def test_get_blog_posts_400_limit_greater_than_100(client):
    response = client.get('/api/blog/posts?limit=101')
    assert response.status_code == 400

# GET /blog/posts?category=

def test_get_blog_posts_200_filter_by_category(client):
    response = client.get('/api/blog/posts?category=News')
    assert response.status_code == 200
    assert response.json['count'] == 3
    assert response.json['total'] == 3
    titles = [p['title'] for p in response.json['blog_posts']]
    assert titles == ['Title Nine', 'Title Five', 'Title One']

def test_get_blog_posts_200_filter_by_category_only_returns_matching(client):
    response = client.get('/api/blog/posts?category=Maintenance')
    assert response.status_code == 200
    for post in response.json['blog_posts']:
        assert post['category'] == 'Maintenance'

def test_get_blog_posts_200_filter_by_category_empty_result(client):
    response = client.get('/api/blog/posts?category=NonExistent')
    assert response.status_code == 200
    assert response.json['count'] == 0
    assert response.json['total'] == 0
    assert response.json['blog_posts'] == []

# GET /blog/posts?tag=

def test_get_blog_posts_200_filter_by_tag(client):
    response = client.get('/api/blog/posts?tag=portal')
    assert response.status_code == 200
    assert response.json['count'] == 5
    assert response.json['total'] == 5
    titles = [p['title'] for p in response.json['blog_posts']]
    assert titles == ['Title Ten', 'Title Eight', 'Title Seven', 'Title Four', 'Title Three']

def test_get_blog_posts_200_filter_by_tag_only_returns_matching(client):
    response = client.get('/api/blog/posts?tag=receiver')
    assert response.status_code == 200
    assert response.json['count'] == 6
    for post in response.json['blog_posts']:
        assert 'receiver' in post['tags']

def test_get_blog_posts_200_filter_by_tag_empty_result(client):
    response = client.get('/api/blog/posts?tag=nonexistenttag')
    assert response.status_code == 200
    assert response.json['count'] == 0
    assert response.json['total'] == 0
    assert response.json['blog_posts'] == []

# GET /blog/posts?category=&tag=

def test_get_blog_posts_200_filter_by_category_and_tag(client):
    response = client.get('/api/blog/posts?category=News&tag=receiver')
    assert response.status_code == 200
    assert response.json['count'] == 3
    titles = [p['title'] for p in response.json['blog_posts']]
    assert titles == ['Title Nine', 'Title Five', 'Title One']
    for post in response.json['blog_posts']:
        assert post['category'] == 'News'
        assert 'receiver' in post['tags']

def test_get_blog_posts_200_filter_by_category_and_tag_no_match(client):
    response = client.get('/api/blog/posts?category=News&tag=portal')
    assert response.status_code == 200
    assert response.json['count'] == 0
    assert response.json['blog_posts'] == []

# GET /blog/posts/meta

def test_get_blog_posts_meta_200(client):
    response = client.get('/api/blog/posts/meta')
    assert response.status_code == 200
    assert 'tags' in response.json
    assert 'categories' in response.json
    assert response.json['total_posts'] == 10

    tags = {item['name']: item['count'] for item in response.json['tags']}
    categories = {item['name']: item['count'] for item in response.json['categories']}

    assert tags['receiver'] == 6
    assert tags['portal'] == 5
    assert categories['Maintenance'] == 2
    assert categories['Announcements'] == 2
    # Uncategorized only appears when posts actually lack a category
    assert 'Uncategorized' not in categories


def test_get_blog_posts_meta_includes_uncategorized_with_count_when_posts_have_no_category(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
        # Create a post with no category
        client.post('/api/blog/post', headers=request_headers, json={
            'title': 'No Category Post',
            'author': 'User One',
            'content': 'This post has no category.',
        })
    response = client.get('/api/blog/posts/meta')
    categories = {item['name']: item['count'] for item in response.json['categories']}
    assert 'Uncategorized' in categories
    assert categories['Uncategorized'] >= 1


def test_get_blog_posts_filter_by_uncategorized(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
        client.post('/api/blog/post', headers=request_headers, json={
            'title': 'Uncategorized Post',
            'author': 'User One',
            'content': 'No category given.',
        })
    response = client.get('/api/blog/posts?category=Uncategorized')
    assert response.status_code == 200
    assert response.json['count'] >= 1
    for post in response.json['blog_posts']:
        assert post['category'] == 'Uncategorized'


def test_post_blog_post_defaults_to_uncategorized_when_no_category(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
        response = client.post('/api/blog/post', headers=request_headers, json={
            'title': 'Default Category Post',
            'author': 'User One',
            'content': 'Content here.',
        })
        assert response.status_code == 201
        post_id = response.json['id']
    post_response = client.get(f'/api/blog/post/{post_id}')
    assert post_response.json['category'] == 'Uncategorized'


def test_get_blog_post_comments_200(client):
    response = client.get('/api/blog/post/1/comments')

    assert response.status_code == 200
    assert response.json['blog_post_id'] == 1
    assert response.json['count'] == 2
    assert response.json['comments'][0]['content'] == 'First top-level comment.'
    assert response.json['comments'][0]['user']['name'] is not None
    assert 'email' not in response.json['comments'][0]['user']
    assert response.json['comments'][0]['replies'][0]['content'] == 'Reply to the first comment.'
    assert response.json['comments'][0]['replies'][0]['parent_comment_id'] == 1
    assert response.json['comments'][1]['content'] == 'Second top-level comment.'
    assert response.json['comments'][1]['replies'] == []


def test_get_blog_post_comments_200_unauthenticated(client):
    """GET /blog/post/{id}/comments is publicly accessible with no authentication.
    User email addresses must not be present in the response."""
    response = client.get('/api/blog/post/1/comments')
    assert response.status_code == 200
    assert 'comments' in response.json
    assert len(response.json['comments']) > 0
    first_comment = response.json['comments'][0]
    assert 'user' in first_comment
    assert 'email' not in first_comment['user']
    assert 'name' in first_comment['user']


def test_get_blog_post_comments_200_deleted_comment_is_anonymized(client, app):
    with app.app_context():
        comment = db.session.get(BlogComment, 1)
        comment.deleted = True
        db.session.commit()

    response = client.get('/api/blog/post/1/comments', headers=None)

    assert response.status_code == 200
    assert response.json['comments'][0]['content'] == '[deleted]'
    assert response.json['comments'][0]['deleted'] is True
    assert response.json['comments'][0]['user_id'] is None
    assert response.json['comments'][0]['user']['id'] is None
    assert response.json['comments'][0]['user']['name'] is None
    assert 'email' not in response.json['comments'][0]['user']
    assert response.json['comments'][0]['replies'][0]['content'] == 'Reply to the first comment.'


# POST /blog/post/{id}/comments

def test_post_blog_comment_201(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'New top-level comment from a user.'
        }

    response = client.post('/api/blog/post/2/comments', headers=request_headers, json=request_json)

    assert response.status_code == 201
    assert response.json['blog_post_id'] == 2
    assert response.json['parent_comment_id'] is None
    assert response.json['content'] == 'New top-level comment from a user.'
    assert response.json['user']['name'] is not None
    assert 'email' not in response.json['user']
    assert response.json['replies'] == []


def test_post_blog_comment_reply_201(client, app):
    with app.app_context():
        access_token = create_another_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'Nested reply from another user.',
            'parent_comment_id': 1,
        }

    response = client.post('/api/blog/post/1/comments', headers=request_headers, json=request_json)

    assert response.status_code == 201
    assert response.json['blog_post_id'] == 1
    assert response.json['parent_comment_id'] == 1
    assert response.json['content'] == 'Nested reply from another user.'
    assert response.json['user']['name'] is not None
    assert 'email' not in response.json['user']


def test_post_blog_comment_400_invalid_parent(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'Reply with wrong parent.',
            'parent_comment_id': 999,
        }

    response = client.post('/api/blog/post/1/comments', headers=request_headers, json=request_json)
    assert response.status_code == 400
    assert response.json['msg'] == 'Parent comment not found for this blog post'


def test_post_blog_comment_403_locked_user(client, app):
    with app.app_context():
        access_token = create_user_token()
        user = db.session.get(User, 2)
        user.locked = True
        db.session.commit()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'This should be rejected.'
        }

    response = client.post('/api/blog/post/1/comments', headers=request_headers, json=request_json)
    assert response.status_code == 403
    assert response.json['msg'] == 'Account is locked'


# PUT /blog/post/{id}/comments/{comment_id}

def test_put_blog_comment_200_marks_comment_edited(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'Updated first top-level comment.'
        }

    response = client.put('/api/blog/post/1/comments/1', headers=request_headers, json=request_json)

    assert response.status_code == 200
    assert response.json['id'] == 1
    assert response.json['content'] == 'Updated first top-level comment.'
    assert response.json['edited'] is True
    assert response.json['edited_at'] is not None
    assert 'email' not in response.json['user']


def test_put_blog_comment_403_for_other_user(client, app):
    with app.app_context():
        access_token = create_another_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'Trying to edit somebody else comment.'
        }

    response = client.put('/api/blog/post/1/comments/1', headers=request_headers, json=request_json)
    assert response.status_code == 403
    assert response.json['msg'] == 'Access denied. You can only edit your own comments'


def test_put_blog_comment_403_locked_user(client, app):
    with app.app_context():
        access_token = create_user_token()
        user = db.session.get(User, 2)
        user.locked = True
        db.session.commit()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'This edit should be rejected.'
        }

    response = client.put('/api/blog/post/1/comments/1', headers=request_headers, json=request_json)
    assert response.status_code == 403
    assert response.json['msg'] == 'Account is locked'


def test_put_blog_comment_404_when_comment_not_on_blog_post(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'Updated content.'
        }

    response = client.put('/api/blog/post/2/comments/1', headers=request_headers, json=request_json)
    assert response.status_code == 404
    assert response.json['msg'] == 'Comment not found for this blog post'


def test_put_blog_comment_400_deleted_comment_cannot_be_edited(client, app):
    with app.app_context():
        comment = db.session.get(BlogComment, 1)
        comment.deleted = True
        db.session.commit()

        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }
        request_json = {
            'content': 'Attempting to edit a deleted comment.'
        }

    response = client.put('/api/blog/post/1/comments/1', headers=request_headers, json=request_json)
    assert response.status_code == 400
    assert response.json['msg'] == 'Deleted comments cannot be edited'


# DELETE /blog/post/{id}/comments/{comment_id}

def test_delete_blog_comment_204_owner_soft_deletes_comment(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        assert db.session.get(BlogComment, 1) is not None
        assert db.session.get(BlogComment, 2) is not None

        response = client.delete('/api/blog/post/1/comments/1', headers=request_headers)

        assert response.status_code == 204
        deleted_comment = db.session.get(BlogComment, 1)
        reply_comment = db.session.get(BlogComment, 2)

        assert deleted_comment is not None
        assert deleted_comment.deleted is True
        assert deleted_comment.deleted_at is not None
        assert reply_comment is not None


def test_delete_blog_comment_204_admin_hard_deletes_leaf_comment(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        response = client.delete('/api/blog/post/1/comments/3', headers=request_headers)

        assert response.status_code == 204
        deleted_comment = db.session.get(BlogComment, 3)
        assert deleted_comment is None


def test_delete_blog_comment_403_other_non_admin_user(client, app):
    with app.app_context():
        access_token = create_another_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

    response = client.delete('/api/blog/post/1/comments/1', headers=request_headers)
    assert response.status_code == 403
    assert response.json['msg'] == 'Access denied. You can only delete your own comments'


def test_delete_blog_comment_403_locked_owner(client, app):
    with app.app_context():
        access_token = create_user_token()
        user = db.session.get(User, 2)
        user.locked = True
        db.session.commit()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

    response = client.delete('/api/blog/post/1/comments/1', headers=request_headers)
    assert response.status_code == 403
    assert response.json['msg'] == 'Account is locked'


def test_delete_blog_comment_200_deleted_comment_is_anonymized_in_get_response(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        delete_response = client.delete('/api/blog/post/1/comments/1', headers=request_headers)
        assert delete_response.status_code == 204

        read_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

    response = client.get('/api/blog/post/1/comments', headers=read_headers)
    assert response.status_code == 200
    assert response.json['comments'][0]['content'] == '[deleted]'
    assert response.json['comments'][0]['deleted'] is True
    assert response.json['comments'][0]['user']['name'] is None
    assert response.json['comments'][0]['replies'][0]['content'] == 'Reply to the first comment.'


def test_delete_blog_comment_204_when_already_deleted(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        first_response = client.delete('/api/blog/post/1/comments/1', headers=request_headers)
        assert first_response.status_code == 204

        second_response = client.delete('/api/blog/post/1/comments/1', headers=request_headers)
        assert second_response.status_code == 204

        deleted_comment = db.session.get(BlogComment, 1)
        assert deleted_comment is not None
        assert deleted_comment.deleted is True


def test_delete_blog_comment_404_when_comment_not_on_blog_post(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

    response = client.delete('/api/blog/post/2/comments/1', headers=request_headers)
    assert response.status_code == 404
    assert response.json['msg'] == 'Comment not found for this blog post'


def test_delete_blog_comment_404_when_hard_deleted_leaf_comment_is_deleted_again(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {
            'Authorization': 'Bearer {}'.format(access_token),
        }

        first_response = client.delete('/api/blog/post/1/comments/3', headers=request_headers)
        assert first_response.status_code == 204

        second_response = client.delete('/api/blog/post/1/comments/3', headers=request_headers)
        assert second_response.status_code == 404

# POST /blog/post - additional coverage

def test_post_blog_post_201_returns_id(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
        response = client.post('/api/blog/post', headers=request_headers, json={
            'title': 'ID Check Post',
            'author': 'User One',
            'content': 'Checking that id is returned.',
        })
    assert response.status_code == 201
    assert 'id' in response.json
    assert isinstance(response.json['id'], int)

def test_post_blog_post_403_non_admin(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.post('/api/blog/post', headers=request_headers, json={
        'title': 'Forbidden Post',
        'author': 'User Two',
        'content': 'Should be rejected.'
    })
    assert response.status_code == 403

# PUT /blog/post/{id} - additional coverage

def test_put_blog_post_403_non_admin(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.put('/api/blog/post/1', headers=request_headers, json={
        'title': 'Forbidden Update',
        'content': 'Should be rejected.'
    })
    assert response.status_code == 403

# DELETE /blog/post/{id} - additional coverage

def test_delete_blog_post_403_non_admin(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.delete('/api/blog/post/1', headers=request_headers)
    assert response.status_code == 403

# GET /blog/posts/all

def test_get_all_blog_posts_200_admin(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all', headers=request_headers)
    assert response.status_code == 200
    assert 'blog_posts' in response.json
    assert 'total' in response.json
    assert 'all_total' in response.json
    assert 'published_total' in response.json
    assert response.json['total'] >= 10

def test_get_all_blog_posts_200_includes_hidden(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    public_response = client.get('/api/blog/posts')
    all_response = client.get('/api/blog/posts/all', headers=request_headers)
    assert all_response.json['total'] >= public_response.json['total']

def test_get_all_blog_posts_401_unauthenticated(client):
    response = client.get('/api/blog/posts/all')
    assert response.status_code == 401

def test_get_all_blog_posts_403_non_admin(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all', headers=request_headers)
    assert response.status_code == 403

def test_get_all_blog_posts_400_invalid_offset(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all?offset=-1', headers=request_headers)
    assert response.status_code == 400

def test_get_all_blog_posts_400_limit_too_large(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all?limit=101', headers=request_headers)
    assert response.status_code == 400

def test_get_all_blog_posts_200_limit_100(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all?limit=100', headers=request_headers)
    assert response.status_code == 200
    assert response.json['limit'] == 100

def test_get_all_blog_posts_200_status_filter(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all?status=draft', headers=request_headers)
    assert response.status_code == 200
    assert 'draft_total' in response.json

def test_get_all_blog_posts_200_search_query(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all?q=Title', headers=request_headers)
    assert response.status_code == 200
    assert 'blog_posts' in response.json

def test_get_all_blog_posts_400_invalid_status(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/posts/all?status=weird', headers=request_headers)
    assert response.status_code == 400

# GET /blog/post/{id}/comments - additional coverage

def test_get_blog_post_comments_404_post_not_found(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.get('/api/blog/post/999/comments', headers=request_headers)
    assert response.status_code == 404
    assert response.json['msg'] == 'Blog post not found'

# POST /blog/post/{id}/comments - additional coverage

def test_post_blog_comment_401_unauthenticated(client):
    response = client.post('/api/blog/post/1/comments', json={'content': 'Hello'})
    assert response.status_code == 401

def test_post_blog_comment_404_post_not_found(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.post('/api/blog/post/999/comments', headers=request_headers, json={'content': 'Hello'})
    assert response.status_code == 404
    assert response.json['msg'] == 'Blog post not found'

def test_post_blog_comment_404_hidden_post(client, app):
    with app.app_context():
        access_token = create_admin_token()
        admin_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    create_response = client.post('/api/blog/post', headers=admin_headers, json={
        'title': 'Hidden', 'author': 'Admin', 'content': 'Hidden post.', 'visible': False
    })
    assert create_response.status_code == 201
    post_id = create_response.json['id']
    with app.app_context():
        access_token = create_user_token()
        user_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.post(f'/api/blog/post/{post_id}/comments', headers=user_headers, json={'content': 'Should not work'})
    assert response.status_code == 404

def test_post_blog_comment_400_content_too_long(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.post('/api/blog/post/1/comments', headers=request_headers, json={'content': 'x' * 5001})
    assert response.status_code == 400

# PUT /blog/post/{id}/comments/{comment_id} - additional coverage

def test_put_blog_comment_401_unauthenticated(client):
    response = client.put('/api/blog/post/1/comments/1', json={'content': 'Update'})
    assert response.status_code == 401

def test_put_blog_comment_404_post_not_found(client, app):
    with app.app_context():
        access_token = create_user_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.put('/api/blog/post/999/comments/1', headers=request_headers, json={'content': 'Update'})
    assert response.status_code == 404
    assert response.json['msg'] == 'Blog post not found'

def test_get_blog_post_404_hidden(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    create_response = client.post('/api/blog/post', headers=request_headers, json={
        'title': 'Hidden Post', 'author': 'Admin', 'content': 'Secret content.', 'visible': False
    })
    assert create_response.status_code == 201
    post_id = create_response.json['id']
    response = client.get(f'/api/blog/post/{post_id}')
    assert response.status_code == 404

def test_get_blog_post_404_future_dated(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    create_response = client.post('/api/blog/post', headers=request_headers, json={
        'title': 'Future Post', 'author': 'Admin', 'content': 'Not yet published.', 'date': '2099-12-31T23:59', 'visible': True
    })
    assert create_response.status_code == 201
    post_id = create_response.json['id']
    response = client.get(f'/api/blog/post/{post_id}')
    assert response.status_code == 404

# DELETE /blog/post/{id}/comments/{comment_id} - additional coverage

def test_delete_blog_comment_401_unauthenticated(client):
    response = client.delete('/api/blog/post/1/comments/1')
    assert response.status_code == 401

def test_delete_blog_comment_404_post_not_found(client, app):
    with app.app_context():
        access_token = create_admin_token()
        request_headers = {'Authorization': 'Bearer {}'.format(access_token)}
    response = client.delete('/api/blog/post/999/comments/1', headers=request_headers)
    assert response.status_code == 404
    assert response.json['msg'] == 'Blog post not found'
