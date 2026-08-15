import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DataService } from '../service/data.service';
import type { AisPosition, AisTarget } from '../shared/api-types';

@Component({
  selector: 'app-ais',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <main class="container py-4">
      <div class="d-flex flex-wrap gap-3 align-items-end justify-content-between mb-4">
        <div>
          <h1 class="h3 mb-1">AIS targets</h1>
          <p class="text-body-secondary mb-0">Recent maritime transmitter history</p>
        </div>
        <div class="input-group" style="max-width: 20rem">
          <input class="form-control" [(ngModel)]="query" (keyup.enter)="load()" placeholder="MMSI, name, callsign" aria-label="Search AIS targets">
          <button class="btn btn-primary" type="button" (click)="load()">Search</button>
        </div>
      </div>
      <div *ngIf="error" class="alert alert-warning">{{ error }}</div>
      <section *ngIf="selectedTarget" class="mb-4">
        <button class="btn btn-link px-0" type="button" (click)="clearSelection()">Back to AIS targets</button>
        <h2 class="h4">{{ selectedTarget.name || selectedTarget.mmsi }}</h2>
        <p class="text-body-secondary">{{ selectedTarget.target_kind }} · MMSI {{ selectedTarget.mmsi }}</p>
        <div class="row g-3 mb-3">
          <div class="col-md-3"><strong>Callsign</strong><br>{{ selectedTarget.callsign || 'Unavailable' }}</div>
          <div class="col-md-3"><strong>Speed</strong><br>{{ selectedTarget.speed == null ? 'Unavailable' : (selectedTarget.speed | number:'1.0-1') + ' kts' }}</div>
          <div class="col-md-3"><strong>Course</strong><br>{{ selectedTarget.course == null ? 'Unavailable' : (selectedTarget.course | number:'1.0-1') + '°' }}</div>
          <div class="col-md-3"><strong>Last seen</strong><br>{{ selectedTarget.last_seen | date:'medium' }}</div>
        </div>
        <h3 class="h6">Recent positions</h3>
        <div class="table-responsive"><table class="table table-sm"><thead><tr><th>Received</th><th>Position</th><th>Speed</th><th>Course</th></tr></thead><tbody>
          <tr *ngFor="let position of positions"><td>{{ position.received_at | date:'medium' }}</td><td>{{ position.latitude == null ? 'Unavailable' : (position.latitude | number:'1.4-4') + ', ' + (position.longitude | number:'1.4-4') }}</td><td>{{ position.speed == null ? 'Unavailable' : (position.speed | number:'1.0-1') + ' kts' }}</td><td>{{ position.course == null ? 'Unavailable' : (position.course | number:'1.0-1') + '°' }}</td></tr>
        </tbody></table></div>
      </section>
      <div *ngIf="!selectedTarget" class="table-responsive">
        <table class="table table-hover align-middle">
          <thead><tr><th>MMSI</th><th>Name</th><th>Type</th><th>Position</th><th>Last seen</th></tr></thead>
          <tbody>
            <tr *ngFor="let target of targets" (click)="selectTarget(target)" tabindex="0" role="button">
              <td>{{ target.mmsi }}</td>
              <td>{{ target.name || 'Unknown' }}<small class="d-block text-body-secondary">{{ target.callsign || '' }}</small></td>
              <td>{{ target.target_kind }}</td>
              <td>{{ target.latitude == null ? 'Unavailable' : (target.latitude | number:'1.4-4') + ', ' + (target.longitude | number:'1.4-4') }}</td>
              <td>{{ target.last_seen | date:'medium' }}</td>
            </tr>
            <tr *ngIf="!loading && !targets.length"><td colspan="5" class="text-body-secondary">No AIS targets found.</td></tr>
          </tbody>
        </table>
      </div>
      <div *ngIf="!selectedTarget" class="d-flex justify-content-between align-items-center">
        <button class="btn btn-outline-secondary" type="button" (click)="previous()" [disabled]="offset === 0">Previous</button>
        <span class="text-body-secondary">{{ offset + 1 }}-{{ offset + targets.length }} of {{ total }}</span>
        <button class="btn btn-outline-secondary" type="button" (click)="next()" [disabled]="offset + limit >= total">Next</button>
      </div>
    </main>
  `
})
export class AisComponent implements OnInit {
  targets: AisTarget[] = [];
  query = '';
  error = '';
  loading = false;
  offset = 0;
  limit = 25;
  total = 0;
  selectedTarget: AisTarget | null = null;
  positions: AisPosition[] = [];

  constructor(private dataService: DataService) {}

  ngOnInit(): void { this.load(); }

  load(): void {
    this.loading = true;
    this.error = '';
    this.dataService.getAisTargets(this.offset, this.limit, this.query).subscribe({
      next: response => {
        this.targets = response.items ?? [];
        this.total = response.total ?? this.targets.length;
        this.loading = false;
      },
      error: () => {
        this.error = 'AIS history is currently unavailable.';
        this.loading = false;
      }
    });
  }

  previous(): void {
    this.offset = Math.max(0, this.offset - this.limit);
    this.load();
  }

  next(): void {
    if (this.offset + this.limit < this.total) {
      this.offset += this.limit;
      this.load();
    }
  }

  selectTarget(target: AisTarget): void {
    this.selectedTarget = target;
    this.positions = [];
    this.dataService.getAisPositions(target.mmsi).subscribe({
      next: response => this.positions = response.items ?? [],
      error: () => this.error = 'Position history is currently unavailable.'
    });
  }

  clearSelection(): void {
    this.selectedTarget = null;
    this.positions = [];
  }
}