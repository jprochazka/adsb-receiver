import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class DataService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) { }

  login(email: string, password: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/token/login`, { email, password });
  }

  register(name: string, email: string, password: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/users/register`, { name, email, password });
  }

  getUser(userId: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/users/user/${userId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  updateUser(userId: number, data: any): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/users/user/${userId}`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getUsers(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/users/users`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  createUser(data: { name: string; email: string; password: string; role: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/users/create`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  deleteUser(userId: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/users/user/${userId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getBlogPost(id: any): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/post/` + id);
  }

  getBlogPosts(): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/posts`);
  }

  createBlogPost(data: { title: string; author: string; content: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/blog/post`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  updateBlogPost(id: number, data: { title: string; content: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/blog/post/${id}`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  deleteBlogPost(id: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/blog/post/${id}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getFlights(): Observable<any> {
    return this.http.get(`${this.apiUrl}/flights`);
  }

  searchFlights(q: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/flights/search`, { params: { q } });
  }

  GetFlightsCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/flights/count`);
  }

  getLinks(): Observable<any> {
    return this.http.get(`${this.apiUrl}/links`);
  }

  createLink(data: { name: string; address: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/link`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  updateLink(id: number, data: { name: string; address: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/link/${id}`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  deleteLink(id: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/link/${id}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getSystemCpu(): Observable<any> {
    return this.http.get(`${this.apiUrl}/system/cpu`);
  }

  getSystemMemory(): Observable<any> {
    return this.http.get(`${this.apiUrl}/system/memory`);
  }

  getSystemDisk(): Observable<any> {
    return this.http.get(`${this.apiUrl}/system/disk`);
  }

  getSystemNetwork(): Observable<any> {
    return this.http.get(`${this.apiUrl}/system/network`);
  }

  getSystemOther(): Observable<any> {
    return this.http.get(`${this.apiUrl}/system/other`);
  }

  getSystemDatabase(): Observable<any> {
    return this.http.get(`${this.apiUrl}/system/database`);
  }

  getNotifications(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/notifications`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  createNotification(flight: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/notification/${encodeURIComponent(flight)}`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  deleteNotification(flight: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/notification/${encodeURIComponent(flight)}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getRecentNotifications(): Observable<any> {
    return this.http.get(`${this.apiUrl}/notifications/recent`);
  }

  purgeFlights(days: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/flights/purge?days=${days}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }
}