import { DatePipe } from '@angular/common';
import { DecimalPipe } from '@angular/common';
import { ChangeDetectorRef, Component, HostListener, OnDestroy, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { interval, Subscription, of, catchError, forkJoin, startWith, switchMap } from 'rxjs';

import 'ol/ol.css';
import OlMap from 'ol/Map';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import LineString from 'ol/geom/LineString';
import CircleGeom from 'ol/geom/Circle';
import Polygon from 'ol/geom/Polygon';
import { fromCircle as polygonFromCircle } from 'ol/geom/Polygon';
import GeoJSON from 'ol/format/GeoJSON';
import VectorSource from 'ol/source/Vector';
import VectorLayer from 'ol/layer/Vector';
import TileLayer from 'ol/layer/Tile';
import View from 'ol/View';
import Style from 'ol/style/Style';
import Icon from 'ol/style/Icon';
import Stroke from 'ol/style/Stroke';
import Fill from 'ol/style/Fill';
import { fromLonLat } from 'ol/proj';
import { OSM } from 'ol/source';
import { FullScreen, ZoomSlider } from 'ol/control';
import ScaleLine from 'ol/control/ScaleLine';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_REFRESH_MS = 5_000;
const DEFAULT_CENTER_LON = 0;
const DEFAULT_CENTER_LAT = 20;
const DEFAULT_ZOOM = 3;
const DEFAULT_TRAIL_POINTS = 20;
const DEFAULT_CENTER_ICON_ENABLED = true;
const DEFAULT_DISTANCE_RINGS_ENABLED = false;
const DEFAULT_DISTANCE_RING_COMPASS_LINES_ENABLED = true;
const DEFAULT_DISTANCE_RING_COUNT = 4;
const DEFAULT_DISTANCE_RING_INTERVAL_MILES = 25;
const DEFAULT_THEORETICAL_RANGE_ENABLED = false;
const DEFAULT_THEORETICAL_RANGE_JSON = '';
const DEFAULT_HEYWHATSTHAT_RINGS_ENABLED = false;
const DEFAULT_HEYWHATSTHAT_RINGS_JSON = '';
const DEFAULT_FLYOUT_WIDTH = 280;
const MIN_FLYOUT_WIDTH = 240;
const MAX_FLYOUT_WIDTH = 560;
const SPIDER_SECTOR_COUNT = 16;
const SPIDER_MAX_RADIUS_METERS = 300_000;
const TRAIL_INTERPOLATION_TARGET_SECONDS = 6;
const TRAIL_INTERPOLATION_TARGET_METERS = 1_500;
const TRAIL_INTERPOLATION_MAX_POINTS = 12;
const TRAIL_SMOOTHING_WINDOW = 3;
const OPENSTREETMAP_ATTRIBUTION_HTML = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap contributors</a>';
const OPENSKY_ATTRIBUTION_HTML = '<a href="https://opensky-network.org/datasets/metadata/aircraftDatabase.csv" target="_blank" rel="noopener noreferrer">OpenSky Network Aircraft Database (ODbL v1.0)</a>';

/** Altitude tiers used for icon/dot colouring. */
const ALTITUDE_TIERS = [
  { max: -1,     color: '#64748b' }, // ground / on-ground flag
  { max: 5_000,  color: '#38bdf8' }, // low
  { max: 15_000, color: '#22c55e' }, // medium-low
  { max: 30_000, color: '#f59e0b' }, // medium-high
  { max: 45_000, color: '#f97316' }, // high
  { max: Infinity, color: '#ef4444' }, // very high
] as const;

/** Return a colour string for a given altitude, or gray when unknown. */
function altitudeColor(alt: number | null | undefined): string {
  if (alt == null) return '#64748b';
  for (const tier of ALTITUDE_TIERS) {
    if (alt <= tier.max) return tier.color;
  }
  return '#ef4444';
}

/** Source colour for icon outlines so ADS-B and UAT are distinguishable on-map. */
function sourceColor(source: string | null | undefined): string {
  return source === 'dump978' ? '#f59e0b' : '#22d3ee';
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface LiveAircraft {
  source:        'dump1090' | 'dump978' | string;
  hex:           string;
  flight:        string | null;
  lat:           number | null;
  lon:           number | null;
  altitude:      number | null;
  speed:         number | null;
  track:         number | null;
  vertical_rate: number | null;
  squawk:        string | null;
  category:      string | null;
  seen:          number | null;
  rssi:          number | null;
  type:          string | null;
  aircraft_class?: string | null;
  classification_source?: string | null;
  classification_confidence?: string | null;
}

type AircraftTypeLegendItem = {
  key: string;
  label: string;
};

type TrailPoint = {
  coord: number[];
  ts: number;
};

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

@Component({
  selector: 'app-live',
  standalone: true,
  imports: [DatePipe, DecimalPipe, FormsModule, SpinnerComponent, RouterLink],
  templateUrl: './live.component.html',
  styleUrl: './live.component.scss'
})
export class LiveComponent implements OnInit, OnDestroy {

  // State
  loading      = true;
  errorMessage = '';
  lastUpdate:    Date | null      = null;
  messageCount:  number | null    = null;

  // Aircraft data
  aircraft:         LiveAircraft[] = [];
  filteredAircraft: LiveAircraft[] = [];
  filterQuery = '';

  // Selection
  selectedHex: string | null = null;
  get selectedAircraft(): LiveAircraft | null {
    return this.selectedHex
      ? (this.aircraft.find(a => a.hex === this.selectedHex) ?? null)
      : null;
  }

  // UI
  panelOpen    = true;
  flyoutWidth = DEFAULT_FLYOUT_WIDTH;
  photoUrl:     string | null = null;
  photoAttrib:  string | null = null;
  photoLoading  = false;

  // Settings
  liveMapEnabled = true;
  refreshMs = DEFAULT_REFRESH_MS;
  defaultCenterLon = DEFAULT_CENTER_LON;
  defaultCenterLat = DEFAULT_CENTER_LAT;
  defaultZoom = DEFAULT_ZOOM;
  trailPoints = DEFAULT_TRAIL_POINTS;
  showAllSeen = true;
  liveMapSpiderOverlayEnabled = true;
  liveMapCenterIconEnabled = DEFAULT_CENTER_ICON_ENABLED;
  liveMapDistanceRingsEnabled = DEFAULT_DISTANCE_RINGS_ENABLED;
  liveMapDistanceRingCompassLinesEnabled = DEFAULT_DISTANCE_RING_COMPASS_LINES_ENABLED;
  liveMapDistanceRingCount = DEFAULT_DISTANCE_RING_COUNT;
  liveMapDistanceRingIntervalMiles = DEFAULT_DISTANCE_RING_INTERVAL_MILES;
  liveMapTheoreticalRangeEnabled = DEFAULT_THEORETICAL_RANGE_ENABLED;
  liveMapTheoreticalRangeJson = DEFAULT_THEORETICAL_RANGE_JSON;
  liveMapHeyWhatsThatRingsEnabled = DEFAULT_HEYWHATSTHAT_RINGS_ENABLED;
  liveMapHeyWhatsThatRingsJson = DEFAULT_HEYWHATSTHAT_RINGS_JSON;

  // Session-only directional spider graph
  private readonly spiderSectorMaxDistanceMeters = Array.from(
    { length: SPIDER_SECTOR_COUNT },
    () => 0
  );
  private spiderCenterProjected: number[] | null = null;

  // Computed counts
  get aircraftWithPosition(): number {
    return this.aircraft.filter(a => a.lat != null && a.lon != null).length;
  }

  // Exposed helper for templates
  readonly altColor = altitudeColor;
  readonly aircraftTypeLegend: AircraftTypeLegendItem[] = [
    { key: 'airliner', label: 'Airliner' },
    { key: 'general_aviation', label: 'General Aviation' },
    { key: 'helicopter', label: 'Helicopter' },
    { key: 'military', label: 'Military' },
    { key: 'glider', label: 'Glider' },
    { key: 'balloon', label: 'Balloon' },
    { key: 'uav', label: 'UAV' },
    { key: 'ground', label: 'Ground Vehicle' },
    { key: 'unknown', label: 'Unknown' },
  ];

  // OL map objects
  private olMap!: OlMap;
  private aircraftSource = new VectorSource();
  private trailSource = new VectorSource();
  private distanceRingSource = new VectorSource();
  private theoreticalRangeSource = new VectorSource();
  private heyWhatsThatRingsSource = new VectorSource();
  private radarSiteSource = new VectorSource();
  private spiderSource = new VectorSource();
  /** hex -> OL Feature lookup for in-place position updates */
  private featureIndex: { [hex: string]: Feature } = {};
  /** hex -> list of projected/time-stamped points retained for trail rendering */
  private trailHistory: { [hex: string]: TrailPoint[] } = {};
  /** hex -> trail line feature */
  private trailFeatureIndex: { [hex: string]: Feature } = {};
  private spiderPolygonFeature: Feature | null = null;

  private readonly spiderCenterStyle = new Style({
    image: new Icon({
      src: 'data:image/svg+xml;utf8,' + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26">' +
        '<g fill="none" fill-rule="evenodd">' +
        '<path d="M13 4.8l5.1 14.8h-2.6l-1.03-3.2h-2.94l-1.04 3.2H7.85L13 4.8Z" fill="rgba(17,24,39,0.92)"/>' +
        '<path d="M12.18 13.82h1.64L13 11.05l-.82 2.77Z" fill="rgba(255,255,255,0.92)"/>' +
        '<path d="M7.3 20.55h11.4" stroke="rgba(17,24,39,0.92)" stroke-width="1.55" stroke-linecap="round"/>' +
        '<circle cx="13" cy="8.85" r="1.65" fill="rgba(17,24,39,0.94)" stroke="rgba(255,255,255,0.92)" stroke-width="0.85"/>' +
        '<path d="M13 8.85a4.8 4.8 0 0 1 4.8 4.8" stroke="rgba(17,24,39,0.88)" stroke-width="1.1" stroke-linecap="round"/>' +
        '<path d="M13 8.85a7.15 7.15 0 0 1 7.15 7.15" stroke="rgba(17,24,39,0.5)" stroke-width="1" stroke-linecap="round"/>' +
        '</g></svg>'
      ),
      opacity: 0.98,
      anchor: [0.5, 0.5],
      scale: 1.22
    })
  });
  private readonly spiderPolygonStyle = new Style({
    fill: new Fill({ color: 'rgba(56, 189, 248, 0.20)' }),
    stroke: new Stroke({ color: 'rgba(56, 189, 248, 0.95)', width: 2.1 })
  });
  private readonly distanceRingStyle = new Style({
    fill: new Fill({ color: 'rgba(0, 0, 0, 0)' }),
    stroke: new Stroke({ color: 'rgba(55, 55, 55, 0.58)', width: 1 })
  });
  private readonly distanceRingRayStyle = new Style({
    stroke: new Stroke({ color: 'rgba(55, 55, 55, 0.24)', width: 0.8 })
  });
  private readonly theoreticalRangeStyle = new Style({
    fill: new Fill({ color: 'rgba(245, 158, 11, 0.10)' }),
    stroke: new Stroke({ color: 'rgba(180, 83, 9, 0.72)', width: 1.6 })
  });
  private readonly heyWhatsThatRingsStyle = new Style({
    fill: new Fill({ color: 'rgba(59, 130, 246, 0.07)' }),
    stroke: new Stroke({ color: 'rgba(37, 99, 235, 0.78)', width: 1.5 })
  });

  private subscription?: Subscription;
  private cdr = inject(ChangeDetectorRef);
  private resizing = false;
  private resizeStartX = 0;
  private resizeStartWidth = DEFAULT_FLYOUT_WIDTH;

  private readonly windowMouseMoveHandler = (event: MouseEvent) => {
    this.onWindowMouseMove(event);
  };

  private readonly windowMouseUpHandler = () => {
    this.stopResize();
  };

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    this.loadSettings(() => {
      this.initMap();

      if (!this.liveMapEnabled) {
        this.loading = false;
        this.errorMessage = 'Live map is currently disabled by an administrator.';
        this.cdr.detectChanges();
        return;
      }

      this.startPolling();
    });
  }

  ngOnDestroy(): void {
    this.subscription?.unsubscribe();
    this.stopResize();
    if (this.olMap) this.olMap.setTarget(undefined);
  }

  @HostListener('window:resize')
  onWindowResize(): void {
    this.flyoutWidth = this.clampFlyoutWidth(this.flyoutWidth);
    this.scheduleMapResize();
  }

  // -------------------------------------------------------------------------
  // Map initialisation
  // -------------------------------------------------------------------------

  private loadSettings(afterLoad: () => void): void {
    forkJoin({
      enabled: this.dataService.getSetting('live_map_enabled').pipe(catchError(() => of({ value: 'true' }))),
      refreshMs: this.dataService.getSetting('live_map_refresh_ms').pipe(catchError(() => of({ value: String(DEFAULT_REFRESH_MS) }))),
      centerLat: this.dataService.getSetting('live_map_center_lat').pipe(catchError(() => of({ value: String(DEFAULT_CENTER_LAT) }))),
      centerLon: this.dataService.getSetting('live_map_center_lon').pipe(catchError(() => of({ value: String(DEFAULT_CENTER_LON) }))),
      zoom: this.dataService.getSetting('live_map_default_zoom').pipe(catchError(() => of({ value: String(DEFAULT_ZOOM) }))),
      trailPoints: this.dataService.getSetting('live_map_trail_points').pipe(catchError(() => of({ value: String(DEFAULT_TRAIL_POINTS) }))),
      showAllSeen: this.dataService.getSetting('live_map_show_all_seen').pipe(catchError(() => of({ value: 'true' }))),
      spiderOverlayEnabled: this.dataService.getSetting('live_map_spider_overlay_enabled').pipe(catchError(() => of({ value: 'true' }))),
      centerIconEnabled: this.dataService.getSetting('live_map_center_icon_enabled').pipe(catchError(() => of({ value: String(DEFAULT_CENTER_ICON_ENABLED) }))),
      distanceRingsEnabled: this.dataService.getSetting('live_map_distance_rings_enabled').pipe(catchError(() => of({ value: String(DEFAULT_DISTANCE_RINGS_ENABLED) }))),
      distanceRingCompassLinesEnabled: this.dataService.getSetting('live_map_distance_ring_compass_lines_enabled').pipe(catchError(() => of({ value: String(DEFAULT_DISTANCE_RING_COMPASS_LINES_ENABLED) }))),
      distanceRingCount: this.dataService.getSetting('live_map_distance_ring_count').pipe(catchError(() => of({ value: String(DEFAULT_DISTANCE_RING_COUNT) }))),
      distanceRingIntervalMiles: this.dataService.getSetting('live_map_distance_ring_interval_miles').pipe(catchError(() => of({ value: String(DEFAULT_DISTANCE_RING_INTERVAL_MILES) }))),
      theoreticalRangeEnabled: this.dataService.getSetting('live_map_theoretical_range_enabled').pipe(catchError(() => of({ value: String(DEFAULT_THEORETICAL_RANGE_ENABLED) }))),
      theoreticalRangeJson: this.dataService.getSetting('live_map_theoretical_range_json').pipe(catchError(() => of({ value: DEFAULT_THEORETICAL_RANGE_JSON }))),
      heyWhatsThatRingsEnabled: this.dataService.getSetting('live_map_heywhatsthat_rings_enabled').pipe(catchError(() => of({ value: String(DEFAULT_HEYWHATSTHAT_RINGS_ENABLED) }))),
      heyWhatsThatRingsJson: this.dataService.getSetting('live_map_heywhatsthat_rings_json').pipe(catchError(() => of({ value: DEFAULT_HEYWHATSTHAT_RINGS_JSON }))),
    }).subscribe(({ enabled, refreshMs, centerLat, centerLon, zoom, trailPoints, showAllSeen, spiderOverlayEnabled, centerIconEnabled, distanceRingsEnabled, distanceRingCompassLinesEnabled, distanceRingCount, distanceRingIntervalMiles, theoreticalRangeEnabled, theoreticalRangeJson, heyWhatsThatRingsEnabled, heyWhatsThatRingsJson }) => {
      this.liveMapEnabled = enabled?.value !== 'false';
      this.refreshMs = this.clampInt(refreshMs?.value, 1_000, 60_000, DEFAULT_REFRESH_MS);
      this.defaultCenterLat = this.clampFloat(centerLat?.value, -85, 85, DEFAULT_CENTER_LAT);
      this.defaultCenterLon = this.clampFloat(centerLon?.value, -180, 180, DEFAULT_CENTER_LON);
      this.defaultZoom = this.clampInt(zoom?.value, 1, 18, DEFAULT_ZOOM);
      this.trailPoints = this.clampInt(trailPoints?.value, 0, 200, DEFAULT_TRAIL_POINTS);
      this.showAllSeen = showAllSeen?.value !== 'false';
      this.liveMapSpiderOverlayEnabled = spiderOverlayEnabled?.value !== 'false';
      this.liveMapCenterIconEnabled = centerIconEnabled?.value !== 'false';
      this.liveMapDistanceRingsEnabled = distanceRingsEnabled?.value === 'true';
      this.liveMapDistanceRingCompassLinesEnabled = distanceRingCompassLinesEnabled?.value !== 'false';
      this.liveMapDistanceRingCount = this.clampInt(distanceRingCount?.value, 1, 12, DEFAULT_DISTANCE_RING_COUNT);
      this.liveMapDistanceRingIntervalMiles = this.clampInt(distanceRingIntervalMiles?.value, 1, 250, DEFAULT_DISTANCE_RING_INTERVAL_MILES);
      this.liveMapTheoreticalRangeEnabled = theoreticalRangeEnabled?.value === 'true';
      this.liveMapTheoreticalRangeJson = String(theoreticalRangeJson?.value ?? '').trim();
      this.liveMapHeyWhatsThatRingsEnabled = heyWhatsThatRingsEnabled?.value === 'true';
      this.liveMapHeyWhatsThatRingsJson = String(heyWhatsThatRingsJson?.value ?? '').trim();
      afterLoad();
    });
  }

  private startPolling(): void {
    this.subscription?.unsubscribe();
    this.subscription = interval(this.refreshMs).pipe(
      startWith(0),
      switchMap(() => this.dataService.getLiveAircraft().pipe(catchError(() => of(null))))
    ).subscribe(data => {
      if (data) {
        this.handleData(data);
      } else if (this.loading) {
        this.loading = false;
        this.errorMessage = 'Unable to reach aircraft data. Ensure the decoder(s) are running and reachable.';
      }
      this.cdr.detectChanges();
    });
  }

  private initMap(): void {
    const osmSource = new OSM({
      attributions: [OPENSTREETMAP_ATTRIBUTION_HTML, OPENSKY_ATTRIBUTION_HTML]
    });

    this.olMap = new OlMap({
      layers: [
        new TileLayer({ source: osmSource }),
        new VectorLayer({
          source: this.distanceRingSource,
          zIndex: 9,
          style: feature => this.distanceRingStyleFor(feature as Feature)
        }),
        new VectorLayer({
          source: this.theoreticalRangeSource,
          zIndex: 10,
          style: this.theoreticalRangeStyle
        }),
        new VectorLayer({
          source: this.heyWhatsThatRingsSource,
          zIndex: 10,
          style: this.heyWhatsThatRingsStyle
        }),
        new VectorLayer({ source: this.trailSource, zIndex: 11 }),
        new VectorLayer({
          source: this.radarSiteSource,
          zIndex: 12,
          style: this.spiderCenterStyle
        }),
        new VectorLayer({
          source: this.spiderSource,
          zIndex: 13,
          style: feature => this.spiderStyleFor(feature as Feature)
        }),
        new VectorLayer({ source: this.aircraftSource, zIndex: 14 }),
      ],
      target: 'live',
      view: new View({
        center: fromLonLat([this.defaultCenterLon, this.defaultCenterLat]),
        zoom: this.defaultZoom,
        maxZoom: 18
      }),
    });

    this.olMap.addControl(new FullScreen());
    this.olMap.addControl(new ScaleLine());
    this.olMap.addControl(new ZoomSlider());
    this.initRadarSiteMarker();
    this.initDistanceRings();
    this.initTheoreticalRangeOverlay();
    this.initHeyWhatsThatRingsOverlay();
    this.initSpiderOverlay();

    // Pointer cursor over aircraft features
    this.olMap.on('pointermove', evt => {
      const hit = this.olMap.hasFeatureAtPixel(evt.pixel, { hitTolerance: 8 });
      (this.olMap.getTargetElement() as HTMLElement).style.cursor = hit ? 'pointer' : '';
    });

    // Click to select / deselect
    this.olMap.on('click', evt => {
      let hitHex: string | null = null;
      this.olMap.forEachFeatureAtPixel(
        evt.pixel,
        feature => {
          hitHex = (feature.get('hex') as string) ?? null;
          return true; // stop after first hit
        },
        { hitTolerance: 8 }
      );
      if (hitHex) {
        this.selectAircraft(hitHex);
      } else {
        this.clearSelection();
        this.cdr.detectChanges();
      }
    });

    this.scheduleMapResize();
  }

  // -------------------------------------------------------------------------
  // Data handling
  // -------------------------------------------------------------------------

  private handleData(data: { now: number; messages: number; aircraft: LiveAircraft[] }): void {
    this.loading      = false;
    this.errorMessage = '';
    this.lastUpdate   = new Date();
    this.messageCount = data.messages ?? null;
    this.aircraft     = data.aircraft ?? [];
    if (this.liveMapSpiderOverlayEnabled) this.updateSpiderHistory();

    this.applyFilter();
    this.syncMapFeatures();

    // Keep selected aircraft data fresh; clear if it disappeared
    if (this.selectedHex && !this.aircraft.find(a => a.hex === this.selectedHex)) {
      this.selectedHex = null;
      this.photoUrl    = null;
      this.photoAttrib = null;
    }
  }

  // -------------------------------------------------------------------------
  // Filter
  // -------------------------------------------------------------------------

  applyFilter(): void {
    const q = this.filterQuery.trim().toLowerCase();
    const source = this.showAllSeen
      ? this.aircraft
      : this.aircraft.filter(a => a.lat != null && a.lon != null);

    const sorted = [...source].sort((a, b) => {
      // Aircraft with known positions first, then by altitude descending
      const aHasPos = a.lat != null ? 0 : 1;
      const bHasPos = b.lat != null ? 0 : 1;
      if (aHasPos !== bHasPos) return aHasPos - bHasPos;
      return (b.altitude ?? -1) - (a.altitude ?? -1);
    });

    this.filteredAircraft = q
      ? sorted.filter(a =>
          a.hex.toLowerCase().includes(q) ||
          (a.flight?.toLowerCase().includes(q) ?? false)
        )
      : sorted;
  }

  // -------------------------------------------------------------------------
  // Map feature synchronisation
  // -------------------------------------------------------------------------

  private syncMapFeatures(): void {
    const activeHexes = new Set(
      this.aircraft
        .filter(a => a.lat != null && a.lon != null)
        .map(a => a.hex)
    );

    // Remove stale features
    for (const hex of Object.keys(this.featureIndex)) {
      if (!activeHexes.has(hex)) {
        this.aircraftSource.removeFeature(this.featureIndex[hex]);
        delete this.featureIndex[hex];
        delete this.trailHistory[hex];
        if (this.trailFeatureIndex[hex]) {
          this.trailSource.removeFeature(this.trailFeatureIndex[hex]);
          delete this.trailFeatureIndex[hex];
        }
      }
    }

    // Add / update features
    for (const ac of this.aircraft) {
      if (ac.lat == null || ac.lon == null) continue;
      const coord = fromLonLat([ac.lon, ac.lat]);
      const isSelected = ac.hex === this.selectedHex;

      this.updateTrail(ac, coord, Date.now());

      if (this.featureIndex[ac.hex]) {
        const f = this.featureIndex[ac.hex];
        (f.getGeometry() as Point).setCoordinates(coord);
        f.set('aircraft', ac, true);
        f.setStyle(this.makeStyle(ac, isSelected));
      } else {
        const f = new Feature({ geometry: new Point(coord) });
        f.set('hex', ac.hex);
        f.set('aircraft', ac);
        f.setStyle(this.makeStyle(ac, false));
        this.aircraftSource.addFeature(f);
        this.featureIndex[ac.hex] = f;
      }
    }
  }

  private updateTrail(ac: LiveAircraft, projectedCoord: number[], sampleTs: number): void {
    if (this.trailPoints <= 0) return;

    const history = this.trailHistory[ac.hex] ?? [];
    const last = history[history.length - 1]?.coord;
    const moved = !last || Math.abs(last[0] - projectedCoord[0]) > 5 || Math.abs(last[1] - projectedCoord[1]) > 5;

    if (moved) {
      this.appendTrailPoint(history, projectedCoord, sampleTs);
      if (history.length > this.trailPoints) {
        history.splice(0, history.length - this.trailPoints);
      }
      this.trailHistory[ac.hex] = history;
    }

    if (history.length < 2) {
      if (this.trailFeatureIndex[ac.hex]) {
        this.trailSource.removeFeature(this.trailFeatureIndex[ac.hex]);
        delete this.trailFeatureIndex[ac.hex];
      }
      return;
    }

    const color = altitudeColor(ac.altitude);
    const renderCoords = this.smoothTrailCoordinates(history.map(p => p.coord));
    if (this.trailFeatureIndex[ac.hex]) {
      const existing = this.trailFeatureIndex[ac.hex];
      (existing.getGeometry() as LineString).setCoordinates(renderCoords);
      existing.setStyle(this.makeTrailStyle(color, ac.hex === this.selectedHex));
    } else {
      const feature = new Feature({ geometry: new LineString(renderCoords) });
      feature.setStyle(this.makeTrailStyle(color, false));
      this.trailSource.addFeature(feature);
      this.trailFeatureIndex[ac.hex] = feature;
    }
  }

  private appendTrailPoint(history: TrailPoint[], projectedCoord: number[], sampleTs: number): void {
    if (history.length === 0) {
      history.push({ coord: projectedCoord, ts: sampleTs });
      return;
    }

    const prev = history[history.length - 1];
    const dtMs = Math.max(1, sampleTs - prev.ts);
    const dx = projectedCoord[0] - prev.coord[0];
    const dy = projectedCoord[1] - prev.coord[1];
    const distance = Math.hypot(dx, dy);

    const dtSteps = Math.ceil(dtMs / (TRAIL_INTERPOLATION_TARGET_SECONDS * 1000));
    const distSteps = Math.ceil(distance / TRAIL_INTERPOLATION_TARGET_METERS);
    const interpolationPoints = Math.min(
      TRAIL_INTERPOLATION_MAX_POINTS,
      Math.max(0, Math.max(dtSteps, distSteps) - 1)
    );

    for (let i = 1; i <= interpolationPoints; i++) {
      const t = i / (interpolationPoints + 1);
      history.push({
        coord: [
          prev.coord[0] + dx * t,
          prev.coord[1] + dy * t,
        ],
        ts: prev.ts + dtMs * t,
      });
    }

    history.push({ coord: projectedCoord, ts: sampleTs });
  }

  private smoothTrailCoordinates(coords: number[][]): number[][] {
    if (coords.length < 3) {
      return coords;
    }

    const smoothed: number[][] = [coords[0]];
    for (let i = 1; i < coords.length - 1; i++) {
      const start = Math.max(0, i - Math.floor(TRAIL_SMOOTHING_WINDOW / 2));
      const end = Math.min(coords.length - 1, i + Math.floor(TRAIL_SMOOTHING_WINDOW / 2));
      let sumX = 0;
      let sumY = 0;
      let count = 0;
      for (let j = start; j <= end; j++) {
        sumX += coords[j][0];
        sumY += coords[j][1];
        count++;
      }
      smoothed.push([sumX / count, sumY / count]);
    }
    smoothed.push(coords[coords.length - 1]);
    return smoothed;
  }

  private refreshAllStyles(): void {
    for (const hex of Object.keys(this.featureIndex)) {
      const f = this.featureIndex[hex];
      const ac = f.get('aircraft') as LiveAircraft;
      f.setStyle(this.makeStyle(ac, hex === this.selectedHex));
      if (this.trailFeatureIndex[hex]) {
        this.trailFeatureIndex[hex].setStyle(this.makeTrailStyle(altitudeColor(ac.altitude), hex === this.selectedHex));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Icon styles
  // -------------------------------------------------------------------------

  private makeStyle(ac: LiveAircraft, selected: boolean): Style {
    const fillColor = selected ? '#ffffff' : '#000000';
    const outlineColor = selected ? '#333333' : '#ffffff';
    const rotation = ((ac.track ?? 0) * Math.PI) / 180;
    const scale = selected ? 1.35 : 1.0;
    const aircraftClass = this.classifyAircraftForIcon(ac);

    return new Style({
      image: new Icon({
        opacity: 1,
        src: 'data:image/svg+xml;utf8,' +
          encodeURIComponent(this.svgForAircraftClass(aircraftClass, fillColor, outlineColor)),
        rotation: aircraftClass === 'balloon' || aircraftClass === 'ground' ? 0 : rotation,
        scale,
      }),
    });
  }

  private makeTrailStyle(color: string, selected: boolean): Style {
    return new Style({
      stroke: new Stroke({
        color,
        width: selected ? 2.6 : 1.8,
        lineCap: 'round',
        lineJoin: 'round'
      })
    });
  }

  private classifyAircraftForIcon(ac: LiveAircraft): string {
    const provided = (ac.aircraft_class || '').trim().toLowerCase();
    if (provided) return provided;

    const category = (ac.category || '').trim().toUpperCase();
    const callsign = (ac.flight || '').trim().toUpperCase();

    if (callsign.startsWith('RCH') || callsign.startsWith('NAVY') || callsign.startsWith('ARMY')) return 'military';
    if (category === 'A7') return 'helicopter';
    if (category === 'A5' || category === 'A6' || category === 'A4') return 'airliner';
    if (category === 'B1') return 'glider';
    if (category === 'B2') return 'balloon';
    if (category === 'B5') return 'uav';
    if (category.startsWith('C')) return 'ground';
    if (category.startsWith('D')) return 'military';
    if (category.startsWith('A') || category.startsWith('B')) return 'general_aviation';

    return 'unknown';
  }

  private svgForAircraftClass(aircraftClass: string, fill: string, outline: string): string {
    switch (aircraftClass) {
      case 'helicopter':
        return this.helicopterSvg(fill, outline);
      case 'military':
        return this.militaryJetSvg(fill, outline);
      case 'glider':
        return this.gliderSvg(fill, outline);
      case 'balloon':
        return this.balloonSvg(fill, outline);
      case 'uav':
        return this.uavSvg(fill, outline);
      case 'ground':
        return this.groundVehicleSvg(fill, outline);
      case 'general_aviation':
        return this.generalAviationSvg(fill, outline);
      case 'unknown':
        return this.unknownAircraftSvg(fill, outline);
      default:
        return this.airlinerSvg(fill, outline);
    }
  }

  /**
   * Returns the same airliner SVG used by the flight-history plot page,
   * allowing reuse of the existing visual language across the portal.
   * The SVG itself is original artwork included under the project's MIT licence.
   */
  private airlinerSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="40" height="40">` +
      `<path d="M25,2 L29,16 L46,24 L44,27 L29,21 L28,36 L34,43 L32,45 L25,40 L18,45 L16,43 L22,36 L21,21 L6,27 L4,24 L21,16 Z"` +
      ` fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round"/>` +
      `</svg>`;
  }

  private unknownAircraftSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<g fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round">` +
      `<path d="M25,4 C26.5,4 28,14 28,24 C28,36 26.5,45 25,48 C23.5,45 22,36 22,24 C22,14 23.5,4 25,4 Z"/>` +
      `<path d="M28,22 L42,32 L40,36 L25,26 L10,36 L8,32 L22,22 Z"/>` +
      `<path d="M25,44 L32,48 L31,49 L25,46 L19,49 L18,48 Z"/>` +
      `</g>` +
      `</svg>`;
  }

  // -------------------------------------------------------------------------
  // Aircraft selection
  // -------------------------------------------------------------------------

  selectAircraft(hex: string): void {
    this.selectedHex = hex;
    this.refreshAllStyles();
    this.photoUrl   = null;
    this.photoAttrib = null;

    const ac = this.aircraft.find(a => a.hex === hex);
    if (ac?.lat != null && ac.lon != null) {
      this.olMap.getView().animate({
        center: fromLonLat([ac.lon, ac.lat]),
        duration: 400,
      });
    }
    if (!this.panelOpen) this.panelOpen = true;

    // Attempt to load a photo from Planespotters
    if (hex) {
      this.photoLoading = true;
      this.dataService.getAircraftPhoto(hex).pipe(
        catchError(() => of(null))
      ).subscribe(res => {
        const photo = res?.photos?.[0];
        this.photoUrl   = photo?.thumbnail_large?.src ?? photo?.thumbnail?.src ?? null;
        this.photoAttrib = photo?.photographer ?? null;
        this.photoLoading = false;
        this.cdr.detectChanges();
      });
    }

    this.cdr.detectChanges();
  }

  clearSelection(): void {
    this.selectedHex  = null;
    this.photoUrl     = null;
    this.photoAttrib  = null;
    this.refreshAllStyles();
  }

  // -------------------------------------------------------------------------
  // Panel toggle
  // -------------------------------------------------------------------------

  togglePanel(): void {
    this.panelOpen = !this.panelOpen;
    // Wait for the panel transition to settle before forcing map re-layout.
    window.setTimeout(() => this.scheduleMapResize(), 320);
  }

  startResize(event: MouseEvent): void {
    event.preventDefault();
    if (!this.panelOpen) return;

    this.resizing = true;
    this.resizeStartX = event.clientX;
    this.resizeStartWidth = this.flyoutWidth;

    window.addEventListener('mousemove', this.windowMouseMoveHandler);
    window.addEventListener('mouseup', this.windowMouseUpHandler);
    document.body.style.cursor = 'ew-resize';
    document.body.style.userSelect = 'none';
  }

  private generalAviationSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<path d="M25,3.8 L27.6,11.6 L40.8,16.4 L40.2,19.6 L30,18.7 L27.7,24.2 L27.4,35.9 L31.9,41.8 L29.8,43.6 L25,39.8 L20.2,43.6 L18.1,41.8 L22.6,35.9 L22.3,24.2 L20,18.7 L9.8,19.6 L9.2,16.4 L22.4,11.6 Z"` +
      ` fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round"/>` +
      `<circle cx="25" cy="4.8" r="1.1" fill="${fill}" stroke="${outline}" stroke-width="0.8"/>` +
      `</svg>`;
  }

  private militaryJetSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="40" height="40">` +
      `<path d="M25,2 L28,14 L28,24 L47,34 L45,37 L28,28 L27,44 L29,47 L25,48 L21,47 L23,44 L22,28 L5,37 L3,34 L22,24 L22,14 Z"` +
      ` fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round"/>` +
      `</svg>`;
  }

  private helicopterSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 54" width="42" height="46">` +
      `<ellipse cx="25" cy="29" rx="7" ry="11" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<rect x="23.5" y="39" width="3" height="11" rx="1" fill="${fill}"/>` +
      `<rect x="18" y="47" width="14" height="3" rx="1.5" fill="${fill}"/>` +
      `<g transform="rotate(45 25 23)">` +
      `<rect x="3" y="21" width="44" height="4" rx="2" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="23" y="3" width="4" height="40" rx="2" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `</g>` +
      `<circle cx="25" cy="23" r="4.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `</svg>`;
  }

  private gliderSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 46" width="52" height="40">` +
      `<ellipse cx="30" cy="24" rx="2.5" ry="18" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<path d="M30,22 L2,26 L2,29 L30,25 L58,29 L58,26 Z" fill="${fill}" stroke="${outline}" stroke-width="0.5" stroke-linejoin="round"/>` +
      `<rect x="20" y="38" width="20" height="3.5" rx="1.75" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `</svg>`;
  }

  private balloonSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<circle cx="25" cy="25" r="22" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `</svg>`;
  }

  private uavSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="40" height="40">` +
      `<line x1="25" y1="25" x2="10" y2="10" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<line x1="25" y1="25" x2="40" y2="10" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<line x1="25" y1="25" x2="10" y2="40" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<line x1="25" y1="25" x2="40" y2="40" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<circle cx="10" cy="10" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<circle cx="40" cy="10" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<circle cx="10" cy="40" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<circle cx="40" cy="40" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<rect x="19" y="19" width="12" height="12" rx="3" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `</svg>`;
  }

  private groundVehicleSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<rect x="13" y="7" width="24" height="36" rx="4" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<rect x="8" y="10" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="36" y="10" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="8" y="29" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="36" y="29" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `</svg>`;
  }

  private onWindowMouseMove(event: MouseEvent): void {
    if (!this.resizing) return;
    const deltaX = event.clientX - this.resizeStartX;
    this.flyoutWidth = this.clampFlyoutWidth(this.resizeStartWidth + deltaX);
    this.cdr.detectChanges();
  }

  private stopResize(): void {
    if (!this.resizing) return;

    this.resizing = false;
    window.removeEventListener('mousemove', this.windowMouseMoveHandler);
    window.removeEventListener('mouseup', this.windowMouseUpHandler);
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
    this.scheduleMapResize();
  }

  private scheduleMapResize(): void {
    if (!this.olMap || typeof this.olMap.updateSize !== 'function') return;
    window.setTimeout(() => this.olMap.updateSize(), 0);
  }

  // -------------------------------------------------------------------------
  // Display helpers
  // -------------------------------------------------------------------------

  formatVRate(vr: number | null): string {
    if (vr == null) return '—';
    if (vr > 0) return `+${vr.toLocaleString()} ft/min`;
    if (vr < 0) return `${vr.toLocaleString()} ft/min`;
    return 'Level';
  }

  formatSeen(seen: number | null): string {
    if (seen == null) return '—';
    if (seen < 2) return 'Just now';
    return `${Math.round(seen)}s ago`;
  }

  formatAlt(alt: number | null): string {
    if (alt == null) return '—';
    if (alt <= 0)    return 'Ground';
    return `${alt.toLocaleString()} ft`;
  }

  aircraftTypeLabel(ac: LiveAircraft | null | undefined): string {
    const klass = (ac?.aircraft_class || '').trim().toLowerCase();
    switch (klass) {
      case 'airliner':
        return 'Airliner';
      case 'general_aviation':
        return 'General Aviation';
      case 'helicopter':
        return 'Helicopter';
      case 'military':
        return 'Military';
      case 'glider':
        return 'Glider';
      case 'balloon':
        return 'Balloon';
      case 'uav':
        return 'UAV';
      case 'ground':
        return 'Ground Vehicle';
      case 'space':
        return 'Space Vehicle';
      default:
        return 'Unknown';
    }
  }

  aircraftTypeSourceLabel(ac: LiveAircraft | null | undefined): string {
    const source = (ac?.classification_source || '').trim().toLowerCase();
    const confidence = (ac?.classification_confidence || '').trim().toLowerCase();
    const confidenceLabel = confidence ? ` (${confidence})` : '';

    if (source === 'opensky') {
      return `OpenSky${confidenceLabel}`;
    }
    return `Heuristic${confidenceLabel}`;
  }

  aircraftTypeLegendIconDataUrl(aircraftClass: string): string {
    const svg = this.svgForAircraftClass(aircraftClass, '#f8fafc', '#0f172a');
    return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  }

  flightHistoryLink(ac: LiveAircraft): string | null {
    if (!ac.flight) return null;
    const flightType = ac.source === 'dump978' ? 'uat' : 'adsb';
    return `/flight-history/${flightType}/${encodeURIComponent(ac.flight)}`;
  }

  sourceLabel(ac: LiveAircraft): string {
    return ac.source === 'dump978' ? 'Dump978 (UAT)' : 'Dump1090 (ADS-B)';
  }

  private clampInt(raw: string | undefined, min: number, max: number, fallback: number): number {
    const parsed = Number.parseInt(String(raw ?? ''), 10);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(min, Math.min(max, parsed));
  }

  private clampFloat(raw: string | undefined, min: number, max: number, fallback: number): number {
    const parsed = Number.parseFloat(String(raw ?? ''));
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(min, Math.min(max, parsed));
  }

  private clampFlyoutWidth(width: number): number {
    const viewportMax = Math.max(MIN_FLYOUT_WIDTH, window.innerWidth - 80);
    const max = Math.min(MAX_FLYOUT_WIDTH, viewportMax);
    return Math.max(MIN_FLYOUT_WIDTH, Math.min(max, width));
  }

  private spiderStyleFor(feature: Feature): Style {
    switch (feature.get('spiderKind')) {
      case 'center':
        return this.spiderCenterStyle;
      case 'polygon':
        return this.spiderPolygonStyle;
      default:
        return this.spiderPolygonStyle;
    }
  }

  private initSpiderOverlay(): void {
    this.spiderSource.clear();
    this.spiderPolygonFeature = null;

    if (!this.liveMapSpiderOverlayEnabled) return;

    this.spiderCenterProjected = fromLonLat([this.defaultCenterLon, this.defaultCenterLat]);
  }

  private initRadarSiteMarker(): void {
    this.radarSiteSource.clear();

    if (!this.liveMapCenterIconEnabled) return;

    const centerProjected = fromLonLat([this.defaultCenterLon, this.defaultCenterLat]);
    const center = new Feature({ geometry: new Point(centerProjected) });
    center.set('spiderKind', 'center');
    this.radarSiteSource.addFeature(center);
  }

  private initDistanceRings(): void {
    this.distanceRingSource.clear();

    if (!this.liveMapDistanceRingsEnabled) return;

    const center = fromLonLat([this.defaultCenterLon, this.defaultCenterLat]);
    const intervalMeters = this.liveMapDistanceRingIntervalMiles * 1609.344;
    const outerRadiusMeters = intervalMeters * this.liveMapDistanceRingCount;

    for (let i = 1; i <= this.liveMapDistanceRingCount; i += 1) {
      const radiusMeters = intervalMeters * i;
      const ring = new Feature({
        geometry: polygonFromCircle(new CircleGeom(center, radiusMeters), 128)
      });
      ring.set('distanceRingKind', 'ring');
      this.distanceRingSource.addFeature(ring);
    }

    if (this.liveMapDistanceRingCompassLinesEnabled) {
      for (let i = 0; i < 16; i += 1) {
        const angle = ((i / 16) * 360 - 90) * (Math.PI / 180);
        const ray = new Feature({
          geometry: new LineString([
            center,
            [
              center[0] + outerRadiusMeters * Math.cos(angle),
              center[1] + outerRadiusMeters * Math.sin(angle)
            ]
          ])
        });
        ray.set('distanceRingKind', 'ray');
        this.distanceRingSource.addFeature(ray);
      }
    }
  }

  private initTheoreticalRangeOverlay(): void {
    this.theoreticalRangeSource.clear();

    if (!this.liveMapTheoreticalRangeEnabled || !this.liveMapTheoreticalRangeJson) return;

    for (const ring of this.extractOverlayRings(this.liveMapTheoreticalRangeJson)) {
      this.theoreticalRangeSource.addFeature(new Feature({
        geometry: new Polygon([ring])
      }));
    }
  }

  private initHeyWhatsThatRingsOverlay(): void {
    this.heyWhatsThatRingsSource.clear();

    if (!this.liveMapHeyWhatsThatRingsEnabled || !this.liveMapHeyWhatsThatRingsJson) return;

    for (const ring of this.extractOverlayRings(this.liveMapHeyWhatsThatRingsJson)) {
      this.heyWhatsThatRingsSource.addFeature(new Feature({
        geometry: new Polygon([ring])
      }));
    }
  }

  private extractOverlayRings(rawJson: string): number[][][] {
    let parsed: unknown;

    try {
      parsed = JSON.parse(rawJson);
    } catch {
      return [];
    }

    const geoJsonFeatures = this.readGeoJsonFeatures(parsed);
    if (geoJsonFeatures.length > 0) {
      return geoJsonFeatures;
    }

    const rings = this.collectCoordinateRings(parsed)
      .map(ring => this.projectRing(ring))
      .filter((ring): ring is number[][] => ring.length >= 4);

    return rings;
  }

  private readGeoJsonFeatures(parsed: unknown): number[][][] {
    try {
      const features = new GeoJSON().readFeatures(parsed as object, {
        featureProjection: 'EPSG:3857',
        dataProjection: 'EPSG:4326'
      });

      return features.flatMap(feature => {
        const geometry = feature.getGeometry();
        if (geometry instanceof Polygon) {
          return [geometry.getCoordinates()[0]];
        }
        return [];
      }).filter(ring => ring.length >= 4);
    } catch {
      return [];
    }
  }

  private collectCoordinateRings(value: unknown): number[][][] {
    if (this.isLonLatPairArray(value)) {
      return [this.closeLonLatRing(value)];
    }

    if (this.isLonLatObjectArray(value)) {
      return [this.closeLonLatRing(value.map(point => [point.lon, point.lat]))];
    }

    if (!value || typeof value !== 'object') {
      return [];
    }

    if (Array.isArray(value)) {
      return value.flatMap(entry => this.collectCoordinateRings(entry));
    }

    return Object.values(value).flatMap(entry => this.collectCoordinateRings(entry));
  }

  private isLonLatPairArray(value: unknown): value is number[][] {
    return Array.isArray(value) && value.length >= 3 && value.every(item =>
      Array.isArray(item) && item.length >= 2 &&
      Number.isFinite(item[0]) && Number.isFinite(item[1])
    );
  }

  private isLonLatObjectArray(value: unknown): value is Array<{ lon: number; lat: number }> {
    return Array.isArray(value) && value.length >= 3 && value.every(item => {
      if (!item || typeof item !== 'object') return false;
      const candidate = item as Record<string, unknown>;
      const lon = candidate['lon'] ?? candidate['lng'] ?? candidate['longitude'];
      const lat = candidate['lat'] ?? candidate['latitude'];
      return Number.isFinite(lon) && Number.isFinite(lat);
    });
  }

  private closeLonLatRing(points: number[][]): number[][] {
    const ring = points.map(([lon, lat]) => [Number(lon), Number(lat)]);
    const first = ring[0];
    const last = ring[ring.length - 1];
    if (!first || !last) return [];
    if (first[0] !== last[0] || first[1] !== last[1]) {
      ring.push([first[0], first[1]]);
    }
    return ring;
  }

  private projectRing(ring: number[][]): number[][] {
    return ring
      .filter(([lon, lat]) => Number.isFinite(lon) && Number.isFinite(lat))
      .map(([lon, lat]) => fromLonLat([lon, lat]));
  }

  private distanceRingStyleFor(feature: Feature): Style {
    return feature.get('distanceRingKind') === 'ray'
      ? this.distanceRingRayStyle
      : this.distanceRingStyle;
  }

  private updateSpiderHistory(): void {
    if (!this.spiderCenterProjected) return;

    for (const ac of this.aircraft) {
      if (ac.lat == null || ac.lon == null || !ac.hex) continue;

      const bearing = this.calculateBearingDegrees(
        this.defaultCenterLat,
        this.defaultCenterLon,
        ac.lat,
        ac.lon
      );
      const sector = this.bearingToSector(bearing);
      const distanceMeters = this.calculateDistanceMeters(
        this.defaultCenterLat,
        this.defaultCenterLon,
        ac.lat,
        ac.lon
      );

      this.spiderSectorMaxDistanceMeters[sector] = Math.max(
        this.spiderSectorMaxDistanceMeters[sector],
        Math.min(distanceMeters, SPIDER_MAX_RADIUS_METERS)
      );
    }

    this.rebuildSpiderPolygon();
  }

  private rebuildSpiderPolygon(): void {
    const coords = this.buildSpiderPolygonCoords();
    if (coords.length === 0) {
      if (this.spiderPolygonFeature) {
        this.spiderSource.removeFeature(this.spiderPolygonFeature);
        this.spiderPolygonFeature = null;
      }
      return;
    }

    if (!this.spiderPolygonFeature) {
      this.spiderPolygonFeature = new Feature({ geometry: new Polygon([coords]) });
      this.spiderPolygonFeature.set('spiderKind', 'polygon');
      this.spiderSource.addFeature(this.spiderPolygonFeature);
      return;
    }

    (this.spiderPolygonFeature.getGeometry() as Polygon).setCoordinates([coords]);
  }

  private buildSpiderPolygonCoords(): number[][] {
    if (!this.spiderCenterProjected) return [];

    const hasData = this.spiderSectorMaxDistanceMeters.some(distance => distance > 0);
    if (!hasData) return [];

    const coords: number[][] = [];

    for (let i = 0; i < SPIDER_SECTOR_COUNT; i += 1) {
      const radius = this.spiderSectorMaxDistanceMeters[i];
      const angle = ((i / SPIDER_SECTOR_COUNT) * 360 - 90) * (Math.PI / 180);
      coords.push([
        this.spiderCenterProjected[0] + radius * Math.cos(angle),
        this.spiderCenterProjected[1] + radius * Math.sin(angle)
      ]);
    }

    coords.push(coords[0]);
    return coords;
  }

  private bearingToSector(bearing: number): number {
    const width = 360 / SPIDER_SECTOR_COUNT;
    const normalized = (bearing + 360 + width / 2) % 360;
    return Math.floor(normalized / width);
  }

  private calculateBearingDegrees(fromLat: number, fromLon: number, toLat: number, toLon: number): number {
    const startLat = this.degToRad(fromLat);
    const startLon = this.degToRad(fromLon);
    const endLat = this.degToRad(toLat);
    const endLon = this.degToRad(toLon);
    const deltaLon = endLon - startLon;

    const y = Math.sin(deltaLon) * Math.cos(endLat);
    const x = Math.cos(startLat) * Math.sin(endLat) -
      Math.sin(startLat) * Math.cos(endLat) * Math.cos(deltaLon);

    return (Math.atan2(y, x) * (180 / Math.PI) + 360) % 360;
  }

  private calculateDistanceMeters(fromLat: number, fromLon: number, toLat: number, toLon: number): number {
    const earthRadiusMeters = 6_371_000;
    const lat1 = this.degToRad(fromLat);
    const lat2 = this.degToRad(toLat);
    const deltaLat = this.degToRad(toLat - fromLat);
    const deltaLon = this.degToRad(toLon - fromLon);

    const a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
      Math.cos(lat1) * Math.cos(lat2) *
      Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  private degToRad(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}
