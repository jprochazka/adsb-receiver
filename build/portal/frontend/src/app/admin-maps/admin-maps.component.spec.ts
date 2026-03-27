import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of } from 'rxjs';

import { AdminMapsComponent } from './admin-maps.component';
import { DataService } from '../service/data.service';

describe('AdminMapsComponent', () => {
  let component: AdminMapsComponent;
  let fixture: ComponentFixture<AdminMapsComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.callFake((name: string) => {
      const values: Record<string, string> = {
        map_nav_enabled: 'true',
        map_dump1090_enabled: 'true',
        map_dump978_enabled: 'false',
        map_adsbx_enabled: 'true',
        map_pfclient_enabled: 'false',
        map_links_order: 'adsbx,dump1090,dump978,pfclient',
      };
      return of({ value: values[name] ?? 'true' });
    }),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
  };

  beforeEach(async () => {
    dataServiceMock.getSetting.calls.reset();
    dataServiceMock.updateSetting.calls.reset();

    await TestBed.configureTestingModule({
      imports: [AdminMapsComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminMapsComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load map items with saved order', () => {
    fixture.detectChanges();

    expect(component.loading).toBeFalse();
    expect(component.mapItems.length).toBe(4);
    expect(component.mapItems[0].key).toBe('adsbx');
    expect(component.mapItems[1].key).toBe('dump1090');
    expect(component.mapItems[2].enabled).toBeFalse();
  });

  it('should save map nav setting', () => {
    fixture.detectChanges();
    component.mapNavEnabled = false;

    component.saveNavEnabled();

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('map_nav_enabled', 'false');
  });

  it('should save map item enabled setting', () => {
    fixture.detectChanges();
    const item = component.mapItems[0];
    item.enabled = false;

    component.saveItemEnabled(item);

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith(item.settingKey, 'false');
  });

  it('should reorder map items on drop and persist order', () => {
    fixture.detectChanges();
    component.dragIndex = 0;

    component.onDrop(new DragEvent('drop'), 1);

    expect(component.mapItems[0].key).toBe('dump1090');
    expect(component.mapItems[1].key).toBe('adsbx');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('map_links_order', jasmine.any(String));
  });
});
