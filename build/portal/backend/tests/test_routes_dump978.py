from conftest import create_admin_token, create_another_user_token, create_user_token
from backend.models import db, Dump978Aircraft, Dump978Flight, User

# GET /api/uat/flight/{flight}

def test_get_uat_flight_200(client):
    response = client.get('/api/uat/flight/UAT0001')
    assert response.status_code == 200
    assert response.json['id'] == 1
    assert response.json['aircraft'] == 1
    assert response.json['flight'] == 'UAT0001'
    assert response.json['first_seen'] == '2024-07-17 01:10:11'
    assert response.json['last_seen'] == '2024-06-17 01:11:01'
    assert response.json['icao'] == 'uicao01'
    assert response.json['aircraft_class'] == 'unknown'
    assert response.json['ignore_on_purge'] is False
    assert response.json['sightings_count'] == 1

def test_get_uat_flight_404(client):
    response = client.get('/api/uat/flight/UAT0000')
    assert response.status_code == 404

# GET /api/uat/flight/{flight}/positions

def test_get_uat_flight_positions_200(client):
    response = client.get('/api/uat/flight/UAT0001/positions')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 500
    assert response.json['count'] == 2
    assert response.json['total'] == 2
    assert response.json['positions'][0]['id'] == 1
    assert response.json['positions'][0]['flight'] == 1
    assert response.json['positions'][0]['aircraft'] == 1
    assert response.json['positions'][0]['time'] == '2024-06-17 01:11:01'
    assert response.json['positions'][0]['message'] == 50
    assert response.json['positions'][0]['squawk'] == 6523
    assert response.json['positions'][0]['latitude'] == 42.649292
    assert response.json['positions'][0]['longitude'] == -84.960896
    assert response.json['positions'][0]['track'] == 98
    assert response.json['positions'][0]['altitude'] == 4000
    assert response.json['positions'][0]['vertical_rate'] == 0
    assert response.json['positions'][0]['speed'] == 120
    assert response.json['positions'][1]['id'] == 2
    assert response.json['positions'][1]['message'] == 75

def test_get_uat_flight_positions_404(client):
    response = client.get('/api/uat/flight/UAT0000/positions')
    assert response.status_code == 404

def test_get_uat_flight_positions_400_offset(client):
    response = client.get('/api/uat/flight/UAT0001/positions?offset=-1')
    assert response.status_code == 400

def test_get_uat_flight_positions_400_limit_too_low(client):
    response = client.get('/api/uat/flight/UAT0001/positions?limit=0')
    assert response.status_code == 400

def test_get_uat_flight_positions_400_limit_too_high(client):
    response = client.get('/api/uat/flight/UAT0001/positions?limit=1001')
    assert response.status_code == 400


def test_get_uat_flight_positions_200_total_reflects_full_database_count(client):
    response = client.get('/api/uat/flight/UAT0001/positions?limit=1')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['total'] == 2

# GET /api/uat/flights

def test_get_uat_flights_200(client):
    response = client.get('/api/uat/flights')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 50
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 2
    assert response.json['flights'][0]['icao'] == 'uicao02'
    assert response.json['flights'][0]['aircraft'] == 2
    assert response.json['flights'][0]['flight'] == 'UAT0002'
    assert response.json['flights'][0]['first_seen'] == '2024-07-17 02:20:22'
    assert response.json['flights'][0]['last_seen'] == '2024-06-17 02:22:02'
    assert response.json['flights'][0]['sightings_count'] == 1
    assert response.json['flights'][1]['id'] == 1
    assert response.json['flights'][1]['icao'] == 'uicao01'
    assert response.json['flights'][1]['aircraft'] == 1
    assert response.json['flights'][1]['flight'] == 'UAT0001'
    assert response.json['flights'][1]['first_seen'] == '2024-07-17 01:10:11'
    assert response.json['flights'][1]['last_seen'] == '2024-06-17 01:11:01'
    assert response.json['flights'][1]['sightings_count'] == 1


def test_get_uat_flights_200_sightings_count_uses_30_min_gap(client, app):
    with app.app_context():
        aircraft = db.session.execute(db.select(Dump978Aircraft).filter_by(icao='uicao01')).scalar_one()
        db.session.add_all([
            Dump978Flight(aircraft=aircraft.id, flight='UAT9000', first_seen='2024-07-18 10:00:00', last_seen='2024-07-18 10:08:00'),
            Dump978Flight(aircraft=aircraft.id, flight='UAT9000', first_seen='2024-07-18 10:20:00', last_seen='2024-07-18 10:29:00'),
            Dump978Flight(aircraft=aircraft.id, flight='UAT9000', first_seen='2024-07-18 11:00:00', last_seen='2024-07-18 11:06:00'),
        ])
        db.session.commit()

    response = client.get('/api/uat/flights/search?q=UAT9000')
    assert response.status_code == 200
    assert response.json['count'] == 3
    assert all(f['sightings_count'] == 2 for f in response.json['flights'])

def test_get_uat_flights_200_offset(client):
    response = client.get('/api/uat/flights?offset=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 50
    assert response.json['count'] == 1
    assert response.json['flights'][0]['id'] == 1
    assert response.json['flights'][0]['flight'] == 'UAT0001'

def test_get_uat_flights_200_limit(client):
    response = client.get('/api/uat/flights?limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['flights'][0]['id'] == 2
    assert response.json['flights'][0]['flight'] == 'UAT0002'

def test_get_uat_flights_200_offset_and_limit(client):
    response = client.get('/api/uat/flights?offset=1&limit=1')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 1
    assert response.json['count'] == 1
    assert response.json['flights'][0]['id'] == 1

def test_get_uat_flights_400_offset(client):
    response = client.get('/api/uat/flights?offset=-1')
    assert response.status_code == 400

def test_get_uat_flights_400_limit_too_low(client):
    response = client.get('/api/uat/flights?limit=0')
    assert response.status_code == 400

def test_get_uat_flights_400_limit_too_high(client):
    response = client.get('/api/uat/flights?limit=101')
    assert response.status_code == 400


def test_get_uat_flights_200_ignore_on_purge_true_filter(client, app):
    with app.app_context():
        from backend.models import Dump978Flight
        flight = db.session.execute(db.select(Dump978Flight).filter_by(flight='UAT0001')).scalar_one()
        flight.ignore_on_purge = True
        db.session.commit()

    response = client.get('/api/uat/flights?ignore_on_purge=true')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['total'] == 1
    assert response.json['flights'][0]['flight'] == 'UAT0001'
    assert response.json['flights'][0]['ignore_on_purge'] is True


def test_get_uat_flights_400_invalid_ignore_on_purge_filter(client):
    response = client.get('/api/uat/flights?ignore_on_purge=maybe')
    assert response.status_code == 400

# GET /api/uat/flights/count

def test_get_uat_flights_count(client):
    response = client.get('/api/uat/flights/count')
    assert response.status_code == 200
    assert response.json['flights'] == 2

# GET /api/uat/flights/search

def test_get_uat_flights_search_200(client):
    response = client.get('/api/uat/flights/search?q=UAT')
    assert response.status_code == 200
    assert response.json['count'] == 2
    assert response.json['total'] == 2

def test_get_uat_flights_search_200_single_result(client):
    response = client.get('/api/uat/flights/search?q=UAT0001')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['flights'][0]['flight'] == 'UAT0001'

def test_get_uat_flights_search_200_single_result_by_icao(client):
    response = client.get('/api/uat/flights/search?q=uicao01')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['flights'][0]['flight'] == 'UAT0001'
    assert response.json['flights'][0]['icao'] == 'uicao01'

def test_get_uat_flights_search_200_no_results(client):
    response = client.get('/api/uat/flights/search?q=NOMATCH')
    assert response.status_code == 200
    assert response.json['count'] == 0

def test_get_uat_flights_search_400_no_query(client):
    response = client.get('/api/uat/flights/search')
    assert response.status_code == 400

# DELETE /api/uat/flights/purge

def test_purge_uat_flights_401(client):
    response = client.delete('/api/uat/flights/purge?days=1')
    assert response.status_code == 401

def test_purge_uat_flights_403(client, app):
    with app.app_context():
        access_token = create_user_token()
    response = client.delete(
        '/api/uat/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 403

def test_purge_uat_flights_400_no_days(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/uat/flights/purge',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 400

def test_purge_uat_flights_400_days_zero(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/uat/flights/purge?days=0',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 400

def test_purge_uat_flights_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/uat/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 200
    assert 'deleted_flights' in response.json
    assert 'deleted_positions' in response.json
    assert 'deleted_comments' in response.json
    assert 'cutoff_date' in response.json


def test_update_uat_flight_purge_preference_200_admin(client, app):
    with app.app_context():
        access_token = create_admin_token(app)

    response = client.put(
        '/api/uat/flight/UAT0001/purge-preference',
        json={'ignore_on_purge': True},
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 200
    assert response.json['flight'] == 'UAT0001'
    assert response.json['ignore_on_purge'] is True

    verify_response = client.get('/api/uat/flight/UAT0001')
    assert verify_response.status_code == 200
    assert verify_response.json['ignore_on_purge'] is True


def test_update_uat_flight_purge_preference_403_non_admin(client, app):
    with app.app_context():
        access_token = create_user_token(app)

    response = client.put(
        '/api/uat/flight/UAT0001/purge-preference',
        json={'ignore_on_purge': True},
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 403


def test_update_uat_flight_purge_preference_400_missing_ignore_on_purge(client, app):
    with app.app_context():
        access_token = create_admin_token(app)

    response = client.put(
        '/api/uat/flight/UAT0001/purge-preference',
        json={},
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 400
    assert response.json['msg'] == 'Bad Request - ignore_on_purge is required'


def test_purge_uat_flights_ignores_protected_flights(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        from backend.models import Dump978Flight
        flight = db.session.execute(db.select(Dump978Flight).filter_by(flight='UAT0001')).scalar_one()
        flight.ignore_on_purge = True
        db.session.commit()

    response = client.delete(
        '/api/uat/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 200

    verify_response = client.get('/api/uat/flight/UAT0001')
    assert verify_response.status_code == 200
    assert verify_response.json['ignore_on_purge'] is True


# GET /api/uat/flight/{flight}/comments

def test_get_uat_flight_comments_200_empty(client):
    response = client.get('/api/uat/flight/UAT0001/comments')
    assert response.status_code == 200
    assert response.json['flight'] == 'UAT0001'
    assert response.json['count'] == 0
    assert response.json['comments'] == []


def test_get_uat_flight_comments_404(client):
    response = client.get('/api/uat/flight/NOFLIGHT/comments')
    assert response.status_code == 404


# POST /api/uat/flight/{flight}/comments

def test_create_uat_flight_comment_401(client):
    response = client.post('/api/uat/flight/UAT0001/comments', json={'content': 'Test comment'})
    assert response.status_code == 401


def test_create_uat_flight_comment_201_user(client, app):
    with app.app_context():
        access_token = create_user_token(app)

    response = client.post(
        '/api/uat/flight/UAT0001/comments',
        json={'content': 'UAT track looked stable.'},
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 201
    assert response.json['content'] == 'UAT track looked stable.'
    assert response.json['edited'] is False
    assert response.json['edited_at'] is None
    assert response.json['user']['name'] == 'Regular User'

    get_response = client.get('/api/uat/flight/UAT0001/comments')
    assert get_response.status_code == 200
    assert get_response.json['count'] == 1
    assert get_response.json['comments'][0]['content'] == 'UAT track looked stable.'


def test_create_uat_flight_comment_403_locked_user(client, app):
    with app.app_context():
        user = db.session.get(User, 2)
        user.locked = True
        db.session.commit()
        access_token = create_user_token(app)

    response = client.post(
        '/api/uat/flight/UAT0001/comments',
        json={'content': 'Should fail because account is locked.'},
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 403


def test_purge_uat_flights_deletes_related_comments(client, app):
    with app.app_context():
        user_token = create_user_token(app)
        admin_token = create_admin_token(app)

    create_response = client.post(
        '/api/uat/flight/UAT0001/comments',
        json={'content': 'This should be purged.'},
        headers={'Authorization': f'Bearer {user_token}'}
    )
    assert create_response.status_code == 201

    purge_response = client.delete(
        '/api/uat/flights/purge?days=1',
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert purge_response.status_code == 200
    assert purge_response.json['deleted_comments'] >= 1


def test_update_uat_flight_comment_403_other_user(client, app):
    with app.app_context():
        owner_token = create_user_token(app)
        other_user_token = create_another_user_token(app)

    create_response = client.post(
        '/api/uat/flight/UAT0001/comments',
        json={'content': 'Needs owner edit coverage.'},
        headers={'Authorization': f'Bearer {owner_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    response = client.put(
        f'/api/uat/flight/UAT0001/comments/{comment_id}',
        json={'content': 'Edited by another user should fail.'},
        headers={'Authorization': f'Bearer {other_user_token}'}
    )
    assert response.status_code == 403
    assert response.json['msg'] == 'Access denied. You can only edit your own comments'


def test_update_uat_flight_comment_200_owner(client, app):
    with app.app_context():
        user_token = create_user_token(app)

    create_response = client.post(
        '/api/uat/flight/UAT0001/comments',
        json={'content': 'Original text.'},
        headers={'Authorization': f'Bearer {user_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    update_response = client.put(
        f'/api/uat/flight/UAT0001/comments/{comment_id}',
        json={'content': 'Edited by owner.'},
        headers={'Authorization': f'Bearer {user_token}'}
    )
    assert update_response.status_code == 200
    assert update_response.json['content'] == 'Edited by owner.'
    assert update_response.json['edited'] is True
    assert update_response.json['edited_at'] is not None


def test_update_uat_flight_comment_200_admin(client, app):
    with app.app_context():
        admin_token = create_admin_token(app)

    create_response = client.post(
        '/api/uat/flight/UAT0001/comments',
        json={'content': 'Original text.'},
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    update_response = client.put(
        f'/api/uat/flight/UAT0001/comments/{comment_id}',
        json={'content': 'Moderated text.'},
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert update_response.status_code == 200
    assert update_response.json['content'] == 'Moderated text.'
    assert update_response.json['edited'] is True
    assert update_response.json['edited_at'] is not None


def test_delete_uat_flight_comment_204_admin(client, app):
    with app.app_context():
        admin_token = create_admin_token(app)

    create_response = client.post(
        '/api/uat/flight/UAT0001/comments',
        json={'content': 'Will be deleted by admin.'},
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    delete_response = client.delete(
        f'/api/uat/flight/UAT0001/comments/{comment_id}',
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert delete_response.status_code == 200
