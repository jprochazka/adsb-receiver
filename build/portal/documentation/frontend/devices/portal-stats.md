# Portal Stats Tab

The **Portal** tab displays a snapshot of aggregated receiver metrics that do not come from RRD graphs.
These statistics are compiled by the backend at page load from the decoder JSON API, the portal database, the OpenSky classification data, and the host operating system.

The tab is divided into four sections:

1. **Receiver** — decoder identity, antenna coordinates, and signal health.
2. **Data Quality** — aircraft classification breakdowns and OpenSky database status.
3. **Traffic Volume** — live and historical flight counts plus message totals.
4. **System Status** — host health, database size, uptime, and data freshness.

---

## Receiver

This section appears when dump1090-fa is active and reporting data.

### Decoder Version

The software version string reported by the running dump1090-fa process.
Check this against the latest FlightAware release to decide whether an upgrade is worthwhile.
Newer versions occasionally change decode behaviour, gain defaults, or the fields available in `receiver.json`.

### Receiver Location

The latitude and longitude configured in dump1090-fa's settings (typically set during FlightAware setup or in `/etc/default/dump1090-fa`).
This location is used by the decoder itself for MLAT calculations and by the portal to compute range statistics.

If this reads `0.0000, 0.0000` or is absent, receiver location has not been configured — range calculations and MLAT will not function correctly.

### Signal Level

The current mean signal level of recently decoded messages, expressed in dBFS (decibels relative to full scale of the ADC).

- **Typical healthy range**: -3 dBFS to -15 dBFS.
- **Too strong (above -1 dBFS)**: The SDR's analog-to-digital converter may be clipping, discarding valid messages. Reduce gain.
- **Too weak (below -20 dBFS)**: Messages arrive near the noise floor. Many weaker signals are likely being lost. Check antenna, cable, and gain.

The card also shows:

- **Peak Signal**: The strongest single-message signal seen in the current stats window. Useful for confirming that nearby aircraft are not saturating the receiver.
- **Noise Level**: The decoder's estimate of the background noise floor. A noise floor above -30 dBFS suggests interference, an overly broad amplifier setting, or local RF noise sources.

### Avg Aircraft RSSI

The mean received signal strength across all aircraft currently in view.
This value is computed live from each aircraft's most recent message.

- Much lower than Signal Level → distant aircraft dominate the feed; gain may need to increase.
- Close to Signal Level → most traffic is nearby or the receiver is in a high-traffic area.

---

## Data Quality

This section describes how the portal classifies live aircraft by type (manufacturer, model, ICAO type designator).

### OpenSky Classified

The number of currently visible aircraft whose ICAO hex codes matched a record in the locally installed OpenSky Network database.
The OpenSky dataset maps ICAO addresses to registration, type designator, manufacturer, and operator.

### Heuristic Classified

Aircraft that did not match the OpenSky database but were classified using fallback rules.
The heuristic engine examines ADS-B category fields, emitter category bytes, wake-vortex category, and callsign patterns to make an educated guess about aircraft type.

Because heuristic classification is probabilistic, it may occasionally misidentify an aircraft — particularly military or experimental aircraft that transmit non-standard category codes.

### Unknown Type

Aircraft currently visible whose ICAO address did not match OpenSky and whose ADS-B metadata was insufficient for heuristic classification.
A high proportion of unknowns (above 30%-40%) usually means the OpenSky database is not installed or is outdated.

### Classification Quality

A percentage breakdown of the three classification sources (OpenSky, Heuristic, Unknown) relative to total live aircraft.
This provides an at-a-glance confidence measure for the type labels shown on live traffic displays.

- **OpenSky 80%+**: Excellent — most aircraft are positively identified from registry data.
- **Heuristic 30%+**: Acceptable — many aircraft are typed, but accuracy depends on ADS-B category fields.
- **Unknown 40%+**: Import or update the OpenSky database to improve coverage.

### Top Aircraft Types

A ranked list of the most frequently seen ICAO type designators among currently visible aircraft.
On a typical installation near a commercial airport, expect narrow-body airliners (B738, A320, A321, B737) to dominate.
Near general aviation fields, expect C172, C182, PA28, SR22, and similar light aircraft.

### OpenSky Database

Status information for the locally imported OpenSky dataset:

- **Status**: Whether the database has been imported (`Installed` / `Not Installed`).
- **Entries**: Total number of ICAO-to-type mappings available for lookups.
- **Downloaded**: The date and time the dataset was last retrieved from the OpenSky Network.

The dataset does not auto-update. To refresh it, use the Settings page or the backend management command. Refreshing periodically (monthly or quarterly) captures newly registered aircraft.

---

## Traffic Volume

Counts of live and stored flights across all active decoders.

### Live Aircraft

The current count of aircraft being tracked by all active decoders combined.
The breakdown beneath shows:

- **ADS-B**: Aircraft tracked by dump1090-fa (1090 MHz).
- **UAT**: Aircraft tracked by dump978-fa (978 MHz), if enabled.

This count is a direct snapshot — it rises and falls with the traffic pattern over your location. Overnight lulls and midday peaks are typical near commercial routes.

### Live Message Counter

The cumulative message count from the decoder since its last restart.
This counter only goes up — it is not a rate. Use it to confirm the decoder is actively receiving and processing frames. If this number stops incrementing, the decoder or SDR may have stalled.

### ACARS Messages

The total number of stored ACARS (Aircraft Communications Addressing and Reporting System) messages if the ACARS decoder is configured.
ACARS messages are short datalink messages exchanged between aircraft and ground stations on VHF frequencies.
If no ACARS decoder is installed, this card reads `0`.

### ADS-B Flights

Total number of distinct ADS-B flight records stored in the portal database.
Each time an ICAO address appears, remains visible long enough to be logged, and then disappears, the portal records it as one flight.
This number grows continuously and is only reduced by the database maintenance purge job.

### UAT Flights

Total stored UAT flight records, equivalent to the ADS-B count but for 978 MHz traffic processed by dump978-fa.
In regions outside the United States, or on receivers without a UAT SDR, this reads `0`.

### ACARS Flights

Distinct flights that included at least one ACARS message. Not every aircraft sends ACARS, and not every ACARS decoder captures every message — this count will always be lower than the ADS-B flight total.

---

## System Status

Host-level metrics to assess the health and age of the current snapshot.

### CPU Temperature

Current thermal reading of the host CPU. If the reading exceeds 80 C the value is highlighted in red; between 60 C and 80 C it is highlighted in amber.

This card displays the instantaneous temperature at page load. For a historical view, switch to the Receiver tab and check the Temperature graph.

### Database Size

The on-disk size of the portal's SQLite (or MySQL/PostgreSQL) database file.
On a busy receiver tracking hundreds of flights per day, the database can grow by 5-20 MB daily depending on position-logging frequency and maintenance purge settings.

If this value is growing faster than expected, confirm that the maintenance purge job is running. Check **Settings → Scheduler** for the maintenance task schedule.

### Receiver Uptime

How long the host has been running since its last boot, formatted as days, hours, and minutes.
Long uptimes are desirable — a short uptime after an unexpected reboot may indicate power issues, kernel panics, or SD card corruption on Raspberry Pi hardware.

### Snapshot Info

Two timestamps:

- **Live snapshot timestamp**: When the backend last queried the decoder to compile the stats displayed on this tab. This is the "freshness" of the data.
- **Page refresh timestamp**: When your browser last fetched this page from the backend.

If the snapshot timestamp is much older than the page refresh, the decoder may have stopped responding, or the backend data-collection job may not be running.
