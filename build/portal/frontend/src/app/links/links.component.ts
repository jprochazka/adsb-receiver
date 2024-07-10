import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { DataService } from '../service/data.service';

@Component({
  selector: 'app-links',
  standalone: true,
  imports: [NgFor, NgIf],
  templateUrl: './links.component.html',
  styleUrl: './links.component.scss'
})
export class LinksComponent implements OnInit  {
  count: any;
  data: any;

  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.data_service.getLinks().subscribe(response => {
      this.data = response;
      console.log(this.data);
    });
  }
}
