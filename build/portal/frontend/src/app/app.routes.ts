import { Routes } from '@angular/router';
import { BlogComponent } from './blog/blog.component';
import { BlogPostComponent } from './blog-post/blog-post.component';
import { FlightHistoryComponent } from './flight-history/flight-history.component';
import { FlightsComponent } from './flights/flights.component';

export const routes: Routes = [
    { path: 'blog', component: BlogComponent },
    { path: 'blog-post/:id', component: BlogPostComponent },
    { path: 'flight-history/:flight', component: FlightHistoryComponent },
    { path: 'flights', component: FlightsComponent },
    { path: 'flights/:page', component: FlightsComponent }
];