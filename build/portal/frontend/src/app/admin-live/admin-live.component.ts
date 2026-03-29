import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs';

import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

interface LiveMapPreset {
  key: string;
  label: string;
  description: string;
  refreshMs: number;
  centerLat: number;
  centerLon: number;
  zoom: number;
  trailPoints: number;
}

interface LiveMapCustomPreset {
  label: string;
  refreshMs: number;
  centerLat: number;
  centerLon: number;
  zoom: number;
  trailPoints: number;
}

const DEFAULT_LIVE_MAP_REFRESH_MS = 5000;
const DEFAULT_LIVE_MAP_CENTER_LAT = 20;
const DEFAULT_LIVE_MAP_CENTER_LON = 0;
const DEFAULT_LIVE_MAP_ZOOM = 3;
const DEFAULT_LIVE_MAP_TRAIL_POINTS = 20;
const DEFAULT_DUMP1090_JSON_URL = 'http://127.0.0.1/dump1090/data/aircraft.json';
const DEFAULT_DUMP978_JSON_URL = 'http://127.0.0.1/dump978/data/aircraft.json';
const MAX_CUSTOM_PRESETS = 10;
const DEFAULT_CUSTOM_PRESETS: LiveMapCustomPreset[] = [
  { label: 'Home',   refreshMs: 2500, centerLat: 39, centerLon: -95, zoom: 7, trailPoints: 40 },
  { label: 'Summer', refreshMs: 5000, centerLat: 20, centerLon: 0,   zoom: 3, trailPoints: 20 },
  { label: 'Winter', refreshMs: 7000, centerLat: 50, centerLon: 10,  zoom: 4, trailPoints: 15 },
];

const LIVE_MAP_PRESETS: LiveMapPreset[] = [
  {
    key: 'balanced',
    label: 'Balanced',
    description: 'General-purpose default for local and regional viewing',
    refreshMs: 5000,
    centerLat: 20,
    centerLon: 0,
    zoom: 3,
    trailPoints: 20,
  },
  {
    key: 'local',
    label: 'Local Receiver',
    description: 'Fast updates and short trails around your station',
    refreshMs: 2000,
    centerLat: 39,
    centerLon: -95,
    zoom: 7,
    trailPoints: 30,
  },
  {
    key: 'continent',
    label: 'Continental',
    description: 'Broader area with moderate updates for lower map churn',
    refreshMs: 7000,
    centerLat: 39,
    centerLon: -98,
    zoom: 4,
    trailPoints: 15,
  },
];

@Component({
  selector: 'app-admin-live',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './admin-live.component.html',
  styleUrl: './admin-live.component.scss'
})
export class AdminLiveComponent implements OnInit {
  loading = true;
  errorMessage = '';
  successMessage = '';

  liveMapEnabled = true;
  liveMapRefreshMs = DEFAULT_LIVE_MAP_REFRESH_MS;
  liveMapCenterLat = DEFAULT_LIVE_MAP_CENTER_LAT;
  liveMapCenterLon = DEFAULT_LIVE_MAP_CENTER_LON;
  liveMapDefaultZoom = DEFAULT_LIVE_MAP_ZOOM;
  liveMapTrailPoints = DEFAULT_LIVE_MAP_TRAIL_POINTS;
  liveMapShowAllSeen = true;
  dump1090JsonUrl = DEFAULT_DUMP1090_JSON_URL;
  dump978JsonUrl = DEFAULT_DUMP978_JSON_URL;
  liveMapPresets = LIVE_MAP_PRESETS;
  customPresetSlots: LiveMapCustomPreset[] = this.defaultCustomPresets();

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    forkJoin({
      liveEnabled: this.dataService.getSetting('live_map_enabled').pipe(catchError(() => of({ value: 'true' }))),
      liveRefreshMs: this.dataService.getSetting('live_map_refresh_ms').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_REFRESH_MS) }))),
      liveCenterLat: this.dataService.getSetting('live_map_center_lat').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_CENTER_LAT) }))),
      liveCenterLon: this.dataService.getSetting('live_map_center_lon').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_CENTER_LON) }))),
      liveZoom: this.dataService.getSetting('live_map_default_zoom').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_ZOOM) }))),
      liveTrailPoints: this.dataService.getSetting('live_map_trail_points').pipe(catchError(() => of({ value: String(DEFAULT_LIVE_MAP_TRAIL_POINTS) }))),
      liveShowAllSeen: this.dataService.getSetting('live_map_show_all_seen').pipe(catchError(() => of({ value: 'true' }))),
      dump1090JsonUrl: this.dataService.getSetting('live_map_json_url').pipe(catchError(() => of({ value: DEFAULT_DUMP1090_JSON_URL }))),
      dump978JsonUrl: this.dataService.getSetting('live_map_json_url_dump978').pipe(catchError(() => of({ value: DEFAULT_DUMP978_JSON_URL }))),
      customPresets: this.dataService.getSetting('live_map_custom_presets').pipe(catchError(() => of({ value: JSON.stringify(DEFAULT_CUSTOM_PRESETS) }))),
    }).subscribe({
      next: ({ liveEnabled, liveRefreshMs, liveCenterLat, liveCenterLon, liveZoom, liveTrailPoints, liveShowAllSeen, dump1090JsonUrl, dump978JsonUrl, customPresets }) => {
        this.liveMapEnabled = liveEnabled?.value !== 'false';
        this.liveMapRefreshMs = this.clampInt(liveRefreshMs?.value, 1000, 60000, DEFAULT_LIVE_MAP_REFRESH_MS);
        this.liveMapCenterLat = this.clampFloat(liveCenterLat?.value, -85, 85, DEFAULT_LIVE_MAP_CENTER_LAT);
        this.liveMapCenterLon = this.clampFloat(liveCenterLon?.value, -180, 180, DEFAULT_LIVE_MAP_CENTER_LON);
        this.liveMapDefaultZoom = this.clampFloat(liveZoom?.value, 1, 18, DEFAULT_LIVE_MAP_ZOOM);
        this.liveMapTrailPoints = this.clampInt(liveTrailPoints?.value, 0, 200, DEFAULT_LIVE_MAP_TRAIL_POINTS);
        this.liveMapShowAllSeen = liveShowAllSeen?.value !== 'false';
        this.dump1090JsonUrl = this.normalizeJsonUrl(dump1090JsonUrl?.value, DEFAULT_DUMP1090_JSON_URL);
        this.dump978JsonUrl = this.normalizeJsonUrl(dump978JsonUrl?.value, DEFAULT_DUMP978_JSON_URL);
        this.customPresetSlots = this.parseCustomPresets(customPresets?.value);
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load live map settings.';
        this.loading = false;
      }
    });
  }

  saveLiveMapEnabled(): void {
    this.errorMessage = '';
    this.dataService.updateSetting('live_map_enabled', String(this.liveMapEnabled)).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; }
    });
  }

  saveLiveMapRefreshMs(): void {
    this.liveMapRefreshMs = this.clampInt(String(this.liveMapRefreshMs), 1000, 60000, DEFAULT_LIVE_MAP_REFRESH_MS);
    this.saveNumericSetting('live_map_refresh_ms', this.liveMapRefreshMs);
  }

  saveLiveMapCenterLat(): void {
    this.liveMapCenterLat = this.clampFloat(String(this.liveMapCenterLat), -85, 85, DEFAULT_LIVE_MAP_CENTER_LAT);
    this.saveNumericSetting('live_map_center_lat', this.liveMapCenterLat);
  }

  saveLiveMapCenterLon(): void {
    this.liveMapCenterLon = this.clampFloat(String(this.liveMapCenterLon), -180, 180, DEFAULT_LIVE_MAP_CENTER_LON);
    this.saveNumericSetting('live_map_center_lon', this.liveMapCenterLon);
  }

  saveLiveMapDefaultZoom(): void {
    this.liveMapDefaultZoom = this.clampFloat(String(this.liveMapDefaultZoom), 1, 18, DEFAULT_LIVE_MAP_ZOOM);
    this.saveNumericSetting('live_map_default_zoom', this.liveMapDefaultZoom);
  }

  saveLiveMapTrailPoints(): void {
    this.liveMapTrailPoints = this.clampInt(String(this.liveMapTrailPoints), 0, 200, DEFAULT_LIVE_MAP_TRAIL_POINTS);
    this.saveNumericSetting('live_map_trail_points', this.liveMapTrailPoints);
  }

  saveLiveMapShowAllSeen(): void {
    this.errorMessage = '';
    this.dataService.updateSetting('live_map_show_all_seen', String(this.liveMapShowAllSeen)).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; }
    });
  }

  saveDump1090JsonUrl(): void {
    this.dump1090JsonUrl = this.normalizeJsonUrl(this.dump1090JsonUrl, DEFAULT_DUMP1090_JSON_URL);
    this.saveStringSetting('live_map_json_url', this.dump1090JsonUrl);
  }

  saveDump978JsonUrl(): void {
    this.dump978JsonUrl = this.normalizeJsonUrl(this.dump978JsonUrl, DEFAULT_DUMP978_JSON_URL);
    this.saveStringSetting('live_map_json_url_dump978', this.dump978JsonUrl);
  }

  applyLiveMapPreset(key: string): void {
    const preset = this.liveMapPresets.find(p => p.key === key);
    if (!preset) return;

    this.liveMapRefreshMs = preset.refreshMs;
    this.liveMapCenterLat = preset.centerLat;
    this.liveMapCenterLon = preset.centerLon;
    this.liveMapDefaultZoom = preset.zoom;
    this.liveMapTrailPoints = preset.trailPoints;
    this.liveMapEnabled = true;

    this.errorMessage = '';
    forkJoin([
      this.dataService.updateSetting('live_map_enabled', 'true'),
      this.dataService.updateSetting('live_map_refresh_ms', String(this.liveMapRefreshMs)),
      this.dataService.updateSetting('live_map_center_lat', String(this.liveMapCenterLat)),
      this.dataService.updateSetting('live_map_center_lon', String(this.liveMapCenterLon)),
      this.dataService.updateSetting('live_map_default_zoom', String(this.liveMapDefaultZoom)),
      this.dataService.updateSetting('live_map_trail_points', String(this.liveMapTrailPoints)),
    ]).subscribe({
      next: () => { this.successMessage = `Applied "${preset.label}" preset.`; },
      error: () => { this.errorMessage = 'Failed to apply preset.'; }
    });
  }

  saveCurrentAsCustomPreset(index: number): void {
    if (index < 0 || index >= this.customPresetSlots.length) return;

    const slot = this.customPresetSlots[index];
    slot.refreshMs = this.clampInt(String(this.liveMapRefreshMs), 1000, 60000, DEFAULT_LIVE_MAP_REFRESH_MS);
    slot.centerLat = this.clampFloat(String(this.liveMapCenterLat), -85, 85, DEFAULT_LIVE_MAP_CENTER_LAT);
    slot.centerLon = this.clampFloat(String(this.liveMapCenterLon), -180, 180, DEFAULT_LIVE_MAP_CENTER_LON);
    slot.zoom = this.clampFloat(String(this.liveMapDefaultZoom), 1, 18, DEFAULT_LIVE_MAP_ZOOM);
    slot.trailPoints = this.clampInt(String(this.liveMapTrailPoints), 0, 200, DEFAULT_LIVE_MAP_TRAIL_POINTS);
    slot.label = this.normalizeLabel(slot.label, `Preset ${index + 1}`);

    this.persistCustomPresets(`Saved current settings to "${slot.label}".`);
  }

  addCustomPreset(): void {
    if (this.customPresetSlots.length >= MAX_CUSTOM_PRESETS) {
      this.errorMessage = `Maximum of ${MAX_CUSTOM_PRESETS} custom presets reached.`;
      return;
    }

    this.customPresetSlots.push({
      label: `Preset ${this.customPresetSlots.length + 1}`,
      refreshMs: this.clampInt(String(this.liveMapRefreshMs), 1000, 60000, DEFAULT_LIVE_MAP_REFRESH_MS),
      centerLat: this.clampFloat(String(this.liveMapCenterLat), -85, 85, DEFAULT_LIVE_MAP_CENTER_LAT),
      centerLon: this.clampFloat(String(this.liveMapCenterLon), -180, 180, DEFAULT_LIVE_MAP_CENTER_LON),
      zoom: this.clampFloat(String(this.liveMapDefaultZoom), 1, 18, DEFAULT_LIVE_MAP_ZOOM),
      trailPoints: this.clampInt(String(this.liveMapTrailPoints), 0, 200, DEFAULT_LIVE_MAP_TRAIL_POINTS),
    });

    this.persistCustomPresets('Added custom preset slot.');
  }

  deleteCustomPreset(index: number): void {
    if (index < 0 || index >= this.customPresetSlots.length) return;

    const deletedLabel = this.customPresetSlots[index].label || `Preset ${index + 1}`;
    this.customPresetSlots.splice(index, 1);
    this.persistCustomPresets(`Deleted custom preset "${deletedLabel}".`);
  }

  applyCustomPreset(index: number): void {
    if (index < 0 || index >= this.customPresetSlots.length) return;
    const slot = this.customPresetSlots[index];

    this.liveMapRefreshMs = this.clampInt(String(slot.refreshMs), 1000, 60000, DEFAULT_LIVE_MAP_REFRESH_MS);
    this.liveMapCenterLat = this.clampFloat(String(slot.centerLat), -85, 85, DEFAULT_LIVE_MAP_CENTER_LAT);
    this.liveMapCenterLon = this.clampFloat(String(slot.centerLon), -180, 180, DEFAULT_LIVE_MAP_CENTER_LON);
    this.liveMapDefaultZoom = this.clampFloat(String(slot.zoom), 1, 18, DEFAULT_LIVE_MAP_ZOOM);
    this.liveMapTrailPoints = this.clampInt(String(slot.trailPoints), 0, 200, DEFAULT_LIVE_MAP_TRAIL_POINTS);
    this.liveMapEnabled = true;

    this.errorMessage = '';
    forkJoin([
      this.dataService.updateSetting('live_map_enabled', 'true'),
      this.dataService.updateSetting('live_map_refresh_ms', String(this.liveMapRefreshMs)),
      this.dataService.updateSetting('live_map_center_lat', String(this.liveMapCenterLat)),
      this.dataService.updateSetting('live_map_center_lon', String(this.liveMapCenterLon)),
      this.dataService.updateSetting('live_map_default_zoom', String(this.liveMapDefaultZoom)),
      this.dataService.updateSetting('live_map_trail_points', String(this.liveMapTrailPoints)),
    ]).subscribe({
      next: () => { this.successMessage = `Applied custom preset "${slot.label}".`; },
      error: () => { this.errorMessage = 'Failed to apply custom preset.'; }
    });
  }

  saveCustomPresetLabel(index: number): void {
    if (index < 0 || index >= this.customPresetSlots.length) return;
    this.customPresetSlots[index].label = this.normalizeLabel(this.customPresetSlots[index].label, `Preset ${index + 1}`);
    this.persistCustomPresets(`Updated custom preset name to "${this.customPresetSlots[index].label}".`);
  }

  private persistCustomPresets(successMessage: string): void {
    this.errorMessage = '';
    this.dataService.updateSetting('live_map_custom_presets', JSON.stringify(this.customPresetSlots)).subscribe({
      next: () => { this.successMessage = successMessage; },
      error: () => { this.errorMessage = 'Failed to save custom presets.'; }
    });
  }

  private defaultCustomPresets(): LiveMapCustomPreset[] {
    return DEFAULT_CUSTOM_PRESETS.map((preset) => ({ ...preset }));
  }

  private parseCustomPresets(raw: string | undefined): LiveMapCustomPreset[] {
    try {
      const parsed = JSON.parse(raw || '[]');
      if (!Array.isArray(parsed)) return this.defaultCustomPresets();

      return parsed
        .filter((source) => source && typeof source === 'object')
        .slice(0, MAX_CUSTOM_PRESETS)
        .map((source, index) => ({
          label: this.normalizeLabel(source.label, `Preset ${index + 1}`),
          refreshMs: this.clampInt(String(source.refreshMs), 1000, 60000, DEFAULT_LIVE_MAP_REFRESH_MS),
          centerLat: this.clampFloat(String(source.centerLat), -85, 85, DEFAULT_LIVE_MAP_CENTER_LAT),
          centerLon: this.clampFloat(String(source.centerLon), -180, 180, DEFAULT_LIVE_MAP_CENTER_LON),
          zoom: this.clampFloat(String(source.zoom), 1, 18, DEFAULT_LIVE_MAP_ZOOM),
          trailPoints: this.clampInt(String(source.trailPoints), 0, 200, DEFAULT_LIVE_MAP_TRAIL_POINTS),
        }));
    } catch {
      return this.defaultCustomPresets();
    }
  }

  private normalizeLabel(label: string | undefined, fallback: string): string {
    const trimmed = (label || '').trim();
    return trimmed || fallback;
  }

  private saveNumericSetting(name: string, value: number): void {
    this.errorMessage = '';
    this.dataService.updateSetting(name, String(value)).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; }
    });
  }

  private saveStringSetting(name: string, value: string): void {
    this.errorMessage = '';
    this.dataService.updateSetting(name, value).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; }
    });
  }

  private normalizeJsonUrl(raw: string | undefined, fallback: string): string {
    const trimmed = (raw || '').trim();
    return trimmed || fallback;
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
}
