# Devices Page — Overview

The Devices page is where you monitor, evaluate, and tune your ADS-B and UAT receivers.
It combines time-series graphs, live system health, and aggregated portal statistics into a single interface built for iterative improvement.

Whether you are setting up a new receiver or fine-tuning one that has been running for months, these documents walk you through everything the Devices page shows and how to act on it.

---

## Documentation Map

Start from the top and work down, or jump to the topic you need.

### Understanding the Interface

| Document | What It Covers |
|----------|---------------|
| [time-controls-and-baseline-compare.md](time-controls-and-baseline-compare.md) | Period slider, visual brush, snap and nudge controls, custom date ranges, resolution selector, baseline compare workflow. |

### Graph and Data References

| Document | What It Covers |
|----------|---------------|
| [dump1090-graphs.md](dump1090-graphs.md) | All ten dump1090 RRD charts and the five ADS-B KPI tiles. Detailed per-graph interpretation with signal-level thresholds and pattern recognition. |
| [dump978-graphs.md](dump978-graphs.md) | All five dump978 RRD charts and the two UAT KPI tiles. UAT-specific waveform characteristics, emitter categories, and what differs from 1090 reception. |
| [system-graphs.md](system-graphs.md) | Seven system health charts — CPU, temperature, memory, network, disk usage, disk IOPS, disk bandwidth. How to separate host issues from radio issues. |
| [portal-stats.md](portal-stats.md) | Portal tab cards — Receiver info, Data Quality and classification, Traffic Volume, System Status. |

### Tuning Guides

| Document | What It Covers |
|----------|---------------|
| [tuning-1090.md](tuning-1090.md) | Step-by-step 1090 MHz tuning workflow: gain sweep, reading the KPIs, before/after comparison, iterating toward optimal reception. |
| [tuning-978.md](tuning-978.md) | Step-by-step 978 MHz tuning workflow: dual-SDR gain management, UAT-specific challenges, message type analysis, altitude-vs-range tradeoffs. |
| [antenna-sdr-and-filtering.md](antenna-sdr-and-filtering.md) | Antenna selection and placement for 1090 and 978, cable types and loss, bandpass filters, SDR dongle selection, dual-SDR configuration, device serial assignment. |
| [troubleshooting.md](troubleshooting.md) | Consolidated troubleshooting for both decoders — symptom-based diagnosis with graph evidence, common failure modes, recovery steps. |

---

## Page Layout — Three Tabs

The Devices page has three tabs. Each can be independently enabled or disabled in **Settings**.

### Receiver Tab

The primary tuning workspace. Contains:

- **Time Window** controls — period slider, visual brush with snap/nudge, From/To date inputs, resolution selector.
- **SDR Tuning Summary** — KPI tiles for ADS-B (five metrics) and UAT (two metrics) with optional baseline comparison deltas.
- **Dump1090 Graphs** — ten RRD-backed charts tracking 1090 MHz receiver performance. Visible when dump1090 graphs are enabled.
- **Dump978 Graphs** — five RRD-backed charts tracking 978 MHz receiver performance. Visible when dump978 graphs are enabled.
- **System Graphs** — seven RRD-backed charts tracking host hardware health.

### System Tab

Snapshot of current hardware state, populated on page load:

| Card | Contents |
|------|----------|
| **CPU** | Usage percentage, core counts, clock frequency, load averages, context switches, interrupts, temperature. |
| **Memory** | Virtual and swap usage with totals. |
| **Disk** | Usage percentage with totals, cumulative I/O counts. |
| **Network** | Byte and packet counters, error and drop rates, IPv4 addresses per interface. |
| **System** | Boot time, logged-in users. |
| **Database** | Database file size on disk. |

### Portal Tab

Aggregated numbers from across the portal — no graphs, just counts and snapshots:

| Section | Cards |
|---------|-------|
| **Receiver** | Decoder version, antenna location, signal level (with peak and noise), average aircraft RSSI. |
| **Data Quality** | OpenSky-classified, heuristic-classified, and unknown aircraft counts. Classification quality percentages. Top aircraft types. OpenSky database status and entry count. |
| **Traffic Volume** | Live aircraft (with ADS-B and UAT breakdown), live message counter, ACARS messages, stored ADS-B/UAT/ACARS flight counts. |
| **System Status** | CPU temperature, database size, receiver uptime, snapshot timestamps. |

---

## Tuning Philosophy

These principles apply to both 1090 and 978 tuning:

- **One change at a time.** Adjust gain, move the antenna, or add a filter — never combine changes. You need to know which variable caused the result.
- **Wait before judging.** Air traffic fluctuates by time of day and day of week. Give each change at least 6 hours, ideally a full 24-hour cycle.
- **Use baseline compare.** The portal's built-in before/after comparison removes guesswork. Set a baseline before changing anything.
- **Optimize for positions, not raw messages.** A receiver that decodes 1000 messages/sec with 10% position yield is worse than one decoding 600 messages/sec with 30% position yield. Positions are what produce map tracks and flight records.
- **Watch for diminishing returns.** After two or three gain iterations with a good antenna and filter, further adjustments usually yield marginal benefit.

---

## Quick Vocabulary

| Term | Meaning |
|------|---------|
| **ADS-B** | Automatic Dependent Surveillance-Broadcast. Aircraft broadcast position, velocity, and identity on 1090 MHz. |
| **UAT** | Universal Access Transceiver. A US-only 978 MHz system used by general aviation below FL180 (18,000 ft). |
| **Mode S** | The underlying surveillance protocol on 1090 MHz. ADS-B is one type of Mode S message. |
| **Message** | A radio packet received and decoded by the SDR. Not all messages contain position data. |
| **Position** | A message containing latitude/longitude that can be plotted on a map. |
| **Track** | A chain of positions linked to the same aircraft ICAO over time. |
| **ICAO** | A six-character hexadecimal aircraft address (e.g., `A1B2C3`). Globally unique per airframe. |
| **dBFS** | Decibels relative to full scale. The SDR's maximum input is 0 dBFS; real signals are negative values. |
| **Gain** | How much the SDR amplifies incoming radio signals before digitizing them. |
| **AGC** | Automatic Gain Control. The SDR adjusts gain on its own. Typically produces worse results than a fixed gain setting. |
| **Strong signal** | A decoded message above -3 dBFS. High percentages suggest gain is too high. |
| **Range** | The maximum distance at which an aircraft was detected in the selected time window. |
| **Baseline** | A saved set of KPI values representing a "before" state, used for comparison after making changes. |
| **KPI** | Key Performance Indicator. A single summary number describing one dimension of receiver health. |
| **RRD** | Round-Robin Database. Fixed-size time-series storage that backs all graphs. |
| **RSSI** | Received Signal Strength Indicator. The power level of a signal from a single aircraft. |
| **MLAT** | Multilateration. Triangulating an aircraft's position using time-of-arrival differences across multiple ground stations. |
| **CPR** | Compact Position Reporting. The encoding format for ADS-B latitude/longitude within Mode S messages. |
| **FIS-B** | Flight Information Service-Broadcast. Weather and airspace data carried on 978 MHz UAT. |
| **TIS-B** | Traffic Information Service-Broadcast. Rebroadcast of radar-derived traffic on 978 MHz for UAT-equipped aircraft. |
| **Emitter Category** | A UAT field (A0 through D7) describing the aircraft type (light, large, rotorcraft, etc.). |
| **OpenSky** | The OpenSky Network aircraft database used to classify ICAO hex codes into aircraft types. |
| **Bandpass Filter** | A hardware filter that passes only a narrow frequency band (e.g., 1090 MHz) and rejects everything else. |
