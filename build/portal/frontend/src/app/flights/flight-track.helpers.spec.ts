import { buildRenderableSegmentCoords, splitTrackSegments } from './flight-track.helpers';

describe('flight track helpers', () => {
  it('splits positions into contiguous time segments without mutating the input order', () => {
    const positions = [
      { latitude: 41.2, longitude: -82.2, time: '2026-04-03 10:10:00' },
      { latitude: 41.0, longitude: -82.0, time: '2026-04-03 07:00:00' },
      { latitude: 41.1, longitude: -82.1, time: '2026-04-03 10:00:00' },
    ];

    const segments = splitTrackSegments(positions, 2);

    expect(segments.length).toBe(2);
    expect(segments[0].map((p) => p.time)).toEqual(['2026-04-03 07:00:00']);
    expect(segments[1].map((p) => p.time)).toEqual([
      '2026-04-03 10:00:00',
      '2026-04-03 10:10:00',
    ]);
    expect(positions.map((p) => p.time)).toEqual([
      '2026-04-03 10:10:00',
      '2026-04-03 07:00:00',
      '2026-04-03 10:00:00',
    ]);
  });

  it('returns no segments for an empty position list', () => {
    expect(splitTrackSegments([])).toEqual([]);
  });

  it('interpolates sparse render coordinates but preserves segment endpoints', () => {
    const segment = [
      { latitude: 41.0, longitude: -82.0, time: '2026-04-03 10:00:00' },
      { latitude: 41.2, longitude: -81.7, time: '2026-04-03 10:00:30' },
    ];

    const coords = buildRenderableSegmentCoords(segment);

    expect(coords.length).toBeGreaterThan(2);
    expect(coords[0]).toEqual(jasmine.any(Array));
    expect(coords[coords.length - 1]).toEqual(jasmine.any(Array));
    expect(coords[0]).not.toEqual(coords[coords.length - 1]);
  });

  it('returns one projected coordinate for a single position', () => {
    const coords = buildRenderableSegmentCoords([
      { latitude: 41.0, longitude: -82.0, time: '2026-04-03 10:00:00' },
    ]);

    expect(coords.length).toBe(1);
  });
});
