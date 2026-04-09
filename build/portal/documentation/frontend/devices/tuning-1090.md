# Tuning dump1090-fa (1090 MHz ADS-B)

A systematic approach to optimising your 1090 MHz receiver by adjusting gain, observing the portal graphs, and iterating until message quality and range stabilise.

---

## Prerequisites

Before tuning the radio, confirm these conditions are met:

1. **Antenna is installed and connected.** A loose connector or damaged cable will mask all gain adjustments.
2. **dump1090-fa is running and producing data.** Verify with `sudo systemctl status dump1090-fa`.
3. **The portal's Receiver tab shows graphs updating.** If graphs are empty, data collection may not be running.
4. **Time range is set to Hourly or Six Hours.** Short windows give you the fastest feedback on each change.

---

## How the Gain Parameter Works

dump1090-fa configures the RTL-SDR's internal low-noise amplifier (LNA) through a discrete set of gain steps. The hardware does not support arbitrary gain values — it snaps to the nearest supported step.

The gain value in dump1090-fa is specified in tenths of a dB and passed to the SDR driver. Common RTL-SDR v3 gain steps (in dB) are:

```
0.0  0.9  1.4  2.7  3.7  7.7  8.7  12.5  14.4  15.7
16.6  19.7  20.7  22.9  25.4  28.0  29.7  32.8  33.8
36.4  37.2  38.6  40.2  42.1  43.4  43.9  44.5  48.0  49.6
```

Setting `--gain -10` enables automatic gain control (AGC), which lets the SDR hardware select the level dynamically. AGC is a reasonable starting point but typically underperforms a manually tuned fixed gain for ADS-B reception.

---

## Configuration File

The primary configuration file for dump1090-fa on Debian-based systems is:

```
/etc/default/dump1090-fa
```

Key parameters:

| Parameter | Purpose |
|-----------|---------|
| `RECEIVER_OPTIONS` | Flags passed to the decoder, including `--gain`, `--device-index`, `--ppm` |
| `DECODER_OPTIONS` | Decoder-specific flags (error correction, DF types) |
| `NET_OPTIONS` | Network ports and output modes |

To change gain, edit `RECEIVER_OPTIONS` in this file and restart the service:

```bash
sudo nano /etc/default/dump1090-fa
# Change: RECEIVER_OPTIONS="--gain 49.6 --device-index 0"
# To:     RECEIVER_OPTIONS="--gain 42.1 --device-index 0"
sudo systemctl restart dump1090-fa
```

After restarting, wait 5-10 minutes for the graphs to accumulate data at the new gain level before drawing conclusions.

---

## The Gain Sweep Method

The most reliable way to find optimal gain is a structured sweep from the highest gain step downward.

### Step 1: Start at Maximum Gain

Set `--gain 49.6` (the highest fixed step on most RTL-SDR v3 dongles). Restart dump1090-fa. This over-amplifies the signal intentionally — the goal is to establish a "too loud" baseline.

### Step 2: Record the Key Metrics

After 10-15 minutes at this gain, note these values from the portal:

| Metric | Where to find it |
|--------|-----------------|
| Message rate | ADS-B KPI tiles or Message Rate graph |
| Aircraft count | ADS-B KPI tiles or Aircraft graph |
| Signal level | Signal graph (mean line) |
| Strong-signal percentage | ADS-B KPI tiles or Strong Signals graph |
| Maximum range | Range graph |

### Step 3: Reduce Gain by One Step

Lower the gain to the next step down (e.g., from 49.6 to 48.0). Restart, wait 10-15 minutes, and record the same metrics.

### Step 4: Continue Downward

Repeat the reduction through several more steps. At each step, record all five metrics.

### Step 5: Identify the Sweet Spot

As you reduce gain from maximum:

- **Message rate** will initially **increase** (because reducing over-amplification eliminates clipping and recovers messages that were being corrupted). At some point it peaks and then begins to fall as the signal becomes too weak to decode.
- **Aircraft count** follows a similar curve but with less noise.
- **Strong-signal percentage** should decrease steadily. A healthy target is below 5%.
- **Signal level** falls proportionally with gain.
- **Maximum range** peaks near the same gain step where message rate peaks.

The optimal gain is typically where message rate is highest and strong-signal percentage is below 5%. For many installations, this falls between 28 and 42 dB, though urban sites with nearby airports may need lower gain and rural hilltop sites may benefit from higher gain.

---

## Using Portal Graphs to Evaluate Changes

### Message Rate Graph

The most direct indicator of decode success. A higher sustained message rate at a given time of day, compared to the same time on a previous day, indicates an improvement.

Use the baseline compare feature:
1. Set the time range to Daily.
2. Record a full day at your current gain.
3. Set the baseline from the current KPIs.
4. Change gain and let another day pass.
5. Compare the new KPIs against the baseline.

### Signal Level Graph

The mean signal line should sit between roughly -3 dBFS and -15 dBFS for a well-tuned receiver.

- Above -1 dBFS: ADC clipping is likely. Red-flag territory — reduce gain immediately.
- The noise floor line should be well separated from the signal line. A gap below 10 dB between mean signal and noise may indicate interference or an overly broad gain setting.

### Strong Signals Graph

This graph shows what fraction of messages arrive with signal strength above a threshold that risks ADC saturation. The relationship between strong-signal percentage and gain is nearly linear: higher gain → more strong signals.

- Above 10%: Gain is almost certainly too high unless you are extremely far from all transmitting aircraft.
- 1-5%: Healthy range for most suburban and exurban installations.
- Below 1%: Gain could potentially be increased slightly without penalty.

### Range Graph

Maximum range reflects how far the receiver can decode aircraft positions. It depends on antenna height, terrain, gain, and atmospheric conditions.

Range is affected by gain, but less predictably than message rate. An overdriven amplifier can reduce effective range by drowning out weak distant signals in amplifier noise. Conversely, too little gain means distant signals fall below the decode threshold.

### Positions Graph

The ratio of CPR (Compact Position Reporting) global and local decodes indicates how effectively the receiver is assembling position reports. The filtered fraction shows messages that failed sanity checks and were discarded.

If filtered positions increase as you raise gain, the receiver is amplifying noise to the point where CPR calculations produce impossible positions.

---

## Timing Your Evaluation

Air traffic follows predictable daily patterns:

- **Peak hours** (midday, early evening): Maximum aircraft count and message rate.
- **Off-peak** (late night, early morning): Minimal traffic.

Compare like with like: evaluate gain changes across the same hours of the day to avoid confusing traffic variation with reception improvement.

The Hourly and Six Hour time periods are best for quick iteration. Once you have converged on a gain setting, let it run for a full 24 hours and review Daily graphs to confirm the choice holds across the full traffic cycle.

---

## Common Pitfalls

### Adjusting Multiple Variables at Once

Change gain and only gain between measurements. If you simultaneously move the antenna, change cables, add a filter, and adjust gain, you cannot attribute any change in the graphs to a specific cause.

### Using AGC as a Permanent Setting

Automatic gain control reacts to instantaneous signal conditions, which sounds ideal but produces erratic decode behaviour for ADS-B. Because ADS-B messages arrive in short bursts from many sources at varying distances, the AGC constantly hunts and can overshoot in both directions. A fixed gain tuned through the sweep process nearly always outperforms AGC.

### Ignoring Temperature Effects

SDR dongles generate heat, and their performance drifts with temperature. If you tune gain during a cool morning and do not check again during a hot afternoon, you may be running sub-optimally during peak traffic hours. Review charts across the full daily temperature cycle.

### Over-Relying on Aircraft Count

Aircraft count reflects how many unique ICAO addresses are being tracked. It can plateau even as message rate continues to rise because the receiver is decoding more messages per aircraft rather than seeing new aircraft. Use message rate as the primary metric and aircraft count as a secondary confirmation.

---

## Quick-Reference Checklist

1. Start at `--gain 49.6`. Record metrics after 10 minutes.
2. Step down one gain level at a time. Record metrics at each step.
3. Target: highest message rate with strong-signal percentage below 5%.
4. Verify signal level is between -3 and -15 dBFS.
5. Confirm with a full 24-hour run at the chosen gain.
6. Re-evaluate if you change antenna, cable, or add/remove a filter.
