import { ComponentFixture, TestBed } from '@angular/core/testing';

import { FlightsComponent } from './flights.component';

describe('FlightsComponent', () => {
  let component: FlightsComponent;
  let fixture: ComponentFixture<FlightsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FlightsComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(FlightsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
