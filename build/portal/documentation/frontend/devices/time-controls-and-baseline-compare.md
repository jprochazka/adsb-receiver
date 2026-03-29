# Time Controls and Baseline Compare

This page explains the time tools in simple terms so you can compare tuning changes fairly.

## Why Time Controls Matter

If you compare different traffic periods, results can be misleading. For example, daytime traffic is often higher than overnight traffic. Time controls help you compare like-for-like windows.

## Time Window Controls

### Period Slider

Choose the main window size:

- 1 hour
- 6 hours
- 1 day
- 2 days
- 7 days
- 30 days

Use short windows for quick tests. Use longer windows to check stability.

### Visual Brush

The brush is the two-handle range bar.

- Drag the left handle to set where analysis starts.
- Drag the right handle to set where analysis ends.
- Labels show the exact start and end times.

### Snap

Snap options are 1 minute, 5 minutes, and 15 minutes.

- 1 minute: fine control
- 5 minutes: good default
- 15 minutes: smoother, less noisy comparisons

### Fine Adjust Buttons

Buttons move each edge in small steps:

- Start - / Start +
- End - / End +

Use these when dragging is close but not exact.

### From/To Inputs

Use From and To when you need exact timestamps.

Select the times, then click Apply Range.

## Resolution

Resolution controls how many data points appear in each chart.

- Auto: system chooses for you
- Fine detail: most detail, best for short windows
- Balanced: recommended default
- Compact: fewer points, best for long windows

## Baseline Compare (Before/After)

Use baseline compare any time you make a tuning change.

1. Pick a stable “before” time window.
2. Click Set Baseline.
3. Make one change (gain, filter, antenna, cable, placement).
4. Turn on Compare to baseline.
5. Review KPI deltas and chart overlays.

Legend:

- Solid line: current window
- Dashed line: baseline window

## What Good Compare Results Look Like

- Positions per message goes up
- Aircraft count stays stable or improves
- Message rate rises together with useful decode quality

## Warning Signs

- Message rate rises but positions per message falls
- Strong signal ratio jumps with little quality improvement
- CPU or temperature climbs during the same test window

## Best Practices

- Make one change at a time.
- Keep notes for each test.
- Re-test both ADS-B and UAT.
- Trust repeated improvements, not one short spike.
