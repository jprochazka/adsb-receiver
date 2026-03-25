import { ComponentFixture, TestBed } from '@angular/core/testing';
import { AcarsComponent } from './acars.component';

describe('AcarsComponent', () => {
  let component: AcarsComponent;
  let fixture: ComponentFixture<AcarsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AcarsComponent]
    }).compileComponents();

    fixture = TestBed.createComponent(AcarsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
