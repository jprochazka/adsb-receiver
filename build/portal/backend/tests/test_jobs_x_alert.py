import os
from io import BytesIO
from datetime import datetime, timedelta, timezone

import pytest
from PIL import Image
from staticmap import StaticMap

from backend.jobs.x_alert import (
    AlertConfig,
    NormalizedAircraft,
    format_alert,
    haversine_nm,
    normalize_aircraft,
    select_candidates,
)
from backend.jobs import x_alert
from backend.models import Setting, db


def _config(**overrides):
    values = {
        'enabled': True,
        'poll_seconds': 15,
        'receiver_lat': 41.0,
        'receiver_lon': -83.0,
        'radius_nm': 5.0,
        'min_altitude_ft': 500,
        'max_altitude_ft': 15000,
        'min_speed_kt': 80,
        'cooldown_minutes': 30,
        'ignore_no_callsign': False,
        'post_mode': 'log-only',
        'api_key': '',
        'api_secret': '',
        'access_token': '',
        'access_secret': '',
        'image_enabled': False,
        'image_lookback_minutes': 10,
        'image_width': 1024,
        'image_height': 768,
        'image_track_points_max': 150,
        'image_fallback_text_only': True,
    }
    values.update(overrides)
    return AlertConfig(**values)


def test_haversine_nm_matches_one_degree_at_equator():
    assert haversine_nm(0, 0, 0, 1) == pytest.approx(60.04, abs=0.1)


def test_normalize_aircraft_accepts_dump1090_fields():
    result = normalize_aircraft({
        'hex': 'ABC123',
        'flight': ' TEST1 ',
        'lat': 41.01,
        'lon': -83.01,
        'alt_baro': 5000,
        'gs': 120.8,
        'track': 91,
        'seen': 2,
    }, 'adsb')

    assert result is not None
    assert result.icao == 'abc123'
    assert result.callsign == 'TEST1'
    assert result.speed_kt == 120


def test_normalize_aircraft_rejects_missing_position():
    assert normalize_aircraft({'hex': 'abc123', 'alt_baro': 5000, 'gs': 120}, 'adsb') is None


def test_select_candidates_filters_and_sorts():
    aircraft = [
        NormalizedAircraft('adsb', 'far', 'FAR1', 41.04, -83.0, 6000, 150, 90, 1),
        NormalizedAircraft('uat', 'near', 'NEAR1', 41.01, -83.0, 5000, 130, 180, 2),
        NormalizedAircraft('adsb', 'slow', 'SLOW1', 41.0, -83.0, 4000, 20, 0, 1),
        NormalizedAircraft('uat', 'stale', 'OLD1', 41.0, -83.0, 4000, 120, 0, 90),
    ]

    result = select_candidates(aircraft, _config())

    assert [item.icao for item in result] == ['near', 'far']
    assert result[0].distance_nm < result[1].distance_nm


def test_format_alert_handles_missing_callsign_and_heading():
    aircraft = NormalizedAircraft('uat', 'abc123', '', 41, -83, 4000, 120, None, 1, 0.5)
    message = format_alert(aircraft, datetime(2026, 1, 2, 3, 4, tzinfo=timezone.utc))

    assert 'ABC123 overhead' in message
    assert 'unknown heading' in message
    assert 'UAT at 03:04 UTC' in message


def test_cooldown_prevents_spam_over_simulated_four_hour_window():
    aircraft = NormalizedAircraft('adsb', 'abc123', 'COOL123', 41, -83, 4000, 120, 90, 1, 0.5)
    started_at = datetime(2026, 1, 2, tzinfo=timezone.utc)
    posted_at = []
    with x_alert._state_lock:
        x_alert._cooldowns.clear()
        original_posted_count = x_alert._status['posted_since_start']

    try:
        for minute in range(241):
            observed_at = started_at + timedelta(minutes=minute)
            if not x_alert._is_suppressed(aircraft, observed_at, cooldown_minutes=30):
                x_alert._mark_posted(aircraft, observed_at)
                posted_at.append(observed_at)

        assert len(posted_at) == 8
        assert all(later - earlier > timedelta(minutes=30) for earlier, later in zip(posted_at, posted_at[1:]))
    finally:
        with x_alert._state_lock:
            x_alert._cooldowns.clear()
            x_alert._status['posted_since_start'] = original_posted_count


def _configure_job(app, **overrides):
    defaults = {
        'x_alert_enabled': 'true',
        'x_alert_receiver_lat': '41.0',
        'x_alert_receiver_lon': '-83.0',
        'x_alert_radius_nm': '10',
        'x_alert_min_altitude_ft': '0',
        'x_alert_max_altitude_ft': '20000',
        'x_alert_min_speed_kt': '0',
        'x_alert_post_mode': 'log-only',
    }
    defaults.update(overrides)
    with app.app_context():
        x_alert.ensure_x_alert_settings()
        for name, value in defaults.items():
            db.session.query(Setting).filter_by(name=name).one().value = value
        db.session.commit()


def _payload(hex_code, flight):
    return {
        'aircraft': [{
            'hex': hex_code,
            'flight': flight,
            'lat': 41.01,
            'lon': -83.01,
            'alt_baro': 5000,
            'gs': 120,
            'track': 90,
            'seen': 1,
        }]
    }


def test_cycle_combines_both_sources(app, monkeypatch):
    _configure_job(app)
    monkeypatch.setattr(
        x_alert,
        'fetch_aircraft_json',
        lambda url: _payload('ad0001', 'ADS001') if '1090' in url else _payload('ua0001', 'UAT001'),
    )

    with app.app_context():
        result = x_alert.execute_x_alert_cycle(dry_run=True, force=True)

    assert result['result'] == 'success'
    assert result['seen'] == 2
    assert result['eligible'] == 2
    assert len(result['messages']) == 2


def test_cycle_continues_when_one_source_is_down(app, monkeypatch):
    _configure_job(app)
    monkeypatch.setattr(
        x_alert,
        'fetch_aircraft_json',
        lambda url: _payload('ad0002', 'ADS002') if '1090' in url else None,
    )

    with app.app_context():
        result = x_alert.execute_x_alert_cycle(dry_run=True, force=True)
        status = x_alert.get_x_alert_status()

    assert result['result'] == 'success'
    assert result['seen'] == 1
    assert status['dump1090_status'] == 'up'
    assert status['dump978_status'] == 'down'


def test_image_generation_failure_falls_back_to_text(app, monkeypatch):
    _configure_job(app, x_alert_image_enabled='true', x_alert_image_fallback_text_only='true')
    monkeypatch.setattr(x_alert, 'fetch_aircraft_json', lambda url: _payload('ad0003', 'ADS003') if '1090' in url else None)
    monkeypatch.setattr(x_alert, 'render_map_image', lambda *args: (_ for _ in ()).throw(RuntimeError('map failed')))
    sent = []
    monkeypatch.setattr(x_alert, 'send_alert', lambda message, config, image_path=None: sent.append((message, image_path)))

    with app.app_context():
        result = x_alert.execute_x_alert_cycle(force=True)
        status = x_alert.get_x_alert_status()

    assert result['result'] == 'success'
    assert result['posted'] == 1
    assert sent[0][1] is None
    assert status['last_image_result'] == 'failed'
    assert status['last_image_at'] is not None


def test_render_map_image_with_deterministic_tiles(app, monkeypatch):
    tile = BytesIO()
    Image.new('RGB', (256, 256), '#dce8ef').save(tile, format='PNG')
    tile_bytes = tile.getvalue()
    monkeypatch.setattr(StaticMap, 'get', lambda self, url, **kwargs: (200, tile_bytes))
    monkeypatch.setattr(x_alert, '_track_points', lambda *args: [(-83.02, 41.0), (-83.01, 41.01)])
    aircraft = NormalizedAircraft('adsb', 'abc123', 'MAP123', 41.02, -83.0, 5000, 120, 90, 1)

    with app.app_context():
        image_path = x_alert.render_map_image(aircraft, _config(image_width=320, image_height=240))

    try:
        with Image.open(image_path) as rendered:
            assert rendered.format == 'PNG'
            assert rendered.size == (320, 240)
            assert rendered.getpixel((0, 239))[:3] == (255, 255, 255)
    finally:
        os.unlink(image_path)


def test_sender_failure_is_returned_without_raising(app, monkeypatch):
    _configure_job(app)
    monkeypatch.setattr(x_alert, 'fetch_aircraft_json', lambda url: _payload('ad0004', 'ADS004') if '1090' in url else None)
    monkeypatch.setattr(x_alert, 'send_alert', lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError('send failed')))

    with app.app_context():
        result = x_alert.execute_x_alert_cycle(force=True)

    assert result['result'] == 'failed'
    assert result['error'] == 'send failed'