# Time Controls and Baseline Compare

All time controls and the baseline compare feature live in the top card of the **Receiver** tab.
They control which time window is displayed in every graph below, and provide the mechanism for rigorous before/after comparisons.

---

## Time Window Controls

### Period Slider

A horizontal slider selects one of six preset time windows:

| Label | Value | Duration |
|-------|-------|----------|
| Hourly | `1h` | 1 hour |
| Six Hours | `6h` | 6 hours |
| Daily | `24h` | 24 hours |
| Two Days | `2d` | 48 hours |
| Weekly | `7d` | 7 days |
| Monthly | `30d` | 30 days |

Use the **-** and **+** buttons on either side to step one position at a time.

Changing the period resets the brush to 100% (full window), clears any custom range, and refreshes the KPI summary.

**When to use each period**:
- **1h** — Live monitoring during an active change. See the effect of a gain adjustment within minutes.
- **6h** — Quick check on a morning or afternoon session.
- **24h** — The default. Captures a full day/night traffic cycle. Best for general assessment.
- **2d** — Ideal for before/after comparison: one day before the change, one day after.
- **7d** — Spot weekly trends, correlate with weather patterns, or verify stability after a change.
- **30d** — Long-term trending. Useful for detecting gradual degradation.

### Visual Brush

Below the period slider, a horizontal brush lets you select a sub-range within the active period.

- **Two handles** (left = start, right = end) define the visible slice.
- **Labels** below the brush show the start and end date/time of your selection.
- The blue highlight between the handles shows the active portion.

The brush does **not** change the graphs directly — it updates the From/To fields. Click **Apply Range** to send the brush selection to the graphs.

### Snap Increment

Three buttons control the snap granularity for the brush handles:

| Button | Meaning |
|--------|---------|
| **1m** | Handles snap to the nearest 1-minute boundary. |
| **5m** | Handles snap to the nearest 5-minute boundary. Default. |
| **15m** | Handles snap to the nearest 15-minute boundary. |

Use finer snaps (1m) when zooming into a specific event. Use coarser snaps (15m) for broad comparisons.

### Fine Adjust (Nudge) Buttons

Four buttons move individual handles by one snap increment:

| Button | Action |
|--------|--------|
| **Start -** | Move the start handle earlier by one snap step. |
| **Start +** | Move the start handle later by one snap step. |
| **End -** | Move the end handle earlier by one snap step. |
| **End +** | Move the end handle later by one snap step. |

Useful for precise alignment when the brush handles are too close together to drag accurately.

### From / To Inputs

Two `datetime-local` fields show the exact start and end of the active window.
You can type or pick values directly, then click **Apply Range** to query graphs for that exact window.

The From/To fields are updated when:
- The period slider changes (reset to full window).
- The brush handles move (snap-aligned values fill in automatically).
- You type a custom value (overrides everything).

### Apply Range Button

Sends the current From/To values to all graphs.
Until you click this button, brush and direct edits to From/To are "pending" — the graphs still show the last applied window.

This intentional separation lets you fine-tune the window without triggering repeated re-renders.

### Active Window Summary

A text line below the controls shows the currently active window in plain English:
- For preset periods: `Daily (24h)`
- For custom ranges: `Jun 15, 2025, 08:00 to Jun 15, 2025, 20:00`

---

## Resolution Selector

A dropdown next to the time window controls that determines how many data points each graph displays.

| Option | Max Points | Step Size (auto-calculated) | Best For |
|--------|-----------|----------------------------|----------|
| **Auto** | Adapts to period: 480 (≤6h), 300 (≤48h), 220 (≤7d), 160 (>7d) | Varies | Default choice. Balances detail and performance. |
| **Fine detail** | 480 | ~60 sec for 1h, ~300 sec for 24h | Zoomed-in analysis of specific events. |
| **Balanced** | 240 | ~150 sec for 1h, ~600 sec for 24h | General use on slower hardware. |
| **Compact** | 120 | ~300 sec for 1h, ~1200 sec for 24h | Overview on narrow screens or very slow connections. |

Higher point counts give more detail but increase RRD query time and rendering load.
On a Raspberry Pi, **Auto** or **Balanced** is recommended for daily use.

---

## Baseline Compare

Baseline compare lets you save a "before" snapshot and overlay it on the current data to evaluate whether a change helped.

### Setting a Baseline

1. Configure the time window to cover your "before" period (e.g., set period to 24h or use the brush to isolate a specific range).
2. Wait for the SDR Tuning Summary to finish loading.
3. Click **Set Baseline**.

This saves:
- The five ADS-B KPI values (Messages/sec, Aircraft Seen, Max Range, Strong Signal Ratio, Positions per Message).
- The two UAT KPI values (Messages/sec, Aircraft Seen).
- The start and end epoch of the window so overlay graphs know where to fetch comparison data.

The baseline label (e.g., "Daily (24h)" or a specific date range) appears above the KPI tiles.

### Enabling Comparison

Toggle the **Compare to baseline** switch.
When enabled:
- Each KPI tile shows a delta value (e.g., `+2.3` or `-1.1`).
- The **Message Rate** and **Signal Level** graphs (both dump1090 and dump978) render the baseline period as a second data series labeled "Baseline."

### Reading Deltas

| Delta | Meaning |
|-------|---------|
| Positive (+) | Current value is higher than baseline. |
| Negative (-) | Current value is lower than baseline. |
| No delta shown | Compare is disabled, or the baseline value for that KPI is null. |

**Important**: A positive delta is not always "better." For Strong Signal Ratio, an increase may indicate overload. Always evaluate deltas in context with all five KPIs.

### Clearing the Baseline

Click **Clear** to remove the saved baseline.
This disables the compare toggle and removes all delta displays and overlay series.

### Workflow for Before/After Gain Change

1. At your current gain, set the period to **24h** and click **Set Baseline**.
2. Change the gain in `/etc/default/dump1090-fa` and restart dump1090-fa.
3. Wait 24 hours.
4. Return to the Devices page. The SDR Tuning Summary now shows current (post-change) values.
5. Enable **Compare to baseline**.
6. Evaluate all deltas:
   - Messages/sec up, Positions per Message up → good.
   - Strong Signal Ratio down (from a high value) → good (less overload).
   - Range stable or improved → good.
7. If the change was beneficial, click **Set Baseline** again to update your reference point for the next change.

### Tips

- **Match time-of-day**: When comparing, try to compare the same hours. Morning traffic differs from midnight traffic. Use the brush to isolate matching windows.
- **Wait long enough**: A 1-hour window can be misleading due to normal traffic variation. 6-24 hours gives a more reliable picture.
- **One baseline at a time**: The system stores only one baseline. Setting a new one replaces the old one.
- **Baseline survives tab switches**: Navigating to the System or Portal tab and back does not clear the baseline. It persists for the duration of the page session.
- **Baseline does not survive page reload**: If you refresh the browser, the baseline is lost. Note down the KPI values if you need them across sessions.
