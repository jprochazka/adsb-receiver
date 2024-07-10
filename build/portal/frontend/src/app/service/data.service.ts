import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class DataService {
  constructor(private http: HttpClient) { }

  getBlogPost(id: any): Observable<any> {
    return this.http.get('http://127.0.0.1:5000/api/blog/post/' + id);
  }

  getBlogPosts(): Observable<any> {
    return this.http.get('http://127.0.0.1:5000/api/blog/posts');
  }

  getFlights(): Observable<any> {
    return this.http.get('http://127.0.0.1:5000/api/flights');
  }

  GetFlightsCount(): Observable<any> {
    return this.http.get('http://127.0.0.1:5000/api/flights/count');
  }

  getLinks(): Observable<any> {
    return this.http.get('http://127.0.0.1:5000/api/links');
  }
}