from __future__ import annotations

import csv
import logging
import os
import time
from typing import Dict, Optional, Tuple

from flask import current_app, has_app_context
from sqlalchemy import select, text

from backend.models import db, OpenSkyAircraft


_IMPORT_CHECK_INTERVAL_SECONDS = 30.0
_IMPORT_STATE = {
    'next_check_at': 0.0,
    'mtime': None,
}
_REGISTRATION_CLASS_INDEX: Dict[str, Tuple[str, str]] = {}


def _opensky_csv_path() -> Optional[str]:
    if not has_app_context():
        return None
    return os.path.join(current_app.instance_path, 'opensky', 'aircraftDatabase.csv')


def _normalize_icao24(value: Optional[str]) -> str:
    return (value or '').strip().lower()


def _normalize_registration(value: Optional[str]) -> str:
    raw = (value or '').strip().upper()
    return ''.join(ch for ch in raw if ch.isalnum())


def _map_from_category_description(category_description: str) -> Tuple[Optional[str], Optional[str]]:
    desc = (category_description or '').strip().lower()
    if not desc:
        return None, None

    if 'rotorcraft' in desc or 'helicopter' in desc:
        return 'helicopter', 'high'
    if 'glider' in desc:
        return 'glider', 'high'
    if 'balloon' in desc:
        return 'balloon', 'high'
    if 'uav' in desc or 'unmanned' in desc or 'drone' in desc:
        return 'uav', 'high'
    if 'surface vehicle' in desc or 'ground' in desc:
        return 'ground', 'high'
    if 'military' in desc or 'fighter' in desc or 'tanker' in desc or 'combat' in desc:
        return 'military', 'high'
    if 'large aircraft' in desc or 'airliner' in desc or 'transport' in desc:
        return 'airliner', 'medium'
    if 'light aircraft' in desc or 'ultralight' in desc or 'business' in desc:
        return 'general_aviation', 'medium'

    return None, None


def _map_from_typecode(typecode: str) -> Tuple[Optional[str], Optional[str]]:
    tc = (typecode or '').strip().upper()
    if not tc:
        return None, None

    helicopter_prefixes = ('R22', 'R44', 'R66', 'EC', 'AS', 'AW', 'BK', 'BO', 'UH', 'CH', 'MI', 'KA', 'S76', 'S92')
    if tc.startswith(helicopter_prefixes):
        return 'helicopter', 'medium'

    if tc.startswith(('A3', 'A2', 'A1', 'B7', 'B8', 'B9', 'CRJ', 'E17', 'E19', 'E1', 'DH8', 'AT7', 'AT4')):
        return 'airliner', 'medium'

    if tc.startswith(('C', 'P', 'M')):
        return 'general_aviation', 'low'

    return None, None


def _map_row_to_class(row: Dict[str, str]) -> Tuple[Optional[str], Optional[str]]:
    category_description = row.get('categoryDescription') or row.get('categorydescription') or ''
    klass, confidence = _map_from_category_description(category_description)
    if klass:
        return klass, confidence

    return _map_from_typecode(row.get('typecode') or '')


def _import_csv_to_db(path: str) -> int:
    """Read the CSV, classify each row, and bulk-insert into opensky_aircraft."""
    rows = []
    reg_index: Dict[str, Tuple[str, str]] = {}
    with open(path, mode='r', encoding='utf-8', newline='') as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            icao = _normalize_icao24(row.get('icao24'))
            if not icao:
                continue
            klass, confidence = _map_row_to_class(row)
            if not klass:
                continue
            conf = confidence or 'low'
            rows.append({'icao24': icao, 'aircraft_class': klass, 'confidence': confidence or 'low'})

            registration = _normalize_registration(row.get('registration'))
            if registration and registration not in reg_index:
                reg_index[registration] = (klass, conf)

    db.session.execute(text('DELETE FROM opensky_aircraft'))
    batch_size = 5000
    for i in range(0, len(rows), batch_size):
        db.session.execute(OpenSkyAircraft.__table__.insert(), rows[i:i + batch_size])
    db.session.commit()

    _REGISTRATION_CLASS_INDEX.clear()
    _REGISTRATION_CLASS_INDEX.update(reg_index)
    return len(rows)


def _ensure_imported() -> None:
    """Check if the CSV has changed and re-import if needed."""
    now = time.time()
    if now < _IMPORT_STATE['next_check_at']:
        return

    _IMPORT_STATE['next_check_at'] = now + _IMPORT_CHECK_INTERVAL_SECONDS

    path = _opensky_csv_path()
    if not path or not os.path.exists(path):
        return

    try:
        mtime = os.path.getmtime(path)
    except OSError:
        return
    if _IMPORT_STATE['mtime'] == mtime:
        return

    logging.info('OpenSky CSV changed (mtime=%s), re-importing to database...', mtime)
    count = _import_csv_to_db(path)
    _IMPORT_STATE['mtime'] = mtime
    logging.info('OpenSky import complete: %d classified aircraft', count)


def import_opensky_csv() -> int:
    """Force a full re-import of the OpenSky CSV into the database. Returns row count."""
    path = _opensky_csv_path()
    if not path or not os.path.exists(path):
        return 0
    count = _import_csv_to_db(path)
    _IMPORT_STATE['mtime'] = os.path.getmtime(path)
    _IMPORT_STATE['next_check_at'] = time.time() + _IMPORT_CHECK_INTERVAL_SECONDS
    return count


def clear_opensky_classification_cache() -> None:
    _IMPORT_STATE['next_check_at'] = 0.0
    _IMPORT_STATE['mtime'] = None
    _REGISTRATION_CLASS_INDEX.clear()


def get_opensky_cache_stats() -> Dict[str, Optional[float]]:
    try:
        count = db.session.scalar(text('SELECT COUNT(*) FROM opensky_aircraft'))
    except Exception:
        count = 0
    return {
        'entries': count,
        'loaded_at': None,
    }


def get_opensky_classification(icao24: Optional[str]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    icao = _normalize_icao24(icao24)
    if not icao:
        return None, None, None

    if not has_app_context():
        return None, None, None

    _ensure_imported()

    row = db.session.execute(
        select(OpenSkyAircraft.aircraft_class, OpenSkyAircraft.confidence)
        .where(OpenSkyAircraft.icao24 == icao)
    ).first()

    if not row:
        return None, None, None

    return row.aircraft_class, 'opensky', row.confidence


def get_opensky_classification_by_registration(registration: Optional[str]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    reg = _normalize_registration(registration)
    if not reg:
        return None, None, None

    if not has_app_context():
        return None, None, None

    _ensure_imported()
    hit = _REGISTRATION_CLASS_INDEX.get(reg)
    if not hit:
        return None, None, None

    klass, confidence = hit
    return klass, 'opensky', confidence
