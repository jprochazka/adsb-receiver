import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import type { BlogPostSummary, PaginatedResponse } from '../shared/api-types';

@Injectable({
  providedIn: 'root'
})
export class DataService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) { }

  private authHeaders(): { Authorization: string } {
    const token = localStorage.getItem('access_token');
    return { Authorization: `Bearer ${token}` };
  }

  private offsetLimitParams(offset: number, limit: number): HttpParams {
    return new HttpParams()
      .set('offset', offset)
      .set('limit', limit);
  }

  private flightUrl(source: 'adsb' | 'uat', flight: string, suffix = ''): string {
    return `${this.apiUrl}/${source}/flight/${encodeURIComponent(flight)}${suffix}`;
  }

  private schedulerJobUrl(jobId: string, action: 'run' | 'pause' | 'resume'): string {
    return `${this.apiUrl}/scheduler/jobs/${encodeURIComponent(jobId)}/${action}`;
  }

  login(email: string, password: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/token/login`, { email, password });
  }

  register(name: string, email: string, password: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/users/register`, { name, email, password });
  }

  getUser(userId: number): Observable<any> {
    return this.http.get(`${this.apiUrl}/users/user/${userId}`, {
      headers: this.authHeaders()
    });
  }

  updateUser(userId: number, data: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/users/user/${userId}`, data, {
      headers: this.authHeaders()
    });
  }

  getUsers(offset = 0, limit = 10, options?: { q?: string; locked?: boolean | null }): Observable<any> {
    let params = this.offsetLimitParams(offset, limit);

    if (options?.q?.trim()) {
      params = params.set('q', options.q.trim());
    }

    if (options?.locked !== undefined && options?.locked !== null) {
      params = params.set('locked', String(options.locked));
    }

    return this.http.get(`${this.apiUrl}/users/users`, {
      params,
      headers: this.authHeaders()
    });
  }

  createUser(data: { name: string; email: string; password: string; role: string }): Observable<any> {
    return this.http.post(`${this.apiUrl}/users/create`, data, {
      headers: this.authHeaders()
    });
  }

  deleteUser(userId: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/users/user/${userId}`, {
      headers: this.authHeaders()
    });
  }

  setUserLocked(userId: number, locked: boolean): Observable<any> {
    return this.http.put(`${this.apiUrl}/users/user/${userId}/lock`, { locked }, {
      headers: this.authHeaders()
    });
  }

  getBlogPost(id: any): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/post/` + id);
  }

  getBlogPostComments(blogPostId: number | string): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/post/${blogPostId}/comments`);
  }

  createBlogComment(blogPostId: number | string, data: { content: string; parent_comment_id?: number }): Observable<any> {
    return this.http.post(`${this.apiUrl}/blog/post/${blogPostId}/comments`, data, {
      headers: this.authHeaders()
    });
  }

  updateBlogComment(blogPostId: number | string, commentId: number, data: { content: string }): Observable<any> {
    return this.http.put(`${this.apiUrl}/blog/post/${blogPostId}/comments/${commentId}`, data, {
      headers: this.authHeaders()
    });
  }

  deleteBlogComment(blogPostId: number | string, commentId: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/blog/post/${blogPostId}/comments/${commentId}`, {
      headers: this.authHeaders()
    });
  }

  getBlogPosts(offset = 0, limit = 10, category = '', tag = ''): Observable<PaginatedResponse<BlogPostSummary>> {
    let params = this.offsetLimitParams(offset, limit);

    if (category) {
      params = params.set('category', category);
    }

    if (tag) {
      params = params.set('tag', tag);
    }

    return this.http.get<PaginatedResponse<BlogPostSummary>>(`${this.apiUrl}/blog/posts`, { params });
  }

  getBlogPostsMeta(): Observable<any> {
    return this.http.get(`${this.apiUrl}/blog/posts/meta`);
  }

  getAdminBlogPosts(offset = 0, limit = 10, options?: { q?: string; status?: string }): Observable<any> {
    let params = this.offsetLimitParams(offset, limit);

    if (options?.q?.trim()) {
      params = params.set('q', options.q.trim());
    }

    if (options?.status && options.status !== 'all') {
      params = params.set('status', options.status);
    }

    return this.http.get(`${this.apiUrl}/blog/posts/all`, {
      params,
      headers: this.authHeaders()
    });
  }

  createBlogPost(data: { title: string; author: string; content: string; date?: string; visible?: boolean; tags?: string[]; category?: string }): Observable<any> {
    return this.http.post(`${this.apiUrl}/blog/post`, data, {
      headers: this.authHeaders()
    });
  }

  updateBlogPost(id: number, data: { title: string; content: string; date?: string; visible?: boolean; tags?: string[]; category?: string }): Observable<any> {
    return this.http.put(`${this.apiUrl}/blog/post/${id}`, data, {
      headers: this.authHeaders()
    });
  }

  deleteBlogPost(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/blog/post/${id}`, {
      headers: this.authHeaders()
    });
  }

  getFlights(offset = 0, limit = 50): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flights`, { params: this.offsetLimitParams(offset, limit) });
  }

  getIgnoredFlights(offset = 0, limit = 10): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flights`, {
      params: { offset, limit, ignore_on_purge: 'true' }
    });
  }

  getFlightDetails(flight: string): Observable<any> {
    return this.http.get(this.flightUrl('adsb', flight));
  }

  updateFlightPurgePreference(flight: string, ignore_on_purge: boolean): Observable<any> {
    return this.http.put(
      this.flightUrl('adsb', flight, '/purge-preference'),
      { ignore_on_purge },
      { headers: this.authHeaders() }
    );
  }

  getUatFlightDetails(flight: string): Observable<any> {
    return this.http.get(this.flightUrl('uat', flight));
  }

  updateUatFlightPurgePreference(flight: string, ignore_on_purge: boolean): Observable<any> {
    return this.http.put(
      this.flightUrl('uat', flight, '/purge-preference'),
      { ignore_on_purge },
      { headers: this.authHeaders() }
    );
  }

  getAircraftPhoto(icao: string): Observable<any> {
    return this.http.get(`https://api.planespotters.net/pub/photos/hex/${encodeURIComponent(icao)}`);
  }

  getFlightPositions(flight: string, limit = 1000): Observable<any> {
    return this.http.get(this.flightUrl('adsb', flight, '/positions'), { params: { limit } });
  }

  getUatFlightPositions(flight: string, limit = 1000): Observable<any> {
    return this.http.get(this.flightUrl('uat', flight, '/positions'), { params: { limit } });
  }

  getFlightComments(flight: string): Observable<any> {
    return this.http.get(this.flightUrl('adsb', flight, '/comments'));
  }

  getUatFlightComments(flight: string): Observable<any> {
    return this.http.get(this.flightUrl('uat', flight, '/comments'));
  }

  createFlightComment(flight: string, content: string): Observable<any> {
    return this.http.post(
      this.flightUrl('adsb', flight, '/comments'),
      { content },
      { headers: this.authHeaders() }
    );
  }

  createUatFlightComment(flight: string, content: string): Observable<any> {
    return this.http.post(
      this.flightUrl('uat', flight, '/comments'),
      { content },
      { headers: this.authHeaders() }
    );
  }

  updateFlightComment(flight: string, commentId: number, content: string): Observable<any> {
    return this.http.put(
      this.flightUrl('adsb', flight, `/comments/${commentId}`),
      { content },
      { headers: this.authHeaders() }
    );
  }

  deleteFlightComment(flight: string, commentId: number): Observable<any> {
    return this.http.delete(
      this.flightUrl('adsb', flight, `/comments/${commentId}`),
      { headers: this.authHeaders() }
    );
  }

  updateUatFlightComment(flight: string, commentId: number, content: string): Observable<any> {
    return this.http.put(
      this.flightUrl('uat', flight, `/comments/${commentId}`),
      { content },
      { headers: this.authHeaders() }
    );
  }

  deleteUatFlightComment(flight: string, commentId: number): Observable<any> {
    return this.http.delete(
      this.flightUrl('uat', flight, `/comments/${commentId}`),
      { headers: this.authHeaders() }
    );
  }

  searchFlights(q: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flights/search`, { params: { q } });
  }

  GetFlightsCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/adsb/flights/count`);
  }

  getUatFlights(offset = 0, limit = 50): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flights`, { params: this.offsetLimitParams(offset, limit) });
  }

  getIgnoredUatFlights(offset = 0, limit = 10): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flights`, {
      params: { offset, limit, ignore_on_purge: 'true' }
    });
  }

  getUatFlightsCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flights/count`);
  }

  searchUatFlights(q: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/uat/flights/search`, { params: { q } });
  }

  getAcarsFlights(offset = 0, limit = 50): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flights`, { params: this.offsetLimitParams(offset, limit) });
  }

  getAcarsFlightsCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flights/count`);
  }

  getAcarsFlightMessages(flightId: number, offset = 0, limit = 25): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flight/${flightId}/messages`, { params: this.offsetLimitParams(offset, limit) });
  }

  getAcarsMessagesCount(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/messages/count`);
  }

  getAcarsDatabase(): Observable<any> {
    return this.http.get(`${this.apiUrl}/acars/flights/database`);
  }

  purgeAcarsFlights(days: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/acars/flights/purge?days=${days}`, {
      headers: this.authHeaders()
    });
  }

  getLinks(offset = 0, limit = 10): Observable<any> {
    return this.http.get(`${this.apiUrl}/links?offset=${offset}&limit=${limit}`);
  }

  createLink(data: { name: string; address: string }): Observable<any> {
    return this.http.post(`${this.apiUrl}/links`, data, {
      headers: this.authHeaders()
    });
  }

  updateLink(id: number, data: { name: string; address: string }): Observable<any> {
    return this.http.put(`${this.apiUrl}/links/${id}`, data, {
      headers: this.authHeaders()
    });
  }

  deleteLink(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/links/${id}`, {
      headers: this.authHeaders()
    });
  }

  reorderLinks(ids: number[]): Observable<any> {
    return this.http.put(`${this.apiUrl}/links/reorder`, { ids }, {
      headers: this.authHeaders()
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
    return this.http.get(`${this.apiUrl}/devices/flights-tables`, {
      headers: this.authHeaders()
    });
  }

  getReceiverInfo(): Observable<any> {
    return this.http.get(`${this.apiUrl}/devices/receiver`);
  }

  getNotifications(): Observable<any> {
    return this.http.get(`${this.apiUrl}/notifications`, {
      headers: this.authHeaders()
    });
  }

  createNotification(flight: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/notifications/${encodeURIComponent(flight)}`, {}, {
      headers: this.authHeaders()
    });
  }

  deleteNotification(flight: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/notifications/${encodeURIComponent(flight)}`, {
      headers: this.authHeaders()
    });
  }

  getRecentNotifications(): Observable<any> {
    return this.http.get(`${this.apiUrl}/notifications/recent`);
  }

  purgeFlights(days: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/adsb/flights/purge?days=${days}`, {
      headers: this.authHeaders()
    });
  }

  purgeUatFlights(days: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/uat/flights/purge?days=${days}`, {
      headers: this.authHeaders()
    });
  }

  getSetting(name: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/setting/${encodeURIComponent(name)}`);
  }

  getApiVersion(): Observable<any> {
    return this.http.get(`${this.apiUrl}/setting/api-version`);
  }

  getGraphData(
    decoder: string,
    metric: string,
    options: { period?: string; start?: number; end?: number; step?: number } = {}
  ): Observable<any> {
    let params = new HttpParams();

    if (options.start != null && options.end != null) {
      params = params.set('start', String(options.start));
      params = params.set('end', String(options.end));
    } else {
      params = params.set('period', options.period ?? '24h');
    }

    if (options.step != null) {
      params = params.set('step', String(options.step));
    }

    return this.http.get(`${this.apiUrl}/graphs/${decoder}/${metric}`, { params });
  }

  updateSetting(name: string, value: string): Observable<any> {
    return this.http.put(`${this.apiUrl}/setting`, { name, value }, {
      headers: this.authHeaders()
    });
  }

  getOpenSkyAircraftDatabaseStatus(): Observable<any> {
    return this.http.get(`${this.apiUrl}/setting/opensky-aircraft-database`);
  }

  updateOpenSkyAircraftDatabase(): Observable<any> {
    return this.http.post(`${this.apiUrl}/setting/opensky-aircraft-database/update`, {}, {
      headers: this.authHeaders()
    });
  }

  getSchedulerStatus(): Observable<any> {
    return this.http.get(`${this.apiUrl}/scheduler`, {
      headers: this.authHeaders()
    });
  }

  getSchedulerJobs(): Observable<any> {
    return this.http.get(`${this.apiUrl}/scheduler/jobs`, {
      headers: this.authHeaders()
    });
  }

  startScheduler(): Observable<any> {
    return this.http.post(`${this.apiUrl}/scheduler/start`, {}, {
      headers: this.authHeaders()
    });
  }

  pauseScheduler(): Observable<any> {
    return this.http.post(`${this.apiUrl}/scheduler/pause`, {}, {
      headers: this.authHeaders()
    });
  }

  resumeScheduler(): Observable<any> {
    return this.http.post(`${this.apiUrl}/scheduler/resume`, {}, {
      headers: this.authHeaders()
    });
  }

  shutdownScheduler(): Observable<any> {
    return this.http.post(`${this.apiUrl}/scheduler/shutdown`, {}, {
      headers: this.authHeaders()
    });
  }

  runSchedulerJob(jobId: string): Observable<any> {
    return this.http.post(this.schedulerJobUrl(jobId, 'run'), {}, {
      headers: this.authHeaders()
    });
  }

  pauseSchedulerJob(jobId: string): Observable<any> {
    return this.http.post(this.schedulerJobUrl(jobId, 'pause'), {}, {
      headers: this.authHeaders()
    });
  }

  resumeSchedulerJob(jobId: string): Observable<any> {
    return this.http.post(this.schedulerJobUrl(jobId, 'resume'), {}, {
      headers: this.authHeaders()
    });
  }

  getLiveAircraft(): Observable<any> {
    return this.http.get(`${this.apiUrl}/live/aircraft`);
  }
}