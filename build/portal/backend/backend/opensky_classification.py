from __future__ import annotations

import csv
import os
import time
from typing import Dict, Optional, Tuple

from flask import current_app, has_app_context


_CACHE_CHECK_INTERVAL_SECONDS = 30.0
_CACHE = {
    'loaded_at': 0.0,
    'next_check_at': 0.0,
    'mtime': None,
    'map': None,
}


def _opensky_db_path() -> Optional[str]:
    if not has_app_context():
        return None
    return os.path.join(current_app.instance_path, 'opensky', 'aircraftDatabase.csv')


def _normalize_icao24(value: Optional[str]) -> str:
    return (value or '').strip().lower()


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


def _load_map(path: str) -> Dict[str, Tuple[str, str]]:
    mapped: Dict[str, Tuple[str, str]] = {}

    with open(path, mode='r', encoding='utf-8', newline='') as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            icao = _normalize_icao24(row.get('icao24'))
            if not icao:
                continue

            klass, confidence = _map_row_to_class(row)
            if not klass:
                continue

            mapped[icao] = (klass, confidence or 'low')

    return mapped


def _get_cached_map() -> Dict[str, Tuple[str, str]]:
    now = time.time()
    cached_map = _CACHE.get('map')
    if cached_map is not None and now < float(_CACHE.get('next_check_at', 0.0)):
        return cached_map

    path = _opensky_db_path()
    if not path or not os.path.exists(path):
        _CACHE['map'] = {}
        _CACHE['mtime'] = None
        _CACHE['loaded_at'] = now
        _CACHE['next_check_at'] = now + _CACHE_CHECK_INTERVAL_SECONDS
        return _CACHE['map']

    mtime = os.path.getmtime(path)
    if cached_map is not None and _CACHE.get('mtime') == mtime:
        _CACHE['next_check_at'] = now + _CACHE_CHECK_INTERVAL_SECONDS
        return cached_map

    mapped = _load_map(path)
    _CACHE['map'] = mapped
    _CACHE['mtime'] = mtime
    _CACHE['loaded_at'] = now
    _CACHE['next_check_at'] = now + _CACHE_CHECK_INTERVAL_SECONDS
    return mapped


def clear_opensky_classification_cache() -> None:
    _CACHE['loaded_at'] = 0.0
    _CACHE['next_check_at'] = 0.0
    _CACHE['mtime'] = None
    _CACHE['map'] = None


def get_opensky_cache_stats() -> Dict[str, Optional[float]]:
    mapped = _CACHE.get('map')
    entries = len(mapped) if isinstance(mapped, dict) else 0
    loaded_at = _CACHE.get('loaded_at') or 0.0
    return {
        'entries': entries,
        'loaded_at': float(loaded_at) if loaded_at else None,
    }


def get_opensky_classification(icao24: Optional[str]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    icao = _normalize_icao24(icao24)
    if not icao:
        return None, None, None

    mapped = _get_cached_map()
    match = mapped.get(icao)
    if not match:
        return None, None, None

    klass, confidence = match
    return klass, 'opensky', confidence
