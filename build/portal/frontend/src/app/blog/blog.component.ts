import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { DataService } from '../service/data.service';

@Component({
  selector: 'app-blog',
  standalone: true,
  imports: [NgFor, NgIf],
  templateUrl: './blog.component.html',
  styleUrl: './blog.component.scss'
})
export class BlogComponent implements OnInit  {
  data: any;

  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.data_service.getBlogPosts().subscribe(response => {
      this.data = response;
      console.log(this.data);
    });
  }
}
