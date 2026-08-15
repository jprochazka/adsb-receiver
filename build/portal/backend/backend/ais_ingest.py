import argparse
import hashlib
import json
import logging
import math
import signal
import socket
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy.exc import IntegrityError, OperationalError

from backend import create_app
from backend.models import AisPosition, AisRawMessage, AisTarget, AisVoyageReport, db


DEFAULT_BIND_ADDRESS = '127.0.0.1'
DEFAULT_PORT = 5556
DEFAULT_MAX_DATAGRAM_SIZE = 65535
DEFAULT_DUPLICATE_BUCKET_SECONDS = 10
DEFAULT_RAW_RETENTION_DAYS = 7
MAX_CLOCK_SKEW_SECONDS = 300
MAX_TIMESTAMP_AGE_SECONDS = 365 * 24 * 60 * 60


@dataclass(frozen=True)
class AisEvent:
    rxuxtime: float
    channel: str
    mmsi: str
    message_type: int
    nmea: str
    target_kind: str
    latitude: Optional[float]
    longitude: Optional[float]
    speed: Optional[float]
    course: Optional[float]
    heading: Optional[int]
    turn_rate: Optional[float]
    navigation_status: Optional[int]
    signal_strength: Optional[float]
    frequency: Optional[float]
    static: dict[str, Any]
    voyage: dict[str, Any]
    decoder_version: Optional[str]


class AisValidationError(ValueError):
    pass


def _number(value: Any, field: str) -> Optional[float]:
    if value is None or value == '':
        return None
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise AisValidationError(f'{field} must be numeric') from exc
    if not math.isfinite(result):
        raise AisValidationError(f'{field} must be finite')
    return result


def _int(value: Any, field: str) -> Optional[int]:
    number = _number(value, field)
    return None if number is None else int(number)


def _sentinel(value: Any, unavailable: set[Any]) -> Any:
    if value in unavailable:
        return None
    return value


def _first(payload: dict[str, Any], *names: str) -> Any:
    for name in names:
        if name in payload:
            return payload[name]
    return None


def _timestamp(value: Any) -> float:
    if isinstance(value, str):
        try:
            value = float(value)
        except ValueError as exc:
            raise AisValidationError('rxuxtime must be numeric') from exc
    if not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise AisValidationError('rxuxtime must be a finite number')
    result = float(value)
    if result > 10_000_000_000:
        result /= 1_000_000
    now = time.time()
    if result <= 0 or result > now + MAX_CLOCK_SKEW_SECONDS:
        raise AisValidationError('rxuxtime is outside the accepted clock window')
    if result < now - MAX_TIMESTAMP_AGE_SECONDS:
        raise AisValidationError('rxuxtime is too old')
    return result


def _nmea_text(value: Any) -> str:
    if isinstance(value, list):
        value = '\n'.join(str(item).strip() for item in value)
    if not isinstance(value, str):
        raise AisValidationError('nmea must be a string or list of strings')
    lines = [line.strip() for line in value.splitlines() if line.strip()]
    if not lines or any(not line.startswith(('!', '$')) for line in lines):
        raise AisValidationError('nmea must contain NMEA sentences')
    return '\n'.join(lines)


def _target_kind(message_type: int, payload: dict[str, Any]) -> str:
    explicit = _first(payload, 'target_kind', 'targetType', 'kind')
    if explicit:
        return str(explicit).strip().lower().replace(' ', '_')[:32]
    return {
        4: 'base_station',
        9: 'sar_aircraft',
        21: 'aid_to_navigation',
        28: 'aid_to_navigation',
    }.get(message_type, 'vessel')


def _decoded_payload(payload: dict[str, Any]) -> dict[str, Any]:
    for name in ('msg', 'message', 'decoded', 'data'):
        nested = payload.get(name)
        if isinstance(nested, dict):
            return nested
    return payload


def normalize_message(payload: dict[str, Any]) -> AisEvent:
    if not isinstance(payload, dict):
        raise AisValidationError('datagram must contain a JSON object')

    decoded = _decoded_payload(payload)
    rxuxtime = _timestamp(payload.get('rxuxtime'))
    channel = str(payload.get('channel', '')).strip()
    if not channel:
        raise AisValidationError('channel is required')
    mmsi_value = _first(payload, 'mmsi', 'MMSI', 'userid')
    if isinstance(mmsi_value, float) and not mmsi_value.is_integer():
        raise AisValidationError('mmsi must be an integer')
    mmsi = str(mmsi_value or '').strip()
    if not mmsi.isdigit() or len(mmsi) != 9:
        raise AisValidationError('mmsi must be a nine-digit identifier')
    message_type = _int(_first(payload, 'type', 'message_type', 'msgtype', 'msg_type'), 'type')
    if message_type is None or message_type < 1 or message_type > 99:
        raise AisValidationError('type must be a positive AIS message type')
    nmea = _nmea_text(payload.get('nmea'))

    latitude = _number(_sentinel(_first(decoded, 'lat', 'latitude'), {None, 91, 91.0, 181, 181.0}), 'latitude')
    longitude = _number(_sentinel(_first(decoded, 'lon', 'longitude'), {None, 181, 181.0, 91, 91.0}), 'longitude')
    if (latitude is None) != (longitude is None):
        raise AisValidationError('latitude and longitude must be provided together')
    if latitude is not None and not -90 <= latitude <= 90:
        raise AisValidationError('latitude is outside valid bounds')
    if longitude is not None and not -180 <= longitude <= 180:
        raise AisValidationError('longitude is outside valid bounds')

    speed = _number(_sentinel(_first(decoded, 'sog', 'speed'), {None, 102.3, 102.2, 102.0}), 'speed')
    course = _number(_sentinel(_first(decoded, 'cog', 'course'), {None, 360, 360.0, 3600, 3600.0}), 'course')
    heading = _int(_sentinel(_first(decoded, 'heading', 'true_heading'), {None, 511, 511.0}), 'heading')
    turn_rate = _number(_sentinel(_first(decoded, 'rot', 'turn', 'turn_rate'), {None, -128, 128}), 'turn_rate')
    navigation_status = _int(_sentinel(_first(decoded, 'status', 'nav_status', 'navigation_status'), {None, 15}), 'navigation_status')

    static = {
        'imo': str(_first(decoded, 'imo', 'imo_number') or '').strip() or None,
        'callsign': str(_first(decoded, 'callsign', 'call_sign') or '').strip() or None,
        'name': str(_first(decoded, 'shipname', 'ship_name', 'name') or '').strip() or None,
        'vessel_type': _int(_first(decoded, 'shiptype', 'ship_type', 'vessel_type'), 'vessel_type'),
        'dimensions': _first(decoded, 'dimension', 'dimensions') or {
            name: decoded.get(name)
            for name in ('to_bow', 'to_stern', 'to_port', 'to_starboard')
            if decoded.get(name) is not None
        } or None,
    }
    voyage = {
        'destination': str(_first(decoded, 'destination') or '').strip() or None,
        'eta_month': _int(_first(decoded, 'eta_month', 'month'), 'eta_month'),
        'eta_day': _int(_first(decoded, 'eta_day', 'day'), 'eta_day'),
        'eta_hour': _int(_first(decoded, 'eta_hour', 'hour'), 'eta_hour'),
        'eta_minute': _int(_first(decoded, 'eta_minute', 'minute'), 'eta_minute'),
        'draught': _number(_first(decoded, 'draught', 'draft'), 'draught'),
    }
    return AisEvent(
        rxuxtime=rxuxtime,
        channel=channel[:16],
        mmsi=mmsi,
        message_type=message_type,
        nmea=nmea,
        target_kind=_target_kind(message_type, decoded),
        latitude=latitude,
        longitude=longitude,
        speed=speed,
        course=course,
        heading=heading,
        turn_rate=turn_rate,
        navigation_status=navigation_status,
        signal_strength=_number(_first(payload, 'signalpower', 'signal_strength', 'rssi'), 'signal_strength'),
        frequency=_number(_first(payload, 'frequency', 'freq'), 'frequency'),
        static=static,
        voyage=voyage,
        decoder_version=str(payload.get('version') or payload.get('decoder_version') or '').strip() or None,
    )


def duplicate_fingerprint(event: AisEvent, receiver_identity: str = 'ais-catcher', bucket_seconds: int = DEFAULT_DUPLICATE_BUCKET_SECONDS) -> str:
    bucket = int(event.rxuxtime // bucket_seconds)
    canonical = f'{event.nmea}\n{receiver_identity}\n{bucket}'
    return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


def _utc_datetime(timestamp: float) -> datetime:
    return datetime.fromtimestamp(timestamp, timezone.utc)


def _merge_non_null(target: AisTarget, values: dict[str, Any]) -> None:
    for field, value in values.items():
        if value is not None and value != '':
            setattr(target, field, value)


def store_event(event: AisEvent, raw_payload: Optional[str] = None, receiver_identity: str = 'ais-catcher') -> str:
    received_at = _utc_datetime(event.rxuxtime)
    fingerprint = duplicate_fingerprint(event, receiver_identity)
    target = AisTarget.query.filter_by(mmsi=event.mmsi, target_kind=event.target_kind).one_or_none()
    if target is None:
        target = AisTarget(
            mmsi=event.mmsi,
            target_kind=event.target_kind,
            first_seen=received_at,
            last_seen=received_at,
        )
        db.session.add(target)
        db.session.flush()

    duplicate = AisPosition.query.filter_by(target_id=target.id, fingerprint=fingerprint).first()
    if duplicate is not None:
        return 'duplicate'

    _merge_non_null(target, event.static)
    target.last_seen = max(target.last_seen, received_at)
    target.channel = event.channel
    if event.latitude is not None and event.longitude is not None:
        target.latitude = event.latitude
        target.longitude = event.longitude
        target.position_timestamp = received_at
        target.speed = event.speed
        target.course = event.course
        target.heading = event.heading
        target.turn_rate = event.turn_rate
        target.navigation_status = event.navigation_status

    position = AisPosition(
        target=target,
        received_at=received_at,
        position_timestamp=received_at if event.latitude is not None else None,
        message_type=event.message_type,
        channel=event.channel,
        latitude=event.latitude,
        longitude=event.longitude,
        speed=event.speed,
        course=event.course,
        heading=event.heading,
        turn_rate=event.turn_rate,
        navigation_status=event.navigation_status,
        signal_strength=event.signal_strength,
        frequency=event.frequency,
        fingerprint=fingerprint,
    )
    db.session.add(position)

    if any(value is not None for value in event.voyage.values()):
        target.static_report_timestamp = received_at
        db.session.add(AisVoyageReport(target=target, reported_at=received_at, **event.static, **event.voyage))

    if raw_payload is not None:
        from datetime import timedelta
        db.session.add(AisRawMessage(
            target=target,
            received_at=received_at,
            expires_at=received_at + timedelta(days=DEFAULT_RAW_RETENTION_DAYS),
            nmea=event.nmea,
            payload=raw_payload,
            channel=event.channel,
            message_type=event.message_type,
            decoder_version=event.decoder_version,
        ))
    return 'accepted'


class AisIngestor:
    def __init__(self, receiver_identity: str = 'ais-catcher', commit_batch_size: int = 25):
        self.receiver_identity = receiver_identity
        self.commit_batch_size = max(1, commit_batch_size)
        self.received = 0
        self.accepted = 0
        self.duplicates = 0
        self.invalid = 0
        self.failed = 0
        self.unknown_type = 0
        self.pending = 0

    def process_datagram(self, data: bytes) -> str:
        self.received += 1
        try:
            raw_payload = data.decode('utf-8')
            payload = json.loads(raw_payload)
            event = normalize_message(payload)
            if event.message_type not in {1, 2, 3, 4, 5, 9, 18, 19, 21, 24, 27}:
                self.unknown_type += 1
            result = store_event(event, raw_payload, self.receiver_identity)
            if result == 'duplicate':
                self.duplicates += 1
            else:
                self.accepted += 1
                self.pending += 1
            return result
        except (UnicodeDecodeError, json.JSONDecodeError, AisValidationError) as exc:
            self.invalid += 1
            logging.warning('Rejected AIS datagram: %s', exc)
            return 'invalid'

    def commit(self) -> None:
        if self.pending:
            db.session.commit()
            self.pending = 0

    def rollback(self) -> None:
        db.session.rollback()
        self.pending = 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='AIS-catcher JSON_FULL UDP ingestion service')
    parser.add_argument('--bind', default=DEFAULT_BIND_ADDRESS)
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--database', default=None)
    parser.add_argument('--batch-size', type=int, default=25)
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    if args.database:
        app = create_app({
            'SQLALCHEMY_DATABASE_URI': f'sqlite:///{args.database}',
            'JWT_SECRET_KEY': 'ais-ingest-service',
        })
    else:
        app = create_app()
    stopping = False

    def stop_handler(signum, frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop_handler)
    signal.signal(signal.SIGINT, stop_handler)
    ingestor = AisIngestor(commit_batch_size=args.batch_size)
    with app.app_context(), socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server:
        server.bind((args.bind, args.port))
        server.settimeout(1.0)
        logging.info('AIS ingest listening on %s:%s', args.bind, args.port)
        while not stopping:
            try:
                data, _ = server.recvfrom(DEFAULT_MAX_DATAGRAM_SIZE)
            except socket.timeout:
                continue
            try:
                ingestor.process_datagram(data)
                if ingestor.pending >= ingestor.commit_batch_size:
                    ingestor.commit()
            except (IntegrityError, OperationalError) as exc:
                ingestor.failed += 1
                ingestor.rollback()
                logging.warning('AIS database write failed: %s', exc)
                time.sleep(min(2, 0.1 * (2 ** min(4, ingestor.failed))))
            except Exception:
                ingestor.failed += 1
                ingestor.rollback()
                logging.exception('Unexpected AIS ingest failure')
        try:
            ingestor.commit()
        except Exception:
            ingestor.rollback()
            logging.exception('Could not flush AIS ingest batch during shutdown')
    return 0


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    raise SystemExit(main())
