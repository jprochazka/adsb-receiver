# Tuning dump978-fa (978 MHz UAT)

A comprehensive guide to configuring and optimising a 978 MHz Universal Access Transceiver (UAT) receiver using dump978-fa, with guidance on interpreting the portal's UAT-specific graphs.

---

## UAT Context

978 MHz UAT is a United States-only datalink mandated by the FAA as an alternative to 1090 MHz ADS-B for aircraft operating below FL180 (18,000 feet). UAT is heavily used by general aviation (GA): single-engine piston aircraft, light twins, helicopters, and gliders.

Because UAT traffic is concentrated at lower altitudes and dominated by GA, reception patterns differ significantly from 1090 MHz ADS-B:

| Characteristic | 1090 MHz ADS-B | 978 MHz UAT |
|----------------|---------------|-------------|
| Altitude range | Surface to FL600+ | Surface to FL180 |
| Dominant traffic | Airlines, business jets | GA piston/turboprop, helicopters |
| Message density | High, continuous | Variable, bursty |
| Range potential | 200+ NM line-of-sight | Typically 50-100 NM (low-flying traffic) |
| Active hours | 24/7, dips overnight | Follows GA patterns: sunrise to sunset |
| TIS-B / FIS-B | Not applicable | Ground stations broadcast traffic and weather |

If your receiver is outside the United States, or your antenna location has no GA traffic below FL180, enabling UAT will produce no results regardless of tuning quality.

---

## Dual-SDR Setup

Receiving both 1090 MHz and 978 MHz simultaneously requires two separate SDR dongles — one cannot tune to both frequencies at the same time.

### Assigning Device Serials

When two RTL-SDR dongles are connected to the same host, the system assigns device indices (0, 1) at boot time. These indices can swap across reboots depending on USB enumeration order. To prevent dump1090-fa and dump978-fa from accidentally using each other's dongle, assign persistent serial numbers:

```bash
# Identify connected devices
rtl_test

# Set serial for the 1090 dongle (while only that dongle is plugged in)
rtl_eeprom -s 00001090

# Set serial for the 978 dongle (while only that dongle is plugged in)
rtl_eeprom -s 00000978
```

After setting serials, reference them in each decoder's configuration by serial string rather than device index. This ensures the correct dongle is used regardless of USB enumeration order.

### Power Considerations

Two SDR dongles draw more power than one. On Raspberry Pi hardware, use a high-quality power supply rated for at least 3A at 5V. Underpowered setups can cause USB resets, kernel errors, and intermittent data loss that mimics radio problems.

If you experience random SDR disconnections visible in `dmesg`, power supply quality is the first thing to investigate.

---

## Configuration File

dump978-fa's configuration on Debian-based systems lives at:

```
/etc/default/dump978-fa
```

Key parameters:

| Parameter | Purpose |
|-----------|---------|
| `RECEIVER_OPTIONS` | Flags for the radio: gain, device selection, PPM correction |
| `DECODER_OPTIONS` | Processing options for the decoded UAT frames |
| `NET_OPTIONS` | Network port and output format settings |

A typical minimal configuration:

```
RECEIVER_OPTIONS="--sdr driver=rtlsdr,serial=00000978 --gain 48"
```

The `--sdr` flag uses SoapySDR syntax. The `driver=rtlsdr,serial=00000978` portion selects the specific dongle by the serial you assigned earlier.

To change gain:

```bash
sudo nano /etc/default/dump978-fa
# Edit the --gain value
sudo systemctl restart dump978-fa
```

Wait at least 15 minutes before evaluating results. UAT traffic is bursty, and short observation windows can be misleading.

---

## UAT Gain Characteristics

UAT gain tuning follows the same principle as 1090 MHz — sweep from high to low and find the peak — but the feedback loop is slower and noisier because of the nature of UAT traffic.

### Why UAT Tuning is Harder

1. **Bursty traffic.** A GA airport may have 20 aircraft in the pattern at 10 AM and zero at 10 PM. Message rate fluctuates with pilot activity, not just reception quality.
2. **Lower altitude = shorter range.** A Cessna at 3,000 feet AGL disappears behind terrain much sooner than a 737 at FL350. Range metrics are naturally limited.
3. **TIS-B and FIS-B inflate message counts.** Ground stations rebroadcast traffic information (TIS-B) and weather products (FIS-B) on 978 MHz. These messages are received along with direct aircraft ADS-B. A gain change that increases FIS-B receipts may not indicate better aircraft reception.
4. **Fewer data points.** Seeing 5 aircraft instead of 50 means statistical noise dominates the metrics.

### Gain Steps for RTL-SDR on 978 MHz

The available gain steps are the same hardware values as for 1090 MHz (the gain is set in the SDR hardware, not the decoder). However, the optimal gain for 978 MHz reception on the same antenna often differs from 1090 because:

- 978 MHz has different propagation characteristics (slightly longer wavelength).
- Background noise at 978 MHz may differ from 1090 MHz at your location.
- An antenna optimised for 1090 MHz has different gain and impedance at 978 MHz.

Start at a high gain step (48.0 or 49.6) and work down. The sweep may require 30-60 minute observation windows per step if traffic is sparse.

---

## Using Portal Graphs for UAT Tuning

### Messages Graph

This is the primary tuning metric for UAT, equivalent to the Message Rate graph for 1090 MHz.

- **Be aware of TIS-B and FIS-B contributions.** The message count includes all UAT frame types. Near a FAA ground station, FIS-B weather products can account for a large portion of the total. Changes in FIS-B counts may reflect your proximity to the ground station rather than your tuning quality.
- **Compare like hours.** If evaluating a gain change, compare 10 AM Tuesday against 10 AM Wednesday, not 10 AM against 10 PM.

### Aircraft Graph

Tracks the count of unique aircraft being tracked, with separate datasets for total, with-position, and with-callsign.

- A gain change that increases message count but does not increase aircraft count may be picking up more messages from the same aircraft (not necessarily bad — additional messages improve position accuracy).
- A sharp drop in aircraft count with stable or rising message count suggests the gain change is favouring nearby ground-station traffic over distant aircraft.

### Signal Graph

Mean received signal strength in dBFS.

UAT signal levels tend to be lower and more variable than 1090 MHz because GA aircraft often transmit at lower power levels and are closer to the ground (more terrain shadowing).

- If the signal level is consistently above -3 dBFS with only a few aircraft, you are likely receiving primarily from a nearby ground station. Reduce gain to let aircraft signals emerge from the ground station's dominant signal.
- If the signal is below -25 dBFS with aircraft known to be overhead, gain is too low or antenna/cable issues exist.

### Range Graph

Maximum distance at which an aircraft position was successfully decoded, stored as a MAX consolidation over the RRD interval.

Because UAT aircraft fly low, achievable range is fundamentally limited by terrain and earth curvature. Expect 50-100 NM from a well-sited antenna, compared to 150-250 NM for 1090 MHz.

Improvements in range plateau quickly as gain increases — once you can decode a low-altitude target at 60 NM, further gain increases are unlikely to extend range because the aircraft drops below the radio horizon before signal strength becomes the limiting factor.

### Altitude Graph

Average altitude of tracked UAT aircraft, updated at each collection interval.

This graph is unique to UAT (dump1090 does not have an equivalent) and reflects the mix of traffic currently visible:

- Higher average altitude suggests traffic is transiting through your area at higher GA altitudes (6,000-12,000 feet).
- Lower average altitude suggests local pattern traffic around nearby airports (1,000-3,000 feet AGL).
- A gain change that shifts average altitude noticeably downward may indicate you are now receiving short-range, low-altitude targets that were previously below the decode threshold — generally a positive sign.

---

## Traffic Pattern Awareness

UAT traffic follows general aviation activity patterns that are strongly influenced by weather and time of day:

- **Dawn to mid-morning**: Traffic ramps up as GA pilots begin flying.
- **Midday**: Sustained activity, especially around training airports and popular cross-country routes.
- **Late afternoon**: Peak GA traffic as pilots return before sunset.
- **After sunset**: UAT traffic drops dramatically. Most GA pilots are VFR-only and do not fly at night.
- **Weekends**: Higher traffic at recreational GA airports.
- **Bad weather days**: Significantly reduced traffic. VFR pilots stay grounded during IFR conditions, and many GA aircraft are not IFR-equipped.

When evaluating tuning changes, be conscious of these patterns. A "better" message count on a sunny Saturday compared to a rainy Tuesday is not evidence of improved reception.

---

## FIS-B and TIS-B as Diagnostic Tools

UAT ground stations broadcast two additional message types that serve as indirect indicators of your 978 MHz reception quality:

### FIS-B (Flight Information Services — Broadcast)

Weather products broadcast by FAA ground stations, including METAR, TAF, NEXRAD imagery, PIREPs, and NOTAMs. These are broadcast on a fixed schedule regardless of whether any aircraft are nearby.

- **As a tuning indicator**: If you are within range of an FAA ground station, FIS-B messages provide a consistent, always-on signal source. A gain or antenna change that increases your FIS-B message rate likely also improves your aircraft reception.
- Conversely, if you are far from any ground station, you may receive zero FIS-B messages even with perfect tuning.

### TIS-B (Traffic Information Services — Broadcast)

The ground station rebroadcasts traffic data for nearby 1090 MHz ADS-B aircraft to 978 MHz UAT receivers. TIS-B messages only appear when there are 1090 MHz aircraft in the area and a nearby ground station is active.

- TIS-B message rates correlate with both your reception quality and the ambient traffic. They are less useful than FIS-B as a stable tuning reference.

The portal's dump978 data collection job processes message_type fields (`adsb_icao`, `tisb_icao`, `tisb_other`, `adsb_other`) from the aircraft.json feed. Monitoring the raw message types can help distinguish between improving direct aircraft reception and simply receiving more ground-station rebroadcasts.

---

## Iterative Tuning Workflow for UAT

1. **Start high**: Set `--gain 48` or `49.6` in `/etc/default/dump978-fa`. Restart.
2. **Wait for GA hours**: Evaluate during midday on a clear-weather weekday.
3. **Record baseline**: Note Messages, Aircraft, and Signal graphs for a 2-hour window.
4. **Reduce gain by one step**: Restart, wait, record.
5. **Compare**: Is Messages steady or higher? Did Aircraft count hold? Did Signal drop proportionally?
6. **Repeat**: Continue until Messages begin to decline.
7. **Select the gain step where Messages peaked** with the best Aircraft count.
8. **Run for a full week**: UAT traffic varies significantly day to day. Confirm the chosen gain performs well across weekdays and weekends, good weather and bad.

---

## Troubleshooting UAT-Specific Issues

### No UAT Messages at All

- Confirm you are in the United States. UAT is not used outside the US.
- Confirm the correct SDR is assigned: `rtl_test -d 00000978` should succeed.
- Confirm dump978-fa is running: `sudo systemctl status dump978-fa`.
- Check that `dump978GraphsEnabled` is `true` in the portal settings.
- Try `--gain -1` (AGC) temporarily to verify any signal can be received.

### Messages Appear but Aircraft Count is Zero

The message count may be dominated by FIS-B/TIS-B. Check the raw feed at `http://127.0.0.1/dump978/data/aircraft.json`. If the JSON is empty but the message counter is incrementing, the messages are ground-station products, not aircraft.

### Highly Erratic Signal Levels

Rapid jumps in the Signal graph between -5 and -30 dBFS suggest the receiver is alternating between ground-station signals (very strong) and aircraft signals (weaker). This is normal in UAT. If the variation is extreme, a SAW bandpass filter centred on 978 MHz can reduce out-of-band interference.

### Range Never Exceeds 30 NM

This is expected in areas with significant terrain. UAT aircraft fly low, and the radio horizon for an aircraft at 3,000 feet AGL is approximately 70 NM under ideal conditions. Hills, mountains, buildings, and trees reduce this substantially. Antenna height is the most effective lever for extending UAT range.
