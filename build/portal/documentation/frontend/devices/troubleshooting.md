# Troubleshooting

Symptom-driven diagnosis for both 1090 MHz (dump1090-fa) and 978 MHz (dump978-fa) receivers, using portal graphs and system tools to identify root causes.

---

## Using This Guide

Each section describes a symptom you might observe, the likely causes ranked by probability, and how to confirm and resolve each one. Portal graph references point to specific charts described in [dump1090-graphs.md](dump1090-graphs.md), [dump978-graphs.md](dump978-graphs.md), and [system-graphs.md](system-graphs.md).

---

## No Data at All — Graphs Are Empty

### Symptom

All graphs on the Receiver tab show flat lines or "No data available." The Portal tab may also show zeros.

### Causes and Checks

**1. Decoder service is not running**

```bash
sudo systemctl status dump1090-fa
sudo systemctl status dump978-fa
```

If the service is inactive or failed, check the journal for the error:

```bash
sudo journalctl -u dump1090-fa --no-pager -n 50
```

Common failure reasons include the SDR not being detected (USB issue or missing device), permission errors, or configuration syntax errors in `/etc/default/dump1090-fa`.

**2. Data collection job is not running**

The portal backend runs scheduled jobs to fetch data from the decoders and write it to RRD files. If these jobs have stopped, the decoders may be running fine but the portal has no data.

Check the scheduler status in the portal's Settings page, or look for recent log entries from the data collection workers.

**3. RRD files do not exist**

If the portal was freshly installed or the RRD directory was cleared, the RRD files may not have been created yet. The data collection job creates them on first run. Wait for at least one collection cycle (typically 60 seconds) after starting the backend.

**4. SDR dongle is not connected or not recognised**

```bash
lsusb | grep -i rtl
rtl_test
```

If `rtl_test` fails with "No supported devices found," the dongle is not connected, not powered, or needs a driver. On some systems, the `dvb_usb_rtl28xxu` kernel module claims the device before `rtlsdr` can use it. Blacklist it:

```bash
echo "blacklist dvb_usb_rtl28xxu" | sudo tee /etc/modprobe.d/blacklist-rtlsdr.conf
sudo modprobe -r dvb_usb_rtl28xxu
```

---

## Message Rate Dropped Suddenly

### Symptom

The Message Rate graph (1090) or Messages graph (978) shows a sharp decline that does not match normal traffic patterns.

### Causes and Checks

**1. Antenna disconnection or damage**

A loose connector, corroded joint, or cable damaged by weather can cause an abrupt drop. Physically inspect the antenna, cable, and all connectors. Look for moisture intrusion at outdoor connections.

Portal evidence: Signal graph shows the mean signal dropping to near the noise floor.

**2. SDR overheating**

SDR dongles generate significant heat, especially in enclosed spaces. Overheating degrades performance and can cause the dongle to reset.

Portal evidence: Temperature graph may show elevated host temperature. The message rate drop may correlate with a temperature peak.

Mitigation: Improve airflow around the dongle, add a small heatsink, or relocate it.

**3. New source of RF interference**

A newly installed device in your home or a neighbour's — a wireless security camera, IoT hub, or amateur radio transmitter — can raise the noise floor enough to drown out weaker signals.

Portal evidence: Signal graph shows the noise floor rising while the mean signal stays the same or drops. Strong Signals percentage may change.

Mitigation: Add or replace the bandpass filter. Try to identify and relocate the interfering device.

**4. Software update changed configuration**

A system-level `apt upgrade` can update dump1090-fa and reset configuration to defaults, including gain.

Check: Compare your `/etc/default/dump1090-fa` against the backup that `dpkg` creates during upgrades (`*.dpkg-old` or `*.dpkg-dist` files in the same directory).

---

## Signal Level is Too High (Above -1 dBFS)

### Symptom

The Signal graph shows the mean signal line near 0 dBFS. The Strong Signals graph shows a high percentage.

### Cause

The SDR's gain is set too high, or an external LNA is amplifying the signal beyond the ADC's dynamic range. Signals above the ADC maximum are clipped, corrupting the message bits and causing decode failures.

### Resolution

1. Reduce gain by 2-3 steps in the decoder configuration.
2. Restart the decoder.
3. Wait 10-15 minutes and re-check the Signal graph.
4. If using an external LNA, consider inserting an attenuator (3-6 dB) between the LNA and the SDR, or removing the LNA entirely if cable loss is low.

---

## Signal Level is Too Low (Below -25 dBFS)

### Symptom

The Signal graph shows mean signal strength near or below the noise floor. Aircraft count is low relative to known traffic.

### Cause

Insufficient gain, excessive cable loss, a mismatched or damaged antenna, or the antenna is obstructed.

### Resolution

1. Increase gain by 2-3 steps.
2. If already at maximum gain, inspect the physical signal path: cable, connectors, antenna.
3. Consider adding an LNA at the antenna end of the cable, preceded by a bandpass filter.
4. Check cable loss — long runs of RG-58 or RG-174 can lose 5+ dB.

---

## Range is Lower Than Expected

### Symptom

The Range graph shows a maximum range well below what terrain and antenna height should allow. Other receivers in the same area report significantly higher range.

### Causes and Checks

**1. Antenna height**

Range is primarily limited by line-of-sight, which is governed by antenna height and terrain. An antenna at 2 metres AGL on flat terrain has a radio horizon of about 100 NM. At 10 metres, approximately 210 NM.

**2. Obstructions**

Buildings, trees, hills, and even the structure the antenna is mounted on can block low-elevation signals. Walk around the antenna location and note which directions have clear vs. obstructed horizons.

**3. Gain too low**

Distant aircraft produce weak signals. If gain is set conservatively, these signals may fall below the decode threshold. Try increasing gain by 1-2 steps and observe whether range improves.

**4. For UAT (978 MHz)**

UAT range is inherently limited because the aircraft fly low. A maximum range of 50-80 NM is typical even with good hardware. See [tuning-978.md](tuning-978.md) for UAT-specific expectations.

---

## High CPU Usage Impacting Decode

### Symptom

The CPU graph shows sustained utilisation above 80%. The dump1090 CPU graph shows the demod thread consuming most of the capacity. Message rate may be lower than expected.

### Causes and Checks

**1. Underpowered host**

Older Raspberry Pi models (Pi 2, Pi Zero) may not have enough processing power to run dump1090, dump978, a web server, a database, and multiple feeders simultaneously.

**2. Competing processes**

Other software may be consuming CPU. Check with:

```bash
top -b -n 1 | head -20
```

Common offenders: `apt` running unattended upgrades, `influxd` or `grafana-server` if installed, log compression, and feeder clients performing bulk uploads.

**3. Too many feeders**

Each feeder client (PiAware, ADS-B Exchange, Flightradar24, etc.) consumes CPU and memory. On constrained hardware, disable feeders you do not actively use.

---

## Temperature Warnings

### Symptom

The Temperature graph on the Receiver tab or the CPU Temperature card on the Portal tab shows readings above 70 C. The portal highlights the temperature card in amber (>60 C) or red (>80 C).

### Resolution

1. Add a heatsink to the CPU if one is not already installed.
2. Ensure the case has adequate ventilation. Sealed plastic cases without vents trap heat.
3. Add a small fan (5V, 30mm) if passive cooling is insufficient.
4. SDR dongles also generate heat — separate them from the host board and ensure airflow.
5. In extreme ambient temperatures, consider relocating the receiver to a cooler location or adding shade to an outdoor enclosure.

---

## Disk Usage Growing Too Fast

### Symptom

The Disk Usage graph shows used space climbing steadily. The Database Size card on the Portal tab confirms the database is large.

### Resolution

1. Check whether the maintenance purge job is scheduled and running. In the portal Settings, confirm the maintenance task exists and has a recent execution time.
2. Adjust the retention period for flight records. Shorter retention = smaller database.
3. Check for runaway log files:

```bash
sudo du -sh /var/log/* | sort -rh | head -10
```

4. If the database has grown very large, a one-time manual purge may be needed:

The portal provides API endpoints for purging old ADS-B and UAT flight data. Use the Settings page or the API directly.

---

## dump978 Shows Messages but No Aircraft

### Symptom

The dump978 Messages graph is incrementing, but the Aircraft graph shows zero.

### Cause

The messages being received are FIS-B weather products or TIS-B rebroadcasts from FAA ground stations, not direct ADS-B messages from aircraft. These ground-station products do not appear as "aircraft" in the tracking display.

### Confirmation

Check the raw dump978 feed:

```bash
curl -s http://127.0.0.1/dump978/data/aircraft.json | python3 -m json.tool
```

If the array is empty, no aircraft are currently being tracked via UAT. The message counter is incrementing from ground-station products.

### Resolution

This is normal behaviour when no GA aircraft are flying in your area. UAT traffic is heavily dependent on time of day, weather, and proximity to GA airports. Check during midday on a clear weekday for the best chance of seeing UAT aircraft.

---

## Graphs Load Slowly or Time Out

### Symptom

Switching to the Receiver tab takes many seconds, or graphs display partial data with loading indicators.

### Causes and Checks

**1. Slow storage**

On SD cards, reading multiple RRD files to assemble graphs can be I/O-bound. The Disk I/O IOPS and Bandwidth graphs will show high read values during page loads.

Mitigation: Move the RRD directory to faster storage (USB SSD) or reduce the number of enabled graph sections.

**2. Wide time range**

Monthly and longer views process more data points. Try a shorter time range to confirm the issue is I/O-related.

**3. Backend overloaded**

If the backend is handling both data collection and many concurrent graph requests, responses slow down. This is most common on single-core hardware.

---

## SDR Stops Receiving Intermittently

### Symptom

Message rate drops to zero for minutes at a time, then recovers. The pattern repeats irregularly.

### Causes and Checks

**1. USB power issues**

Insufficient USB bus power causes the SDR to disconnect and reconnect. Check kernel logs:

```bash
dmesg | grep -i "usb\|rtl"
```

Look for "USB disconnect" or "device descriptor read" errors. Use a powered USB hub or a higher-rated power supply.

**2. Thermal shutdown**

The SDR dongle may be overheating and entering a protective shutdown. It recovers after cooling. Add a heatsink to the SDR and improve ventilation.

**3. Driver conflict**

The kernel DVB driver may be intermittently claiming the device. Re-check the blacklist from the "No Data" section above.

---

## Quick Diagnostic Table

| Symptom | First check | Portal graph to examine |
|---------|------------|------------------------|
| No data at all | `systemctl status dump1090-fa` | — (all empty) |
| Message rate dropped | Antenna connectors | Signal, Message Rate |
| Low range | Antenna height/obstructions | Range |
| Signal clipping (>-1 dBFS) | Reduce gain | Signal, Strong Signals |
| Weak signal (<-25 dBFS) | Increase gain or check cable | Signal |
| High CPU | `top` for competing processes | CPU, dump1090 CPU |
| High temperature | Add heatsink/fan | Temperature |
| Disk filling up | Check purge job schedule | Disk Usage |
| UAT msgs but no aircraft | Check during GA flying hours | dump978 Messages, Aircraft |
| Intermittent dropouts | `dmesg` for USB errors | Message Rate (look for gaps) |
