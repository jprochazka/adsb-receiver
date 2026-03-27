import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';

import { LogoutComponent } from './logout.component';

describe('LogoutComponent', () => {
  let component: LogoutComponent;
  let fixture: ComponentFixture<LogoutComponent>;
  let router: Router;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LogoutComponent],
      providers: [provideRouter([])],
    }).compileComponents();

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(LogoutComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should remove tokens and navigate to login on logout', () => {
    const navigateSpy = spyOn(router, 'navigate').and.resolveTo(true);
    localStorage.setItem('access_token', 'token');
    localStorage.setItem('refresh_token', 'refresh');

    component.logout();

    expect(localStorage.getItem('access_token')).toBeNull();
    expect(localStorage.getItem('refresh_token')).toBeNull();
    expect(navigateSpy).toHaveBeenCalledWith(['/login']);
  });

  it('should trigger logout when link is clicked', () => {
    const logoutSpy = spyOn(component, 'logout').and.callThrough();

    const link: HTMLAnchorElement | null = fixture.nativeElement.querySelector('a.nav-link');
    expect(link).not.toBeNull();

    link?.click();

    expect(logoutSpy).toHaveBeenCalled();
  });
});
