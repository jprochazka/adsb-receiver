import { Component, OnInit } from '@angular/core';

import { DataService } from '../service/data.service';

@Component({
  selector: 'app-links',
  standalone: true,
  imports: [],
  templateUrl: './links.component.html',
  styleUrl: './links.component.scss'
})
export class LinksComponent implements OnInit  {
  count: any;
  data: any;
  loading = true;

  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.data_service.getLinks().subscribe({
      next: (response) => {
        this.data = response;
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }
}
