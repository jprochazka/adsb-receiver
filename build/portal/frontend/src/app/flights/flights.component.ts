import { Component, OnDestroy, OnInit, inject } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { forkJoin, combineLatest } from 'rxjs';
import { catchError, of } from 'rxjs';
import 'ol/ol.css';
import Map from 'ol/Map';
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
import { ZoomSlider, FullScreen } from 'ol/control';
import ControlScaleLine from 'ol/control/ScaleLine';
import smooth from 'to-smooth';

const PAGE_SIZE = 50;
const TRACK_GAP_HOURS = 2;
const TRACK_COLORS = ['#0ea5e9', '#22c55e', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4'];

@Component({
  selector: 'app-flights',
  standalone: true,
  imports: [FormsModule, SpinnerComponent, RouterLink],
  templateUrl: './flights.component.html',
  styleUrl: './flights.component.scss'
})
export class FlightsComponent implements OnInit, OnDestroy {
  // ADS-B
  adsbData: any;
  adsbCurrentPage = 1;
  adsbTotalPages = 1;
  adsbTotalFlights = 0;
  adsbPageNumbers: number[] = [];

  // UAT
  uatData: any;
  uatCurrentPage = 1;
  uatTotalPages = 1;
  uatTotalFlights = 0;
  uatPageNumbers: number[] = [];

  // Tab visibility settings
  allTabEnabled  = true;
  adsbTabEnabled = true;
  uatTabEnabled  = true;

  // Combined list (both sources merged, sorted by last_seen desc)
  combinedFlights: any[] = [];

  loading = true;
  errorMessage = '';
  searchQuery = '';
  private _filterQuery = '';
  get filterQuery(): string {
    return this._filterQuery;
  }
  set filterQuery(val: string) {
    this._filterQuery = val;
  }
  activeTab: 'all' | 'adsb' | 'uat' = 'all';

  // Flight detail/map mode
  detailMode = false;
  flightId = '';
  flightType: 'adsb' | 'uat' = 'adsb';
  selectedTrackIdx: number | null = null;
  tracks: Array<{
    color: string;
    dateLabel: string;
    extent: any;
    startTime: string;
    endTime: string;
    positionCount: number;
    lastAltitude: number | null;
    lastSpeed: number | null;
    lastSquawk: number | null;
  }> = [];
  flyoutOpen = true;
  photoUrl: string | null = null;
  photoAttribution: string | null = null;
  flightInfo: {
    icao: string;
    firstSeen: string;
    lastSeen: string;
    totalPositions: number;
    trackCount: number;
    lastAltitude: number | null;
    lastSpeed: number | null;
    lastSquawk: number | null;
  } | null = null;

  get activeTrack() {
    return this.selectedTrackIdx !== null ? this.tracks[this.selectedTrackIdx] : null;
  }

  private map!: Map;
  private vectorLayer: VectorLayer<any> | null = null;
  private allExtent: any = null;

  private route = inject(ActivatedRoute);
  private router = inject(Router);

  constructor(private data_service: DataService) {}

  ngOnDestroy(): void {
    if (this.map) {
      this.map.setTarget(undefined);
    }
  }

  ngOnInit() {
    forkJoin({
      allTab:  this.data_service.getSetting('all_tab_enabled').pipe(catchError(() => of({ value: 'true' }))),
      adsbTab: this.data_service.getSetting('adsb_tab_enabled').pipe(catchError(() => of({ value: 'true' }))),
      uatTab:  this.data_service.getSetting('uat_tab_enabled').pipe(catchError(() => of({ value: 'true' }))),
    }).subscribe(({ allTab, adsbTab, uatTab }) => {
      this.allTabEnabled  = allTab?.value  !== 'false';
      this.adsbTabEnabled = adsbTab?.value !== 'false';
      this.uatTabEnabled  = uatTab?.value  !== 'false';
      if (this.allTabEnabled && this.adsbTabEnabled && this.uatTabEnabled) {
        this.activeTab = 'all';
      } else if (!this.adsbTabEnabled && this.uatTabEnabled) {
        this.activeTab = 'uat';
      } else if (this.adsbTabEnabled && !this.uatTabEnabled) {
        this.activeTab = 'adsb';
      } else {
        this.activeTab = 'all';
      }
      this.subscribeToRoute();
    });
  }

  private subscribeToRoute() {
    combineLatest([
      this.route.paramMap,
      this.route.queryParamMap
    ]).subscribe(([params, queryParams]) => {
      const detailFlight = params.get('flight');
      if (detailFlight) {
        this.enterDetailMode(detailFlight);
        return;
      }

      this.detailMode = false;
      const q = queryParams.get('q') || '';
      this.searchQuery = q;
      this.loading = true;
      this.errorMessage = '';

      if (q) {
        forkJoin({
          adsb: this.data_service.searchFlights(q).pipe(catchError(() => of(null))),
          uat:  this.data_service.searchUatFlights(q).pipe(catchError(() => of(null))),
        }).subscribe(({ adsb, uat }) => {
          this.adsbData = adsb;
          this.uatData  = uat;
          this.adsbTotalFlights = adsb?.count ?? 0;
          this.uatTotalFlights  = uat?.count  ?? 0;
          this.adsbTotalPages = 1;
          this.uatTotalPages  = 1;
          this.adsbPageNumbers = [];
          this.uatPageNumbers  = [];
          const adsbMapped = (adsb?.flights || []).map((f: any) => ({ ...f, _type: 'adsb' }));
          const uatMapped  = (uat?.flights  || []).map((f: any) => ({ ...f, _type: 'uat'  }));
          this.combinedFlights = [...adsbMapped, ...uatMapped]
            .sort((a, b) => (b.last_seen > a.last_seen ? 1 : -1));
          this.loading = false;
        });
      } else {
        const adsbPage = Math.max(1, parseInt(params.get('page') || '1', 10) || 1);
        const uatPage  = Math.max(1, parseInt(params.get('uatPage') || '1', 10) || 1);
        this.adsbCurrentPage = adsbPage;
        this.uatCurrentPage  = uatPage;

        forkJoin({
          adsbCount: this.data_service.GetFlightsCount(),
          adsbFlights: this.data_service.getFlights((adsbPage - 1) * PAGE_SIZE, PAGE_SIZE),
          uatCount: this.data_service.getUatFlightsCount().pipe(catchError(() => of({ flights: 0 }))),
          uatFlights: this.data_service.getUatFlights((uatPage - 1) * PAGE_SIZE, PAGE_SIZE).pipe(catchError(() => of(null))),
        }).subscribe(({ adsbCount, adsbFlights, uatCount, uatFlights }) => {
          this.adsbTotalFlights = adsbCount.flights;
          this.adsbTotalPages   = Math.max(1, Math.ceil(adsbCount.flights / PAGE_SIZE));
          this.adsbCurrentPage  = Math.min(adsbPage, this.adsbTotalPages);
          this.adsbPageNumbers  = this.buildPageNumbers(this.adsbCurrentPage, this.adsbTotalPages);
          this.adsbData = adsbFlights;

          this.uatTotalFlights = uatCount.flights;
          this.uatTotalPages   = Math.max(1, Math.ceil(uatCount.flights / PAGE_SIZE));
          this.uatCurrentPage  = Math.min(uatPage, this.uatTotalPages);
          this.uatPageNumbers  = this.buildPageNumbers(this.uatCurrentPage, this.uatTotalPages);
          this.uatData = uatFlights;

          const adsbMapped = (adsbFlights?.flights || []).map((f: any) => ({ ...f, _type: 'adsb' }));
          const uatMapped  = (uatFlights?.flights  || []).map((f: any) => ({ ...f, _type: 'uat'  }));
          this.combinedFlights = [...adsbMapped, ...uatMapped]
            .sort((a, b) => (b.last_seen > a.last_seen ? 1 : -1));

          this.loading = false;
        });
      }
    });
  }

  private enterDetailMode(flight: string): void {
    this.detailMode = true;
    this.loading = true;
    this.errorMessage = '';
    this.flightId = flight;
    this.flightType = (this.route.snapshot.url[1]?.path === 'uat') ? 'uat' : 'adsb';
    this.tracks = [];
    this.flightInfo = null;
    this.selectedTrackIdx = null;
    this.photoUrl = null;
    this.photoAttribution = null;
    this.flyoutOpen = true;

    if (!this.map) {
      this.initMap();
    }

    if (this.vectorLayer) {
      this.map.removeLayer(this.vectorLayer);
      this.vectorLayer = null;
    }

    this.loadDetailPositions();
  }

  private initMap(): void {
    this.map = new Map({
      layers: [new TileLayer({ source: new OSM() })],
      target: 'map',
      view: new View({ center: fromLonLat([0, 20]), zoom: 3, maxZoom: 18 })
    });
    this.map.addControl(new FullScreen());
    this.map.addControl(new ControlScaleLine());
    this.map.addControl(new ZoomSlider());
  }

  private loadDetailPositions(): void {
    const details$ = this.flightType === 'uat'
      ? this.data_service.getUatFlightDetails(this.flightId).pipe(catchError(() => of(null)))
      : this.data_service.getFlightDetails(this.flightId).pipe(catchError(() => of(null)));
    const posData$ = this.flightType === 'uat'
      ? this.data_service.getUatFlightPositions(this.flightId)
      : this.data_service.getFlightPositions(this.flightId);

    forkJoin({ details: details$, posData: posData$ }).subscribe({
      next: ({ details, posData }) => {
        this.loading = false;
        this.flightInfo = {
          icao: details?.icao ?? '—',
          firstSeen: details?.first_seen ?? '—',
          lastSeen: details?.last_seen ?? '—',
          totalPositions: posData.positions?.length ?? 0,
          trackCount: 0,
          lastAltitude: null,
          lastSpeed: null,
          lastSquawk: null
        };
        if (!posData.positions?.length) {
          this.errorMessage = 'No position data available for this flight.';
          return;
        }
        this.plotTracks(posData.positions);

        const icao = details?.icao;
        if (icao && icao !== '—') {
          this.data_service.getAircraftPhoto(icao).pipe(catchError(() => of(null))).subscribe(res => {
            const photo = res?.photos?.[0];
            this.photoUrl = photo?.thumbnail_large?.src ?? photo?.thumbnail?.src ?? null;
            this.photoAttribution = photo?.photographer ?? null;
          });
        }
      },
      error: () => {
        this.loading = false;
        this.errorMessage = 'Failed to load position data.';
      }
    });
  }

  private splitIntoSegments(positions: any[]): any[][] {
    positions.sort((a, b) => a.time.localeCompare(b.time));

    const segments: any[][] = [];
    let current: any[] = [positions[0]];

    for (let i = 1; i < positions.length; i++) {
      const prevMs = new Date(positions[i - 1].time.replace(' ', 'T')).getTime();
      const currMs = new Date(positions[i].time.replace(' ', 'T')).getTime();
      if ((currMs - prevMs) / 3_600_000 > TRACK_GAP_HOURS) {
        segments.push(current);
        current = [positions[i]];
      } else {
        current.push(positions[i]);
      }
    }
    segments.push(current);
    return segments.filter(s => s.length > 0);
  }

  private plotTracks(positions: any[]): void {
    const segments = this.splitIntoSegments(positions);
    const allFeatures: Feature[] = [];
    this.tracks = [];

    segments.forEach((segment, idx) => {
      const color = TRACK_COLORS[idx % TRACK_COLORS.length];
      const coords = segment.map((p: any) => fromLonLat([p.longitude, p.latitude]));
      const smoothed = coords.length <= 25 ? this.makeSmooth(coords, 3) : coords;

      const line = new Feature({ geometry: new LineString(smoothed) });
      line.setStyle(new Style({
        stroke: new Stroke({ color, width: 2.5, lineCap: 'round', lineJoin: 'round' })
      }));
      allFeatures.push(line);

      allFeatures.push(this.iconFeature(segment[0], color));
      if (segment.length > 1) {
        allFeatures.push(this.iconFeature(segment[segment.length - 1], color));
      }

      const segSource = new VectorSource({ features: [line] });
      const segExtent = segSource.getExtent();

      const startDate = segment[0].time.substring(0, 10);
      const endDate = segment[segment.length - 1].time.substring(0, 10);
      const lastPos = segment[segment.length - 1];
      this.tracks.push({
        color,
        dateLabel: startDate === endDate ? startDate : `${startDate} → ${endDate}`,
        extent: segExtent,
        startTime: segment[0].time,
        endTime: lastPos.time,
        positionCount: segment.length,
        lastAltitude: lastPos.altitude ?? null,
        lastSpeed: lastPos.speed ?? null,
        lastSquawk: lastPos.squawk ?? null
      });
    });

    const source = new VectorSource({ features: allFeatures });
    this.vectorLayer = new VectorLayer({ source });
    this.map.addLayer(this.vectorLayer);
    this.allExtent = source.getExtent();

    this.map.getView().fit(this.allExtent, {
      padding: [80, 60, 60, 300],
      maxZoom: 12,
      duration: 600
    });

    if (this.flightInfo) {
      this.flightInfo.trackCount = segments.length;
      const lastSeg = segments[segments.length - 1];
      const lastPos = lastSeg[lastSeg.length - 1];
      this.flightInfo.lastAltitude = lastPos.altitude ?? null;
      this.flightInfo.lastSpeed = lastPos.speed ?? null;
      this.flightInfo.lastSquawk = lastPos.squawk ?? null;
    }
  }

  selectTrack(val: string): void {
    const idx = parseInt(val, 10);
    if (isNaN(idx) || idx < 0) {
      this.selectedTrackIdx = null;
      if (this.allExtent) {
        this.map.getView().fit(this.allExtent, {
          padding: [80, 60, 60, 300],
          maxZoom: 12,
          duration: 600
        });
      }
    } else {
      this.selectedTrackIdx = idx;
      const extent = this.tracks[idx]?.extent;
      if (extent) {
        this.map.getView().fit(extent, {
          padding: [100, 80, 80, 310],
          maxZoom: 12,
          duration: 600
        });
      }
    }
  }

  toggleFlyout(): void {
    this.flyoutOpen = !this.flyoutOpen;
  }

  zoomToTrack(idx: number): void {
    this.selectTrack(String(idx));
  }

  private iconFeature(pos: any, color: string): Feature {
    const rotationRad = ((pos.track ?? 0) * Math.PI) / 180;
    const f = new Feature({ geometry: new Point(fromLonLat([pos.longitude, pos.latitude])) });
    f.setStyle(new Style({
      image: new Icon({
        opacity: 1,
        src: 'data:image/svg+xml;utf8,' + encodeURIComponent(this.airlinerSvg('#0b142e', color)),
        rotation: rotationRad
      })
    }));
    return f;
  }

  private airlinerSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 25 26" width="25px" height="26px"><defs><style>.cls-1{fill:${fill};}.cls-2{fill:${outline};}</style></defs><title>airliner</title><g id="Layer_2" data-name="Layer 2"><g id="Airliner"><path class="cls-1" d="M12.51,25.75c-.26,0-.74-.71-.86-1.41l-3.33.86L8,25.29l.08-1.41.11-.07c1.13-.68,2.68-1.64,3.2-2-.37-1.06-.51-3.92-.43-8.52v0L8,13.31C5.37,14.12,1.2,15.39,1,15.5a.5.5,0,0,1-.21,0,.52.52,0,0,1-.49-.45,1,1,0,0,1,.52-1l1.74-.91c1.36-.71,3.22-1.69,4.66-2.43a4,4,0,0,1,0-.52c0-.69,0-1,0-1.14l.25-.13H7.16A1.07,1.07,0,0,1,8.24,7.73,1.12,1.12,0,0,1,9.06,8a1.46,1.46,0,0,1,.26.87L9.08,9h.25c0,.14,0,.31,0,.58l1.52-.84c0-1.48,0-7.06,1.1-8.25a.74.74,0,0,1,1.13,0c1.15,1.19,1.13,6.78,1.1,8.25l1.52.84c0-.32,0-.48,0-.58l.25-.13H15.7A1.46,1.46,0,0,1,16,8a1.11,1.11,0,0,1,.82-.28,1.06,1.06,0,0,1,1.08,1.16V9c0,.19,0,.48,0,1.17a4,4,0,0,1,0,.52c1.75.9,4.4,2.29,5.67,3l.73.38a.9.9,0,0,1,.5,1,.55.55,0,0,1-.5.47h0l-.11,0c-.28-.11-4.81-1.49-7.16-2.2H14.06v0c.09,4.6-.06,7.46-.43,8.52.52.33,2.07,1.29,3.2,2l.11.07L17,25.29l-.33-.09-3.33-.86c-.12.7-.6,1.41-.86,1.41h0Z"/><path class="cls-2" d="M12.51.5C13.93.5,14,7,13.93,8.91c.3.16,1.64.91,2,1.1,0-.6,0-.85,0-1s0-.09,0-.13a1.18,1.18,0,0,1,.19-.7A.88.88,0,0,1,16.78,8h0a.82.82,0,0,1,.83.91s0,.07,0,.13,0,.44,0,1.17a3.21,3.21,0,0,1-.06.66c2.33,1.19,6.51,3.39,6.56,3.42.59.3.4,1,.11,1h-.07c-.37-.14-7.18-2.21-7.18-2.21l-3.18,0c0,.22.22,7.56-.48,8.91,0,0,2,1.26,3.39,2.08l.06.93L13.15,24a2.14,2.14,0,0,1-.64,1.47A2.14,2.14,0,0,1,11.87,24L8.26,25,8.31,24c1.38-.82,3.39-2.08,3.39-2.08-.7-1.35-.48-8.69-.48-8.91L8,13.06S1.17,15.13.86,15.27l-.11,0c-.32,0-.43-.73.14-1S5.13,12,7.46,10.85a3.21,3.21,0,0,1-.06-.66c0-.73,0-1,0-1.17s0-.09,0-.13A.82.82,0,0,1,8.24,8h0a.88.88,0,0,1,.65.21,1.18,1.18,0,0,1,.19.7s0,.07,0,.13,0,.39,0,1c.36-.19,1.71-.94,2-1.1C11.05,7,11.09.5,12.51.5m0-.5a1,1,0,0,0-.74.34c-1.16,1.2-1.2,6.3-1.18,8.28L10,8.93l-.46.25V8.91a1.68,1.68,0,0,0-.33-1.06,1.34,1.34,0,0,0-1-.36,1.31,1.31,0,0,0-1.33,1.4V9h0v0c0,.16,0,.46,0,1.14,0,.13,0,.26,0,.38l-4.5,2.35-1.74.91A1.2,1.2,0,0,0,0,15.15a.77.77,0,0,0,.73.64.74.74,0,0,0,.31-.07c.29-.12,4.35-1.35,7-2.17l2.6,0c-.1,5.54.17,7.46.38,8.2-.64.4-2,1.25-3,1.86l-.22.13,0,.26-.06.93,0,.81.7-.31,3.06-.79c.19.67.63,1.35,1,1.35s.86-.68,1-1.35l3.06.79.7.31,0-.81L17.2,24l0-.26L17,23.6c-1-.61-2.4-1.47-3-1.86.21-.74.48-2.66.38-8.2l2.6,0c2.72.83,6.81,2.07,7.07,2.18a.68.68,0,0,0,.25,0,.79.79,0,0,0,.74-.67,1.15,1.15,0,0,0-.63-1.29l-.71-.37c-1.23-.65-3.78-2-5.53-2.88,0-.12,0-.25,0-.38,0-.67,0-1,0-1.14h0V8.92a1.32,1.32,0,0,0-1.32-1.44,1.35,1.35,0,0,0-1,.36,1.67,1.67,0,0,0-.33,1V9h0v.22L15,8.93l-.57-.32c0-2,0-7.08-1.18-8.28A1,1,0,0,0,12.51,0Z"/></g></g></svg>`;
  }

  private makeSmooth(coords: any[], iterations: number): any[] {
    iterations = Math.min(Math.max(iterations, 1), 10);
    while (iterations-- > 0) coords = smooth(coords);
    return coords;
  }

  setTab(tab: 'all' | 'adsb' | 'uat') {
    this.activeTab = tab;
  }

  goToAdsbPage(page: number) {
    if (page < 1 || page > this.adsbTotalPages || page === this.adsbCurrentPage) return;
    this.router.navigate(['/flights', page]);
  }

  goToUatPage(page: number) {
    if (page < 1 || page > this.uatTotalPages || page === this.uatCurrentPage) return;
    this.router.navigate(['/flights'], { queryParams: { uatPage: page } });
  }

  get filteredCombinedFlights(): any[] {
    const q = this.filterQuery.trim().toLowerCase();
    if (!q) return this.combinedFlights;
    return this.combinedFlights.filter(f => this.matchesFlight(f, q));
  }

  get filteredAdsbFlights(): any[] {
    const q = this.filterQuery.trim().toLowerCase();
    const flights = this.adsbData?.flights || [];
    if (!q) return flights;
    return flights.filter((f: any) => this.matchesFlight(f, q));
  }

  get filteredUatFlights(): any[] {
    const q = this.filterQuery.trim().toLowerCase();
    const flights = this.uatData?.flights || [];
    if (!q) return flights;
    return flights.filter((f: any) => this.matchesFlight(f, q));
  }

  get combinedTabCount(): number {
    if (!this.filterQuery.trim()) return this.adsbTotalFlights + this.uatTotalFlights;
    return this.filteredCombinedFlights.length;
  }

  get adsbTabCount(): number {
    if (!this.filterQuery.trim()) return this.adsbTotalFlights;
    return this.filteredAdsbFlights.length;
  }

  get uatTabCount(): number {
    if (!this.filterQuery.trim()) return this.uatTotalFlights;
    return this.filteredUatFlights.length;
  }

  private matchesFlight(flight: any, q: string): boolean {
    return (flight.flight || '').toLowerCase().includes(q) || (flight.icao || '').toLowerCase().includes(q);
  }

  private buildPageNumbers(current: number, total: number): number[] {
    if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
    const pages = new Set<number>();
    pages.add(1);
    pages.add(total);
    for (let i = Math.max(1, current - 2); i <= Math.min(total, current + 2); i++) pages.add(i);
    return Array.from(pages).sort((a, b) => a - b);
  }
}
