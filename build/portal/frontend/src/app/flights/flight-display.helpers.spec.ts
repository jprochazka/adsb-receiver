import {
  aircraftTypeLabelForFlight,
  buildPageNumbers,
  inferAircraftClass,
  normalizeCount,
  normalizeSightingsCount,
} from './flight-display.helpers';

describe('flight display helpers', () => {
  it('normalizes bounded page-number windows around the current page', () => {
    expect(buildPageNumbers(1, 1)).toEqual([1]);
    expect(buildPageNumbers(1, 10)).toEqual([1, 2, 3]);
    expect(buildPageNumbers(5, 10)).toEqual([3, 4, 5, 6, 7]);
    expect(buildPageNumbers(10, 10)).toEqual([8, 9, 10]);
  });

  it('normalizes count-like API values while preserving fallback behavior', () => {
    expect(normalizeCount('12.9', 0)).toBe(12);
    expect(normalizeCount(0, 7)).toBe(0);
    expect(normalizeCount(-1, 7)).toBe(7);
    expect(normalizeCount('bad', 7)).toBe(7);

    expect(normalizeSightingsCount('3.9', 0)).toBe(3);
    expect(normalizeSightingsCount(0, 4)).toBe(4);
    expect(normalizeSightingsCount('bad', 4)).toBe(4);
  });

  it('infers aircraft class from explicit class, emitter category, and military callsigns', () => {
    expect(inferAircraftClass({ aircraft_class: ' Helicopter ' })).toBe('helicopter');
    expect(inferAircraftClass({ flight: 'RCH123', emitter_category: 'A1' })).toBe('military');
    expect(inferAircraftClass({ emitter_category: 'A7' })).toBe('helicopter');
    expect(inferAircraftClass({ emitter_category: 'A5' })).toBe('airliner');
    expect(inferAircraftClass({ emitter_category: 'B1' })).toBe('glider');
    expect(inferAircraftClass({ emitter_category: 'B2' })).toBe('balloon');
    expect(inferAircraftClass({ emitter_category: 'B5' })).toBe('uav');
    expect(inferAircraftClass({ emitter_category: 'C2' })).toBe('ground');
    expect(inferAircraftClass({ emitter_category: 'D1' })).toBe('military');
    expect(inferAircraftClass({ emitter_category: 'B3' })).toBe('general_aviation');
    expect(inferAircraftClass({})).toBe('unknown');
  });

  it('maps aircraft classes to public display labels', () => {
    expect(aircraftTypeLabelForFlight({ aircraft_class: 'airliner' })).toBe('Airliner');
    expect(aircraftTypeLabelForFlight({ aircraft_class: 'general_aviation' })).toBe('General Aviation');
    expect(aircraftTypeLabelForFlight({ aircraft_class: 'ground' })).toBe('Ground Vehicle');
    expect(aircraftTypeLabelForFlight({ aircraft_class: 'space' })).toBe('Space Vehicle');
    expect(aircraftTypeLabelForFlight({ aircraft_class: 'not_a_real_class' })).toBe('Unknown');
  });
});
