import json
import logging
import math
import os
import tempfile
import threading
import time

from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from urllib.error import URLError
from urllib.request import Request, urlopen

from flask import current_app
from sqlalchemy import select

from backend.jobs.aircraft_data_collection import aircraft_altitude, log_job_message
from backend.models import Aircraft, Dump978Aircraft, Dump978Position, Position, Setting, db


DUMP1090_URL = 'http://127.0.0.1/dump1090/data/aircraft.json'
DUMP978_URL = 'http://127.0.0.1/dump978/data/aircraft.json'
EARTH_RADIUS_NM = 3440.065
MAX_SEEN_SECONDS = 60.0

SETTING_DEFAULTS = {
	'x_alert_enabled': 'false',
	'x_alert_poll_seconds': '15',
	'x_alert_receiver_lat': '',
	'x_alert_receiver_lon': '',
	'x_alert_radius_nm': '3.0',
	'x_alert_min_altitude_ft': '500',
	'x_alert_max_altitude_ft': '15000',
	'x_alert_min_speed_kt': '80',
	'x_alert_cooldown_minutes': '30',
	'x_alert_ignore_no_callsign': 'false',
	'x_alert_post_mode': 'log-only',
	'x_alert_x_api_key': '',
	'x_alert_x_api_secret': '',
	'x_alert_x_access_token': '',
	'x_alert_x_access_secret': '',
	'x_alert_image_enabled': 'false',
	'x_alert_image_lookback_minutes': '10',
	'x_alert_image_width': '1024',
	'x_alert_image_height': '768',
	'x_alert_image_track_points_max': '150',
	'x_alert_image_fallback_text_only': 'true',
}

SECRET_SETTING_NAMES = {
	'x_alert_x_api_key',
	'x_alert_x_api_secret',
	'x_alert_x_access_token',
	'x_alert_x_access_secret',
}


@dataclass(frozen=True)
class AlertConfig:
	enabled: bool
	poll_seconds: int
	receiver_lat: float | None
	receiver_lon: float | None
	radius_nm: float
	min_altitude_ft: int
	max_altitude_ft: int
	min_speed_kt: int
	cooldown_minutes: int
	ignore_no_callsign: bool
	post_mode: str
	api_key: str
	api_secret: str
	access_token: str
	access_secret: str
	image_enabled: bool
	image_lookback_minutes: int
	image_width: int
	image_height: int
	image_track_points_max: int
	image_fallback_text_only: bool


@dataclass(frozen=True)
class NormalizedAircraft:
	source: str
	icao: str
	callsign: str
	latitude: float
	longitude: float
	altitude_ft: int
	speed_kt: int
	track_deg: int | None
	seen_seconds: float
	distance_nm: float = 0.0


_state_lock = threading.Lock()
_run_lock = threading.Lock()
_cooldowns: dict[str, datetime] = {}
_last_scheduled_run = 0.0
_status = {
	'last_run': None,
	'last_result': 'never',
	'last_error': None,
	'posted_since_start': 0,
	'suppressed_since_start': 0,
	'dump1090_status': 'unknown',
	'dump978_status': 'unknown',
	'seen': 0,
	'eligible': 0,
	'last_image_result': 'never',
	'last_image_at': None,
}


def _as_bool(value: str, default: bool = False) -> bool:
	if value is None:
		return default
	return str(value).strip().lower() in {'1', 'true', 'yes', 'on'}


def _as_int(value: str, default: int, minimum: int, maximum: int) -> int:
	try:
		parsed = int(value)
	except (TypeError, ValueError):
		return default
	return max(minimum, min(maximum, parsed))


def _as_float(value: str, default: float, minimum: float, maximum: float) -> float:
	try:
		parsed = float(value)
	except (TypeError, ValueError):
		return default
	return max(minimum, min(maximum, parsed))


def _optional_float(value: str, minimum: float, maximum: float) -> float | None:
	try:
		parsed = float(value)
	except (TypeError, ValueError):
		return None
	if parsed < minimum or parsed > maximum:
		return None
	return parsed


def ensure_x_alert_settings() -> None:
	existing_names = set(db.session.execute(
		select(Setting.name).where(Setting.name.in_(SETTING_DEFAULTS))
	).scalars())
	for name, value in SETTING_DEFAULTS.items():
		if name not in existing_names:
			db.session.add(Setting(name=name, value=value))
	db.session.commit()


def get_x_alert_setting_values() -> dict[str, str]:
	rows = db.session.execute(
		select(Setting).where(Setting.name.in_(SETTING_DEFAULTS))
	).scalars()
	values = dict(SETTING_DEFAULTS)
	values.update({row.name: row.value for row in rows})
	return values


def load_config() -> AlertConfig:
	values = get_x_alert_setting_values()
	receiver_lat = _optional_float(values['x_alert_receiver_lat'], -90.0, 90.0)
	receiver_lon = _optional_float(values['x_alert_receiver_lon'], -180.0, 180.0)

	if receiver_lat is None or receiver_lon is None:
		fallback_rows = db.session.execute(
			select(Setting).where(Setting.name.in_({'live_map_center_lat', 'live_map_center_lon'}))
		).scalars()
		fallback = {row.name: row.value for row in fallback_rows}
		receiver_lat = receiver_lat if receiver_lat is not None else _optional_float(
			fallback.get('live_map_center_lat', ''), -90.0, 90.0
		)
		receiver_lon = receiver_lon if receiver_lon is not None else _optional_float(
			fallback.get('live_map_center_lon', ''), -180.0, 180.0
		)

	return AlertConfig(
		enabled=_as_bool(values['x_alert_enabled']),
		poll_seconds=_as_int(values['x_alert_poll_seconds'], 15, 15, 3600),
		receiver_lat=receiver_lat,
		receiver_lon=receiver_lon,
		radius_nm=_as_float(values['x_alert_radius_nm'], 3.0, 0.1, 250.0),
		min_altitude_ft=_as_int(values['x_alert_min_altitude_ft'], 500, -2000, 100000),
		max_altitude_ft=_as_int(values['x_alert_max_altitude_ft'], 15000, -2000, 100000),
		min_speed_kt=_as_int(values['x_alert_min_speed_kt'], 80, 0, 2000),
		cooldown_minutes=_as_int(values['x_alert_cooldown_minutes'], 30, 1, 10080),
		ignore_no_callsign=_as_bool(values['x_alert_ignore_no_callsign']),
		post_mode=values['x_alert_post_mode'] if values['x_alert_post_mode'] in {'log-only', 'x-api'} else 'log-only',
		api_key=values['x_alert_x_api_key'],
		api_secret=values['x_alert_x_api_secret'],
		access_token=values['x_alert_x_access_token'],
		access_secret=values['x_alert_x_access_secret'],
		image_enabled=_as_bool(values['x_alert_image_enabled']),
		image_lookback_minutes=_as_int(values['x_alert_image_lookback_minutes'], 10, 1, 180),
		image_width=_as_int(values['x_alert_image_width'], 1024, 320, 2048),
		image_height=_as_int(values['x_alert_image_height'], 768, 240, 2048),
		image_track_points_max=_as_int(values['x_alert_image_track_points_max'], 150, 2, 1000),
		image_fallback_text_only=_as_bool(values['x_alert_image_fallback_text_only'], True),
	)


def fetch_aircraft_json(url: str) -> dict | None:
	request = Request(url, headers={'User-Agent': 'adsb-receiver-x-alert/1.0'})
	try:
		with urlopen(request, timeout=10) as response:
			payload = json.load(response)
		return payload if isinstance(payload, dict) else None
	except (OSError, URLError, json.JSONDecodeError, ValueError):
		logging.warning('[x_alert] Failed to read %s', url, exc_info=True)
		return None


def normalize_aircraft(raw: dict, source: str) -> NormalizedAircraft | None:
	required = ('hex', 'lat', 'lon', 'gs')
	if not all(raw.get(key) is not None for key in required):
		return None
	altitude = aircraft_altitude(raw)
	if not isinstance(altitude, (int, float)):
		return None
	try:
		seen = float(raw.get('seen', 0.0))
		return NormalizedAircraft(
			source=source,
			icao=str(raw['hex']).strip().lower(),
			callsign=str(raw.get('flight', '')).strip(),
			latitude=float(raw['lat']),
			longitude=float(raw['lon']),
			altitude_ft=int(altitude),
			speed_kt=int(float(raw['gs'])),
			track_deg=int(float(raw['track'])) if raw.get('track') is not None else None,
			seen_seconds=seen,
		)
	except (TypeError, ValueError):
		return None


def haversine_nm(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	lat1_rad, lat2_rad = math.radians(lat1), math.radians(lat2)
	delta_lat = math.radians(lat2 - lat1)
	delta_lon = math.radians(lon2 - lon1)
	a = math.sin(delta_lat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2
	return EARTH_RADIUS_NM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def select_candidates(aircraft: list[NormalizedAircraft], config: AlertConfig) -> list[NormalizedAircraft]:
	if config.receiver_lat is None or config.receiver_lon is None:
		return []
	candidates = []
	for item in aircraft:
		if item.seen_seconds >= MAX_SEEN_SECONDS:
			continue
		if config.ignore_no_callsign and not item.callsign:
			continue
		if not config.min_altitude_ft <= item.altitude_ft <= config.max_altitude_ft:
			continue
		if item.speed_kt < config.min_speed_kt:
			continue
		distance = haversine_nm(config.receiver_lat, config.receiver_lon, item.latitude, item.longitude)
		if distance <= config.radius_nm:
			candidates.append(NormalizedAircraft(**{**asdict(item), 'distance_nm': distance}))
	return sorted(candidates, key=lambda item: (item.distance_nm, item.altitude_ft))


def _dedup_key(aircraft: NormalizedAircraft) -> str:
	return (aircraft.callsign or aircraft.icao).upper()


def _is_suppressed(aircraft: NormalizedAircraft, now: datetime, cooldown_minutes: int) -> bool:
	key = _dedup_key(aircraft)
	cutoff = now - timedelta(minutes=cooldown_minutes)
	with _state_lock:
		expired = [item_key for item_key, sent_at in _cooldowns.items() if sent_at < cutoff]
		for item_key in expired:
			_cooldowns.pop(item_key, None)
		return _cooldowns.get(key, datetime.min.replace(tzinfo=timezone.utc)) >= cutoff


def _mark_posted(aircraft: NormalizedAircraft, now: datetime) -> None:
	with _state_lock:
		_cooldowns[_dedup_key(aircraft)] = now
		_status['posted_since_start'] += 1


def format_alert(aircraft: NormalizedAircraft, now: datetime) -> str:
	identifier = aircraft.callsign or aircraft.icao.upper()
	heading = f'{aircraft.track_deg} deg' if aircraft.track_deg is not None else 'unknown heading'
	source = 'UAT' if aircraft.source == 'uat' else 'ADS-B'
	return (
		f'{identifier} overhead: {aircraft.distance_nm:.1f} NM, '
		f'{aircraft.altitude_ft:,} ft, {aircraft.speed_kt} kt, {heading}. '
		f'{source} at {now:%H:%M} UTC.'
	)


def _track_points(aircraft: NormalizedAircraft, config: AlertConfig) -> list[tuple[float, float]]:
	if aircraft.source == 'uat':
		aircraft_model, position_model = Dump978Aircraft, Dump978Position
	else:
		aircraft_model, position_model = Aircraft, Position
	aircraft_row = db.session.execute(
		select(aircraft_model).where(aircraft_model.icao == aircraft.icao)
	).scalar_one_or_none()
	if not aircraft_row:
		return []
	cutoff = str(datetime.now(timezone.utc) - timedelta(minutes=config.image_lookback_minutes))
	rows = db.session.execute(
		select(position_model)
		.where(position_model.aircraft == aircraft_row.id, position_model.time >= cutoff)
		.order_by(position_model.id.desc())
		.limit(config.image_track_points_max)
	).scalars()
	return [(row.longitude, row.latitude) for row in reversed(list(rows))]


def render_map_image(aircraft: NormalizedAircraft, config: AlertConfig) -> str:
	try:
		from PIL import ImageDraw
		from staticmap import CircleMarker, Line, StaticMap
	except ImportError as ex:
		raise RuntimeError('Map image dependencies staticmap and Pillow are not installed') from ex

	points = _track_points(aircraft, config)
	current_point = (aircraft.longitude, aircraft.latitude)
	if not points or points[-1] != current_point:
		points.append(current_point)

	map_image = StaticMap(
		config.image_width,
		config.image_height,
		url_template='https://tile.openstreetmap.org/{z}/{x}/{y}.png',
		headers={'User-Agent': 'adsb-receiver-x-alert/1.0'},
	)
	if len(points) > 1:
		map_image.add_line(Line(points, '#1677ff', 4))
	map_image.add_marker(CircleMarker((config.receiver_lon, config.receiver_lat), '#dc3545', 10))
	map_image.add_marker(CircleMarker(current_point, '#111111', 9))
	image = map_image.render()
	draw = ImageDraw.Draw(image)
	draw.rectangle((0, config.image_height - 24, config.image_width, config.image_height), fill=(255, 255, 255, 220))
	draw.text((8, config.image_height - 19), 'Map data © OpenStreetMap contributors', fill='#222222')

	with tempfile.NamedTemporaryFile(prefix='x-alert-', suffix='.png', delete=False) as output:
		image.save(output.name, format='PNG')
		return output.name


def send_alert(message: str, config: AlertConfig, image_path: str | None = None) -> None:
	if config.post_mode == 'log-only':
		log_job_message('x_alert', message)
		return
	if not all((config.api_key, config.api_secret, config.access_token, config.access_secret)):
		raise RuntimeError('X API credentials are incomplete')
	try:
		import tweepy
	except ImportError as ex:
		raise RuntimeError('The tweepy package is not installed') from ex

	media_ids = None
	if image_path:
		auth = tweepy.OAuth1UserHandler(config.api_key, config.api_secret, config.access_token, config.access_secret)
		media = tweepy.API(auth).media_upload(image_path)
		media_ids = [media.media_id]
	client = tweepy.Client(
		consumer_key=config.api_key,
		consumer_secret=config.api_secret,
		access_token=config.access_token,
		access_token_secret=config.access_secret,
	)
	client.create_tweet(text=message, media_ids=media_ids)


def get_x_alert_status() -> dict:
	with _state_lock:
		return dict(_status)


def execute_x_alert_cycle(*, dry_run: bool = False, force: bool = False) -> dict:
	global _last_scheduled_run
	if not _run_lock.acquire(blocking=False):
		return {'result': 'skipped', 'reason': 'already_running'}
	now = datetime.now(timezone.utc)
	cycle = {'seen': 0, 'eligible': 0, 'posted': 0, 'suppressed': 0, 'failed': 0, 'messages': []}
	try:
		config = load_config()
		monotonic_now = time.monotonic()
		if not force and monotonic_now - _last_scheduled_run < config.poll_seconds:
			return {'result': 'skipped', 'reason': 'poll_interval'}
		_last_scheduled_run = monotonic_now
		if not config.enabled and not force:
			return {'result': 'disabled', **cycle}
		if config.receiver_lat is None or config.receiver_lon is None:
			raise RuntimeError('Receiver latitude and longitude are not configured')
		if config.min_altitude_ft > config.max_altitude_ft:
			raise RuntimeError('Minimum altitude cannot exceed maximum altitude')

		normalized = []
		source_status = {}
		for source, url in (('dump1090', DUMP1090_URL), ('dump978', DUMP978_URL)):
			payload = fetch_aircraft_json(url)
			source_status[f'{source}_status'] = 'up' if payload is not None else 'down'
			if payload:
				normalized.extend(
					item for raw in payload.get('aircraft', [])
					if (item := normalize_aircraft(raw, 'uat' if source == 'dump978' else 'adsb')) is not None
				)

		cycle['seen'] = len(normalized)
		candidates = select_candidates(normalized, config)
		cycle['eligible'] = len(candidates)

		for aircraft in candidates:
			if _is_suppressed(aircraft, now, config.cooldown_minutes):
				cycle['suppressed'] += 1
				continue
			message = format_alert(aircraft, now)
			cycle['messages'].append(message)
			if dry_run:
				continue

			image_path = None
			try:
				if config.image_enabled:
					try:
						image_path = render_map_image(aircraft, config)
						with _state_lock:
							_status.update({'last_image_result': 'success', 'last_image_at': now.isoformat()})
					except Exception:
						with _state_lock:
							_status.update({'last_image_result': 'failed', 'last_image_at': now.isoformat()})
						if not config.image_fallback_text_only:
							raise
						logging.warning('[x_alert] Map generation failed; posting text-only', exc_info=True)
				send_alert(message, config, image_path)
				_mark_posted(aircraft, now)
				cycle['posted'] += 1
			except Exception:
				if not image_path or not config.image_fallback_text_only:
					raise
				logging.warning('[x_alert] Image post failed; retrying text-only', exc_info=True)
				send_alert(message, config)
				_mark_posted(aircraft, now)
				cycle['posted'] += 1
			finally:
				if image_path:
					try:
						os.unlink(image_path)
					except OSError:
						logging.warning('[x_alert] Failed to remove temporary image %s', image_path)

		with _state_lock:
			_status.update({
				'last_run': now.isoformat(),
				'last_result': 'success',
				'last_error': None,
				'seen': cycle['seen'],
				'eligible': cycle['eligible'],
				'suppressed_since_start': _status['suppressed_since_start'] + cycle['suppressed'],
				**source_status,
			})
		log_job_message(
			'x_alert',
			'Cycle complete: seen=%d eligible=%d posted=%d suppressed=%d failed=%d' % (
				cycle['seen'], cycle['eligible'], cycle['posted'], cycle['suppressed'], cycle['failed']
			),
		)
		return {'result': 'success', **cycle}
	except Exception as ex:
		cycle['failed'] += 1
		logging.error('[x_alert] Cycle failed', exc_info=True)
		with _state_lock:
			_status.update({'last_run': now.isoformat(), 'last_result': 'failed', 'last_error': str(ex)})
		return {'result': 'failed', 'error': str(ex), **cycle}
	finally:
		_run_lock.release()


def x_alert_job() -> None:
	with current_app.app_context():
		execute_x_alert_cycle()
