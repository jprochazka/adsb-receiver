import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { FlightHistoryComponent } from './flight-history/flight-history.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, FlightHistoryComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent {
  title = 'frontend';
}
