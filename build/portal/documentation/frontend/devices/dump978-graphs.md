# Dump978 Graphs — UAT (978 MHz)

Five RRD-backed charts and two KPI summary tiles covering dump978-fa's view of 978 MHz Universal Access Transceiver traffic.
All charts appear on the **Receiver** tab when dump978 graphs are enabled in Settings.

UAT reception differs from 1090 MHz ADS-B in several important ways.
Understanding those differences helps you interpret the data correctly and avoid applying 1090-centric assumptions.

---

## How UAT Differs from ADS-B on 1090

| Dimension | 1090 MHz ADS-B | 978 MHz UAT |
|-----------|----------------|-------------|
| **Geography** | Worldwide | United States only |
| **Altitude ceiling** | Used at all flight levels | Primarily below FL180 (18,000 ft pressure altitude). Aircraft operating above FL180 must use 1090. |
| **Typical traffic** | Airliners, business jets, military, GA | Light general aviation, helicopters, balloons, some drones |
| **Transmit power** | Mode S transponders typically 125-500 W | UAT transmitters often 20-50 W for portable devices, up to 125 W for panel-mount |
| **Message structure** | Mode S with 56 or 112-bit frames at fixed intervals | 276-microsecond burst at irregular intervals, containing ADS-B payload plus optional FIS-B/TIS-B |
| **Antenna wavelength** | ~27.5 cm (quarter-wave ~6.9 cm) | ~30.7 cm (quarter-wave ~7.7 cm) |
| **Typical range** | 150-250+ nm with a well-placed antenna | 50-150 nm — lower because of lower transmit power and lower-flying aircraft |
| **Traffic density** | Consistent, high volume near any airport | Episodic and seasonal — GA traffic is strongly influenced by weather and daylight |

These characteristics mean that lower message rates, fewer aircraft, shorter range, and more variable traffic patterns are all **normal** for a UAT receiver. Do not judge your 978 setup by 1090 standards.

---

## UAT Emitter Categories

dump978-fa decodes an emitter-category field from each UAT message. The portal uses this alongside OpenSky database lookups and heuristic rules to classify aircraft. The raw categories are:

| Code | Description |
|------|-------------|
| A0 | No category information |
| A1 | Light aircraft (less than 15,500 lb MTOW) |
| A2 | Small aircraft (15,500 to 75,000 lb) |
| A3 | Large aircraft (75,000 to 300,000 lb) |
| A4 | High-vortex large (e.g., B757) |
| A5 | Heavy aircraft (greater than 300,000 lb) |
| A6 | High-performance/high-speed (e.g., supersonic) |
| A7 | Rotorcraft |
| B1 | Glider or sailplane |
| B2 | Lighter-than-air (balloon, airship) |
| B3 | Parachutist or skydiver |
| B4 | Ultralight, hang glider, paraglider |
| B5 | Reserved |
| B6 | Unmanned aerial vehicle (UAV/drone) |
| B7 | Space or transatmospheric vehicle |
| C1 | Surface vehicle — emergency |
| C2 | Surface vehicle — service |
| C3 | Point obstacle (fixed, lighted) |
| C4-C7 | Various cluster and line obstacles |
| D0-D7 | Reserved |

The emitter category is displayed on UAT flight detail pages and stored in the database with each flight record.

---

## UAT Message Types

dump978-fa tags each decoded message with a type label. The three primary types you will see:

| Type | Meaning |
|------|---------|
| **adsb_icao** | Standard ADS-B message from a UAT-equipped aircraft broadcasting its own ICAO address and position. This is the UAT equivalent of a 1090 DF17 message. |
| **tisb_icao** / **tisb_other** | Traffic Information Service-Broadcast. A ground station rebroadcasts radar-derived positions of aircraft that are not UAT-equipped, so that UAT-only cockpit displays can see surrounding traffic. Receiving TIS-B means you are within range of an FAA ground station and your antenna is performing adequately. |
| **adsb_other** | ADS-B from a non-ICAO source, such as an anonymous or temporary address. Commonly used by some GA aircraft for privacy. |

The presence of TIS-B messages in your data is a positive indicator — it means your receiver is picking up ground-station broadcasts, which validates antenna performance on 978 MHz.

---

## UAT KPI Tiles (SDR Tuning Summary)

Two UAT KPI tiles sit in the UAT column of the SDR Tuning Summary card. They operate identically to the ADS-B tiles: showing averages over the active time window with optional baseline deltas.

| Tile | How It Is Calculated | What It Tells You | What "Better" Looks Like |
|------|---------------------|-------------------|--------------------------|
| **Messages/sec** | Average of the `messages` dataset from the dump978 `messages` RRD | How many UAT packets per second the decoder processed. | Higher, but expect much lower numbers than 1090. A rural site with little GA traffic might see single-digit messages per second during business hours and near zero overnight. An airfield with active flight training might produce 20-50/sec in good weather. |
| **Aircraft Seen** | Average of the `total` dataset from the dump978 `aircraft` RRD | Average number of UAT-equipped aircraft tracked simultaneously. | Higher, but again expect lower counts than ADS-B. Seasonal and weather-dependent variation is pronounced — GA traffic drops sharply in winter and in instrument meteorological conditions. |

---

## Message Rate

- **RRD metric**: `messages`
- **Datasets**: `messages`
- **Y-axis**: Messages per second
- **Baseline overlay**: Yes

Total UAT messages processed by dump978-fa during each sample interval.

**Reading the chart**:

- UAT traffic follows general-aviation patterns much more than airline schedules. Expect peaks during VFR (visual flight rules) weather on weekend mornings and near zero during overnight hours or bad weather.
- A complete absence of messages while 1090 traffic is healthy usually means the 978 SDR is not connected, dump978-fa is not running, or the antenna and SDR are not tuned/configured for 978 MHz.
- Gradual upward trends over months may reflect increased UAT equipage as the ADS-B mandate matures and more aircraft add UAT transmitters.
- Unlike 1090 where you see a clear daily cycle in most locations, 978 may have multi-day gaps in rural areas where no GA traffic is flying. This is normal and not an indication of a receiver problem.

---

## Aircraft Seen / Tracked

- **RRD metric**: `aircraft`
- **Datasets**: `total` (all tracked aircraft), `positions` (aircraft providing position data), `with_callsign` (aircraft broadcasting a callsign)
- **Y-axis**: Aircraft count

How many unique UAT-equipped aircraft your receiver is tracking at each sample point.

**Reading the chart**:

- The aircraft count fluctuates more than 1090 because GA traffic is less predictable. Weekday counts may be higher near flight schools; weekend counts higher near recreational airfields.
- The gap between `total` and `positions` represents aircraft heard but not positioned. Because UAT position messages are included in most ADS-B frames, a large gap here may indicate signal quality issues — the message was partially decoded but not enough of the position payload survived.
- `with_callsign` shows how many aircraft are broadcasting a flight identifier. Some GA operators do not set a callsign, so this being lower than `total` is expected.
- If this chart shows zero while the Message Rate chart shows activity, dump978-fa is receiving messages but not associating them with aircraft — possibly because the messages are FIS-B or TIS-B products rather than direct aircraft broadcasts.

---

## Signal Strength

- **RRD metric**: `signal`
- **Datasets**: `signal`
- **Y-axis**: dBFS
- **Baseline overlay**: Yes

The signal power level of received UAT messages as digitized by the SDR.

**Reading the chart**:

- UAT signals tend to be weaker than 1090 signals because: GA transmitters use lower power, aircraft fly lower (shorter line-of-sight for a ground antenna), and portable UAT transmitters in some aircraft have modest output.
- Average signal levels between -20 and -5 dBFS are reasonable for a UAT receiver. Expect wider scatter than 1090 — a nearby Cessna on takeoff might register -3 dBFS while a distant aircraft at low altitude might barely break -30 dBFS.
- If you see no signal data at all, verify that the SDR assigned to dump978-fa is tuned to 978 MHz and that the correct device serial or index is configured.
- Compare this chart against your 1090 signal chart: if both show elevated noise floors, the problem is likely broadband interference rather than frequency-specific. If only one is affected, the interference is specific to that band.

---

## Range

- **RRD metric**: `range`
- **Datasets**: `max_range`
- **Y-axis**: Nautical miles, statute miles, or kilometres (configurable in Settings)

The maximum distance at which any UAT aircraft was detected during each sample interval.

**Reading the chart**:

- UAT range is naturally shorter than 1090 range. A ceiling of 50-100 nm is common even with a good antenna, because GA aircraft fly between 1,000 and 10,000 ft AGL where the radio horizon from a ground-level antenna is limited.
- Range is heavily influenced by aircraft altitude: a single aircraft at 17,500 ft (just below FL180) can produce a range spike far beyond normal traffic. These spikes are informative — they show the theoretical reach of your antenna when the geometry cooperates.
- Consistently low range (under 30 nm) with reasonable signal levels indicates an antenna that is much too low, heavily obstructed, or oriented vertically when a horizontal polarisation might help at 978 MHz.
- Sharp range drops coinciding with weather conditions may indicate that the aircraft in your area are not flying, not that your receiver degraded.

---

## Altitude

- **RRD metric**: `altitude`
- **Datasets**: `altitude` (average altitude of tracked aircraft)
- **Y-axis**: Feet or metres (configurable in Settings)

This chart is unique to dump978 — dump1090 graphs do not include an altitude summary because 1090 traffic spans all flight levels and an average would be meaningless.

**Reading the chart**:

- Average altitudes for UAT traffic typically fall between 2,000 and 12,000 ft. Lower averages indicate you are near an active GA field where aircraft are in the traffic pattern; higher averages suggest your best-received aircraft are en route at moderate altitudes.
- Altitude trends can help evaluate antenna performance for low-flying traffic. If the average is consistently high and you are near an airport, aircraft in the pattern may be too low for your antenna to capture — consider lowering the antenna or adjusting its tilt if it is directional.
- Spikes to 17,500 ft correspond to the FL180 ceiling for UAT — aircraft at transition altitude before switching to 1090.
- If average altitude drops toward zero, check whether ground-based TIS-B emitters or surface vehicles (emitter category C1/C2) are being included in the mix, which can pull the average down.

---

## Graphs Not Present for UAT

dump978 does not produce equivalents for several dump1090 graphs. Understanding why helps avoid fruitless investigation:

| Missing Graph | Why It Is Absent |
|---------------|-----------------|
| **Tracks Seen** | dump978-fa does not report track-level statistics (new tracks, single-message tracks). Aircraft lifecycles are managed by the portal's data collection job instead. |
| **Positions Decoded** | UAT does not use CPR encoding. Positions are transmitted directly in latitude/longitude within the UAT message payload, so there is no global/local/filtered breakdown. |
| **Strong Signals** | dump978's RRD logging does not segregate messages by signal strength threshold. You can approximate this using the Signal Strength chart — if signal levels are consistently near 0 dBFS, the same overload concerns from 1090 apply. |
| **Message Types (DF Types)** | UAT does not have Mode S Downlink Format codes. Message categorization is by type label (adsb_icao, tisb_icao, etc.) and is stored per-flight in the database rather than as a time-series. |
| **Decoder CPU** | dump978-fa does not expose CPU utilisation to RRD. Monitor the system-level CPU chart instead. |

---

## What FIS-B and TIS-B Messages Tell You About Your Setup

Even though FIS-B (weather products) and TIS-B (rebroadcast traffic) are not displayed as separate graphs, their presence in your UAT data provides tuning information:

- **Receiving TIS-B** confirms your antenna and SDR can hear 978 MHz ground-station broadcasts. These stations transmit at higher power than aircraft, so if you can hear TIS-B but not direct aircraft ADS-B, your receiver sensitivity is marginal — gain may need to increase, or your antenna may have too much loss.
- **Receiving FIS-B** weather products means you are hearing ground-station uplinks that include METARs, TAFs, NOTAMs, and graphical weather. FIS-B reception further validates that the 978 MHz receive path is working correctly.
- If you receive neither TIS-B nor FIS-B and you are in the United States, either there is no FAA ground station within range, or the 978 receive chain is not functioning.
