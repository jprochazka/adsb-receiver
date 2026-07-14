from conftest import create_admin_token, create_another_user_token, create_user_token
from backend.models import db, Aircraft, Flight, User

# GET /api/adsb/flight/{flight}

def test_get_flight_200(client):
    response = client.get('/api/adsb/flight/FLT0001')
    assert response.status_code == 200
    assert response.json['id'] == 1
    assert response.json['aircraft'] == 1
    assert response.json['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['last_seen'] == "2024-06-17 01:11:01"
    assert response.json['aircraft_class'] == 'unknown'
    assert 'ignore_on_purge' not in response.json
    assert response.json['sightings_count'] == 1

def test_get_flight_404(client):
    response = client.get('/api/adsb/flight/FLT0000')
    assert response.status_code == 404

# GET /api/adsb/flight/{flight}/positions

def test_get_flight_positions_200(client):
    response = client.get('/api/adsb/flight/FLT0005/positions')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 500
    assert response.json['count'] == 4
    assert response.json['total'] == 4
    assert response.json['positions'][0]['id'] == 11
    assert response.json['positions'][0]['flight'] == 4
    assert response.json['positions'][0]['aircraft'] == 5
    assert response.json['positions'][0]['time'] == '2024-06-17 05:55:05'
    assert response.json['positions'][0]['message'] == 323
    assert response.json['positions'][0]['squawk'] == 1317
    assert response.json['positions'][0]['latitude'] == 41.774163
    assert response.json['positions'][0]['longitude'] == -83.827344
    assert response.json['positions'][0]['track'] == 91
    assert response.json['positions'][0]['altitude'] == 36475
    assert response.json['positions'][0]['vertical_rate'] == 832
    assert response.json['positions'][0]['speed'] == 486
    assert response.json['positions'][1]['id'] == 12
    assert response.json['positions'][1]['flight'] == 4
    assert response.json['positions'][1]['aircraft'] == 5
    assert response.json['positions'][1]['time'] == '2024-07-17 05:50:20'
    assert response.json['positions'][1]['message'] == 340
    assert response.json['positions'][1]['squawk'] == 1317
    assert response.json['positions'][1]['latitude'] == 41.773837
    assert response.json['positions'][1]['longitude'] == -83.788828
    assert response.json['positions'][1]['track'] == 91
    assert response.json['positions'][1]['altitude'] == 36625
    assert response.json['positions'][1]['vertical_rate'] == 960
    assert response.json['positions'][1]['speed'] == 487
    assert response.json['positions'][2]['id'] == 13
    assert response.json['positions'][2]['flight'] == 4
    assert response.json['positions'][2]['aircraft'] == 5
    assert response.json['positions'][2]['time'] == '2024-07-17 05:50:35'
    assert response.json['positions'][2]['message'] == 417
    assert response.json['positions'][2]['squawk'] == 1317
    assert response.json['positions'][2]['latitude'] == 41.773464
    assert response.json['positions'][2]['longitude'] == -83.749737
    assert response.json['positions'][2]['track'] == 91
    assert response.json['positions'][2]['altitude'] == 36825
    assert response.json['positions'][2]['vertical_rate'] == 768
    assert response.json['positions'][2]['speed'] == 487
    assert response.json['positions'][3]['id'] == 14
    assert response.json['positions'][3]['flight'] == 4
    assert response.json['positions'][3]['aircraft'] == 5
    assert response.json['positions'][3]['time'] == '2024-07-17 05:50:55'
    assert response.json['positions'][3]['message'] == 504
    assert response.json['positions'][3]['squawk'] == 1317
    assert response.json['positions'][3]['latitude'] == 41.772903
    assert response.json['positions'][3]['longitude'] == -83.690727
    assert response.json['positions'][3]['track'] == 91
    assert response.json['positions'][3]['altitude'] == 37225
    assert response.json['positions'][3]['vertical_rate'] == 1216
    assert response.json['positions'][3]['speed'] == 484

def test_get_flight_positions_404(client):
    response = client.get('/api/adsb/flight/FLT0000/positions')
    assert response.status_code == 404

def test_get_flight_positions_400_offset(client):
    response = client.get('/api/adsb/flight/FLT0001/positions?offset=-1')
    assert response.status_code == 400

def test_get_flight_positions_400_limit_too_low(client):
    response = client.get('/api/adsb/flight/FLT0001/positions?limit=0')
    assert response.status_code == 400

def test_get_flight_positions_400_limit_too_high(client):
    response = client.get('/api/adsb/flight/FLT0001/positions?limit=1001')
    assert response.status_code == 400


def test_get_flight_positions_200_total_reflects_full_database_count(client):
    response = client.get('/api/adsb/flight/FLT0001/positions?limit=3')
    assert response.status_code == 200
    assert response.json['count'] == 3
    assert response.json['total'] == 10

# GET /api/adsb/flights

def test_get_flights_200(client):
    response = client.get('/api/adsb/flights')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 50
    assert response.json['count'] == 4
    assert response.json['flights'][0]['id'] == 4
    assert response.json['flights'][0]['aircraft'] == 5
    assert response.json['flights'][0]['icao'] == 'icao05'
    assert response.json['flights'][0]['flight'] == "FLT0005"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 04:40:44"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 04:44:04"
    assert response.json['flights'][0]['sightings_count'] == 1
    assert response.json['flights'][1]['id'] == 3
    assert response.json['flights'][1]['aircraft'] == 3
    assert response.json['flights'][1]['icao'] == 'icao03'
    assert response.json['flights'][1]['flight'] == "FLT0003"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 03:33:03"
    assert response.json['flights'][1]['sightings_count'] == 1
    assert response.json['flights'][2]['id'] == 2
    assert response.json['flights'][2]['aircraft'] == 2
    assert response.json['flights'][2]['flight'] == "FLT0002"
    assert response.json['flights'][2]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['flights'][2]['last_seen'] == "2024-06-17 02:22:02"
    assert response.json['flights'][2]['sightings_count'] == 1
    assert response.json['flights'][3]['id'] == 1
    assert response.json['flights'][3]['aircraft'] == 1
    assert response.json['flights'][3]['flight'] == "FLT0001"
    assert response.json['flights'][3]['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['flights'][3]['last_seen'] == "2024-06-17 01:11:01"
    assert response.json['flights'][3]['sightings_count'] == 1


def test_get_flights_200_sightings_count_uses_30_min_gap(client, app):
    with app.app_context():
        aircraft = db.session.execute(db.select(Aircraft).filter_by(icao='icao01')).scalar_one()
        db.session.add_all([
            Flight(aircraft=aircraft.id, flight='FLT9000', first_seen='2024-07-18 10:00:00', last_seen='2024-07-18 10:10:00'),
            Flight(aircraft=aircraft.id, flight='FLT9000', first_seen='2024-07-18 10:20:00', last_seen='2024-07-18 10:25:00'),
            Flight(aircraft=aircraft.id, flight='FLT9000', first_seen='2024-07-18 10:55:00', last_seen='2024-07-18 11:05:00'),
        ])
        db.session.commit()

    response = client.get('/api/adsb/flights/search?q=FLT9000')
    assert response.status_code == 200
    assert response.json['count'] == 3
    assert all(f['sightings_count'] == 2 for f in response.json['flights'])
    
def test_get_flights_200_offset(client):
    response = client.get('/api/adsb/flights?offset=2')
    assert response.status_code == 200
    assert response.json['offset'] == 2
    assert response.json['limit'] == 50
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 2
    assert response.json['flights'][0]['aircraft'] == 2
    assert response.json['flights'][0]['flight'] == "FLT0002"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 02:22:02"
    assert response.json['flights'][1]['id'] == 1
    assert response.json['flights'][1]['aircraft'] == 1
    assert response.json['flights'][1]['flight'] == "FLT0001"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 01:10:11"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 01:11:01"

def test_get_flights_200_limit(client):
    response = client.get('/api/adsb/flights?limit=2')
    assert response.status_code == 200
    assert response.json['offset'] == 0
    assert response.json['limit'] == 2
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 4
    assert response.json['flights'][0]['aircraft'] == 5
    assert response.json['flights'][0]['flight'] == "FLT0005"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 04:40:44"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 04:44:04"
    assert response.json['flights'][1]['id'] == 3
    assert response.json['flights'][1]['aircraft'] == 3
    assert response.json['flights'][1]['flight'] == "FLT0003"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 03:33:03"

def test_get_flights_200_offset_and_limit(client):
    response = client.get('/api/adsb/flights?offset=1&limit=2')
    assert response.status_code == 200
    assert response.json['offset'] == 1
    assert response.json['limit'] == 2
    assert response.json['count'] == 2
    assert response.json['flights'][0]['id'] == 3
    assert response.json['flights'][0]['aircraft'] == 3
    assert response.json['flights'][0]['flight'] == "FLT0003"
    assert response.json['flights'][0]['first_seen'] == "2024-07-17 03:30:33"
    assert response.json['flights'][0]['last_seen'] == "2024-06-17 03:33:03"
    assert response.json['flights'][1]['id'] == 2
    assert response.json['flights'][1]['aircraft'] == 2
    assert response.json['flights'][1]['flight'] == "FLT0002"
    assert response.json['flights'][1]['first_seen'] == "2024-07-17 02:20:22"
    assert response.json['flights'][1]['last_seen'] == "2024-06-17 02:22:02"

def test_get_flights_400_offset_less_than_0(client):
    response = client.get('/api/adsb/flights?offset=-1')
    assert response.status_code == 400

def test_get_flights_400_limit_less_than_0(client):
    response = client.get('/api/adsb/flights?limit=-1')
    assert response.status_code == 400

def test_get_flights_400_limit_greater_than_100(client):
    response = client.get('/api/adsb/flights?limit=101')
    assert response.status_code == 400


def test_get_flights_200_ignore_on_purge_true_filter(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        from backend.models import Flight
        flight = db.session.execute(db.select(Flight).filter_by(flight='FLT0001')).scalar_one()
        flight.ignore_on_purge = True
        db.session.commit()

    response = client.get(
        '/api/adsb/flights?ignore_on_purge=true',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['total'] == 1
    assert response.json['flights'][0]['flight'] == 'FLT0001'
    assert response.json['flights'][0]['ignore_on_purge'] is True


def test_get_flights_400_invalid_ignore_on_purge_filter(client):
    response = client.get('/api/adsb/flights?ignore_on_purge=maybe')
    assert response.status_code == 401

# GET /api/adsb/flights/count

def test_get_flights_count(client):
    response = client.get('/api/adsb/flights/count')
    assert response.status_code == 200
    assert response.json["flights"] == 4

# GET /api/adsb/flights/search

def test_get_flights_search_200(client):
    response = client.get('/api/adsb/flights/search?q=FLT')
    assert response.status_code == 200
    assert response.json['count'] == 4
    assert response.json['total'] == 4

def test_get_flights_search_200_single_result(client):
    response = client.get('/api/adsb/flights/search?q=FLT0001')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['flights'][0]['flight'] == 'FLT0001'

def test_get_flights_search_200_single_result_by_icao(client):
    response = client.get('/api/adsb/flights/search?q=icao01')
    assert response.status_code == 200
    assert response.json['count'] == 1
    assert response.json['flights'][0]['flight'] == 'FLT0001'
    assert response.json['flights'][0]['icao'] == 'icao01'

def test_get_flights_search_200_no_results(client):
    response = client.get('/api/adsb/flights/search?q=NOMATCH')
    assert response.status_code == 200
    assert response.json['count'] == 0

def test_get_flights_search_400_no_query(client):
    response = client.get('/api/adsb/flights/search')
    assert response.status_code == 400

# DELETE /api/adsb/flights/purge

def test_purge_flights_401(client):
    response = client.delete('/api/adsb/flights/purge?days=1')
    assert response.status_code == 401

def test_purge_flights_403(client, app):
    with app.app_context():
        access_token = create_user_token()
    response = client.delete(
        '/api/adsb/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 403

def test_purge_flights_400_no_days(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/adsb/flights/purge',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 400

def test_purge_flights_400_days_zero(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/adsb/flights/purge?days=0',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 400

def test_purge_flights_200(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
    response = client.delete(
        '/api/adsb/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 200
    assert 'deleted_flights' in response.json
    assert 'deleted_positions' in response.json
    assert 'deleted_comments' in response.json
    assert 'cutoff_date' in response.json


def test_update_flight_purge_preference_200_admin(client, app):
    with app.app_context():
        access_token = create_admin_token(app)

    response = client.put(
        '/api/adsb/flight/FLT0001/purge-preference',
        json={'ignore_on_purge': True},
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 200
    assert response.json['flight'] == 'FLT0001'
    assert response.json['ignore_on_purge'] is True

    verify_response = client.get(
        '/api/adsb/flight/FLT0001',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert verify_response.status_code == 200
    assert verify_response.json['ignore_on_purge'] is True


def test_update_flight_purge_preference_403_non_admin(client, app):
    with app.app_context():
        access_token = create_user_token(app)

    response = client.put(
        '/api/adsb/flight/FLT0001/purge-preference',
        json={'ignore_on_purge': True},
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 403


def test_update_flight_purge_preference_400_missing_ignore_on_purge(client, app):
    with app.app_context():
        access_token = create_admin_token(app)

    response = client.put(
        '/api/adsb/flight/FLT0001/purge-preference',
        json={},
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 400
    assert response.json['msg'] == 'Bad Request - ignore_on_purge is required'


def test_purge_flights_ignores_protected_flights(client, app):
    with app.app_context():
        access_token = create_admin_token(app)
        from backend.models import Flight
        flight = db.session.execute(db.select(Flight).filter_by(flight='FLT0001')).scalar_one()
        flight.ignore_on_purge = True
        db.session.commit()

    response = client.delete(
        '/api/adsb/flights/purge?days=1',
        headers={'Authorization': f'Bearer {access_token}'}
    )

    assert response.status_code == 200

    verify_response = client.get(
        '/api/adsb/flight/FLT0001',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert verify_response.status_code == 200
    assert verify_response.json['ignore_on_purge'] is True


# GET /api/adsb/flight/{flight}/comments

def test_get_flight_comments_200_empty(client):
    response = client.get('/api/adsb/flight/FLT0001/comments')
    assert response.status_code == 200
    assert response.json['flight'] == 'FLT0001'
    assert response.json['count'] == 0
    assert response.json['comments'] == []


def test_get_flight_comments_404(client):
    response = client.get('/api/adsb/flight/NOFLIGHT/comments')
    assert response.status_code == 404


# POST /api/adsb/flight/{flight}/comments

def test_create_flight_comment_401(client):
    response = client.post('/api/adsb/flight/FLT0001/comments', json={'content': 'Test comment'})
    assert response.status_code == 401


def test_create_flight_comment_201_user(client, app):
    with app.app_context():
        access_token = create_user_token(app)

    response = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'Observed at low altitude.'},
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 201
    assert response.json['content'] == 'Observed at low altitude.'
    assert response.json['edited'] is False
    assert response.json['edited_at'] is None
    assert response.json['user']['name'] == 'Regular User'

    get_response = client.get('/api/adsb/flight/FLT0001/comments')
    assert get_response.status_code == 200
    assert get_response.json['count'] == 1
    assert get_response.json['comments'][0]['content'] == 'Observed at low altitude.'


def test_create_flight_comment_403_locked_user(client, app):
    with app.app_context():
        user = db.session.get(User, 2)
        user.locked = True
        db.session.commit()
        access_token = create_user_token(app)

    response = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'Should fail because account is locked.'},
        headers={'Authorization': f'Bearer {access_token}'}
    )
    assert response.status_code == 403


def test_purge_flights_deletes_related_comments(client, app):
    with app.app_context():
        user_token = create_user_token(app)
        admin_token = create_admin_token(app)

    create_response = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'This should be purged.'},
        headers={'Authorization': f'Bearer {user_token}'}
    )
    assert create_response.status_code == 201

    purge_response = client.delete(
        '/api/adsb/flights/purge?days=1',
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert purge_response.status_code == 200
    assert purge_response.json['deleted_comments'] >= 1


def test_update_flight_comment_403_other_user(client, app):
    with app.app_context():
        owner_token = create_user_token(app)
        other_user_token = create_another_user_token(app)

    create_response = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'Needs owner edit coverage.'},
        headers={'Authorization': f'Bearer {owner_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    response = client.put(
        f'/api/adsb/flight/FLT0001/comments/{comment_id}',
        json={'content': 'Edited by another user should fail.'},
        headers={'Authorization': f'Bearer {other_user_token}'}
    )
    assert response.status_code == 403
    assert response.json['msg'] == 'Access denied. You can only edit your own comments'


def test_update_flight_comment_200_owner(client, app):
    with app.app_context():
        user_token = create_user_token(app)

    create_response = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'Original text.'},
        headers={'Authorization': f'Bearer {user_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    update_response = client.put(
        f'/api/adsb/flight/FLT0001/comments/{comment_id}',
        json={'content': 'Edited by owner.'},
        headers={'Authorization': f'Bearer {user_token}'}
    )
    assert update_response.status_code == 200
    assert update_response.json['content'] == 'Edited by owner.'
    assert update_response.json['edited'] is True
    assert update_response.json['edited_at'] is not None


def test_update_flight_comment_200_admin(client, app):
    with app.app_context():
        admin_token = create_admin_token(app)

    create_response = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'Original text.'},
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    update_response = client.put(
        f'/api/adsb/flight/FLT0001/comments/{comment_id}',
        json={'content': 'Moderated text.'},
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert update_response.status_code == 200
    assert update_response.json['content'] == 'Moderated text.'
    assert update_response.json['edited'] is True
    assert update_response.json['edited_at'] is not None


def test_delete_flight_comment_204_admin(client, app):
    with app.app_context():
        admin_token = create_admin_token(app)

    create_response = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'Will be deleted by admin.'},
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert create_response.status_code == 201
    comment_id = create_response.json['id']

    delete_response = client.delete(
        f'/api/adsb/flight/FLT0001/comments/{comment_id}',
        headers={'Authorization': f'Bearer {admin_token}'}
    )
    assert delete_response.status_code == 200


def test_delete_flight_comment_owner_allowed_other_user_denied(client, app):
    with app.app_context():
        owner_token = create_user_token(app)
        other_token = create_another_user_token(app)

    created = client.post(
        '/api/adsb/flight/FLT0001/comments',
        json={'content': 'Owned comment.'},
        headers={'Authorization': f'Bearer {owner_token}'},
    )
    comment_url = f"/api/adsb/flight/FLT0001/comments/{created.json['id']}"
    assert client.delete(comment_url, headers={'Authorization': f'Bearer {other_token}'}).status_code == 403
    assert client.delete(comment_url, headers={'Authorization': f'Bearer {owner_token}'}).status_code == 200