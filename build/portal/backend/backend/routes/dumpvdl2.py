import math
import os
import shlex
import subprocess

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields

from backend.auth import require_admin


dumpvdl2 = Blueprint('dumpvdl2', __name__)
dumpvdl2_ns = Namespace('dumpvdl2', description='dumpvdl2 decoder configuration')

DUMPVDL2_SERVICE = 'dumpvdl2.service'
ACARS_INGEST_SERVICE = 'acars-ingest.service'
DEFAULT_CONFIG_PATH = '/etc/default/dumpvdl2'
DEFAULT_CONFIG_HELPER = '/usr/local/sbin/adsb-receiver-dumpvdl2-config'
MIN_FREQUENCY_MHZ = 118.0
MAX_FREQUENCY_MHZ = 137.0
MAX_FREQUENCIES = 20


dumpvdl2_config_model = dumpvdl2_ns.model('Dumpvdl2Config', {
    'installed': restx_fields.Boolean(required=True),
    'active': restx_fields.Boolean(required=True),
    'ingest_active': restx_fields.Boolean(required=True),
    'frequencies': restx_fields.List(restx_fields.Float, required=True),
})

update_dumpvdl2_config_model = dumpvdl2_ns.model('UpdateDumpvdl2Config', {
    'frequencies': restx_fields.List(
        restx_fields.Float,
        required=True,
        min_items=1,
        max_items=MAX_FREQUENCIES,
    ),
})


def _config_path() -> str:
    return os.environ.get('DUMPVDL2_CONFIG_PATH', DEFAULT_CONFIG_PATH)


def _config_helper_path() -> str:
    return os.environ.get('DUMPVDL2_CONFIG_HELPER', DEFAULT_CONFIG_HELPER)


def _service_active(service_name: str) -> bool:
    try:
        result = subprocess.run(
            ['/usr/bin/systemctl', 'is-active', '--quiet', service_name],
            capture_output=True,
            timeout=5,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _frequency_to_mhz(value: str) -> float:
    normalized = value.strip()
    multiplier = 1.0
    if normalized.lower().endswith('m'):
        normalized = normalized[:-1]
    elif normalized.lower().endswith('k'):
        normalized = normalized[:-1]
        multiplier = 0.001
    frequency = float(normalized) * multiplier
    if frequency > 1_000_000:
        frequency /= 1_000_000
    return round(frequency, 3)


def _read_frequencies() -> list[float]:
    try:
        with open(_config_path(), encoding='utf-8') as config_file:
            for line in config_file:
                key, separator, value = line.partition('=')
                if separator and key.strip() == 'DUMPVDL2_FREQUENCIES':
                    frequency_values = [
                        item
                        for field in shlex.split(value)
                        for item in field.split()
                    ]
                    return [_frequency_to_mhz(item) for item in frequency_values]
    except (FileNotFoundError, OSError, ValueError):
        return []
    return []


def _build_config() -> dict:
    return {
        'installed': os.path.exists(_config_path()),
        'active': _service_active(DUMPVDL2_SERVICE),
        'ingest_active': _service_active(ACARS_INGEST_SERVICE),
        'frequencies': _read_frequencies(),
    }


def _validate_frequencies(values) -> list[float]:
    if not isinstance(values, list) or not values:
        raise ValueError('At least one frequency is required')
    if len(values) > MAX_FREQUENCIES:
        raise ValueError(f'No more than {MAX_FREQUENCIES} frequencies may be configured')

    frequencies = []
    for value in values:
        if isinstance(value, bool):
            raise ValueError('Frequencies must be numeric')
        try:
            frequency = round(float(value), 3)
        except (TypeError, ValueError) as ex:
            raise ValueError('Frequencies must be numeric') from ex
        if not math.isfinite(frequency):
            raise ValueError('Frequencies must be finite')
        if frequency < MIN_FREQUENCY_MHZ or frequency > MAX_FREQUENCY_MHZ:
            raise ValueError(
                f'Frequencies must be between {MIN_FREQUENCY_MHZ:.1f} and '
                f'{MAX_FREQUENCY_MHZ:.1f} MHz'
            )
        frequencies.append(frequency)
    return sorted(set(frequencies))


def _apply_frequencies(frequencies: list[float]):
    helper_path = _config_helper_path()
    if not os.path.isfile(helper_path):
        raise FileNotFoundError(helper_path)
    frequency_arg = ','.join(f'{frequency:.3f}' for frequency in frequencies)
    subprocess.run(
        ['/usr/bin/sudo', '--non-interactive', helper_path, frequency_arg],
        capture_output=True,
        text=True,
        timeout=15,
        check=True,
    )


@dumpvdl2_ns.route('/config')
class Dumpvdl2ConfigResource(Resource):
    @dumpvdl2_ns.response(
        200,
        'dumpvdl2 configuration retrieved successfully',
        dumpvdl2_config_model,
    )
    @dumpvdl2_ns.response(401, 'Unauthorized - authentication required')
    @dumpvdl2_ns.response(403, 'Forbidden - admin role required')
    @dumpvdl2_ns.doc('get_dumpvdl2_config', security='Bearer')
    @require_admin()
    def get(self):
        """Return dumpvdl2 service state and configured frequencies."""
        return _build_config(), 200

    @dumpvdl2_ns.expect(update_dumpvdl2_config_model, validate=True)
    @dumpvdl2_ns.response(
        200,
        'dumpvdl2 configuration updated successfully',
        dumpvdl2_config_model,
    )
    @dumpvdl2_ns.response(400, 'Invalid frequency configuration')
    @dumpvdl2_ns.response(401, 'Unauthorized - authentication required')
    @dumpvdl2_ns.response(403, 'Forbidden - admin role required')
    @dumpvdl2_ns.response(503, 'dumpvdl2 configuration helper unavailable')
    @dumpvdl2_ns.doc('update_dumpvdl2_config', security='Bearer')
    @require_admin()
    def put(self):
        """Update monitored VDL Mode 2 frequencies and restart dumpvdl2."""
        try:
            frequencies = _validate_frequencies((request.get_json(silent=True) or {}).get('frequencies'))
            _apply_frequencies(frequencies)
        except ValueError as ex:
            return {'msg': str(ex)}, 400
        except (
            FileNotFoundError,
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
        ):
            return {'msg': 'dumpvdl2 configuration helper unavailable'}, 503
        return _build_config(), 200
