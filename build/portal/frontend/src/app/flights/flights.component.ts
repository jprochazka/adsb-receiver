import { DatePipe } from '@angular/common';
import { ChangeDetectorRef, Component, OnDestroy, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import { getCurrentAccessTokenPayload } from '../shared/auth-session';
import { aircraftTypeLabelForFlight, buildPageNumbers, inferAircraftClass, normalizeCount, normalizeSightingsCount } from './flight-display.helpers';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { forkJoin, combineLatest } from 'rxjs';
import { catchError, map, of } from 'rxjs';
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

const DEFAULT_PAGE_SIZE = 50;
const TRACK_GAP_HOURS = 2;
const TRACK_COLORS = ['#0ea5e9', '#22c55e', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4'];
const TRACK_INTERPOLATION_TARGET_SECONDS = 6;
const TRACK_INTERPOLATION_TARGET_METERS = 2_000;
const TRACK_INTERPOLATION_MAX_POINTS_PER_EDGE = 16;
const OPENSTREETMAP_ATTRIBUTION_HTML = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap contributors</a>';
const OPENSKY_ATTRIBUTION_HTML = '<a href="https://opensky-network.org/datasets/metadata/aircraftDatabase.csv" target="_blank" rel="noopener noreferrer">OpenSky Network Aircraft Database (ODbL v1.0)</a>';

@Component({
  selector: 'app-flights',
  standalone: true,
  imports: [DatePipe, FormsModule, SpinnerComponent, RouterLink],
  templateUrl: './flights.component.html',
  styleUrl: './flights.component.scss'
})
export class FlightsComponent implements OnInit, OnDestroy {
  readonly pageSizeOptions = [10, 25, 50, 100];
  perPage = DEFAULT_PAGE_SIZE;

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
  allCurrentPage = 1;

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
  commentsOpen = false;
  commentsLoading = false;
  commentsSubmitting = false;
  commentsMutating = false;
  commentsError = '';
  commentDraft = '';
  comments: any[] = [];
  editingCommentId: number | null = null;
  editingDraft = '';
  currentUserId: number | null = null;
  currentUserLocked = true;
  currentUserRole: string | null = null;
  ignoreOnPurge = false;
  ignoreOnPurgeUpdating = false;
  ignoreOnPurgeError = '';
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
    aircraftClass: string;
  } | null = null;

  private currentAircraftClass = 'unknown';

  get activeTrack() {
    return this.selectedTrackIdx !== null ? this.tracks[this.selectedTrackIdx] : null;
  }

  private map!: Map;
  private vectorLayer: VectorLayer<any> | null = null;
  private allExtent: any = null;

  private route = inject(ActivatedRoute);
  router = inject(Router);
  private cdr = inject(ChangeDetectorRef);

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
      if (this.map) {
        this.map.setTarget(undefined);
      }
      this.commentsOpen = false;
      this.comments = [];
      this.commentDraft = '';
      this.editingCommentId = null;
      this.editingDraft = '';
      this.commentsError = '';
      const q = queryParams.get('q') || '';
      this.searchQuery = q;
      const requestedPerPage = Number(queryParams.get('perPage') || DEFAULT_PAGE_SIZE);
      this.perPage = this.pageSizeOptions.includes(requestedPerPage) ? requestedPerPage : DEFAULT_PAGE_SIZE;
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
        const allPage = Math.max(1, parseInt(queryParams.get('allPage') || '1', 10) || 1);
        this.adsbCurrentPage = adsbPage;
        this.uatCurrentPage  = uatPage;
        this.allCurrentPage = allPage;

        forkJoin({
          adsbCount: this.data_service.GetFlightsCount(),
          uatCount: this.data_service.getUatFlightsCount().pipe(catchError(() => of({ flights: 0 }))),
        }).subscribe(({ adsbCount, uatCount }) => {
          this.adsbTotalFlights = adsbCount.flights;
          this.adsbTotalPages   = Math.max(1, Math.ceil(adsbCount.flights / this.perPage));
          this.adsbCurrentPage  = Math.min(adsbPage, this.adsbTotalPages);
          this.adsbPageNumbers  = buildPageNumbers(this.adsbCurrentPage, this.adsbTotalPages);

          this.uatTotalFlights = uatCount.flights;
          this.uatTotalPages   = Math.max(1, Math.ceil(uatCount.flights / this.perPage));
          this.uatCurrentPage  = Math.min(uatPage, this.uatTotalPages);
          this.uatPageNumbers  = buildPageNumbers(this.uatCurrentPage, this.uatTotalPages);

          const allTotalPages = Math.max(1, Math.ceil(this.allTotalFlights / this.perPage));
          this.allCurrentPage = Math.min(allPage, allTotalPages);

          const combinedNeeded = this.allCurrentPage * this.perPage;
          forkJoin({
            adsbFlights: this.data_service.getFlights((this.adsbCurrentPage - 1) * this.perPage, this.perPage),
            uatFlights: this.data_service.getUatFlights((this.uatCurrentPage - 1) * this.perPage, this.perPage).pipe(catchError(() => of(null))),
            adsbTopFlights: this.loadTopAdsbFlights(combinedNeeded),
            uatTopFlights: this.loadTopUatFlights(combinedNeeded),
          }).subscribe(({ adsbFlights, uatFlights, adsbTopFlights, uatTopFlights }) => {
            this.adsbData = adsbFlights;
            this.uatData = uatFlights;

            const allMapped = [
              ...adsbTopFlights.map((f: any) => ({ ...f, _type: 'adsb' })),
              ...uatTopFlights.map((f: any) => ({ ...f, _type: 'uat' })),
            ].sort((a, b) => (b.last_seen > a.last_seen ? 1 : -1));

            const allOffset = (this.allCurrentPage - 1) * this.perPage;
            this.combinedFlights = allMapped.slice(allOffset, allOffset + this.perPage);

            this.loading = false;
          });
        });
      }
    });
  }

  private loadTopAdsbFlights(limit: number) {
    return this.loadTopFlights(
      (offset, size) => this.data_service.getFlights(offset, size),
      this.adsbTotalFlights,
      limit,
    );
  }

  private loadTopUatFlights(limit: number) {
    return this.loadTopFlights(
      (offset, size) => this.data_service.getUatFlights(offset, size).pipe(catchError(() => of({ flights: [] }))),
      this.uatTotalFlights,
      limit,
    );
  }

  private loadTopFlights(
    fetchPage: (offset: number, limit: number) => any,
    total: number,
    neededLimit: number,
  ) {
    const target = Math.min(Math.max(0, neededLimit), Math.max(0, total));
    if (target === 0) {
      return of([] as any[]);
    }

    const requests = [];
    for (let offset = 0; offset < target; offset += 100) {
      const chunk = Math.min(100, target - offset);
      requests.push(fetchPage(offset, chunk));
    }

    return forkJoin(requests).pipe(
      map((responses: any[]) =>
        responses.flatMap((response) => Array.isArray(response?.flights) ? response.flights : [])
      )
    );
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
    this.commentsOpen = false;
    this.comments = [];
    this.commentDraft = '';
    this.editingCommentId = null;
    this.editingDraft = '';
    this.commentsError = '';
    this.ignoreOnPurge = false;
    this.ignoreOnPurgeUpdating = false;
    this.ignoreOnPurgeError = '';
    this.loadCurrentUserState();

    // Recreate map every time detail mode is entered to avoid stale target state.
    if (this.map) {
      this.map.setTarget(undefined);
    }
    this.cdr.detectChanges();
    this.initMap();

    if (this.vectorLayer) {
      this.map.removeLayer(this.vectorLayer);
      this.vectorLayer = null;
    }

    this.loadDetailPositions();
  }

  private initMap(): void {
    const osmSource = new OSM({
      attributions: [OPENSTREETMAP_ATTRIBUTION_HTML, OPENSKY_ATTRIBUTION_HTML]
    });

    this.map = new Map({
      layers: [new TileLayer({ source: osmSource })],
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
        const aircraftClass = inferAircraftClass(details);
        this.currentAircraftClass = aircraftClass;
        this.flightInfo = {
          icao: details?.icao ?? '—',
          firstSeen: details?.first_seen ?? '—',
          lastSeen: details?.last_seen ?? '—',
          totalPositions: normalizeCount(posData?.total, posData.positions?.length ?? 0),
          trackCount: normalizeSightingsCount(details?.sightings_count, 0),
          lastAltitude: null,
          lastSpeed: null,
          lastSquawk: null,
          aircraftClass,
        };
        this.ignoreOnPurge = !!details?.ignore_on_purge;
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
      const coords = this.buildRenderableSegmentCoords(segment);
      const smoothed = coords.length <= 25 ? this.makeSmooth(coords, 3) : this.makeSmooth(coords, 2);

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
      if (!this.flightInfo.trackCount || this.flightInfo.trackCount < 1) {
        this.flightInfo.trackCount = segments.length;
      }
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

  openComments(): void {
    this.commentsOpen = true;
    this.commentsError = '';
    this.loadComments();
    this.loadCurrentUserState();
  }

  closeComments(): void {
    this.commentsOpen = false;
    this.editingCommentId = null;
    this.editingDraft = '';
  }

  get isLoggedIn(): boolean {
    const payload = this.getTokenPayload();
    return !!payload && (payload.exp * 1000 > Date.now());
  }

  get canAddComments(): boolean {
    if (!this.isLoggedIn) return false;
    if (this.currentUserLocked) return false;
    return this.currentUserRole === 'Admin' || this.currentUserRole === 'User';
  }

  get canModerateComments(): boolean {
    if (!this.isLoggedIn) return false;
    if (this.currentUserLocked) return false;
    return this.hasAdminRole();
  }

  get canToggleIgnoreOnPurge(): boolean {
    return this.canModerateComments;
  }

  canEditComment(comment: any): boolean {
    if (!this.isLoggedIn || this.currentUserLocked) return false;
    if (this.hasAdminRole()) return true;
    return this.currentUserId !== null && comment?.user_id === this.currentUserId;
  }

  private hasAdminRole(): boolean {
    return (this.currentUserRole || '').trim().toLowerCase() === 'admin';
  }

  canDeleteComment(comment: any): boolean {
    if (!comment) return false;
    return this.canModerateComments;
  }

  updateIgnoreOnPurge(event: Event): void {
    if (!this.canToggleIgnoreOnPurge || this.ignoreOnPurgeUpdating) {
      const input = event.target as HTMLInputElement;
      input.checked = this.ignoreOnPurge;
      return;
    }

    const input = event.target as HTMLInputElement;
    const nextValue = !!input.checked;
    const previousValue = this.ignoreOnPurge;

    this.ignoreOnPurge = nextValue;
    this.ignoreOnPurgeUpdating = true;
    this.ignoreOnPurgeError = '';

    const request$ = this.flightType === 'uat'
      ? this.data_service.updateUatFlightPurgePreference(this.flightId, nextValue)
      : this.data_service.updateFlightPurgePreference(this.flightId, nextValue);

    request$.subscribe({
      next: (response) => {
        this.ignoreOnPurge = !!response?.ignore_on_purge;
        this.ignoreOnPurgeUpdating = false;
      },
      error: (err) => {
        this.ignoreOnPurge = previousValue;
        input.checked = previousValue;
        this.ignoreOnPurgeUpdating = false;
        this.ignoreOnPurgeError = err?.error?.msg || 'Unable to update purge preference.';
      }
    });
  }

  submitComment(): void {
    const content = this.commentDraft.trim();
    if (!content || !this.canAddComments || this.commentsSubmitting) {
      return;
    }

    this.commentsSubmitting = true;
    this.commentsError = '';

    const request$ = this.flightType === 'uat'
      ? this.data_service.createUatFlightComment(this.flightId, content)
      : this.data_service.createFlightComment(this.flightId, content);

    request$.subscribe({
      next: (comment) => {
        this.commentDraft = '';
        this.comments.unshift(comment);
        this.commentsSubmitting = false;
      },
      error: (err) => {
        this.commentsSubmitting = false;
        this.commentsError = err?.error?.msg || 'Unable to add comment.';
      }
    });
  }

  private loadComments(): void {
    this.commentsLoading = true;
    this.commentsError = '';

    const request$ = this.flightType === 'uat'
      ? this.data_service.getUatFlightComments(this.flightId)
      : this.data_service.getFlightComments(this.flightId);

    request$.subscribe({
      next: (res) => {
        this.comments = (res?.comments || []).slice().reverse();
        this.editingCommentId = null;
        this.editingDraft = '';
        this.commentsLoading = false;
      },
      error: (err) => {
        this.comments = [];
        this.commentsLoading = false;
        this.commentsError = err?.error?.msg || 'Unable to load comments.';
      }
    });
  }

  private loadCurrentUserState(): void {
    if (!this.isLoggedIn) {
      this.currentUserId = null;
      this.currentUserLocked = true;
      this.currentUserRole = null;
      return;
    }

    const payload = this.getTokenPayload();
    this.currentUserId = payload?.user_id ?? null;
    this.currentUserRole = payload?.role || null;

    const userId = payload?.user_id;
    if (!userId) {
      this.currentUserId = null;
      this.currentUserLocked = true;
      return;
    }

    this.data_service.getUser(userId).pipe(catchError(() => of(null))).subscribe((user) => {
      this.currentUserId = user?.id ?? this.currentUserId;
      this.currentUserLocked = user?.locked !== false;
      this.currentUserRole = user?.role || this.currentUserRole;
    });
  }

  private getTokenPayload(): any | null {
    return getCurrentAccessTokenPayload();
  }

  beginEditComment(comment: any): void {
    if (!this.canEditComment(comment)) return;
    this.editingCommentId = comment.id;
    this.editingDraft = comment.content || '';
  }

  cancelEditComment(): void {
    this.editingCommentId = null;
    this.editingDraft = '';
  }

  saveEditedComment(comment: any): void {
    if (!this.canEditComment(comment) || this.commentsMutating) return;
    const content = this.editingDraft.trim();
    if (!content) return;

    this.commentsMutating = true;
    this.commentsError = '';

    const request$ = this.flightType === 'uat'
      ? this.data_service.updateUatFlightComment(this.flightId, comment.id, content)
      : this.data_service.updateFlightComment(this.flightId, comment.id, content);

    request$.subscribe({
      next: (updated) => {
        const idx = this.comments.findIndex(c => c.id === comment.id);
        if (idx >= 0) this.comments[idx] = updated;
        this.commentsMutating = false;
        this.cancelEditComment();
      },
      error: (err) => {
        this.commentsMutating = false;
        this.commentsError = err?.error?.msg || 'Unable to update comment.';
      }
    });
  }

  deleteComment(comment: any): void {
    if (!this.canDeleteComment(comment) || this.commentsMutating) return;

    this.commentsMutating = true;
    this.commentsError = '';

    const request$ = this.flightType === 'uat'
      ? this.data_service.deleteUatFlightComment(this.flightId, comment.id)
      : this.data_service.deleteFlightComment(this.flightId, comment.id);

    request$.subscribe({
      next: () => {
        this.comments = this.comments.filter(c => c.id !== comment.id);
        this.commentsMutating = false;
        if (this.editingCommentId === comment.id) this.cancelEditComment();
      },
      error: (err) => {
        this.commentsMutating = false;
        this.commentsError = err?.error?.msg || 'Unable to delete comment.';
      }
    });
  }

  zoomToTrack(idx: number): void {
    this.selectTrack(String(idx));
  }

  private iconFeature(pos: any, color: string): Feature {
    const rotationRad = ((pos.track ?? 0) * Math.PI) / 180;
    const iconClass = this.currentAircraftClass || 'unknown';
    const f = new Feature({ geometry: new Point(fromLonLat([pos.longitude, pos.latitude])) });
    f.setStyle(new Style({
      image: new Icon({
        opacity: 1,
        src: 'data:image/svg+xml;utf8,' + encodeURIComponent(this.svgForAircraftClass(iconClass, '#000000', '#ffffff')),
        rotation: iconClass === 'balloon' || iconClass === 'ground' ? 0 : rotationRad
      })
    }));
    return f;
  }

  aircraftTypeIconDataUrl(flight: any): string {
    const klass = inferAircraftClass(flight);
    const svg = this.svgForAircraftClass(klass, '#f8fafc', '#0f172a');
    return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  }

  flyoutAircraftTypeIconDataUrl(): string {
    const klass = this.currentAircraftClass || this.flightInfo?.aircraftClass || 'unknown';
    const svg = this.svgForAircraftClass(String(klass).trim().toLowerCase(), '#f8fafc', '#0f172a');
    return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  }

  flyoutAircraftTypeLabel(): string {
    return this.aircraftTypeLabelForFlight({ aircraft_class: this.currentAircraftClass || this.flightInfo?.aircraftClass || 'unknown' });
  }

  aircraftTypeLabelForFlight(flight: any): string {
    return aircraftTypeLabelForFlight(flight);
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

  private unknownAircraftSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<g fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round">` +
      `<path d="M25,4 C26.5,4 28,14 28,24 C28,36 26.5,45 25,48 C23.5,45 22,36 22,24 C22,14 23.5,4 25,4 Z"/>` +
      `<path d="M28,22 L42,32 L40,36 L25,26 L10,36 L8,32 L22,22 Z"/>` +
      `<path d="M25,44 L32,48 L31,49 L25,46 L19,49 L18,48 Z"/>` +
      `</g>` +
      `</svg>`;
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

  private airlinerSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="40" height="40">` +
      `<path d="M25,2 L29,16 L46,24 L44,27 L29,21 L28,36 L34,43 L32,45 L25,40 L18,45 L16,43 L22,36 L21,21 L6,27 L4,24 L21,16 Z"` +
      ` fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round"/>` +
      `</svg>`;
  }

  private makeSmooth(coords: any[], iterations: number): any[] {
    if (coords.length < 3) {
      return coords;
    }
    iterations = Math.min(Math.max(iterations, 1), 10);
    while (iterations-- > 0) coords = smooth(coords);
    return coords;
  }

  private buildRenderableSegmentCoords(segment: any[]): number[][] {
    if (!segment.length) {
      return [];
    }

    const baseCoords = segment.map((p: any) => fromLonLat([p.longitude, p.latitude]));
    if (baseCoords.length < 2) {
      return baseCoords;
    }

    const rendered: number[][] = [baseCoords[0]];

    for (let i = 1; i < segment.length; i++) {
      const prev = segment[i - 1];
      const curr = segment[i];
      const prevCoord = baseCoords[i - 1];
      const currCoord = baseCoords[i];

      const prevMs = new Date(String(prev.time).replace(' ', 'T')).getTime();
      const currMs = new Date(String(curr.time).replace(' ', 'T')).getTime();
      const dtMs = Math.max(1, currMs - prevMs);

      const dx = currCoord[0] - prevCoord[0];
      const dy = currCoord[1] - prevCoord[1];
      const distance = Math.hypot(dx, dy);

      const dtSteps = Math.ceil(dtMs / (TRACK_INTERPOLATION_TARGET_SECONDS * 1000));
      const distSteps = Math.ceil(distance / TRACK_INTERPOLATION_TARGET_METERS);
      const interpolationPoints = Math.min(
        TRACK_INTERPOLATION_MAX_POINTS_PER_EDGE,
        Math.max(0, Math.max(dtSteps, distSteps) - 1)
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

  setTab(tab: 'all' | 'adsb' | 'uat') {
    this.activeTab = tab;
  }

  goToAdsbPage(page: number) {
    if (page < 1 || page > this.adsbTotalPages || page === this.adsbCurrentPage) return;

    const commands = page === 1 ? ['/flights'] : ['/flights', page];
    const queryParams = this.buildFlightsListQueryParams(
      this.uatCurrentPage > 1 ? this.uatCurrentPage : undefined,
      this.allCurrentPage > 1 ? this.allCurrentPage : undefined,
    );

    this.router.navigate(commands, { queryParams });
  }

  goToUatPage(page: number) {
    if (page < 1 || page > this.uatTotalPages || page === this.uatCurrentPage) return;

    const commands = this.adsbCurrentPage === 1 ? ['/flights'] : ['/flights', this.adsbCurrentPage];
    const queryParams = this.buildFlightsListQueryParams(
      page > 1 ? page : undefined,
      this.allCurrentPage > 1 ? this.allCurrentPage : undefined,
    );

    this.router.navigate(commands, { queryParams });
  }

  updatePerPage(perPage: number): void {
    if (!this.pageSizeOptions.includes(perPage)) return;

    this.perPage = perPage;
    this.allCurrentPage = 1;
    this.adsbCurrentPage = 1;
    this.uatCurrentPage = 1;

    this.router.navigate(['/flights'], {
      queryParams: this.buildFlightsListQueryParams(),
    });
  }

  get filteredCombinedFlights(): any[] {
    const q = this.filterQuery.trim().toLowerCase();
    if (!q) return this.combinedFlights;
    return this.combinedFlights.filter(f => this.matchesFlight(f, q));
  }

  get displayedCombinedFlights(): any[] {
    const filtered = this.filteredCombinedFlights;
    if (this.searchQuery || this.filterQuery.trim()) {
      return filtered;
    }
    return filtered.slice(0, this.perPage);
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

  get allTotalPages(): number {
    return Math.max(1, Math.ceil(this.allTotalFlights / this.perPage));
  }

  get allPageNumbers(): number[] {
    return buildPageNumbers(this.allCurrentPage, this.allTotalPages);
  }

  get allTotalFlights(): number {
    return this.adsbTotalFlights + this.uatTotalFlights;
  }

  get allDisplayStart(): number {
    if (this.displayedCombinedFlights.length === 0) return 0;
    return (this.allCurrentPage - 1) * this.perPage + 1;
  }

  get allDisplayEnd(): number {
    if (this.displayedCombinedFlights.length === 0) return 0;
    return Math.min(this.allDisplayStart + this.displayedCombinedFlights.length - 1, this.allTotalFlights);
  }

  goToAllPage(page: number): void {
    if (page < 1 || page > this.allTotalPages || page === this.allCurrentPage) return;

    const commands = this.adsbCurrentPage === 1 ? ['/flights'] : ['/flights', this.adsbCurrentPage];
    const queryParams = this.buildFlightsListQueryParams(
      this.uatCurrentPage > 1 ? this.uatCurrentPage : undefined,
      page > 1 ? page : undefined,
    );
    this.router.navigate(commands, { queryParams });
  }

  private matchesFlight(flight: any, q: string): boolean {
    return (flight.flight || '').toLowerCase().includes(q) || (flight.icao || '').toLowerCase().includes(q);
  }

  private buildFlightsListQueryParams(
    uatPage?: number,
    allPage?: number,
  ): { uatPage?: number; allPage?: number; perPage?: number } {
    const queryParams: { uatPage?: number; allPage?: number; perPage?: number } = {};
    if (uatPage && uatPage > 1) {
      queryParams.uatPage = uatPage;
    }
    if (allPage && allPage > 1) {
      queryParams.allPage = allPage;
    }
    if (this.perPage !== DEFAULT_PAGE_SIZE) {
      queryParams.perPage = this.perPage;
    }
    return queryParams;
  }
}
