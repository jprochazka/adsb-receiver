import { extractOverlayRings } from './live-overlay.helpers';

describe('live overlay helpers', () => {
  it('returns no rings for invalid or non-coordinate JSON', () => {
    expect(extractOverlayRings('{not-json')).toEqual([]);
    expect(extractOverlayRings(JSON.stringify({ enabled: true }))).toEqual([]);
  });

  it('parses and closes lon/lat pair arrays before projecting them', () => {
    const rings = extractOverlayRings(JSON.stringify([
      [-90.0, 40.0],
      [-90.1, 40.0],
      [-90.1, 40.1],
    ]));

    expect(rings.length).toBe(1);
    expect(rings[0].length).toBe(4);
    expect(rings[0][0]).toEqual(rings[0][3]);
  });

  it('parses object coordinate arrays using lon, lng, longitude and lat aliases', () => {
    const rings = extractOverlayRings(JSON.stringify([
      { lon: -90.0, lat: 40.0 },
      { lng: -90.1, lat: 40.0 },
      { longitude: -90.1, latitude: 40.1 },
    ]));

    expect(rings.length).toBe(1);
    expect(rings[0].length).toBe(4);
  });

  it('recursively finds coordinate rings inside nested config objects', () => {
    const rings = extractOverlayRings(JSON.stringify({
      metadata: { name: 'range' },
      rings: [
        [
          [-90.0, 40.0],
          [-90.2, 40.0],
          [-90.1, 40.2],
          [-90.0, 40.0],
        ],
      ],
    }));

    expect(rings.length).toBe(1);
    expect(rings[0].length).toBe(4);
  });

  it('parses GeoJSON polygon features', () => {
    const rings = extractOverlayRings(JSON.stringify({
      type: 'FeatureCollection',
      features: [
        {
          type: 'Feature',
          properties: {},
          geometry: {
            type: 'Polygon',
            coordinates: [[
              [-90.0, 40.0],
              [-90.2, 40.0],
              [-90.1, 40.2],
              [-90.0, 40.0],
            ]],
          },
        },
      ],
    }));

    expect(rings.length).toBe(1);
    expect(rings[0].length).toBe(4);
  });
});
