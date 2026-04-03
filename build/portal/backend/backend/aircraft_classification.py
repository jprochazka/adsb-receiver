from __future__ import annotations

from typing import Optional

# ICAO/emitter-category-first classifier intended for map icon selection.
# This is intentionally conservative: if confidence is weak, return "unknown".

MILITARY_CALLSIGN_PREFIXES = {
    'RCH', 'MC', 'VM', 'LAGR', 'KING', 'REACH', 'NAVY', 'ARMY', 'AF', 'PACK', 'SHELL', 'MOOSE', 'SPAR'
}


def classify_aircraft(
    category: Optional[str],
    msg_type: Optional[str] = None,
    flight: Optional[str] = None,
    opensky_class: Optional[str] = None,
) -> str:
    if opensky_class:
        return opensky_class

    cat = (category or '').strip().upper()
    mtype = (msg_type or '').strip().lower()
    callsign = (flight or '').strip().upper()

    if _looks_military(callsign):
        return 'military'

    if cat == 'A7':
        return 'helicopter'

    if cat in {'A5', 'A6'}:
        return 'airliner'

    if cat in {'A3', 'A4'}:
        return 'airliner'

    if cat in {'A1', 'A2'}:
        # Category-only cannot reliably split prop GA vs business jet.
        return 'general_aviation'

    if cat in {'B1'}:
        return 'glider'

    if cat in {'B2'}:
        return 'balloon'

    if cat in {'B4'}:
        return 'general_aviation'

    if cat in {'B5'}:
        return 'uav'

    if cat in {'B6'}:
        return 'space'

    if cat.startswith('C'):
        return 'ground'

    if cat.startswith('D'):
        return 'military'

    if mtype == 'adsb_icao' and cat:
        return 'general_aviation'

    return 'unknown'


def _looks_military(callsign: str) -> bool:
    if not callsign:
        return False

    for prefix in MILITARY_CALLSIGN_PREFIXES:
        if callsign.startswith(prefix):
            return True

    return False
