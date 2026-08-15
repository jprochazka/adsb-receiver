import json
import time
from pathlib import Path

import pytest

from backend.ais_ingest import (
    AisValidationError,
    duplicate_fingerprint,
    normalize_message,
)


def valid_message(**overrides):
    message = {
        'rxuxtime': time.time(),
        'channel': 'A',
        'mmsi': 244123456,
        'type': 1,
        'nmea': '!AIVDM,1,1,,A,15N:;P0P00PD;88MD5MTDwwvl0<0,0*00',
        'lat': 52.1,
        'lon': 4.2,
        'sog': 12.5,
        'cog': 181.2,
        'heading': 180,
    }
    message.update(overrides)
    return message


def test_normalize_position_message():
    event = normalize_message(valid_message())

    assert event.mmsi == '244123456'
    assert event.latitude == 52.1
    assert event.longitude == 4.2
    assert event.speed == 12.5
    assert event.target_kind == 'vessel'


def test_normalize_sentinel_values_to_none():
    event = normalize_message(valid_message(sog=102.3, cog=360, heading=511))

    assert event.speed is None
    assert event.course is None
    assert event.heading is None


def test_normalize_ais_catcher_field_names():
    event = normalize_message(valid_message(status=5, turn=2.5, month=7, day=8, hour=9, minute=10))

    assert event.navigation_status == 5
    assert event.turn_rate == 2.5
    assert event.voyage['eta_month'] == 7
    assert event.voyage['eta_minute'] == 10


def test_reject_mismatched_coordinates():
    with pytest.raises(AisValidationError, match='latitude and longitude'):
        normalize_message(valid_message(lon=None))


def test_classify_special_target_types():
    assert normalize_message(valid_message(type=4)).target_kind == 'base_station'
    assert normalize_message(valid_message(type=9)).target_kind == 'sar_aircraft'
    assert normalize_message(valid_message(type=21)).target_kind == 'aid_to_navigation'


def test_accept_unknown_future_message_type():
    event = normalize_message(valid_message(type=28))

    assert event.message_type == 28


def test_duplicate_fingerprint_changes_after_bucket():
    timestamp = time.time()
    first = normalize_message(valid_message(rxuxtime=timestamp))
    second = normalize_message(valid_message(rxuxtime=timestamp + 11))

    assert duplicate_fingerprint(first) != duplicate_fingerprint(second)


def test_reference_fixtures_cover_initial_message_set():
    fixture_directory = Path(__file__).parents[1] / 'fixtures' / 'ais'
    packets = []
    for fixture_path in fixture_directory.glob('*.json'):
        packets.extend(json.loads(fixture_path.read_text(encoding='utf-8')))

    assert {packet['type'] for packet in packets} >= {1, 4, 5, 9, 18, 19, 21, 24, 27}
    assert sum(packet['type'] == 24 and packet.get('partno') == 0 for packet in packets) == 1
    assert sum(packet['type'] == 24 and packet.get('partno') == 1 for packet in packets) == 1
