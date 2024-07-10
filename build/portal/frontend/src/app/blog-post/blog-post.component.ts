import { Component, OnInit, inject } from '@angular/core';
import { NgIf } from '@angular/common';
import { DataService } from '../service/data.service';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-blog-post',
  standalone: true,
  imports: [NgIf],
  templateUrl: './blog-post.component.html',
  styleUrl: './blog-post.component.scss'
})
export class BlogPostComponent implements OnInit  {
  data: any;
  id!: any;

  private route = inject(ActivatedRoute);
  
  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.route.paramMap.subscribe((params) => {
      this.id = params.get('id')!;
    });

    this.data_service.getBlogPost(this.id).subscribe(response => {
      this.data = response;
      console.log(this.data);
    });
  }
}