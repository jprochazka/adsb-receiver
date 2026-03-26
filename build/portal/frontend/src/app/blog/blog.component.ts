import { Component, OnInit } from '@angular/core';

import { ActivatedRoute, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-blog',
  standalone: true,
  imports: [RouterLink, SpinnerComponent],
  templateUrl: './blog.component.html',
  styleUrl: './blog.component.scss'
})
export class BlogComponent implements OnInit {
  posts: any[] = [];
  loading = true;
  currentPage = 1;
  totalPages = 1;
  total = 0;
  readonly perPage = 10;

  constructor(private dataService: DataService, private route: ActivatedRoute) {}

  ngOnInit() {
    this.route.params.subscribe(params => {
      this.currentPage = Math.max(1, parseInt(params['page'] ?? '1', 10) || 1);
      this.loadPage();
    });
  }

  loadPage() {
    this.loading = true;
    const offset = (this.currentPage - 1) * this.perPage;
    this.dataService.getBlogPosts(offset, this.perPage).subscribe({
      next: (response) => {
        this.posts    = response.blog_posts ?? [];
        this.total    = response.total ?? 0;
        this.totalPages = Math.max(1, Math.ceil(this.total / this.perPage));
        this.loading  = false;
      },
      error: () => { this.loading = false; }
    });
  }

  get pageNumbers(): number[] {
    const range: number[] = [];
    const start = Math.max(1, this.currentPage - 2);
    const end   = Math.min(this.totalPages, this.currentPage + 2);
    for (let i = start; i <= end; i++) range.push(i);
    return range;
  }
}

