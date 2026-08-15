import { DatePipe } from '@angular/common';
import { DecimalPipe } from '@angular/common';
import { ChangeDetectorRef, Component, HostListener, OnDestroy, OnInit, inject, ChangeDetectionStrategy } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import type { AisTarget } from '../shared/api-types';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import {
  AIRCRAFT_TYPE_LEGEND,
  aircraftTypeLabel,
  aircraftTypeSourceLabel,
  altitudeColor,
  classifyAircraftForIcon,
  flightHistoryLink,
  sourceLabel,
} from './live-display.helpers';
import { extractOverlayRings } from './live-overlay.helpers';
import { DEFAULT_FLYOUT_WIDTH, DEFAULT_LIVE_MAP_SETTINGS, clampFlyoutWidth, parseLiveMapSettings } from './live-settings.helpers';
import { interval, Subscription, of, catchError, forkJoin, startWith, switchMap } from 'rxjs';

import 'ol/ol.css';
import OlMap from 'ol/Map';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import LineString from 'ol/geom/LineString';
import CircleGeom from 'ol/geom/Circle';
import Polygon from 'ol/geom/Polygon';
import { fromCircle as polygonFromCircle } from 'ol/geom/Polygon';
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

const SPIDER_SECTOR_COUNT = 16;
const SPIDER_MAX_RADIUS_METERS = 300_000;
const TRAIL_INTERPOLATION_TARGET_SECONDS = 6;
const TRAIL_INTERPOLATION_TARGET_METERS = 1_500;
const TRAIL_INTERPOLATION_MAX_POINTS = 12;
const TRAIL_SMOOTHING_WINDOW = 3;
const OPENSTREETMAP_ATTRIBUTION_HTML = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap contributors</a>';
const OPENSKY_ATTRIBUTION_HTML = '<a href="https://opensky-network.org/datasets/metadata/aircraftDatabase.csv" target="_blank" rel="noopener noreferrer">OpenSky Network Aircraft Database (ODbL v1.0)</a>';

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
  changeDetection: ChangeDetectionStrategy.Eager,
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
  selectedAisIdentity: string | null = null;
  get selectedAircraft(): LiveAircraft | null {
    return this.selectedHex
      ? (this.aircraft.find(a => a.hex === this.selectedHex) ?? null)
      : null;
  }
  get selectedAis(): AisTarget | null {
    if (!this.selectedAisIdentity) return null;
    return this.aisTargets.find(target =>
      `ais:${target.mmsi}:${target.target_kind}` === this.selectedAisIdentity
    ) ?? null;
  }

  // UI
  panelOpen    = true;
  flyoutWidth = DEFAULT_FLYOUT_WIDTH;
  photoUrl:     string | null = null;
  photoAttrib:  string | null = null;
  photoLoading  = false;

  // Settings
  liveMapEnabled = DEFAULT_LIVE_MAP_SETTINGS.liveMapEnabled;
  refreshMs = DEFAULT_LIVE_MAP_SETTINGS.refreshMs;
  defaultCenterLon = DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLon;
  defaultCenterLat = DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLat;
  defaultZoom = DEFAULT_LIVE_MAP_SETTINGS.defaultZoom;
  trailPoints = DEFAULT_LIVE_MAP_SETTINGS.trailPoints;
  showAllSeen = DEFAULT_LIVE_MAP_SETTINGS.showAllSeen;
  liveMapSpiderOverlayEnabled = DEFAULT_LIVE_MAP_SETTINGS.liveMapSpiderOverlayEnabled;
  liveMapCenterIconEnabled = DEFAULT_LIVE_MAP_SETTINGS.liveMapCenterIconEnabled;
  liveMapDistanceRingsEnabled = DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingsEnabled;
  liveMapDistanceRingCompassLinesEnabled = DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingCompassLinesEnabled;
  liveMapDistanceRingCount = DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingCount;
  liveMapDistanceRingIntervalMiles = DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingIntervalMiles;
  liveMapTheoreticalRangeEnabled = DEFAULT_LIVE_MAP_SETTINGS.liveMapTheoreticalRangeEnabled;
  liveMapTheoreticalRangeJson = DEFAULT_LIVE_MAP_SETTINGS.liveMapTheoreticalRangeJson;
  liveMapHeyWhatsThatRingsEnabled = DEFAULT_LIVE_MAP_SETTINGS.liveMapHeyWhatsThatRingsEnabled;
  liveMapHeyWhatsThatRingsJson = DEFAULT_LIVE_MAP_SETTINGS.liveMapHeyWhatsThatRingsJson;

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

  get aisWithPosition(): number {
    return this.aisTargets.filter(target => target.latitude != null && target.longitude != null).length;
  }

  get trackedCount(): number {
    return this.aircraft.length + this.aisTargets.length;
  }

  get plottedCount(): number {
    return this.aircraftWithPosition + this.aisWithPosition;
  }

  // Exposed helper for templates
  readonly altColor = altitudeColor;
  readonly aircraftTypeLegend = AIRCRAFT_TYPE_LEGEND;

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
  private aisSource = new VectorSource();
  private aisFeatureIndex: { [identity: string]: Feature } = {};
  aisTargets: AisTarget[] = [];
  aisTargetKindFilter = 'all';
  get filteredAisTargets(): AisTarget[] {
    if (this.aisTargetKindFilter === 'all') return this.aisTargets;
    return this.aisTargets.filter(target => target.target_kind === this.aisTargetKindFilter);
  }
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
      refreshMs: this.dataService.getSetting('live_map_refresh_ms').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.refreshMs) }))),
      centerLat: this.dataService.getSetting('live_map_center_lat').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLat) }))),
      centerLon: this.dataService.getSetting('live_map_center_lon').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLon) }))),
      zoom: this.dataService.getSetting('live_map_default_zoom').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.defaultZoom) }))),
      trailPoints: this.dataService.getSetting('live_map_trail_points').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.trailPoints) }))),
      showAllSeen: this.dataService.getSetting('live_map_show_all_seen').pipe(catchError(() => of({ value: 'true' }))),
      spiderOverlayEnabled: this.dataService.getSetting('live_map_spider_overlay_enabled').pipe(catchError(() => of({ value: 'true' }))),
      centerIconEnabled: this.dataService.getSetting('live_map_center_icon_enabled').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.liveMapCenterIconEnabled) }))),
      distanceRingsEnabled: this.dataService.getSetting('live_map_distance_rings_enabled').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingsEnabled) }))),
      distanceRingCompassLinesEnabled: this.dataService.getSetting('live_map_distance_ring_compass_lines_enabled').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingCompassLinesEnabled) }))),
      distanceRingCount: this.dataService.getSetting('live_map_distance_ring_count').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingCount) }))),
      distanceRingIntervalMiles: this.dataService.getSetting('live_map_distance_ring_interval_miles').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingIntervalMiles) }))),
      theoreticalRangeEnabled: this.dataService.getSetting('live_map_theoretical_range_enabled').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.liveMapTheoreticalRangeEnabled) }))),
      theoreticalRangeJson: this.dataService.getSetting('live_map_theoretical_range_json').pipe(catchError(() => of({ value: DEFAULT_LIVE_MAP_SETTINGS.liveMapTheoreticalRangeJson }))),
      heyWhatsThatRingsEnabled: this.dataService.getSetting('live_map_heywhatsthat_rings_enabled').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_SETTINGS.liveMapHeyWhatsThatRingsEnabled) }))),
      heyWhatsThatRingsJson: this.dataService.getSetting('live_map_heywhatsthat_rings_json').pipe(catchError(() => of({ value: DEFAULT_LIVE_MAP_SETTINGS.liveMapHeyWhatsThatRingsJson }))),
    }).subscribe(({ enabled, refreshMs, centerLat, centerLon, zoom, trailPoints, showAllSeen, spiderOverlayEnabled, centerIconEnabled, distanceRingsEnabled, distanceRingCompassLinesEnabled, distanceRingCount, distanceRingIntervalMiles, theoreticalRangeEnabled, theoreticalRangeJson, heyWhatsThatRingsEnabled, heyWhatsThatRingsJson }) => {
      Object.assign(this, parseLiveMapSettings({
        enabled: enabled?.value,
        refreshMs: refreshMs?.value,
        centerLat: centerLat?.value,
        centerLon: centerLon?.value,
        zoom: zoom?.value,
        trailPoints: trailPoints?.value,
        showAllSeen: showAllSeen?.value,
        spiderOverlayEnabled: spiderOverlayEnabled?.value,
        centerIconEnabled: centerIconEnabled?.value,
        distanceRingsEnabled: distanceRingsEnabled?.value,
        distanceRingCompassLinesEnabled: distanceRingCompassLinesEnabled?.value,
        distanceRingCount: distanceRingCount?.value,
        distanceRingIntervalMiles: distanceRingIntervalMiles?.value,
        theoreticalRangeEnabled: theoreticalRangeEnabled?.value,
        theoreticalRangeJson: theoreticalRangeJson?.value,
        heyWhatsThatRingsEnabled: heyWhatsThatRingsEnabled?.value,
        heyWhatsThatRingsJson: heyWhatsThatRingsJson?.value,
      }));
      afterLoad();
    });
  }

  private startPolling(): void {
    this.subscription?.unsubscribe();
    this.subscription = interval(this.refreshMs).pipe(
      startWith(0),
      switchMap(() => forkJoin({
        aircraft: this.dataService.getLiveAircraft().pipe(catchError(() => of(null))),
        ais: this.dataService.getLiveAis().pipe(catchError(() => of(null))),
      }))
    ).subscribe(data => {
      if (data.aircraft) {
        this.handleData(data.aircraft);
      }
      if (data.ais) {
        this.handleAisData(data.ais);
      } else if (this.loading) {
        this.loading = false;
        this.errorMessage = 'Unable to reach aircraft or AIS data. Ensure the decoder(s) are running and reachable.';
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
        new VectorLayer({ source: this.aisSource, zIndex: 15 }),
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
      let hitAis: string | null = null;
      this.olMap.forEachFeatureAtPixel(
        evt.pixel,
        feature => {
          hitHex = (feature.get('hex') as string) ?? null;
          hitAis = (feature.get('id') as string) ?? null;
          return true; // stop after first hit
        },
        { hitTolerance: 8 }
      );
      const aisIdentity = hitAis as string | null;
      if (hitHex) {
        this.selectAircraft(hitHex);
      } else if (aisIdentity?.startsWith('ais:')) {
        this.selectAis(aisIdentity);
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

  private handleAisData(data: { items?: AisTarget[] }): void {
    this.aisTargets = data.items ?? [];
    const active = new Set<string>();
    for (const target of this.aisTargets) {
      if (target.latitude == null || target.longitude == null) continue;
      const identity = `ais:${target.mmsi}:${target.target_kind}`;
      active.add(identity);
      const coordinate = fromLonLat([target.longitude, target.latitude]);
      const existing = this.aisFeatureIndex[identity];
      if (existing) {
        (existing.getGeometry() as Point).setCoordinates(coordinate);
        existing.set('ais', target, true);
        existing.setStyle(this.makeAisStyle(target));
      } else {
        const feature = new Feature({ geometry: new Point(coordinate) });
        feature.set('id', identity);
        feature.set('ais', target);
        feature.setStyle(this.makeAisStyle(target));
        this.aisSource.addFeature(feature);
        this.aisFeatureIndex[identity] = feature;
      }
    }
    for (const identity of Object.keys(this.aisFeatureIndex)) {
      if (!active.has(identity)) {
        this.aisSource.removeFeature(this.aisFeatureIndex[identity]);
        delete this.aisFeatureIndex[identity];
      }
    }
    if (this.selectedAisIdentity && !active.has(this.selectedAisIdentity)) {
      this.selectedAisIdentity = null;
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
    const aircraftClass = classifyAircraftForIcon(ac);

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

  private makeAisStyle(target: AisTarget): Style {
    const rotation = ((target.heading ?? target.course ?? 0) * Math.PI) / 180;
    const stale = target.last_seen
      ? Date.now() - Date.parse(target.last_seen) > 300_000
      : true;
    const fill = stale ? '#64748b' : '#0f766e';
    const outline = stale ? '#cbd5e1' : '#ccfbf1';
    const icon = this.aisIconForTarget(target, fill, outline);
    return new Style({
      image: new Icon({
        src: 'data:image/svg+xml;utf8,' + encodeURIComponent(icon.svg),
        rotation: icon.rotates ? rotation : 0,
        scale: 0.9,
      }),
    });
  }

  private aisIconForTarget(target: AisTarget, fill: string, outline: string): { svg: string; rotates: boolean } {
    switch (target.target_kind) {
      case 'sar_aircraft':
        return { svg: this.aisSarSvg(fill, outline), rotates: true };
      case 'base_station':
        return { svg: this.aisBaseStationSvg(fill, outline), rotates: false };
      case 'aid_to_navigation':
        return { svg: this.aisAidSvg(fill, outline), rotates: false };
      default:
        return { svg: this.aisVesselSvg(target.vessel_type, fill, outline), rotates: true };
    }
  }

  private aisVesselSvg(vesselType: number | null | undefined, fill: string, outline: string): string {
    const shape = vesselType != null && vesselType >= 80 && vesselType <= 89
      ? '<path d="M16 2 23 21 19 28 13 28 9 21Z"/>'
      : vesselType != null && vesselType >= 70 && vesselType <= 79
        ? '<path d="M16 2 24 8 22 27 10 27 8 8Z"/><path d="M10 13h12M10 18h12M11 23h10" fill="none"/>'
      : vesselType != null && vesselType >= 60 && vesselType <= 69
        ? '<path d="M16 2 24 9 22 26 10 26 8 9Z"/><path d="M11 12h10M10 17h12" fill="none"/>'
        : vesselType != null && vesselType >= 30 && vesselType <= 39
          ? '<path d="M16 3 22 22 16 29 10 22Z"/><path d="M11 21h10" fill="none"/>'
          : '<path d="M16 3 22 22 16 29 10 22Z"/>';
    return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="${fill}" stroke="${outline}" stroke-width="2" stroke-linejoin="round">${shape}</g><path d="M16 7v15" stroke="${outline}" stroke-width="1.5"/></svg>`;
  }

  private aisSarSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="${fill}" stroke="${outline}" stroke-width="2" stroke-linejoin="round"><path d="M16 3 19 12 29 16 19 20 16 29 13 20 3 16 13 12Z"/><circle cx="16" cy="16" r="3" fill="${outline}" stroke="none"/></g></svg>`;
  }

  private aisBaseStationSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="${outline}" stroke-width="2" stroke-linecap="round"><path d="M16 6v20M10 26h12M12 12a6 6 0 0 1 8 0M8 8a11 11 0 0 1 16 0"/><circle cx="16" cy="6" r="3" fill="${fill}"/></g></svg>`;
  }

  private aisAidSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="${fill}" stroke="${outline}" stroke-width="2" stroke-linejoin="round"><path d="M16 3 21 10 20 25 16 29 12 25 11 10Z"/><path d="M7 13h18M8 18h16" fill="none"/></g></svg>`;
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
    this.selectedAisIdentity = null;
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

  selectAis(identity: string): void {
    const target = this.aisTargets.find(item =>
      `ais:${item.mmsi}:${item.target_kind}` === identity
    );
    if (!target) return;
    this.selectedAisIdentity = identity;
    this.selectedHex = null;
    if (target.latitude != null && target.longitude != null) {
      this.olMap.getView().animate({
        center: fromLonLat([target.longitude, target.latitude]),
        duration: 400,
      });
    }
    if (!this.panelOpen) this.panelOpen = true;
    this.cdr.detectChanges();
  }

  clearSelection(): void {
    this.selectedHex  = null;
    this.selectedAisIdentity = null;
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
    return aircraftTypeLabel(ac);
  }

  aircraftTypeSourceLabel(ac: LiveAircraft | null | undefined): string {
    return aircraftTypeSourceLabel(ac);
  }

  aircraftTypeLegendIconDataUrl(aircraftClass: string): string {
    const svg = this.svgForAircraftClass(aircraftClass, '#f8fafc', '#0f172a');
    return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  }

  aisLegendIconDataUrl(): string {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">' +
      '<path d="M16 3 22 22 16 29 10 22Z" fill="#0f766e" stroke="#ccfbf1" stroke-width="2"/>' +
      '<path d="M16 7v15" stroke="#ccfbf1" stroke-width="1.5"/>' +
      '</svg>';
    return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  }

  flightHistoryLink(ac: LiveAircraft): string | null {
    return flightHistoryLink(ac);
  }

  sourceLabel(ac: LiveAircraft): string {
    return sourceLabel(ac);
  }

  private clampFlyoutWidth(width: number): number {
    return clampFlyoutWidth(width, window.innerWidth);
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

    for (const ring of extractOverlayRings(this.liveMapTheoreticalRangeJson)) {
      this.theoreticalRangeSource.addFeature(new Feature({
        geometry: new Polygon([ring])
      }));
    }
  }

  private initHeyWhatsThatRingsOverlay(): void {
    this.heyWhatsThatRingsSource.clear();

    if (!this.liveMapHeyWhatsThatRingsEnabled || !this.liveMapHeyWhatsThatRingsJson) return;

    for (const ring of extractOverlayRings(this.liveMapHeyWhatsThatRingsJson)) {
      this.heyWhatsThatRingsSource.addFeature(new Feature({
        geometry: new Polygon([ring])
      }));
    }
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
