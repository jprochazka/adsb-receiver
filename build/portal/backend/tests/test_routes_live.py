"""Tests for the /api/live/aircraft endpoint."""
import json
from unittest.mock import patch
from urllib.error import URLError

import pytest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

SAMPLE_DUMP1090_AIRCRAFT_JSON = {
    "now": 1_700_000_000.5,
    "messages": 123456,
    "aircraft": [
        {
            "hex": "a1b2c3",
            "flight": "UAL123  ",
            "lat": 37.621,
            "lon": -122.379,
            "alt_baro": 35000,
            "gs": 450.5,
            "track": 270.0,
            "baro_rate": -64,
            "squawk": "1200",
            "category": "A3",
            "seen": 0.3,
            "rssi": -14.8,
            "type": "adsb_icao",
        },
        {
            # Aircraft on the ground: alt_baro reported as 'ground'
            "hex": "deadbe",
            "lat": 37.624,
            "lon": -122.381,
            "alt_baro": "ground",
            "alt_geom": 50,
            "gs": 5.0,
            "track": 90.0,
            "seen": 1.2,
            "rssi": -20.0,
            "type": "adsb_icao",
        },
        {
            # Aircraft with no position fix
            "hex": "000000",
            "seen": 15.0,
            "rssi": -30.0,
            "type": "adsb_icao",
        },
    ],
}

SAMPLE_DUMP978_AIRCRAFT_JSON = {
    "now": 1_700_000_001.5,
    "messages": 333,
    "aircraft": [
        {
            "hex": "b4c5d6",
            "flight": "FFT321  ",
            "lat": 36.08,
            "lon": -115.15,
            "alt_baro": 12000,
            "gs": 190.0,
            "track": 180.0,
            "geom_rate": 512,
            "squawk": "2345",
            "category": "A1",
            "seen": 0.8,
            "rssi": -16.0,
            "type": "uat_icao",
        }
    ],
}


def _make_mock_response(data: dict):
    """Return a context-manager mock that yields JSON bytes."""
    raw = json.dumps(data).encode()
    import io
    buf = io.BytesIO(raw)
    buf.__enter__ = lambda s: s
    buf.__exit__ = lambda s, *a: None
    return buf


def _mock_urlopen_for_both(dump1090_data: dict | Exception, dump978_data: dict | Exception):
    def _dispatch(req, timeout=5):
        url = req.full_url if hasattr(req, 'full_url') else str(req)
        if '/dump1090/' in url:
            if isinstance(dump1090_data, Exception):
                raise dump1090_data
            return _make_mock_response(dump1090_data)
        if '/dump978/' in url:
            if isinstance(dump978_data, Exception):
                raise dump978_data
            return _make_mock_response(dump978_data)
        raise AssertionError(f'Unexpected URL requested: {url}')

    return _dispatch


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestLiveAircraftEndpoint:

    @patch('backend.routes.live.urlopen')
    def test_get_live_aircraft_200(self, mock_urlopen, client):
        """Should return 200 with normalised aircraft from dump1090 and dump978."""
        mock_urlopen.side_effect = _mock_urlopen_for_both(
            SAMPLE_DUMP1090_AIRCRAFT_JSON,
            SAMPLE_DUMP978_AIRCRAFT_JSON,
        )
        resp = client.get('/api/live/aircraft')
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['now'] == SAMPLE_DUMP1090_AIRCRAFT_JSON['now']
        assert data['messages'] == (
            SAMPLE_DUMP1090_AIRCRAFT_JSON['messages'] +
            SAMPLE_DUMP978_AIRCRAFT_JSON['messages']
        )
        assert len(data['aircraft']) == 4

        sources = {a['source'] for a in data['aircraft']}
        assert sources == {'dump1090', 'dump978'}

    @patch('backend.routes.live.urlopen')
    def test_get_live_aircraft_normalises_callsign(self, mock_urlopen, client):
        """Trailing whitespace in flight callsigns must be stripped."""
        mock_urlopen.side_effect = _mock_urlopen_for_both(
            SAMPLE_DUMP1090_AIRCRAFT_JSON,
            SAMPLE_DUMP978_AIRCRAFT_JSON,
        )
        resp = client.get('/api/live/aircraft')
        aircraft = resp.get_json()['aircraft']
        adsb_ac = next(a for a in aircraft if a['source'] == 'dump1090' and a['hex'] == 'a1b2c3')
        uat_ac = next(a for a in aircraft if a['source'] == 'dump978' and a['hex'] == 'b4c5d6')
        assert adsb_ac['flight'] == 'UAL123'
        assert uat_ac['flight'] == 'FFT321'

    @patch('backend.routes.live.urlopen')
    def test_get_live_aircraft_normalises_ground_alt(self, mock_urlopen, client):
        """When alt_baro == 'ground' the geom altitude should be used as fallback."""
        mock_urlopen.side_effect = _mock_urlopen_for_both(
            SAMPLE_DUMP1090_AIRCRAFT_JSON,
            SAMPLE_DUMP978_AIRCRAFT_JSON,
        )
        resp = client.get('/api/live/aircraft')
        aircraft = resp.get_json()['aircraft']
        ac = next(a for a in aircraft if a['source'] == 'dump1090' and a['hex'] == 'deadbe')
        assert ac['altitude'] == 50   # fell back to alt_geom

    @patch('backend.routes.live.urlopen')
    def test_get_live_aircraft_null_fields_for_no_position(self, mock_urlopen, client):
        """Aircraft without position should have null lat/lon/altitude."""
        mock_urlopen.side_effect = _mock_urlopen_for_both(
            SAMPLE_DUMP1090_AIRCRAFT_JSON,
            SAMPLE_DUMP978_AIRCRAFT_JSON,
        )
        resp = client.get('/api/live/aircraft')
        aircraft = resp.get_json()['aircraft']
        ac = next(a for a in aircraft if a['source'] == 'dump1090' and a['hex'] == '000000')
        assert ac['lat'] is None
        assert ac['lon'] is None
        assert ac['altitude'] is None
        assert ac['flight'] is None

    @patch('backend.routes.live.urlopen')
    def test_get_live_aircraft_200_when_only_dump1090_available(self, mock_urlopen, client):
        """Should return 200 when dump1090 works but dump978 is unavailable."""
        mock_urlopen.side_effect = _mock_urlopen_for_both(
            {
                'now': 1_700_000_000.0,
                'messages': 7,
                'aircraft': [],
            },
            URLError('connection refused'),
        )
        resp = client.get('/api/live/aircraft')
        assert resp.status_code == 200
        assert resp.get_json()['aircraft'] == []
        assert resp.get_json()['messages'] == 7

    @patch('backend.routes.live.urlopen', side_effect=URLError('connection refused'))
    def test_get_live_aircraft_503_when_all_unreachable(self, _mock, client):
        """Should return 503 when both dump1090 and dump978 are unreachable."""
        resp = client.get('/api/live/aircraft')
        assert resp.status_code == 503
        body = resp.get_json()
        assert 'msg' in body
        assert 'detail' in body

    @patch('backend.routes.live.urlopen')
    def test_get_live_aircraft_200_when_only_dump978_available(self, mock_urlopen, client):
        """Should return 200 when dump978 works but dump1090 is unavailable."""
        mock_urlopen.side_effect = _mock_urlopen_for_both(
            URLError('connection refused'),
            SAMPLE_DUMP978_AIRCRAFT_JSON,
        )
        resp = client.get('/api/live/aircraft')
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['now'] == SAMPLE_DUMP978_AIRCRAFT_JSON['now']
        assert data['messages'] == SAMPLE_DUMP978_AIRCRAFT_JSON['messages']
        assert len(data['aircraft']) == 1
        assert data['aircraft'][0]['source'] == 'dump978'
