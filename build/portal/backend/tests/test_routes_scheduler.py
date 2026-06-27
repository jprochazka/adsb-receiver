from conftest import create_admin_token, create_user_token


def test_scheduler_unauthorized_without_token(client):
    response = client.get('/api/scheduler')
    assert response.status_code == 401


def test_scheduler_jobs_unauthorized_without_token(client):
    response = client.get('/api/scheduler/jobs')
    assert response.status_code == 401


def test_scheduler_forbidden_for_non_admin(client, app):
    access_token = create_user_token(app)
    headers = {
        'Authorization': f'Bearer {access_token}',
        'accept': 'application/json',
    }

    response = client.get('/api/scheduler', headers=headers)
    assert response.status_code == 403


def test_scheduler_jobs_forbidden_for_non_admin(client, app):
    access_token = create_user_token(app)
    headers = {
        'Authorization': f'Bearer {access_token}',
        'accept': 'application/json',
    }

    response = client.get('/api/scheduler/jobs', headers=headers)
    assert response.status_code == 403


def test_scheduler_accessible_for_admin(client, app):
    access_token = create_admin_token(app)
    headers = {
        'Authorization': f'Bearer {access_token}',
        'accept': 'application/json',
    }

    response = client.get('/api/scheduler', headers=headers)
    assert response.status_code == 200


def test_scheduler_jobs_accessible_for_admin(client, app):
    access_token = create_admin_token(app)
    headers = {
        'Authorization': f'Bearer {access_token}',
        'accept': 'application/json',
    }

    response = client.get('/api/scheduler/jobs', headers=headers)
    assert response.status_code == 200
