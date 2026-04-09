# Dump1090 Graphs — ADS-B (1090 MHz)

Ten RRD-backed charts and five KPI summary tiles covering everything dump1090-fa reports about your 1090 MHz ADS-B receiver.
All charts appear on the **Receiver** tab when dump1090 graphs are enabled in Settings.

---

## ADS-B KPI Tiles (SDR Tuning Summary)

The top of the Receiver tab presents five KPI tiles summarizing ADS-B performance for the active time window.
When baseline compare is enabled, each tile also displays a signed delta relative to the saved baseline.

| Tile | How It Is Calculated | What It Tells You | What "Better" Looks Like |
|------|---------------------|-------------------|--------------------------|
| **Messages/sec** | Average of the `messages` dataset from the dump1090 `message-rate` RRD | Throughput — how many Mode S packets per second your SDR decoded. | Higher is generally better, but only when accompanied by a proportional rise in positions. If messages climb while positions stagnate, you are decoding noise rather than useful aircraft data. |
| **Aircraft Seen** | Average of the `total` dataset from the dump1090 `aircraft` RRD | How many distinct aircraft your receiver tracked simultaneously, averaged over the window. | Higher indicates broader coverage. Normal variation between busy daytime and quiet overnight is expected. |
| **Max Range** | Average of the `max_range` dataset from the dump1090 `range` RRD, converted to nautical miles, statute miles, or kilometres depending on Settings | The farthest distance at which an aircraft was detected. | Higher indicates your antenna and gain setup can reach farther. A sudden drop that persists may point to hardware damage, new obstructions, or interference. |
| **Strong Signal Ratio** | `(strong_signals / messages) * 100` from the `message-rate` RRD | The percentage of decoded messages that arrived above -3 dBFS — close to the SDR's maximum input level. | A moderate ratio of 5-15% is typical. Values above 30% often indicate the gain is too high, causing nearby aircraft to saturate the analog-to-digital converter and potentially masking weaker, more distant signals. Values near zero suggest the gain may be too low. |
| **Positions per Message** | `(positions / messages) * 100` from the `message-rate` RRD | What fraction of all decoded messages actually contain usable latitude and longitude. | This is the single most important indicator of decode quality. A higher ratio means more of the radio energy your SDR captures is turning into map-plottable positions. If this ratio drops while message rate stays steady, something is degrading decode quality — overload, interference, or a timing problem. |

---

## Message Rate

- **RRD metric**: `message-rate`
- **Datasets**: `messages`, `positions`, `strong_signals`
- **Y-axis**: Messages per second
- **Baseline overlay**: Yes — the chart renders a second series from the saved baseline window when Compare is enabled.

This is the primary throughput chart. It shows three things at once: total decoded Mode S packets, the subset that produced position fixes, and the count above the strong-signal threshold.

**Reading the chart**:

- A clean day/night cycle — traffic rises after dawn, peaks in the afternoon, and tapers after midnight — indicates a healthy, stable receiver.
- The gap between `messages` and `positions` represents messages that were decoded but did not yield coordinates. Some gap is always expected because not every Mode S frame carries position data. Altitude replies, identity squawks, and air-to-air coordination all generate messages without positions.
- If `messages` climbs sharply but `positions` does not follow, suspect overload (gain too high), interference, or an antenna problem that allows partial decodes without clean phase recovery.
- Flat lines at zero mean dump1090-fa is not running, the SDR is not connected, or the antenna feed is broken.

---

## Aircraft Seen / Tracked

- **RRD metric**: `aircraft`
- **Datasets**: `total`, `positions` (aircraft currently providing position data), `mlat` (aircraft located via multilateration)
- **Y-axis**: Aircraft count

Each point shows how many unique ICAO hex addresses your receiver was tracking at that moment.

**Reading the chart**:

- A predictable pattern of daytime highs and overnight lows reflects normal air traffic rhythm.
- The difference between `total` and `positions` represents aircraft that your receiver can hear but cannot position — typically aircraft at the fringe of your range that register only a few Mode S messages without enough CPR data for a fix.
- The `mlat` count shows aircraft positioned through multilateration rather than self-reported ADS-B. If you feed data to networks like FlightAware that provide MLAT results, this line shows how much of your traffic relies on that cooperative technique.
- A sudden drop to zero suggests a decoder restart, USB disconnect, or system reboot. Check the timestamps of any gap.

---

## Tracks Seen

- **RRD metric**: `tracks`
- **Datasets**: `all`, `single_message`
- **Y-axis**: Tracks per hour (the raw per-second value is multiplied by 3600 for display)

A "track" starts when dump1090 first hears a new ICAO hex and ends when that hex goes silent for a timeout period. `single_message` counts aircraft heard exactly once before timing out.

**Reading the chart**:

- Single-message tracks are often phantom decodes — bit errors that happen to look like valid frames — or aircraft so far away that only one message arrived before the aircraft passed out of range.
- A large proportion of single-message tracks relative to total tracks can indicate that gain is set too high and the receiver is producing spurious decodes. Reduce gain and check whether single-message tracks drop without sacrificing real traffic.
- Stable track counts that scale proportionally with aircraft counts indicate normal, healthy operation.

---

## Range (Max Distance)

- **RRD metric**: `range`
- **Datasets**: `max_range`
- **Y-axis**: Nautical miles, statute miles, or kilometres (configurable in Settings)

Each data point records the greatest distance at which any aircraft was seen during that sample interval. This is a maximum, not an average.

**Reading the chart**:

- A consistent ceiling that holds steady day after day reflects the physical limits of your antenna height and terrain. This is expected.
- A gradual decline over weeks may indicate connector corrosion, moisture in a coax junction, or slow degradation of an outdoor antenna element.
- A sudden one-time drop suggests a physical event — a connector came loose, a cable was damaged, or a new structure appeared in the signal path.
- Practical range for a well-placed 1090 MHz antenna with line-of-sight horizon ranges from 150 to 250+ nautical miles. If your range ceiling is well below this, investigate antenna height, cable loss, gain settings, and local obstructions.

---

## Signal Level

- **RRD metric**: `signal`
- **Datasets**: `signal`, `noise`, `peak_signal` (exact dataset names may vary by dump1090 build)
- **Y-axis**: dBFS (decibels relative to full scale)
- **Baseline overlay**: Yes

This chart shows the power level of received messages as measured by the SDR's analog-to-digital converter. All values are negative; 0 dBFS is the absolute maximum the converter can represent, meaning a signal at 0 dBFS is clipping.

**Reading the chart**:

- Average signal between -15 and -3 dBFS is typical for a well-tuned receiver. Most signals arrive in this band from aircraft within 50-100 nm.
- If the peak signal regularly touches 0 dBFS, the SDR is clipping on close-in or high-power aircraft. This distorts not just those messages but can bleed into adjacent samples, corrupting weaker signals. Reduce gain.
- Average signal below -25 dBFS suggests the gain is too low or there is excessive cable loss between the antenna and the SDR.
- The noise floor ideally stays below -35 dBFS. If noise is above -30 dBFS, local RF interference may be raising the floor. A 1090 MHz bandpass filter can help.
- If a gain increase causes both signal and noise to rise by similar amounts, the SDR is amplifying broadband noise along with the signal. This means no net improvement in signal-to-noise ratio, and a different gain step or a filter is needed.

---

## Positions Decoded

- **RRD metric**: `positions`
- **Datasets**: `cpr_global`, `cpr_local`, `cpr_filtered`
- **Y-axis**: Positions per hour (the raw per-second rate is multiplied by 3600 for display)

ADS-B position reports use Compact Position Reporting (CPR) encoding. Two methods decode them:

- **CPR Global** requires two messages (one odd, one even frame) to compute a unique position. It works at any range and is the most common decode path.
- **CPR Local** uses a single message combined with the receiver's known location to compute position. It only works reliably when the aircraft is relatively close (within about 180 nm of the receiver).
- **CPR Filtered** counts positions that were computed but then rejected by dump1090's sanity checks — speed-limit violations, unreasonable jumps, or positions too far from the receiver.

**Reading the chart**:

- `cpr_global` being larger than `cpr_local` is normal and expected — most aircraft generate enough messages for two-frame decode.
- A high `cpr_filtered` rate means positions are being thrown away as implausible. Common causes: the receiver latitude/longitude is misconfigured in dump1090-fa, the system clock is significantly wrong, or there is multipath interference causing position computation errors.
- If you notice a high filtered-to-decoded ratio, verify your receiver location: open the Portal tab and check the Receiver Location card, then compare with your actual antenna coordinates.

---

## Strong Signals (>-3 dBFS)

- **RRD metric**: `strong-signals`
- **Datasets**: `strong` (count of messages above -3 dBFS), `total` (total messages)
- **Display**: Computed as a percentage — `(strong / total) * 100`
- **Y-axis**: Percent of messages

This chart isolates the overload question: what fraction of received messages are arriving at or near the SDR's maximum input capacity?

**Reading the chart**:

- 5-15% is a comfortable operating range for most locations. Some nearby aircraft will always produce strong signals, and that is expected.
- Above 30%, the receiver is likely experiencing ADC saturation on a significant number of messages. The strong signals from close-in aircraft compress the dynamic range available for weaker distant aircraft, reducing effective sensitivity. Step gain down.
- Below 1%, the gain may be too conservative. Local aircraft are arriving weak, and distant aircraft are probably below the decode threshold entirely. Step gain up cautiously.
- Look for correlation with aircraft counts: if strong signal percentage rises while total aircraft stays flat or drops, you have gained nothing useful from the additional signal strength.

---

## Message Types (DF Types)

- **RRD metric**: `df-types`
- **Datasets**: `df17` (ADS-B extended squitter), `df18` (extended squitter from non-transponder sources), `df11` (all-call reply), `df4` (altitude reply), `df5` (identity reply), `df20` (altitude with BDS data), `df21` (identity with BDS data), `total`
- **Y-axis**: Messages per second

Each Mode S message carries a Downlink Format code identifying its purpose. This chart breaks them down.

**Reading the chart**:

- **DF17** is the ADS-B workhorse — these messages carry position, velocity, identification, and other extended squitter content. In a healthy ADS-B environment, DF17 should be the most prominent format.
- **DF18** carries ADS-B from non-transponder sources. TIS-B rebroadcasts appear as DF18.
- **DF11** is the Mode S all-call reply — aircraft respond to interrogation from SSR or TCAS. High DF11 rates relative to DF17 mean you are near a radar interrogator. This is not a tuning issue, just a characteristic of your location.
- **DF4/5/20/21** are surveillance replies triggered by radar interrogation. They provide altitude and identity information but not ADS-B positions.
- If non-DF17 messages vastly outnumber DF17, it generally means the local environment is dominated by radar returns rather than ADS-B broadcasts. This is common near airports with traditional surveillance radar and does not indicate a receiver problem.

---

## dump1090 CPU Utilization

- **RRD metric**: `cpu`
- **Datasets**: `demod` (demodulation), `reader` (USB data reader), `background` (housekeeping)
- **Y-axis**: CPU percentage (the raw value stored in the RRD is in permille and divided by 10 for display)

This chart shows how much processing time dump1090-fa itself consumes, separated by task.

**Reading the chart**:

- The `demod` component does the heavy lifting — correlating incoming samples against known preamble patterns and extracting frames. On constrained hardware such as a Raspberry Pi Zero, sustained demod usage above 60% may indicate the CPU cannot keep up with the incoming sample rate.
- `reader` handles the USB data transfer from the SDR dongle. It should be minimal unless there are USB contention issues.
- `background` covers internal housekeeping tasks like expiring stale tracks.
- If dump1090 CPU is consistently low but the system CPU chart (in System Graphs) is high, other processes — feeders, web server, database writes — are competing for the same cores.
- On multi-core hardware (Pi 4 and above), dump1090-fa processing is typically not a bottleneck. If it becomes one, consider the `--max-range` flag to limit decode distance and reduce the number of messages that reach the demodulation stage.
