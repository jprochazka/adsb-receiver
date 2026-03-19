import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-blog',
  standalone: true,
  imports: [NgFor, NgIf, SpinnerComponent],
  templateUrl: './blog.component.html',
  styleUrl: './blog.component.scss'
})
export class BlogComponent implements OnInit  {
  data: any;
  loading = true;

  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.data_service.getBlogPosts().subscribe({
      next: (response) => {
        this.data = response;
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }
}
