import json
import logging
import time
from urllib.request import urlopen, Request
from urllib.error import URLError

from flask import Blueprint
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.models import db, Setting
from backend.aircraft_classification import classify_aircraft
from backend.opensky_classification import get_opensky_classification, get_opensky_cache_stats
from sqlalchemy import select

live = Blueprint('live', __name__)

live_ns = Namespace('live', description='Live aircraft data from dump1090 and dump978')

# ---------------------------------------------------------------------------
# API models
# ---------------------------------------------------------------------------

aircraft_model = live_ns.model('LiveAircraft', {
    'source':        restx_fields.String(description='Data source (dump1090 or dump978)'),
    'hex':           restx_fields.String(description='ICAO 24-bit address (hex)'),
    'flight':        restx_fields.String(description='Callsign / flight number'),
    'lat':           restx_fields.Float(description='Latitude in decimal degrees'),
    'lon':           restx_fields.Float(description='Longitude in decimal degrees'),
    'altitude':      restx_fields.Integer(description='Barometric altitude in feet (alt_geom as fallback)'),
    'speed':         restx_fields.Float(description='Ground speed in knots'),
    'track':         restx_fields.Float(description='True track angle in degrees (0 = N, 90 = E)'),
    'vertical_rate': restx_fields.Integer(description='Barometric vertical rate in ft/min'),
    'squawk':        restx_fields.String(description='Transponder squawk code'),
    'category':      restx_fields.String(description='Emitter category (A0-D7)'),
    'seen':          restx_fields.Float(description='Seconds since any message was received'),
    'rssi':          restx_fields.Float(description='Signal strength in dBFS'),
    'type':          restx_fields.String(description='ADS-B message type'),
    'aircraft_class': restx_fields.String(description='Mapped aircraft class for iconography'),
    'classification_source': restx_fields.String(description='Classification source: opensky or heuristic'),
    'classification_confidence': restx_fields.String(description='Classification confidence: high, medium, or low'),
})

live_response_model = live_ns.model('LiveData', {
    'now':      restx_fields.Float(description='Unix epoch timestamp of the feed snapshot'),
    'messages': restx_fields.Integer(description='Total ADS-B messages received by dump1090 since startup'),
    'aircraft': restx_fields.List(restx_fields.Nested(aircraft_model)),
    'classification_stats': restx_fields.Raw(description='Public aircraft classification and cache stats'),
})

error_model = live_ns.model('LiveError', {
    'msg':    restx_fields.String(description='Error summary'),
    'detail': restx_fields.String(description='Additional diagnostic information'),
})

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_DEFAULT_DUMP1090_JSON_URL = 'http://127.0.0.1/dump1090/data/aircraft.json'
_DEFAULT_DUMP978_JSON_URL = 'http://127.0.0.1/dump978/data/aircraft.json'
_LIVE_CACHE_TTL_SECONDS = 2.0
_LIVE_AIRCRAFT_CACHE = {
    'expires_at': 0.0,
    'payload': None,
}


def _get_cached_live_aircraft_payload(now: float):
    payload = _LIVE_AIRCRAFT_CACHE.get('payload')
    expires_at = _LIVE_AIRCRAFT_CACHE.get('expires_at', 0.0)
    if payload is not None and now < expires_at:
        return payload
    return None


def _set_cached_live_aircraft_payload(payload: dict, now: float):
    _LIVE_AIRCRAFT_CACHE['payload'] = payload
    _LIVE_AIRCRAFT_CACHE['expires_at'] = now + _LIVE_CACHE_TTL_SECONDS


def _clear_live_aircraft_cache():
    _LIVE_AIRCRAFT_CACHE['payload'] = None
    _LIVE_AIRCRAFT_CACHE['expires_at'] = 0.0


def _get_dump1090_json_url() -> str:
    """Return the configured dump1090 aircraft.json URL, or the default."""
    setting = db.session.execute(
        select(Setting).filter_by(name='live_map_json_url')
    ).scalar_one_or_none()
    return setting.value if (setting and setting.value) else _DEFAULT_DUMP1090_JSON_URL


def _get_dump978_json_url() -> str:
    """Return the configured dump978 aircraft.json URL, or the default."""
    setting = db.session.execute(
        select(Setting).filter_by(name='live_map_json_url_dump978')
    ).scalar_one_or_none()
    return setting.value if (setting and setting.value) else _DEFAULT_DUMP978_JSON_URL


def _aircraft_altitude(raw: dict):
    alt = raw.get('alt_baro')
    if not isinstance(alt, int):
        alt = raw.get('alt_geom')
    return alt if isinstance(alt, int) else None


def _aircraft_classification(raw: dict, flight: str | None):
    category = raw.get('category')
    msg_type = raw.get('type')
    opensky_class, opensky_source, opensky_confidence = get_opensky_classification(raw.get('hex'))
    aircraft_class = classify_aircraft(category, msg_type, flight, opensky_class=opensky_class)
    return {
        'aircraft_class': aircraft_class,
        'classification_source': opensky_source or 'heuristic',
        'classification_confidence': opensky_confidence or ('medium' if aircraft_class != 'unknown' else 'low'),
    }


def _normalize_aircraft(raw: dict, *, source: str, vertical_rate_key: str) -> dict:
    flight = (raw.get('flight') or '').strip() or None
    return {
        'source': source,
        'hex': raw.get('hex', ''),
        'flight': flight,
        'lat': raw.get('lat'),
        'lon': raw.get('lon'),
        'altitude': _aircraft_altitude(raw),
        'speed': raw.get('gs'),
        'track': raw.get('track'),
        'vertical_rate': raw.get(vertical_rate_key),
        'squawk': raw.get('squawk'),
        'category': raw.get('category'),
        'seen': raw.get('seen'),
        'rssi': raw.get('rssi'),
        'type': raw.get('type'),
        **_aircraft_classification(raw, flight),
    }


def _normalize_dump1090_aircraft(raw: dict) -> dict:
    return _normalize_aircraft(raw, source='dump1090', vertical_rate_key='baro_rate')


def _normalize_dump978_aircraft(raw: dict) -> dict:
    return _normalize_aircraft(raw, source='dump978', vertical_rate_key='geom_rate')


def _fetch_json_from_url(url: str) -> dict:
    with urlopen(Request(url), timeout=5) as resp:
        return json.load(resp)


def _fetch_dump1090_json() -> dict:
    return _fetch_json_from_url(_get_dump1090_json_url())


def _fetch_dump978_json() -> dict:
    return _fetch_json_from_url(_get_dump978_json_url())


def _fetch_decoder_feed(source: str, url: str, fetch_func, errors: list[str]):
    try:
        return fetch_func()
    except URLError as exc:
        logging.warning('Could not reach %s aircraft.json at %s: %s', source, url, exc)
        errors.append(f'{source}: {exc}')
    except json.JSONDecodeError as exc:
        logging.error('Invalid JSON from %s aircraft.json at %s: %s', source, url, exc)
        errors.append(f'{source} invalid json: {exc}')
    except Exception as exc:
        logging.error('Unexpected error fetching %s aircraft.json', source, exc_info=exc)
        errors.append(f'{source} internal error')
    return None


def _extend_normalized_aircraft(aircraft_list: list, feed_data: dict | None, normalizer):
    if feed_data:
        aircraft_list.extend(normalizer(aircraft) for aircraft in feed_data.get('aircraft', []))


def _live_now_value(dump1090_data: dict | None, dump978_data: dict | None):
    if dump1090_data and dump1090_data.get('now') is not None:
        return dump1090_data.get('now')
    if dump978_data:
        return dump978_data.get('now')
    return None


def _live_messages_value(*feeds: dict | None) -> int:
    return sum(feed.get('messages') for feed in feeds if feed and isinstance(feed.get('messages'), int))


def _classification_stats(aircraft_list: list[dict]) -> dict:
    cache_stats = get_opensky_cache_stats()
    return {
        'opensky_count': sum(1 for aircraft in aircraft_list if aircraft.get('classification_source') == 'opensky'),
        'heuristic_count': sum(1 for aircraft in aircraft_list if aircraft.get('classification_source') != 'opensky'),
        'unknown_count': sum(1 for aircraft in aircraft_list if aircraft.get('aircraft_class') == 'unknown'),
        'opensky_cache_entries': cache_stats.get('entries', 0),
        'opensky_cache_loaded_at': cache_stats.get('loaded_at'),
    }


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

@live_ns.route('/aircraft')
class LiveAircraftResource(Resource):
    @live_ns.response(200, 'Success', live_response_model)
    @live_ns.response(503, 'Upstream data source unavailable', error_model)
    @live_ns.response(500, 'Internal server error', error_model)
    @live_ns.doc('get_live_aircraft')
    def get(self):
        """
        Fetch a real-time snapshot of aircraft visible to dump1090 and dump978.

        Reads from both decoders' aircraft.json feeds (dump1090 URL configurable
        via ``live_map_json_url``; dump978 via ``live_map_json_url_dump978``),
        then returns a single normalised list with a ``source`` marker per
        aircraft. If one decoder is unavailable, the other decoder's data is
        still returned. A 503 is returned only when both feeds are unavailable.
        """
        request_started = time.perf_counter()
        now_ts = time.time()
        cached = _get_cached_live_aircraft_payload(now_ts)
        if cached is not None:
            elapsed_ms = (time.perf_counter() - request_started) * 1000
            logging.info('live_aircraft cache=hit aircraft=%d elapsed_ms=%.2f', len(cached.get('aircraft', [])), elapsed_ms)
            return cached, 200

        errors = []
        dump1090_data = _fetch_decoder_feed(
            'dump1090', _get_dump1090_json_url(), _fetch_dump1090_json, errors
        )
        dump978_data = _fetch_decoder_feed(
            'dump978', _get_dump978_json_url(), _fetch_dump978_json, errors
        )

        if dump1090_data is None and dump978_data is None:
            return {
                'msg': 'Upstream data source unavailable',
                'detail': '; '.join(errors) if errors else 'No decoder data available',
            }, 503

        aircraft_list = []
        _extend_normalized_aircraft(aircraft_list, dump1090_data, _normalize_dump1090_aircraft)
        _extend_normalized_aircraft(aircraft_list, dump978_data, _normalize_dump978_aircraft)

        payload = {
            'now': _live_now_value(dump1090_data, dump978_data),
            'messages': _live_messages_value(dump1090_data, dump978_data),
            'aircraft': aircraft_list,
            'classification_stats': _classification_stats(aircraft_list),
        }
        _set_cached_live_aircraft_payload(payload, now_ts)
        elapsed_ms = (time.perf_counter() - request_started) * 1000
        logging.info('live_aircraft cache=miss aircraft=%d elapsed_ms=%.2f', len(aircraft_list), elapsed_ms)
        return payload, 200
