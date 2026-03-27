import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminLinksComponent } from './admin-links.component';
import { DataService } from '../service/data.service';

describe('AdminLinksComponent', () => {
  let component: AdminLinksComponent;
  let fixture: ComponentFixture<AdminLinksComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.returnValue(of({ value: 'true' })),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
    getLinks: jasmine.createSpy('getLinks').and.returnValue(of({ links: [{ id: 1, name: 'One', address: 'https://one.test' }, { id: 2, name: 'Two', address: 'https://two.test' }] })),
    createLink: jasmine.createSpy('createLink').and.returnValue(of({})),
    updateLink: jasmine.createSpy('updateLink').and.returnValue(of({})),
    deleteLink: jasmine.createSpy('deleteLink').and.returnValue(of({})),
    reorderLinks: jasmine.createSpy('reorderLinks').and.returnValue(of({})),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());

    await TestBed.configureTestingModule({
      imports: [AdminLinksComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminLinksComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load links on init', () => {
    fixture.detectChanges();

    expect(dataServiceMock.getLinks).toHaveBeenCalledWith(0, 100);
    expect(component.links.length).toBe(2);
    expect(component.loading).toBeFalse();
  });

  it('should validate create link form', () => {
    fixture.detectChanges();
    component.newName = ' ';
    component.newAddress = ' ';

    component.createLink();

    expect(component.errorMessage).toBe('Name and address are required.');
    expect(dataServiceMock.createLink).not.toHaveBeenCalled();
  });

  it('should create link successfully', () => {
    fixture.detectChanges();
    component.newName = ' Example ';
    component.newAddress = ' https://example.com ';

    component.createLink();

    expect(dataServiceMock.createLink).toHaveBeenCalledWith({ name: 'Example', address: 'https://example.com' });
    expect(component.creating).toBeFalse();
    expect(component.successMessage).toBe('Link created successfully.');
  });

  it('should reorder links on drop', () => {
    fixture.detectChanges();
    component.links = [
      { id: 1, name: 'One', address: 'https://one.test' },
      { id: 2, name: 'Two', address: 'https://two.test' },
    ];
    component.dragIndex = 0;

    component.onDrop(new DragEvent('drop'), 1);

    expect(dataServiceMock.reorderLinks).toHaveBeenCalled();
    expect(component.dragIndex).toBeNull();
    expect(component.dragOverIndex).toBeNull();
  });

  it('should reload links when reordering fails', () => {
    dataServiceMock.reorderLinks.and.returnValue(throwError(() => new Error('failed')));
    fixture.detectChanges();
    component.links = [
      { id: 1, name: 'One', address: 'https://one.test' },
      { id: 2, name: 'Two', address: 'https://two.test' },
    ];
    component.dragIndex = 0;

    component.onDrop(new DragEvent('drop'), 1);

    expect(component.errorMessage).toBe('Failed to save link order.');
    expect(dataServiceMock.getLinks).toHaveBeenCalledTimes(2);
  });
});
