from datetime import datetime, timedelta, timezone

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from sqlalchemy import func, or_, select

from backend.models import AisPosition, AisRawMessage, AisTarget, AisVoyageReport, Setting, db
from backend.auth import require_admin


ais = Blueprint('ais', __name__)
ais_ns = Namespace('ais', description='AIS target data and history')


ais_target_model = ais_ns.model('AisTarget', {
    'id': restx_fields.Integer,
    'mmsi': restx_fields.String,
    'target_kind': restx_fields.String,
    'imo': restx_fields.String,
    'callsign': restx_fields.String,
    'name': restx_fields.String,
    'vessel_type': restx_fields.Integer,
    'dimensions': restx_fields.Raw,
    'first_seen': restx_fields.DateTime,
    'last_seen': restx_fields.DateTime,
    'latitude': restx_fields.Float,
    'longitude': restx_fields.Float,
    'speed': restx_fields.Float,
    'course': restx_fields.Float,
    'heading': restx_fields.Integer,
    'turn_rate': restx_fields.Float,
    'navigation_status': restx_fields.Integer,
    'channel': restx_fields.String,
    'position_timestamp': restx_fields.DateTime,
    'static_report_timestamp': restx_fields.DateTime,
})


def _pagination():
    try:
        offset = max(0, int(request.args.get('offset', 0)))
        limit = min(1000, max(1, int(request.args.get('limit', 100))))
    except ValueError as exc:
        raise ValueError('offset and limit must be integers') from exc
    return offset, limit


def _parse_datetime(value: str | None):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError as exc:
        raise ValueError('dates must be ISO-8601 timestamps') from exc


def _bbox(value: str | None):
    if not value:
        return None
    try:
        west, south, east, north = (float(item) for item in value.split(','))
    except (TypeError, ValueError) as exc:
        raise ValueError('bbox must be west,south,east,north') from exc
    if not -180 <= west <= 180 or not -180 <= east <= 180 or not -90 <= south <= 90 or not -90 <= north <= 90:
        raise ValueError('bbox contains invalid coordinates')
    return west, south, east, north


def _target_filters(query, *, live=False):
    target_kind = request.args.get('target_kind')
    if target_kind:
        query = query.filter(AisTarget.target_kind == target_kind)
    vessel_type = request.args.get('vessel_type')
    if vessel_type:
        try:
            query = query.filter(AisTarget.vessel_type == int(vessel_type))
        except ValueError as exc:
            raise ValueError('vessel_type must be an integer') from exc
    search = request.args.get('q')
    if search:
        pattern = f'%{search.strip()}%'
        query = query.filter(or_(
            AisTarget.mmsi.like(pattern),
            AisTarget.imo.like(pattern),
            AisTarget.name.like(pattern),
            AisTarget.callsign.like(pattern),
        ))
    if live:
        freshness = float(request.args.get('freshness', 300))
        if freshness <= 0 or freshness > 86400:
            raise ValueError('freshness must be between 1 and 86400 seconds')
        query = query.filter(AisTarget.last_seen >= datetime.now(timezone.utc) - timedelta(seconds=freshness))
        bounds = _bbox(request.args.get('bbox'))
        if bounds:
            west, south, east, north = bounds
            query = query.filter(
                AisTarget.latitude >= south,
                AisTarget.latitude <= north,
                AisTarget.longitude >= west,
                AisTarget.longitude <= east,
            )
    return query


def _collection(query, serializer):
    offset, limit = _pagination()
    total = db.session.scalar(select(func.count()).select_from(query.subquery()))
    items = db.session.scalars(query.offset(offset).limit(limit)).all()
    return {'items': [serializer(item) for item in items], 'total': total, 'offset': offset, 'limit': limit}


@ais_ns.route('/live')
class AisLiveResource(Resource):
    def get(self):
        try:
            query = _target_filters(
                select(AisTarget).where(AisTarget.latitude.is_not(None), AisTarget.longitude.is_not(None)),
                live=True,
            ).order_by(AisTarget.last_seen.desc())
            result = _collection(query, AisTarget.to_dict)
            return result, 200
        except ValueError as exc:
            return {'msg': str(exc)}, 400


@ais_ns.route('/targets')
class AisTargetsResource(Resource):
    def get(self):
        try:
            query = _target_filters(select(AisTarget), live=False)
            for field in ('mmsi', 'imo', 'name', 'callsign'):
                value = request.args.get(field)
                if value:
                    query = query.filter(getattr(AisTarget, field).like(f'%{value.strip()}%'))
            query = query.order_by(AisTarget.last_seen.desc())
            return _collection(query, AisTarget.to_dict), 200
        except ValueError as exc:
            return {'msg': str(exc)}, 400


@ais_ns.route('/targets/<string:mmsi>')
class AisTargetResource(Resource):
    @ais_ns.marshal_with(ais_target_model)
    def get(self, mmsi):
        target = db.session.scalar(select(AisTarget).where(AisTarget.mmsi == mmsi).limit(1))
        if target is None:
            return {'msg': 'AIS target not found'}, 404
        return target.to_dict(), 200


@ais_ns.route('/targets/<string:mmsi>/positions')
class AisPositionsResource(Resource):
    def get(self, mmsi):
        target = db.session.scalar(select(AisTarget).where(AisTarget.mmsi == mmsi).limit(1))
        if target is None:
            return {'msg': 'AIS target not found'}, 404
        try:
            query = select(AisPosition).where(AisPosition.target_id == target.id)
            start = _parse_datetime(request.args.get('from'))
            end = _parse_datetime(request.args.get('to'))
            if start:
                query = query.where(AisPosition.received_at >= start)
            if end:
                query = query.where(AisPosition.received_at <= end)
            return _collection(query.order_by(AisPosition.received_at.desc()), AisPosition.to_dict), 200
        except ValueError as exc:
            return {'msg': str(exc)}, 400


@ais_ns.route('/targets/<string:mmsi>/voyages')
class AisVoyagesResource(Resource):
    def get(self, mmsi):
        target = db.session.scalar(select(AisTarget).where(AisTarget.mmsi == mmsi).limit(1))
        if target is None:
            return {'msg': 'AIS target not found'}, 404
        query = select(AisVoyageReport).where(AisVoyageReport.target_id == target.id)
        return _collection(query.order_by(AisVoyageReport.reported_at.desc()), AisVoyageReport.to_dict), 200


@ais_ns.route('/status')
class AisStatusResource(Resource):
    def get(self):
        latest_position = db.session.scalar(select(AisPosition).order_by(AisPosition.received_at.desc()).limit(1))
        latest_raw = db.session.scalar(select(AisRawMessage).order_by(AisRawMessage.received_at.desc()).limit(1))
        return {
            'last_packet': latest_raw.received_at.isoformat() if latest_raw else None,
            'last_valid_message': latest_position.received_at.isoformat() if latest_position else None,
            'ingest_available': latest_position is not None or latest_raw is not None,
        }, 200


@ais_ns.route('/stats')
class AisStatsResource(Resource):
    def get(self):
        return {
            'targets': db.session.scalar(select(func.count()).select_from(AisTarget)),
            'positions': db.session.scalar(select(func.count()).select_from(AisPosition)),
            'voyages': db.session.scalar(select(func.count()).select_from(AisVoyageReport)),
            'raw_messages': db.session.scalar(select(func.count()).select_from(AisRawMessage)),
        }, 200


AIS_SETTINGS = {
    'ais_map_enabled': 'true',
    'ais_live_freshness_seconds': '300',
    'ais_history_retention_days': '30',
    'ais_raw_capture_enabled': 'false',
    'ais_raw_retention_days': '7',
}


@ais_ns.route('/settings')
class AisSettingsResource(Resource):
    @require_admin()
    def get(self):
        stored = {
            setting.name: setting.value
            for setting in db.session.scalars(select(Setting).where(Setting.name.in_(AIS_SETTINGS)))
        }
        return {name: stored.get(name, default) for name, default in AIS_SETTINGS.items()}, 200

    @require_admin()
    def put(self):
        payload = request.get_json(silent=True) or {}
        unknown = set(payload) - set(AIS_SETTINGS)
        if unknown:
            return {'msg': f'Unknown AIS settings: {", ".join(sorted(unknown))}'}, 400
        for name, value in payload.items():
            if isinstance(value, (dict, list)):
                return {'msg': f'{name} must be a scalar value'}, 400
            setting = db.session.scalar(select(Setting).where(Setting.name == name))
            if setting is None:
                setting = Setting(name=name, value=str(value))
                db.session.add(setting)
            else:
                setting.value = str(value)
        db.session.commit()
        return self.get()


@ais_ns.route('/purge')
class AisPurgeResource(Resource):
    @require_admin()
    def post(self):
        payload = request.get_json(silent=True) or {}
        if payload.get('confirm') is not True:
            return {'msg': 'Purge requires confirm=true'}, 400
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)
        positions = db.session.query(AisPosition).filter(AisPosition.received_at < cutoff).delete(synchronize_session=False)
        voyages = db.session.query(AisVoyageReport).filter(AisVoyageReport.reported_at < cutoff).delete(synchronize_session=False)
        raw = db.session.query(AisRawMessage).filter(AisRawMessage.expires_at < datetime.now(timezone.utc)).delete(synchronize_session=False)
        db.session.commit()
        return {'positions': positions, 'voyages': voyages, 'raw_messages': raw}, 200
