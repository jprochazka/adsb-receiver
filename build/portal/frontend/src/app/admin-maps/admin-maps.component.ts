import { Component, OnInit } from '@angular/core';
import { NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-maps',
  standalone: true,
  imports: [NgIf, FormsModule, SpinnerComponent],
  templateUrl: './admin-maps.component.html',
  styleUrl: './admin-maps.component.scss'
})
export class AdminMapsComponent implements OnInit {
  loading = true;
  saving = false;
  errorMessage = '';
  successMessage = '';

  mapNavEnabled      = true;
  mapDump1090Enabled = true;
  mapDump978Enabled  = true;
  mapAdsbxEnabled    = true;
  mapPfclientEnabled = false;

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    forkJoin({
      nav:      this.dataService.getSetting('map_nav_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d1090:    this.dataService.getSetting('map_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:     this.dataService.getSetting('map_dump978_enabled').pipe(catchError(() => of({ value: 'true' }))),
      adsbx:    this.dataService.getSetting('map_adsbx_enabled').pipe(catchError(() => of({ value: 'true' }))),
      pfclient: this.dataService.getSetting('map_pfclient_enabled').pipe(catchError(() => of({ value: 'false' }))),
    }).subscribe({
      next: ({ nav, d1090, d978, adsbx, pfclient }) => {
        this.mapNavEnabled      = nav?.value      !== 'false';
        this.mapDump1090Enabled = d1090?.value    !== 'false';
        this.mapDump978Enabled  = d978?.value     !== 'false';
        this.mapAdsbxEnabled    = adsbx?.value    !== 'false';
        this.mapPfclientEnabled = pfclient?.value === 'true';
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load maps management settings.';
        this.loading = false;
      }
    });
  }

  save(): void {
    this.saving = true;
    this.errorMessage = '';
    this.successMessage = '';

    forkJoin([
      this.dataService.updateSetting('map_nav_enabled',      String(this.mapNavEnabled)),
      this.dataService.updateSetting('map_dump1090_enabled', String(this.mapDump1090Enabled)),
      this.dataService.updateSetting('map_dump978_enabled',  String(this.mapDump978Enabled)),
      this.dataService.updateSetting('map_adsbx_enabled',    String(this.mapAdsbxEnabled)),
      this.dataService.updateSetting('map_pfclient_enabled', String(this.mapPfclientEnabled)),
    ]).subscribe({
      next: () => {
        this.saving = false;
        this.successMessage = 'Maps management settings saved successfully.';
      },
      error: () => {
        this.saving = false;
        this.errorMessage = 'Failed to save maps management settings.';
      }
    });
  }
}
