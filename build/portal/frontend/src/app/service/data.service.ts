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

  setUserLocked(userId: number, locked: boolean): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/users/user/${userId}/lock`, { locked }, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getBlogPost(id: any): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/post/` + id);
  }

  getBlogPostComments(blogPostId: number | string): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/post/${blogPostId}/comments`);
  }

  createBlogComment(blogPostId: number | string, data: { content: string; parent_comment_id?: number }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/blog/post/${blogPostId}/comments`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  updateBlogComment(blogPostId: number | string, commentId: number, data: { content: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/blog/post/${blogPostId}/comments/${commentId}`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  deleteBlogComment(blogPostId: number | string, commentId: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/blog/post/${blogPostId}/comments/${commentId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getBlogPosts(offset = 0, limit = 10, category = '', tag = ''): Observable<any> {
    const cat = category ? `&category=${encodeURIComponent(category)}` : '';
    const tg = tag ? `&tag=${encodeURIComponent(tag)}` : '';
    return this.http.get(`${this.apiUrl}/blog/posts?offset=${offset}&limit=${limit}${cat}${tg}`);
  }

  getBlogPostsMeta(): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/posts/meta`);
  }

  getAdminBlogPosts(offset = 0, limit = 10): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/blog/posts/all?offset=${offset}&limit=${limit}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  createBlogPost(data: { title: string; author: string; content: string; date?: string; visible?: boolean; tags?: string[]; category?: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/blog/post`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  updateBlogPost(id: number, data: { title: string; content: string; date?: string; visible?: boolean; tags?: string[]; category?: string }): Observable<any> {
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

  getAcarsFlightMessages(flightId: number, offset = 0, limit = 25): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flight/${flightId}/messages`, { params: { offset, limit } });
  }

  getAcarsMessagesCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/messages/count`);
  }

  getAcarsDatabase(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flights/database`);
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
    return this.http.post(`${this.apiUrl}/links`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  updateLink(id: number, data: { name: string; address: string }): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/links/${id}`, data, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  deleteLink(id: number): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/links/${id}`, {
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
    return this.http.get(`${this.apiUrl}/devices/cpu`);
  }

  getSystemMemory(): Observable<any> {
    return this.http.get(`${this.apiUrl}/devices/memory`);
  }

  getSystemDisk(): Observable<any> {
    return this.http.get(`${this.apiUrl}/devices/disk`);
  }

  getSystemNetwork(): Observable<any> {
    return this.http.get(`${this.apiUrl}/devices/network`);
  }

  getSystemOther(): Observable<any> {
    return this.http.get(`${this.apiUrl}/devices/other`);
  }

  getSystemDatabase(): Observable<any> {
    return this.http.get(`${this.apiUrl}/devices/database`);
  }

  getSystemFlightsTables(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/devices/flights-tables`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getNotifications(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/notifications`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  createNotification(flight: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/notifications/${encodeURIComponent(flight)}`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  deleteNotification(flight: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.delete(`${this.apiUrl}/notifications/${encodeURIComponent(flight)}`, {
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

  getGraphData(decoder: string, metric: string, period: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/graphs/${decoder}/${metric}?period=${period}`);
  }

  updateSetting(name: string, value: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.put(`${this.apiUrl}/setting`, { name, value }, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getSchedulerStatus(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/scheduler`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  getSchedulerJobs(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.get(`${this.apiUrl}/scheduler/jobs`, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  startScheduler(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/scheduler/start`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  pauseScheduler(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/scheduler/pause`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  resumeScheduler(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/scheduler/resume`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  shutdownScheduler(): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/scheduler/shutdown`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  runSchedulerJob(jobId: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/scheduler/jobs/${encodeURIComponent(jobId)}/run`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  pauseSchedulerJob(jobId: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/scheduler/jobs/${encodeURIComponent(jobId)}/pause`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  resumeSchedulerJob(jobId: string): Observable<any> {
    const token = localStorage.getItem('access_token');
    return this.http.post(`${this.apiUrl}/scheduler/jobs/${encodeURIComponent(jobId)}/resume`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }
}