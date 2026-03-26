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

  getUsers(offset = 0, limit = 10): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/users/users?offset=${offset}&limit=${limit}`, {
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

  getBlogPosts(offset = 0, limit = 10): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/posts?offset=${offset}&limit=${limit}`);
  }

  getAdminBlogPosts(offset = 0, limit = 10): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/blog/posts/all?offset=${offset}&limit=${limit}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  createBlogPost(data: { title: string; author: string; content: string; date?: string; visible?: boolean }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/blog/post`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  updateBlogPost(id: number, data: { title: string; content: string; date?: string; visible?: boolean }): Observable<any> {
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

  getFlights(offset = 0, limit = 50): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flights`, { params: { offset, limit } });
  }

  getFlightDetails(flight: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flight/${encodeURIComponent(flight)}`);
  }

  getUatFlightDetails(flight: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flight/${encodeURIComponent(flight)}`);
  }

  getAircraftPhoto(icao: string): Observable<any> {
    return this.http.get(`https://api.planespotters.net/pub/photos/hex/${encodeURIComponent(icao)}`);
  }

  getFlightPositions(flight: string, limit = 1000): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flight/${encodeURIComponent(flight)}/positions`, { params: { limit } });
  }

  getUatFlightPositions(flight: string, limit = 1000): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flight/${encodeURIComponent(flight)}/positions`, { params: { limit } });
  }

  searchFlights(q: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flights/search`, { params: { q } });
  }

  GetFlightsCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flights/count`);
  }

  getUatFlights(offset = 0, limit = 50): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flights`, { params: { offset, limit } });
  }

  getUatFlightsCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flights/count`);
  }

  searchUatFlights(q: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flights/search`, { params: { q } });
  }

  getAcarsFlights(offset = 0, limit = 50): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flights`, { params: { offset, limit } });
  }

  getAcarsFlightsCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flights/count`);
  }

  searchAcarsFlights(q: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flights/search`, { params: { q } });
  }

  getAcarsFlightMessages(flightId: number, offset = 0, limit = 25): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flight/${flightId}/messages`, { params: { offset, limit } });
  }

  getAcarsStations(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/stations`);
  }

  getAcarsMessagesCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/messages/count`);
  }

  purgeAcarsFlights(days: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/acars/flights/purge?days=${days}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getLinks(offset = 0, limit = 10): Observable<any> {
    return this.http.get(`${this.apiUrl}/links?offset=${offset}&limit=${limit}`);
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

  reorderLinks(ids: number[]): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/links/reorder`, { ids }, {
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
    return this.http.delete(`${this.apiUrl}/adsb/flights/purge?days=${days}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  purgeUatFlights(days: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/uat/flights/purge?days=${days}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getSetting(name: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/setting/${encodeURIComponent(name)}`);
  }

  updateSetting(name: string, value: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/setting`, { name, value }, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }
}