import { fromLonLat } from 'ol/proj';

export interface TrackPositionLike {
  latitude: number;
  longitude: number;
  time: string;
  altitude?: number | null;
  speed?: number | null;
  squawk?: number | null;
  track?: number | null;
}

export const DEFAULT_TRACK_GAP_HOURS = 2;
export const TRACK_INTERPOLATION_TARGET_SECONDS = 6;
export const TRACK_INTERPOLATION_TARGET_METERS = 2_000;
export const TRACK_INTERPOLATION_MAX_POINTS_PER_EDGE = 16;

function timeMs(value: string): number {
  return new Date(String(value).replace(' ', 'T')).getTime();
}

export function splitTrackSegments(
  positions: TrackPositionLike[],
  gapHours = DEFAULT_TRACK_GAP_HOURS,
): TrackPositionLike[][] {
  if (!positions.length) {
    return [];
  }

  const sortedPositions = positions.slice().sort((a, b) => String(a.time).localeCompare(String(b.time)));
  const segments: TrackPositionLike[][] = [];
  let current: TrackPositionLike[] = [sortedPositions[0]];

  for (let i = 1; i < sortedPositions.length; i++) {
    const prevMs = timeMs(sortedPositions[i - 1].time);
    const currMs = timeMs(sortedPositions[i].time);
    if ((currMs - prevMs) / 3_600_000 > gapHours) {
      segments.push(current);
      current = [sortedPositions[i]];
    } else {
      current.push(sortedPositions[i]);
    }
  }

  segments.push(current);
  return segments.filter((segment) => segment.length > 0);
}

export function buildRenderableSegmentCoords(segment: TrackPositionLike[]): number[][] {
  if (!segment.length) {
    return [];
  }

  const baseCoords = segment.map((p) => fromLonLat([p.longitude, p.latitude]));
  if (baseCoords.length < 2) {
    return baseCoords;
  }

  const rendered: number[][] = [baseCoords[0]];

  for (let i = 1; i < segment.length; i++) {
    const prev = segment[i - 1];
    const curr = segment[i];
    const prevCoord = baseCoords[i - 1];
    const currCoord = baseCoords[i];

    const prevMs = timeMs(prev.time);
    const currMs = timeMs(curr.time);
    const dtMs = Math.max(1, currMs - prevMs);

    const dx = currCoord[0] - prevCoord[0];
    const dy = currCoord[1] - prevCoord[1];
    const distance = Math.hypot(dx, dy);

    const dtSteps = Math.ceil(dtMs / (TRACK_INTERPOLATION_TARGET_SECONDS * 1000));
    const distSteps = Math.ceil(distance / TRACK_INTERPOLATION_TARGET_METERS);
    const interpolationPoints = Math.min(
      TRACK_INTERPOLATION_MAX_POINTS_PER_EDGE,
      Math.max(0, Math.max(dtSteps, distSteps) - 1),
    );

    for (let j = 1; j <= interpolationPoints; j++) {
      const t = j / (interpolationPoints + 1);
      rendered.push([
        prevCoord[0] + dx * t,
        prevCoord[1] + dy * t,
      ]);
    }

    rendered.push(currCoord);
  }

  return rendered;
}
