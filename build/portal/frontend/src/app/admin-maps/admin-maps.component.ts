import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

interface MapItem {
  key: string;
  label: string;
  description: string;
  settingKey: string;
  enabled: boolean;
}

const MAP_LINK_DEFS: Omit<MapItem, 'enabled'>[] = [
  { key: 'dump1090', settingKey: 'map_dump1090_enabled', label: 'Dump1090',            description: 'Live aircraft map powered by dump1090-fa' },
  { key: 'dump978',  settingKey: 'map_dump978_enabled',  label: 'Dump978',             description: 'UAT 978 MHz aircraft map' },
  { key: 'adsbx',    settingKey: 'map_adsbx_enabled',    label: 'ADS-B Exchange',      description: 'ADS-B Exchange live map' },
  { key: 'pfclient', settingKey: 'map_pfclient_enabled', label: 'Plane Finder Client', description: 'Plane Finder Client web interface (device address port 30053)' },
];
const DEFAULT_ORDER = 'dump1090,dump978,adsbx,pfclient';

@Component({
  selector: 'app-admin-maps',
  standalone: true,
  imports: [NgFor, NgIf, FormsModule, SpinnerComponent],
  templateUrl: './admin-maps.component.html',
  styleUrl: './admin-maps.component.scss'
})
export class AdminMapsComponent implements OnInit {
  loading = true;
  errorMessage = '';
  successMessage = '';

  mapNavEnabled = true;
  mapItems: MapItem[] = [];

  // Drag-and-drop state
  dragIndex: number | null = null;
  dragOverIndex: number | null = null;

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    forkJoin({
      nav:      this.dataService.getSetting('map_nav_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d1090:    this.dataService.getSetting('map_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:     this.dataService.getSetting('map_dump978_enabled').pipe(catchError(() => of({ value: 'true' }))),
      adsbx:    this.dataService.getSetting('map_adsbx_enabled').pipe(catchError(() => of({ value: 'true' }))),
      pfclient: this.dataService.getSetting('map_pfclient_enabled').pipe(catchError(() => of({ value: 'false' }))),
      order:    this.dataService.getSetting('map_links_order').pipe(catchError(() => of({ value: DEFAULT_ORDER }))),
    }).subscribe({
      next: ({ nav, d1090, d978, adsbx, pfclient, order }) => {
        this.mapNavEnabled = nav?.value !== 'false';

        const enabledMap: Record<string, boolean> = {
          dump1090: d1090?.value    !== 'false',
          dump978:  d978?.value     !== 'false',
          adsbx:    adsbx?.value    !== 'false',
          pfclient: pfclient?.value === 'true',
        };

        const orderKeys = (order?.value || DEFAULT_ORDER)
          .split(',').map((k: string) => k.trim())
          .filter((k: string) => MAP_LINK_DEFS.some(d => d.key === k));
        for (const def of MAP_LINK_DEFS) {
          if (!orderKeys.includes(def.key)) orderKeys.push(def.key);
        }

        this.mapItems = orderKeys.map((key: string) => {
          const def = MAP_LINK_DEFS.find(d => d.key === key)!;
          return { ...def, enabled: enabledMap[key] ?? false };
        });

        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load maps management settings.';
        this.loading = false;
      }
    });
  }

  saveNavEnabled(): void {
    this.errorMessage = '';
    this.dataService.updateSetting('map_nav_enabled', String(this.mapNavEnabled)).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; }
    });
  }

  saveItemEnabled(item: MapItem): void {
    this.errorMessage = '';
    this.dataService.updateSetting(item.settingKey, String(item.enabled)).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; }
    });
  }

  private saveOrder(): void {
    this.errorMessage = '';
    this.dataService.updateSetting('map_links_order', this.mapItems.map(i => i.key).join(',')).subscribe({
      next: () => { this.successMessage = 'Order saved.'; },
      error: () => { this.errorMessage = 'Failed to save order.'; }
    });
  }

  // Drag-and-drop handlers
  onDragStart(event: DragEvent, index: number) {
    event.dataTransfer?.setData('text/plain', String(index));
    this.dragIndex = index;
  }

  onDragOver(event: DragEvent, index: number) {
    event.preventDefault();
    this.dragOverIndex = index;
  }

  onDragLeave(event: DragEvent) {
    const el = event.currentTarget as HTMLElement;
    if (!el.contains(event.relatedTarget as Node)) {
      this.dragOverIndex = null;
    }
  }

  onDrop(event: DragEvent, dropIndex: number) {
    event.preventDefault();
    if (this.dragIndex === null || this.dragIndex === dropIndex) {
      this.dragIndex = null;
      this.dragOverIndex = null;
      return;
    }

    const reordered = [...this.mapItems];
    const [moved] = reordered.splice(this.dragIndex, 1);
    reordered.splice(dropIndex, 0, moved);
    this.mapItems = reordered;
    this.dragIndex = null;
    this.dragOverIndex = null;

    this.saveOrder();
  }

  onDragEnd() {
    this.dragIndex = null;
    this.dragOverIndex = null;
  }
}
