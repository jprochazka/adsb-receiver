import { Component, ChangeDetectionStrategy, computed, input, output } from '@angular/core';

@Component({
  selector: 'app-admin-setting-toggle',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <li class="list-group-item d-flex justify-content-between align-items-center">
      <div>
        <div class="fw-semibold">{{ title() }}</div>
        <div class="text-muted small">{{ description() }}</div>
      </div>
      <div class="form-check form-switch mb-0">
        <input
          class="form-check-input"
          type="checkbox"
          role="switch"
          [id]="id()"
          [checked]="checked()"
          (change)="onChange($event)">
        <label class="form-check-label" [for]="id()">
          {{ stateLabel() }}
        </label>
      </div>
    </li>
  `,
})
export class AdminSettingToggleComponent {
  readonly id = input.required<string>();
  readonly title = input.required<string>();
  readonly description = input.required<string>();
  readonly checked = input(false);
  readonly enabledLabel = input('Enabled');
  readonly disabledLabel = input('Disabled');

  readonly checkedChange = output<boolean>();

  protected readonly stateLabel = computed(() => this.checked() ? this.enabledLabel() : this.disabledLabel());

  onChange(event: Event): void {
    const target = event.target as HTMLInputElement | null;
    if (!target) {
      return;
    }

    this.checkedChange.emit(target.checked);
  }
}
