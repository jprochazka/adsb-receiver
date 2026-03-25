import { Component, OnInit } from '@angular/core';
import { NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';

@Component({
  selector: 'app-admin-acars',
  standalone: true,
  imports: [NgIf, FormsModule],
  templateUrl: './admin-acars.component.html',
  styleUrl: './admin-acars.component.scss'
})
export class AdminAcarsComponent implements OnInit {
  acarsNavEnabled = true;
  savingNav = false;
  navSuccessMessage = '';
  navErrorMessage = '';

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    this.dataService.getSetting('acars_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.acarsNavEnabled = res?.value !== 'false';
    });
  }

  saveNavSetting(): void {
    this.savingNav = true;
    this.navSuccessMessage = '';
    this.navErrorMessage = '';
    this.dataService.updateSetting('acars_nav_enabled', String(this.acarsNavEnabled)).subscribe({
      next: () => {
        this.savingNav = false;
        this.navSuccessMessage = 'ACARS settings saved successfully.';
      },
      error: () => {
        this.savingNav = false;
        this.navErrorMessage = 'Failed to save settings.';
      }
    });
  }
}
