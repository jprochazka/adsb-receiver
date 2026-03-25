import { Component, OnInit } from '@angular/core';
import { NgIf, NgFor, DecimalPipe, DatePipe } from '@angular/common';
import { forkJoin } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-system-information',
  standalone: true,
  imports: [NgIf, NgFor, DecimalPipe, DatePipe, SpinnerComponent],
  templateUrl: './system-information.component.html',
  styleUrl: './system-information.component.scss'
})
export class SystemInformationComponent implements OnInit {
  loading = true;
  cpu: any;
  memory: any;
  disk: any;
  network: any;
  other: any;
  database: any;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    forkJoin({
      cpu: this.dataService.getSystemCpu(),
      memory: this.dataService.getSystemMemory(),
      disk: this.dataService.getSystemDisk(),
      network: this.dataService.getSystemNetwork(),
      other: this.dataService.getSystemOther(),
      database: this.dataService.getSystemDatabase()
    }).subscribe({
      next: ({ cpu, memory, disk, network, other, database }) => {
        this.cpu = cpu;
        this.memory = memory;
        this.disk = disk;
        this.network = network;
        this.other = other;
        this.database = database;
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }

  formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return (bytes / Math.pow(k, i)).toFixed(2) + ' ' + sizes[i];
  }

  bootTime(): Date {
    return new Date(this.other.other_boot_time * 1000);
  }
}
