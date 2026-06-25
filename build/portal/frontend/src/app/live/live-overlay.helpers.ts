import GeoJSON from 'ol/format/GeoJSON';
import Polygon from 'ol/geom/Polygon';
import { fromLonLat } from 'ol/proj';

export function extractOverlayRings(rawJson: string): number[][][] {
  let parsed: unknown;

  try {
    parsed = JSON.parse(rawJson);
  } catch {
    return [];
  }

  const geoJsonFeatures = readGeoJsonFeatures(parsed);
  if (geoJsonFeatures.length > 0) {
    return geoJsonFeatures;
  }

  return collectCoordinateRings(parsed)
    .map((ring) => projectRing(ring))
    .filter((ring): ring is number[][] => ring.length >= 4);
}

function readGeoJsonFeatures(parsed: unknown): number[][][] {
  try {
    const features = new GeoJSON().readFeatures(parsed as object, {
      featureProjection: 'EPSG:3857',
      dataProjection: 'EPSG:4326',
    });

    return features.flatMap((feature) => {
      const geometry = feature.getGeometry();
      if (geometry instanceof Polygon) {
        return [geometry.getCoordinates()[0]];
      }
      return [];
    }).filter((ring) => ring.length >= 4);
  } catch {
    return [];
  }
}

function collectCoordinateRings(value: unknown): number[][][] {
  if (isLonLatPairArray(value)) {
    return [closeLonLatRing(value)];
  }

  if (isLonLatObjectArray(value)) {
    return [closeLonLatRing(value.map((point) => [point.lon, point.lat]))];
  }

  if (!value || typeof value !== 'object') {
    return [];
  }

  if (Array.isArray(value)) {
    return value.flatMap((entry) => collectCoordinateRings(entry));
  }

  return Object.values(value).flatMap((entry) => collectCoordinateRings(entry));
}

function isLonLatPairArray(value: unknown): value is number[][] {
  return Array.isArray(value) && value.length >= 3 && value.every((item) =>
    Array.isArray(item) && item.length >= 2 &&
    Number.isFinite(item[0]) && Number.isFinite(item[1]),
  );
}

type LonLatObject = { lon: number; lat: number };

function isLonLatObjectArray(value: unknown): value is LonLatObject[] {
  if (!Array.isArray(value) || value.length < 3) {
    return false;
  }

  const normalized = value.map((item) => {
    if (!item || typeof item !== 'object') return false;
    const candidate = item as Record<string, unknown>;
    const lon = candidate['lon'] ?? candidate['lng'] ?? candidate['longitude'];
    const lat = candidate['lat'] ?? candidate['latitude'];
    if (!Number.isFinite(lon) || !Number.isFinite(lat)) {
      return false;
    }
    return { lon: Number(lon), lat: Number(lat) };
  });

  if (normalized.some((item) => item === false)) {
    return false;
  }

  value.splice(0, value.length, ...(normalized as LonLatObject[]));
  return true;
}

function closeLonLatRing(points: number[][]): number[][] {
  const ring = points.map(([lon, lat]) => [Number(lon), Number(lat)]);
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (!first || !last) return [];
  if (first[0] !== last[0] || first[1] !== last[1]) {
    ring.push([first[0], first[1]]);
  }
  return ring;
}

function projectRing(ring: number[][]): number[][] {
  return ring
    .filter(([lon, lat]) => Number.isFinite(lon) && Number.isFinite(lat))
    .map(([lon, lat]) => fromLonLat([lon, lat]));
}
