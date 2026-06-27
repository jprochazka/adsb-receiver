import {
  buildPurgeCompleteMessage,
  buildPurgePreferenceError,
  canGoToNextIgnoredPage,
  getIgnoredRangeEnd,
  getIgnoredRangeStart,
  getNextIgnoredOffset,
  getPreviousIgnoredOffset,
  normalizeIgnoredOffsetAfterLoad,
  readIgnoreOnPurgeChecked,
} from './admin-flights.helpers';

describe('admin flights helpers', () => {
  it('buildPurgeCompleteMessage should format deleted counts and cutoff', () => {
    expect(buildPurgeCompleteMessage({
      deleted_flights: 2,
      deleted_positions: 10,
      cutoff_date: '2026-03-01 00:00:00',
    })).toBe('Purge complete: 2 flight(s) and 10 position(s) deleted (cutoff: 2026-03-01 00:00:00).');
  });

  it('ignored range helpers should show zero start for empty totals and bounded ends', () => {
    expect(getIgnoredRangeStart(0, 20)).toBe(0);
    expect(getIgnoredRangeStart(50, 20)).toBe(21);
    expect(getIgnoredRangeEnd(20, 25, 42)).toBe(42);
  });

  it('pagination helpers should prevent invalid prev/next movement', () => {
    expect(getPreviousIgnoredOffset(20, 10)).toBe(10);
    expect(getPreviousIgnoredOffset(0, 10)).toBe(0);
    expect(canGoToNextIgnoredPage(false, 10, 10, 25)).toBeTrue();
    expect(canGoToNextIgnoredPage(false, 20, 10, 25)).toBeFalse();
    expect(canGoToNextIgnoredPage(true, 10, 10, 25)).toBeFalse();
    expect(getNextIgnoredOffset(10, 10)).toBe(20);
  });

  it('normalizeIgnoredOffsetAfterLoad should step back when current offset exceeds total', () => {
    expect(normalizeIgnoredOffsetAfterLoad(20, 10, 15)).toBe(10);
    expect(normalizeIgnoredOffsetAfterLoad(10, 10, 15)).toBe(10);
    expect(normalizeIgnoredOffsetAfterLoad(20, 10, 0)).toBe(20);
  });

  it('readIgnoreOnPurgeChecked should return null when the event target is not an input', () => {
    expect(readIgnoreOnPurgeChecked({ target: { checked: true } } as unknown as Event)).toBeTrue();
    expect(readIgnoreOnPurgeChecked({ target: null } as unknown as Event)).toBeNull();
  });

  it('buildPurgePreferenceError should identify the source and flight', () => {
    expect(buildPurgePreferenceError('ADS-B', 'FLT0001')).toBe('Failed to update purge preference for ADS-B flight FLT0001.');
    expect(buildPurgePreferenceError('UAT', 'UAT0001')).toBe('Failed to update purge preference for UAT flight UAT0001.');
  });
});
