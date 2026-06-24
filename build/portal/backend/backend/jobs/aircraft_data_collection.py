import logging

from backend.aircraft_classification import classify_aircraft
from backend.opensky_classification import get_opensky_classification

POSITION_KEYS = ('lat', 'lon', 'alt_baro', 'gs', 'track', 'geom_rate', 'hex')


def log_job_message(prefix: str, message: str):
    logging.info('[%s] %s', prefix, message)


def aircraft_has_position_fields(aircraft: dict) -> bool:
    return all(key in aircraft for key in POSITION_KEYS)


def aircraft_altitude(aircraft: dict):
    return aircraft.get('alt_geom', aircraft.get('alt_baro'))


def aircraft_squawk(aircraft: dict):
    return aircraft.get('squawk')


def classified_flight_fields(aircraft: dict):
    flight = aircraft['flight'].strip()
    emitter_category = aircraft.get('category')
    message_type = aircraft.get('type')
    opensky_class, _, _ = get_opensky_classification(aircraft.get('hex'))
    aircraft_class = classify_aircraft(
        emitter_category,
        message_type,
        flight,
        opensky_class=opensky_class,
    )
    return flight, emitter_category, message_type, aircraft_class
