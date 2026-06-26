import { Component, ChangeDetectionStrategy } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { AdminSettingToggleComponent } from './admin-setting-toggle.component';

@Component({
  standalone: true,
  imports: [AdminSettingToggleComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <app-admin-setting-toggle
      id="toggle-test"
      title="Test Toggle"
      description="Toggle description"
      [checked]="enabled"
      enabledLabel="Visible"
      disabledLabel="Hidden"
      (checkedChange)="enabled = $event">
    </app-admin-setting-toggle>
  `,
})
class HostComponent {
  enabled = true;
}

describe('AdminSettingToggleComponent', () => {
  let fixture: ComponentFixture<HostComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [HostComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(HostComponent);
    fixture.detectChanges();
  });

  it('should render title, description, and current state label', () => {
    const html = fixture.nativeElement as HTMLElement;

    expect(html.textContent).toContain('Test Toggle');
    expect(html.textContent).toContain('Toggle description');
    expect(html.textContent).toContain('Visible');
    expect(html.querySelector('input')?.id).toBe('toggle-test');
  });

  it('should emit checkedChange when toggled', () => {
    const input = fixture.nativeElement.querySelector('input') as HTMLInputElement;
    input.checked = false;
    input.dispatchEvent(new Event('change'));
    fixture.detectChanges();

    expect(fixture.componentInstance.enabled).toBeFalse();
    expect(fixture.nativeElement.textContent).toContain('Hidden');
  });
});
