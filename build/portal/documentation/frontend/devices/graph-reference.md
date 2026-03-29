# Devices Graph Reference

This guide explains each graph in plain language: what it means, what “good” usually looks like, and what to try if results look poor.

## Read This First

Do not make decisions from one graph alone. Use at least two signals together.

Good example:

- Messages go up
- Positions per message also goes up

Risky example:

- Messages go up
- Positions per message goes down

The second case often means “more noise, not more useful data.”

## SDR Tuning Summary Card

The summary card gives quick before/after numbers for your selected time window.

### ADS-B (1090)

- Messages/sec: How busy your receiver is.
- Aircraft Seen: How many different aircraft you are decoding.
- Max Range: Farthest aircraft distance seen.
- Strong Signal Ratio: How many messages are very strong.
- Positions per Message: How many messages are actually useful for location.

Most important quality metric: Positions per Message.

### UAT (978)

- Messages/sec: UAT message activity.
- Aircraft Seen: Number of UAT aircraft decoded.

## ADS-B Graphs (dump1090)

### Message Rate

Shows:

- messages
- strong_signals
- positions

How to use it:

- If messages and positions rise together, that is usually good.
- If strong signals spike but positions do not improve, reduce gain or improve filtering.

### Aircraft Seen / Tracked

Shows:

- total
- positions
- mlat

How to use it:

- You usually want total and positions to rise together.
- If total rises but positions stay flat, quality may be weak.

### Tracks Seen

Shows:

- all
- single_message

How to use it:

- Lower single-message dominance is usually healthier.

### Max Range

Shows the farthest aircraft seen in the window.

How to use it:

- Treat range as supporting evidence.
- Do not keep a change based on one big range spike.

### Signal Level

Shows:

- signal
- peak_signal
- min_signal
- noise

How to use it:

- Rising noise without quality gains usually means tuning is too aggressive.

### Positions Decoded

Shows usable position output directly.

How to use it:

- This is one of the best practical success measures.

### Strong Signals

Shows strong signal percentage.

How to use it:

- Higher is not always better.
- Very high values can mean overload from nearby strong sources.

### Message Types

Shows DF message mix (df17, df18, df11, df4, df5, df20, df21, total).

How to use it:

- Use for pattern changes, not as your primary tuning metric.

### dump1090 CPU Utilization

Shows demod/reader/background usage.

How to use it:

- If CPU is near limits, receiver quality can fall even with good RF conditions.

## UAT Graphs (dump978)

### Message Rate

Core UAT activity indicator.

### Aircraft Seen / Tracked

Shows total, positions, and callsign-related activity.

### Signal Strength

Use to watch stability while changing gain/filter settings.

### Max Range

Supporting metric only; always pair with positions/aircraft trends.

### Avg Altitude

Traffic context metric. Different traffic altitude patterns can change graph behavior.

## System Graphs (Receiver Tab)

These tell you if the host computer is limiting performance.

- CPU: Detect saturation.
- Temperature: Detect overheating.
- Memory: Detect pressure/swapping risk.
- Network: Detect transport bottlenecks.
- Disk usage and I/O: Detect storage pressure.

If host health is poor, fix host issues before concluding RF tuning failed.

## System Tab Cards

The System tab is a quick health snapshot (CPU, memory, disk, network, host status).

Use it before and after tuning sessions to confirm the machine itself stayed stable.
