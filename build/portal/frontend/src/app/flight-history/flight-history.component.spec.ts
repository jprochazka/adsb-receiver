import { ComponentFixture, TestBed } from '@angular/core/testing';

import { FlightHistoryComponent } from './flight-history.component';

describe('MapComponent', () => {
  let component: FlightHistoryComponent;
  let fixture: ComponentFixture<FlightHistoryComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FlightHistoryComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(FlightHistoryComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
