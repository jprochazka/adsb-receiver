import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { DataService } from '../service/data.service';

@Component({
  selector: 'app-flights',
  standalone: true,
  imports: [NgFor, NgIf],
  templateUrl: './flights.component.html',
  styleUrl: './flights.component.scss'
})
export class FlightsComponent implements OnInit  {
  count: any;
  data: any;

  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.data_service.GetFlightsCount().subscribe(response => {
      this.count = response;
      console.log(this.count);
    });
    this.data_service.getFlights().subscribe(response => {
      this.data = response;
      console.log(this.data);
    });
  }
}
