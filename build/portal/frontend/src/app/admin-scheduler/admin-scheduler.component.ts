import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, forkJoin, of } from 'rxjs';

import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { isAdminAccessToken } from '../shared/auth-session';

@Component({
  selector: 'app-admin-scheduler',
  standalone: true,
  imports: [SpinnerComponent],
  templateUrl: './admin-scheduler.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './admin-scheduler.component.scss'
})
export class AdminSchedulerComponent implements OnInit {
  loading = true;
  actionBusy = false;
  jobsBusy: Record<string, boolean> = {};

  schedulerStatus: any = null;
  jobs: any[] = [];

  successMessage = '';
  errorMessage = '';

  constructor(private dataService: DataService, private router: Router) {}

  ngOnInit(): void {
    if (!this.isAdmin()) {
      this.router.navigate(['/login']);
      return;
    }
    this.refresh();
  }

  refresh(): void {
    this.loading = true;
    this.errorMessage = '';

    forkJoin({
      status: this.dataService.getSchedulerStatus().pipe(catchError(() => of(null))),
      jobs: this.dataService.getSchedulerJobs().pipe(catchError(() => of([]))),
    }).subscribe({
      next: ({ status, jobs }) => {
        this.schedulerStatus = status;
        this.jobs = Array.isArray(jobs) ? jobs : [];
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load scheduler data.';
        this.loading = false;
      }
    });
  }

  schedulerStateLabel(): string {
    if (!this.schedulerStatus) return 'Unknown';

    const state = String(this.schedulerStatus.state ?? '').toUpperCase();
    if (state.includes('RUNNING') || this.schedulerStatus.running === true) return 'Running';
    if (state.includes('PAUSED') || this.schedulerStatus.paused === true) return 'Paused';
    if (state.includes('STOPPED') || state.includes('SHUTDOWN')) return 'Stopped';
    return this.schedulerStatus.state ?? 'Unknown';
  }

  isSchedulerRunning(): boolean {
    const state = String(this.schedulerStatus?.state ?? '').toUpperCase();
    return state.includes('RUNNING') || this.schedulerStatus?.running === true;
  }

  isSchedulerPaused(): boolean {
    const state = String(this.schedulerStatus?.state ?? '').toUpperCase();
    return state.includes('PAUSED') || this.schedulerStatus?.paused === true;
  }

  isSchedulerStopped(): boolean {
    const state = String(this.schedulerStatus?.state ?? '').toUpperCase();
    return state.includes('STOPPED') || state.includes('SHUTDOWN');
  }

  isSchedulerStateUnknown(): boolean {
    return !this.isSchedulerRunning() && !this.isSchedulerPaused() && !this.isSchedulerStopped();
  }

  canStartScheduler(): boolean {
    return this.isSchedulerStopped();
  }

  canPauseScheduler(): boolean {
    return this.isSchedulerRunning();
  }

  canResumeScheduler(): boolean {
    return this.isSchedulerPaused();
  }

  canShutdownScheduler(): boolean {
    return this.isSchedulerRunning() || this.isSchedulerPaused();
  }

  isJobPaused(job: any): boolean {
    return !job?.next_run_time && !job?.pending;
  }

  canRunJob(job: any): boolean {
    return !job?.pending;
  }

  canPauseJob(job: any): boolean {
    return !this.isJobPaused(job) && !job?.pending;
  }

  canResumeJob(job: any): boolean {
    return this.isJobPaused(job);
  }

  start(): void {
    this.performSchedulerAction(() => this.dataService.startScheduler(), 'Scheduler started.');
  }

  pause(): void {
    this.performSchedulerAction(() => this.dataService.pauseScheduler(), 'Scheduler paused.');
  }

  resume(): void {
    this.performSchedulerAction(() => this.dataService.resumeScheduler(), 'Scheduler resumed.');
  }

  shutdown(): void {
    this.performSchedulerAction(() => this.dataService.shutdownScheduler(), 'Scheduler shut down.');
  }

  runJob(jobId: string): void {
    this.performJobAction(jobId, () => this.dataService.runSchedulerJob(jobId), `Job ${jobId} queued to run.`);
  }

  pauseJob(jobId: string): void {
    this.performJobAction(jobId, () => this.dataService.pauseSchedulerJob(jobId), `Job ${jobId} paused.`);
  }

  resumeJob(jobId: string): void {
    this.performJobAction(jobId, () => this.dataService.resumeSchedulerJob(jobId), `Job ${jobId} resumed.`);
  }

  private performSchedulerAction(action: () => any, successMessage: string): void {
    this.actionBusy = true;
    this.successMessage = '';
    this.errorMessage = '';

    action().subscribe({
      next: () => {
        this.actionBusy = false;
        this.successMessage = successMessage;
        this.refresh();
      },
      error: () => {
        this.actionBusy = false;
        this.errorMessage = 'Scheduler action failed. Ensure you are logged in as Admin.';
      }
    });
  }

  private performJobAction(jobId: string, action: () => any, successMessage: string): void {
    this.jobsBusy[jobId] = true;
    this.successMessage = '';
    this.errorMessage = '';

    action().subscribe({
      next: () => {
        this.jobsBusy[jobId] = false;
        this.successMessage = successMessage;
        this.refresh();
      },
      error: () => {
        this.jobsBusy[jobId] = false;
        this.errorMessage = `Action failed for job ${jobId}.`;
      }
    });
  }

  private isAdmin(): boolean {
    return isAdminAccessToken();
  }
}
