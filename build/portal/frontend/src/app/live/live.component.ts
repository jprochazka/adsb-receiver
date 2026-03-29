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
import VectorSource from 'ol/source/Vector';
import VectorLayer from 'ol/layer/Vector';
import TileLayer from 'ol/layer/Tile';
import View from 'ol/View';
import Style from 'ol/style/Style';
import Icon from 'ol/style/Icon';
import Stroke from 'ol/style/Stroke';
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
const DEFAULT_FLYOUT_WIDTH = 280;
const MIN_FLYOUT_WIDTH = 240;
const MAX_FLYOUT_WIDTH = 560;

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
}

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

  // Computed counts
  get aircraftWithPosition(): number {
    return this.aircraft.filter(a => a.lat != null && a.lon != null).length;
  }

  // Exposed helper for templates
  readonly altColor = altitudeColor;

  // OL map objects
  private olMap!: OlMap;
  private aircraftSource = new VectorSource();
  private trailSource = new VectorSource();
  /** hex -> OL Feature lookup for in-place position updates */
  private featureIndex: { [hex: string]: Feature } = {};
  /** hex -> list of projected points retained for trail rendering */
  private trailHistory: { [hex: string]: number[][] } = {};
  /** hex -> trail line feature */
  private trailFeatureIndex: { [hex: string]: Feature } = {};

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
    }).subscribe(({ enabled, refreshMs, centerLat, centerLon, zoom, trailPoints, showAllSeen }) => {
      this.liveMapEnabled = enabled?.value !== 'false';
      this.refreshMs = this.clampInt(refreshMs?.value, 1_000, 60_000, DEFAULT_REFRESH_MS);
      this.defaultCenterLat = this.clampFloat(centerLat?.value, -85, 85, DEFAULT_CENTER_LAT);
      this.defaultCenterLon = this.clampFloat(centerLon?.value, -180, 180, DEFAULT_CENTER_LON);
      this.defaultZoom = this.clampFloat(zoom?.value, 1, 18, DEFAULT_ZOOM);
      this.trailPoints = this.clampInt(trailPoints?.value, 0, 200, DEFAULT_TRAIL_POINTS);
      this.showAllSeen = showAllSeen?.value !== 'false';
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
    this.olMap = new OlMap({
      layers: [
        new TileLayer({ source: new OSM() }),
        new VectorLayer({ source: this.trailSource, zIndex: 8 }),
        new VectorLayer({ source: this.aircraftSource, zIndex: 10 }),
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

      this.updateTrail(ac, coord);

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

  private updateTrail(ac: LiveAircraft, projectedCoord: number[]): void {
    if (this.trailPoints <= 0) return;

    const history = this.trailHistory[ac.hex] ?? [];
    const last = history[history.length - 1];
    const moved = !last || Math.abs(last[0] - projectedCoord[0]) > 5 || Math.abs(last[1] - projectedCoord[1]) > 5;

    if (moved) {
      history.push(projectedCoord);
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
    if (this.trailFeatureIndex[ac.hex]) {
      const existing = this.trailFeatureIndex[ac.hex];
      (existing.getGeometry() as LineString).setCoordinates(history);
      existing.setStyle(this.makeTrailStyle(color, ac.hex === this.selectedHex));
    } else {
      const feature = new Feature({ geometry: new LineString(history) });
      feature.setStyle(this.makeTrailStyle(color, false));
      this.trailSource.addFeature(feature);
      this.trailFeatureIndex[ac.hex] = feature;
    }
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
    const fillColor    = selected ? '#ffffff' : altitudeColor(ac.altitude);
    const outlineColor = sourceColor(ac.source);
    const rotation     = ((ac.track ?? 0) * Math.PI) / 180;
    const scale        = selected ? 1.35 : 1.0;

    return new Style({
      image: new Icon({
        opacity: 1,
        src: 'data:image/svg+xml;utf8,' +
          encodeURIComponent(this.airlinerSvg(outlineColor, fillColor)),
        rotation,
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

  /**
   * Returns the same airliner SVG used by the flight-history plot page,
   * allowing reuse of the existing visual language across the portal.
   * The SVG itself is original artwork included under the project's MIT licence.
   */
  private airlinerSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 25 26" width="25px" height="26px">` +
      `<defs><style>.cls-1{fill:${fill};}.cls-2{fill:${outline};}</style></defs>` +
      `<title>airliner</title><g><g>` +
      `<path class="cls-1" d="M12.51,25.75c-.26,0-.74-.71-.86-1.41l-3.33.86L8,25.29l.08-1.41.11-.07` +
      `c1.13-.68,2.68-1.64,3.2-2-.37-1.06-.51-3.92-.43-8.52v0L8,13.31C5.37,14.12,1.2,15.39,1,15.5` +
      `a.5.5,0,0,1-.21,0,.52.52,0,0,1-.49-.45,1,1,0,0,1,.52-1l1.74-.91c1.36-.71,3.22-1.69,4.66-2.43` +
      `a4,4,0,0,1,0-.52c0-.69,0-1,0-1.14l.25-.13H7.16A1.07,1.07,0,0,1,8.24,7.73,1.12,1.12,0,0,1,9.06,8` +
      `a1.46,1.46,0,0,1,.26.87L9.08,9h.25c0,.14,0,.31,0,.58l1.52-.84c0-1.48,0-7.06,1.1-8.25a.74.74,0,0,1,1.13,0` +
      `c1.15,1.19,1.13,6.78,1.1,8.25l1.52.84c0-.32,0-.48,0-.58l.25-.13H15.7A1.46,1.46,0,0,1,16,8` +
      `a1.11,1.11,0,0,1,.82-.28,1.06,1.06,0,0,1,1.08,1.16V9c0,.19,0,.48,0,1.17a4,4,0,0,1,0,.52` +
      `c1.75.9,4.4,2.29,5.67,3l.73.38a.9.9,0,0,1,.5,1,.55.55,0,0,1-.5.47h0l-.11,0` +
      `c-.28-.11-4.81-1.49-7.16-2.2H14.06v0c.09,4.6-.06,7.46-.43,8.52.52.33,2.07,1.29,3.2,2l.11.07` +
      `L17,25.29l-.33-.09-3.33-.86c-.12.7-.6,1.41-.86,1.41h0Z"/>` +
      `<path class="cls-2" d="M12.51.5C13.93.5,14,7,13.93,8.91c.3.16,1.64.91,2,1.1,0-.6,0-.85,0-1` +
      `s0-.09,0-.13a1.18,1.18,0,0,1,.19-.7A.88.88,0,0,1,16.78,8h0a.82.82,0,0,1,.83.91s0,.07,0,.13` +
      `s0,.44,0,1.17a3.21,3.21,0,0,1-.06.66c2.33,1.19,6.51,3.39,6.56,3.42.59.3.4,1,.11,1h-.07` +
      `c-.37-.14-7.18-2.21-7.18-2.21l-3.18,0c0,.22.22,7.56-.48,8.91,0,0,2,1.26,3.39,2.08l.06.93` +
      `L13.15,24a2.14,2.14,0,0,1-.64,1.47A2.14,2.14,0,0,1,11.87,24L8.26,25,8.31,24` +
      `c1.38-.82,3.39-2.08,3.39-2.08-.7-1.35-.48-8.69-.48-8.91L8,13.06S1.17,15.13.86,15.27l-.11,0` +
      `c-.32,0-.43-.73.14-1S5.13,12,7.46,10.85a3.21,3.21,0,0,1-.06-.66c0-.73,0-1,0-1.17` +
      `s0-.09,0-.13A.82.82,0,0,1,8.24,8h0a.88.88,0,0,1,.65.21,1.18,1.18,0,0,1,.19.7` +
      `s0,.07,0,.13,0,.39,0,1c.36-.19,1.71-.94,2-1.1C11.05,7,11.09.5,12.51.5m0-.5a1,1,0,0,0-.74.34` +
      `c-1.16,1.2-1.2,6.3-1.18,8.28L10,8.93l-.46.25V8.91a1.68,1.68,0,0,0-.33-1.06,1.34,1.34,0,0,0-1-.36` +
      `a1.31,1.31,0,0,0-1.33,1.4V9h0v0c0,.16,0,.46,0,1.14,0,.13,0,.26,0,.38l-4.5,2.35-1.74.91` +
      `A1.2,1.2,0,0,0,0,15.15a.77.77,0,0,0,.73.64.74.74,0,0,0,.31-.07c.29-.12,4.35-1.35,7-2.17l2.6,0` +
      `c-.1,5.54.17,7.46.38,8.2-.64.4-2,1.25-3,1.86l-.22.13,0,.26-.06.93,0,.81.7-.31,3.06-.79` +
      `c.19.67.63,1.35,1,1.35s.86-.68,1-1.35l3.06.79.7.31,0-.81L17.2,24l0-.26L17,23.6` +
      `c-1-.61-2.4-1.47-3-1.86.21-.74.48-2.66.38-8.2l2.6,0c2.72.83,6.81,2.07,7.07,2.18` +
      `a.68.68,0,0,0,.25,0,.79.79,0,0,0,.74-.67,1.15,1.15,0,0,0-.63-1.29l-.71-.37` +
      `c-1.23-.65-3.78-2-5.53-2.88,0-.12,0-.25,0-.38,0-.67,0-1,0-1.14h0V8.92` +
      `a1.32,1.32,0,0,0-1.32-1.44,1.35,1.35,0,0,0-1,.36,1.67,1.67,0,0,0-.33,1V9h0v.22` +
      `L15,8.93l-.57-.32c0-2,0-7.08-1.18-8.28A1,1,0,0,0,12.51,0Z"/></g></g></svg>`;
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
}
