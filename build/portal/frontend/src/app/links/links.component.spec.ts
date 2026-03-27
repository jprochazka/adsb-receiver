import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { LinksComponent } from './links.component';
import { DataService } from '../service/data.service';

describe('LinksComponent', () => {
  let component: LinksComponent;
  let fixture: ComponentFixture<LinksComponent>;

  const dataServiceMock = {
    getLinks: jasmine.createSpy('getLinks').and.returnValue(of({
      links: [{ id: 1, name: 'Link One', address: 'https://example.com' }],
    })),
  };

  beforeEach(async () => {
    dataServiceMock.getLinks.calls.reset();
    dataServiceMock.getLinks.and.returnValue(of({
      links: [{ id: 1, name: 'Link One', address: 'https://example.com' }],
    }));

    await TestBed.configureTestingModule({
      imports: [LinksComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(LinksComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load links on init', () => {
    expect(dataServiceMock.getLinks).toHaveBeenCalled();
    expect(component.data).toEqual({
      links: [{ id: 1, name: 'Link One', address: 'https://example.com' }],
    });
    expect(component.loading).toBeFalse();
  });

  it('should set loading false when links request fails', () => {
    dataServiceMock.getLinks.and.returnValue(throwError(() => new Error('failed')));

    component.ngOnInit();

    expect(component.loading).toBeFalse();
  });
});
