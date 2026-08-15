import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DataService } from '../service/data.service';
import type { AisSettings, AisStats } from '../shared/api-types';

@Component({
  selector: 'app-admin-ais',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <main class="container py-4">
      <h1 class="h3 mb-4">AIS administration</h1>
      <div *ngIf="error" class="alert alert-danger">{{ error }}</div>
      <section class="mb-4">
        <h2 class="h5">Map and retention</h2>
        <div class="row g-3">
          <label class="col-md-4">Live map enabled <select class="form-select" [(ngModel)]="settings.ais_map_enabled"><option value="true">Enabled</option><option value="false">Disabled</option></select></label>
          <label class="col-md-4">Freshness seconds <input class="form-control" type="number" [(ngModel)]="settings.ais_live_freshness_seconds"></label>
          <label class="col-md-4">History retention days <input class="form-control" type="number" [(ngModel)]="settings.ais_history_retention_days"></label>
          <label class="col-md-4">Raw capture <select class="form-select" [(ngModel)]="settings.ais_raw_capture_enabled"><option value="true">Enabled</option><option value="false">Disabled</option></select></label>
          <label class="col-md-4">Raw retention days <input class="form-control" type="number" [(ngModel)]="settings.ais_raw_retention_days"></label>
        </div>
        <button class="btn btn-primary mt-3" type="button" (click)="save()" [disabled]="saving">Save settings</button>
      </section>
      <section class="mb-4">
        <h2 class="h5">Storage</h2>
        <p class="text-body-secondary">Targets: {{ stats.targets || 0 }} | Positions: {{ stats.positions || 0 }} | Voyages: {{ stats.voyages || 0 }} | Raw messages: {{ stats.raw_messages || 0 }}</p>
        <button class="btn btn-outline-danger" type="button" (click)="purge()" [disabled]="purging">Purge expired AIS data</button>
      </section>
      <p *ngIf="message" class="alert alert-success">{{ message }}</p>
    </main>
  `
})
export class AdminAisComponent implements OnInit {
  settings: AisSettings = {
    ais_map_enabled: 'true',
    ais_live_freshness_seconds: '300',
    ais_history_retention_days: '30',
    ais_raw_capture_enabled: 'false',
    ais_raw_retention_days: '7',
  };
  stats: AisStats = { targets: 0, positions: 0, voyages: 0, raw_messages: 0 };
  error = '';
  message = '';
  saving = false;
  purging = false;

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    this.dataService.getAisSettings().subscribe({ next: settings => this.settings = settings, error: () => this.error = 'AIS settings are unavailable.' });
    this.refreshStats();
  }

  save(): void {
    this.saving = true;
    this.dataService.updateAisSettings(this.settings).subscribe({
      next: settings => { this.settings = settings; this.message = 'AIS settings saved.'; this.saving = false; },
      error: () => { this.error = 'AIS settings could not be saved.'; this.saving = false; }
    });
  }

  purge(): void {
    if (!window.confirm('Purge expired AIS data?')) return;
    this.purging = true;
    this.dataService.purgeAis().subscribe({
      next: result => { this.message = `Purged ${result.positions || 0} positions, ${result.voyages || 0} voyages, and ${result.raw_messages || 0} raw messages.`; this.purging = false; this.refreshStats(); },
      error: () => { this.error = 'AIS purge failed.'; this.purging = false; }
    });
  }

  private refreshStats(): void {
    this.dataService.getAisStats().subscribe({ next: stats => this.stats = stats, error: () => this.error = 'AIS statistics are unavailable.' });
  }
}