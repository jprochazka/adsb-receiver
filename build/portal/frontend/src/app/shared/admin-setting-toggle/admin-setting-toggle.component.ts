import { Component, EventEmitter, Input, Output } from '@angular/core';

@Component({
  selector: 'app-admin-setting-toggle',
  standalone: true,
  template: `
    <li class="list-group-item d-flex justify-content-between align-items-center">
      <div>
        <div class="fw-semibold">{{ title }}</div>
        <div class="text-muted small">{{ description }}</div>
      </div>
      <div class="form-check form-switch mb-0">
        <input
          class="form-check-input"
          type="checkbox"
          role="switch"
          [id]="id"
          [checked]="checked"
          (change)="onChange($event)">
        <label class="form-check-label" [for]="id">
          {{ checked ? enabledLabel : disabledLabel }}
        </label>
      </div>
    </li>
  `,
})
export class AdminSettingToggleComponent {
  @Input({ required: true }) id = '';
  @Input({ required: true }) title = '';
  @Input({ required: true }) description = '';
  @Input() checked = false;
  @Input() enabledLabel = 'Enabled';
  @Input() disabledLabel = 'Disabled';

  @Output() checkedChange = new EventEmitter<boolean>();

  onChange(event: Event): void {
    const target = event.target as HTMLInputElement | null;
    if (!target) {
      return;
    }

    this.checkedChange.emit(target.checked);
  }
}
