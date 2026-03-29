import json
import logging
from urllib.request import urlopen, Request
from urllib.error import URLError

from flask import Blueprint
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.models import db, Setting
from sqlalchemy import select

live = Blueprint('live', __name__)

live_ns = Namespace('live', description='Live aircraft data from dump1090')

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
})

live_response_model = live_ns.model('LiveData', {
    'now':      restx_fields.Float(description='Unix epoch timestamp of the feed snapshot'),
    'messages': restx_fields.Integer(description='Total ADS-B messages received by dump1090 since startup'),
    'aircraft': restx_fields.List(restx_fields.Nested(aircraft_model)),
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


def _normalize_dump1090_aircraft(raw: dict) -> dict:
    """
    Convert a raw dump1090 aircraft entry into a normalised dict.

    dump1090 field mapping:
      hex        -> hex
      flight     -> flight (stripped of whitespace)
      lat / lon  -> lat / lon
      alt_baro   -> altitude (alt_geom used as fallback when alt_baro is 'ground')
      gs         -> speed
      track      -> track
      baro_rate  -> vertical_rate
      squawk     -> squawk
      category   -> category
      seen       -> seen
      rssi       -> rssi
      type       -> type
    """
    alt = raw.get('alt_baro')
    # dump1090 may report 'ground' as a string instead of an integer
    if not isinstance(alt, int):
        alt = raw.get('alt_geom')
    if not isinstance(alt, int):
        alt = None

    return {
        'source':        'dump1090',
        'hex':           raw.get('hex', ''),
        'flight':        (raw.get('flight') or '').strip() or None,
        'lat':           raw.get('lat'),
        'lon':           raw.get('lon'),
        'altitude':      alt,
        'speed':         raw.get('gs'),
        'track':         raw.get('track'),
        'vertical_rate': raw.get('baro_rate'),
        'squawk':        raw.get('squawk'),
        'category':      raw.get('category'),
        'seen':          raw.get('seen'),
        'rssi':          raw.get('rssi'),
        'type':          raw.get('type'),
    }


def _normalize_dump978_aircraft(raw: dict) -> dict:
    """
    Convert a raw dump978 aircraft entry into a normalised dict.

    dump978 field mapping:
      hex        -> hex
      flight     -> flight (stripped of whitespace)
      lat / lon  -> lat / lon
      alt_baro   -> altitude (alt_geom used as fallback when alt_baro is 'ground')
      gs         -> speed
      track      -> track
      geom_rate  -> vertical_rate
      squawk     -> squawk
      category   -> category
      seen       -> seen
      rssi       -> rssi
      type       -> type
    """
    alt = raw.get('alt_baro')
    # dump978 may report 'ground' as a string instead of an integer
    if not isinstance(alt, int):
        alt = raw.get('alt_geom')
    if not isinstance(alt, int):
        alt = None

    return {
        'source':        'dump978',
        'hex':           raw.get('hex', ''),
        'flight':        (raw.get('flight') or '').strip() or None,
        'lat':           raw.get('lat'),
        'lon':           raw.get('lon'),
        'altitude':      alt,
        'speed':         raw.get('gs'),
        'track':         raw.get('track'),
        'vertical_rate': raw.get('geom_rate'),
        'squawk':        raw.get('squawk'),
        'category':      raw.get('category'),
        'seen':          raw.get('seen'),
        'rssi':          raw.get('rssi'),
        'type':          raw.get('type'),
    }


def _fetch_json_from_url(url: str) -> dict:
    with urlopen(Request(url), timeout=5) as resp:
        return json.load(resp)


def _fetch_dump1090_json() -> dict:
    return _fetch_json_from_url(_get_dump1090_json_url())


def _fetch_dump978_json() -> dict:
    return _fetch_json_from_url(_get_dump978_json_url())


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
        dump1090_data = None
        dump978_data = None
        errors = []

        dump1090_url = _get_dump1090_json_url()
        try:
            dump1090_data = _fetch_dump1090_json()
        except URLError as exc:
            logging.warning('Could not reach dump1090 aircraft.json at %s: %s', dump1090_url, exc)
            errors.append(f'dump1090: {exc}')
        except json.JSONDecodeError as exc:
            logging.error('Invalid JSON from dump1090 aircraft.json at %s: %s', dump1090_url, exc)
            errors.append(f'dump1090 invalid json: {exc}')
        except Exception as exc:
            logging.error('Unexpected error fetching dump1090 aircraft.json', exc_info=exc)
            errors.append('dump1090 internal error')

        dump978_url = _get_dump978_json_url()
        try:
            dump978_data = _fetch_dump978_json()
        except URLError as exc:
            logging.warning('Could not reach dump978 aircraft.json at %s: %s', dump978_url, exc)
            errors.append(f'dump978: {exc}')
        except json.JSONDecodeError as exc:
            logging.error('Invalid JSON from dump978 aircraft.json at %s: %s', dump978_url, exc)
            errors.append(f'dump978 invalid json: {exc}')
        except Exception as exc:
            logging.error('Unexpected error fetching dump978 aircraft.json', exc_info=exc)
            errors.append('dump978 internal error')

        if dump1090_data is None and dump978_data is None:
            return {
                'msg': 'Upstream data source unavailable',
                'detail': '; '.join(errors) if errors else 'No decoder data available',
            }, 503

        aircraft_list = []
        if dump1090_data:
            aircraft_list.extend(_normalize_dump1090_aircraft(a) for a in dump1090_data.get('aircraft', []))
        if dump978_data:
            aircraft_list.extend(_normalize_dump978_aircraft(a) for a in dump978_data.get('aircraft', []))

        now_value = None
        if dump1090_data and dump1090_data.get('now') is not None:
            now_value = dump1090_data.get('now')
        elif dump978_data:
            now_value = dump978_data.get('now')

        messages_value = 0
        if dump1090_data and isinstance(dump1090_data.get('messages'), int):
            messages_value += dump1090_data.get('messages')
        if dump978_data and isinstance(dump978_data.get('messages'), int):
            messages_value += dump978_data.get('messages')

        return {
            'now':      now_value,
            'messages': messages_value,
            'aircraft': aircraft_list,
        }, 200
