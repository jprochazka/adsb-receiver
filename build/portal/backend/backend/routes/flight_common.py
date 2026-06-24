import datetime

from sqlalchemy import or_, select

from backend.models import db
from backend.routes.common import parse_bool_arg


IGNORE_ON_PURGE_ERROR = 'invalid ignore_on_purge value'


def parse_timestamp(value: str | None, timestamp_format: str):
    if not value:
        return None

    try:
        return datetime.datetime.strptime(value, timestamp_format)
    except ValueError:
        return None


def get_sightings_counts(flight_model, flights: list[str], *, gap, timestamp_format):
    unique_flights = sorted({flight for flight in flights if flight})
    if not unique_flights:
        return {}

    rows = db.session.execute(
        select(flight_model.flight, flight_model.first_seen)
        .where(flight_model.flight.in_(unique_flights))
        .order_by(flight_model.flight.asc(), flight_model.first_seen.asc(), flight_model.id.asc())
    ).all()

    counts: dict[str, int] = {}
    previous_seen: dict[str, datetime.datetime | None] = {}

    for flight, first_seen in rows:
        current_seen = parse_timestamp(first_seen, timestamp_format)
        if current_seen is None:
            counts[flight] = counts.get(flight, 0) + 1
            continue

        prior_seen = previous_seen.get(flight)
        if prior_seen is None or (current_seen - prior_seen) >= gap:
            counts[flight] = counts.get(flight, 0) + 1

        previous_seen[flight] = current_seen

    return counts


def serialize_flights(rows, sightings_counts_func):
    flights_rows = list(rows)
    flights_data = []
    for flight_obj in flights_rows:
        data = flight_obj.to_dict()
        data['icao'] = flight_obj.aircraft_ref.icao if flight_obj.aircraft_ref else None
        flights_data.append(data)

    sightings_counts = sightings_counts_func(
        [data.get('flight') for data in flights_data if data.get('flight')]
    )
    for data in flights_data:
        flight_code = data.get('flight')
        data['sightings_count'] = sightings_counts.get(flight_code, 1 if flight_code else 0)

    return flights_data


def parse_ignore_on_purge(value: str | None):
    return parse_bool_arg(
        {'ignore_on_purge': value},
        'ignore_on_purge',
        true_values={'true', '1'},
        false_values={'false', '0'},
        error_message=IGNORE_ON_PURGE_ERROR,
    )


def apply_flight_filters(stmt, flight_model, aircraft_model, q: str | None, ignore_on_purge: bool | None):
    if q:
        stmt = stmt.filter(
            or_(
                flight_model.flight.ilike(f'%{q}%'),
                aircraft_model.icao.ilike(f'%{q}%'),
            )
        )

    if ignore_on_purge is not None:
        stmt = stmt.filter(flight_model.ignore_on_purge.is_(ignore_on_purge))

    return stmt


def validate_flight_comment_content(content):
    normalized = (content or '').strip()
    if not normalized:
        return None, {'msg': 'Bad Request - content is required'}, 400
    if len(normalized) > 5000:
        return None, {'msg': 'Bad Request - content cannot exceed 5000 characters'}, 400
    return normalized, None, None


def can_modify_comment(current_user, comment):
    return comment.user_id == current_user.id or current_user.is_admin()
