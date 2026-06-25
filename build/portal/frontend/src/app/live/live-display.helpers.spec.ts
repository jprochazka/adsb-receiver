import {
  AIRCRAFT_TYPE_LEGEND,
  aircraftTypeLabel,
  aircraftTypeSourceLabel,
  altitudeColor,
  classifyAircraftForIcon,
  flightHistoryLink,
  sourceColor,
  sourceLabel,
} from './live-display.helpers';

describe('live display helpers', () => {
  it('maps altitude tiers to stable map colors', () => {
    expect(altitudeColor(null)).toBe('#64748b');
    expect(altitudeColor(-1)).toBe('#64748b');
    expect(altitudeColor(5_000)).toBe('#38bdf8');
    expect(altitudeColor(15_000)).toBe('#22c55e');
    expect(altitudeColor(30_000)).toBe('#f59e0b');
    expect(altitudeColor(45_000)).toBe('#f97316');
    expect(altitudeColor(45_001)).toBe('#ef4444');
  });

  it('distinguishes ADS-B and UAT source colors and labels', () => {
    expect(sourceColor('dump978')).toBe('#f59e0b');
    expect(sourceColor('dump1090')).toBe('#22d3ee');
    expect(sourceLabel({ source: 'dump978' })).toBe('Dump978 (UAT)');
    expect(sourceLabel({ source: 'dump1090' })).toBe('Dump1090 (ADS-B)');
  });

  it('classifies aircraft from explicit class, emitter category, and military callsign', () => {
    expect(classifyAircraftForIcon({ aircraft_class: 'helicopter', category: 'A4' })).toBe('helicopter');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: 'A7' })).toBe('helicopter');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: 'A4' })).toBe('airliner');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: 'B1' })).toBe('glider');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: 'B2' })).toBe('balloon');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: 'B5' })).toBe('uav');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: 'C1' })).toBe('ground');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: 'D1' })).toBe('military');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: null, flight: 'RCH123' })).toBe('military');
    expect(classifyAircraftForIcon({ aircraft_class: null, category: null, flight: null })).toBe('unknown');
  });

  it('maps aircraft class and source metadata to public labels', () => {
    expect(aircraftTypeLabel({ aircraft_class: 'airliner' })).toBe('Airliner');
    expect(aircraftTypeLabel({ aircraft_class: 'general_aviation' })).toBe('General Aviation');
    expect(aircraftTypeLabel({ aircraft_class: 'space' })).toBe('Space Vehicle');
    expect(aircraftTypeLabel({ aircraft_class: 'not-real' })).toBe('Unknown');
    expect(aircraftTypeSourceLabel({ classification_source: 'opensky', classification_confidence: 'high' })).toBe('OpenSky (high)');
    expect(aircraftTypeSourceLabel({ classification_source: 'heuristic', classification_confidence: '' })).toBe('Heuristic');
  });

  it('builds flight-history links only for aircraft with callsigns', () => {
    expect(flightHistoryLink({ source: 'dump978', flight: 'UAT123' })).toBe('/flight-history/uat/UAT123');
    expect(flightHistoryLink({ source: 'dump1090', flight: 'AAL 123' })).toBe('/flight-history/adsb/AAL%20123');
    expect(flightHistoryLink({ source: 'dump1090', flight: null })).toBeNull();
  });

  it('exposes the stable aircraft type legend used by the template', () => {
    expect(AIRCRAFT_TYPE_LEGEND.map((item) => item.key)).toEqual([
      'airliner',
      'general_aviation',
      'helicopter',
      'military',
      'glider',
      'balloon',
      'uav',
      'ground',
      'unknown',
    ]);
    expect(AIRCRAFT_TYPE_LEGEND.find((item) => item.key === 'general_aviation')?.label).toBe('General Aviation');
  });
});
