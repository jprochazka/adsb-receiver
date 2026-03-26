import { Component, OnInit, inject } from '@angular/core';

import { DataService } from '../service/data.service';
import { ActivatedRoute } from '@angular/router';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-blog-post',
  standalone: true,
  imports: [SpinnerComponent],
  templateUrl: './blog-post.component.html',
  styleUrl: './blog-post.component.scss'
})
export class BlogPostComponent implements OnInit  {
  data: any;
  id!: any;
  loading = true;

  private route = inject(ActivatedRoute);
  
  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.route.paramMap.subscribe((params) => {
      this.id = params.get('id')!;
    });

    this.data_service.getBlogPost(this.id).subscribe({
      next: (response) => {
        this.data = response;
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }
}