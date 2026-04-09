# Antenna, SDR, and Filtering

Hardware decisions determine the upper limit of what software tuning can achieve.
This guide covers the physical components between the aircraft and the decoder software, with considerations for both 1090 MHz and 978 MHz reception.

---

## Antenna Fundamentals

### Why Antenna Choice Matters

An SDR receiver amplifies and digitises whatever the antenna delivers. No amount of gain adjustment can recover a signal the antenna never captured. Conversely, a well-placed antenna with a mediocre SDR will outperform a premium SDR connected to a poor antenna.

### Frequency and Wavelength

The antenna's electrical length must be appropriate for the target frequency:

| Frequency | Wavelength | Quarter-wave element |
|-----------|-----------|---------------------|
| 1090 MHz | ~27.5 cm (10.8 in) | ~6.9 cm (2.7 in) |
| 978 MHz | ~30.7 cm (12.1 in) | ~7.7 cm (3.0 in) |

A quarter-wave ground-plane antenna is the most common DIY design for ADS-B. The element lengths differ by about 12% between the two frequencies. An antenna cut for 1090 MHz will still receive 978 MHz, but with reduced gain and a shifted radiation pattern. For best results on both frequencies, use two separate antennas, each cut to length.

### Antenna Types

**Quarter-wave ground plane (spider)**
Four radial elements at roughly 45 degrees below horizontal, with a single vertical element. Simple, inexpensive, and effective. Can be built from a chassis-mount SMA connector and stiff wire. Offers omnidirectional coverage in the horizontal plane.

**Collinear**
Multiple half-wave elements stacked vertically to increase gain in the horizontal plane at the expense of vertical beam width. Best for flat terrain where aircraft are usually near or below the horizon from the antenna's perspective. Commercially available collinear antennas designed for ADS-B are available from FlightAware, Jetvision, DPD Productions, and others.

**Cantenna / can antenna**
A tuned cavity resonator made from a metal can. Provides moderate gain and some directional filtering. More complex to build correctly and less common for ADS-B.

**Discone**
A broadband antenna that covers a wide frequency range. Useful if you want to receive both 1090 and 978 MHz on a single antenna, plus other frequencies. The tradeoff is less gain than a frequency-specific antenna.

### Antenna Placement

Placement has a larger effect on reception than antenna type:

- **Height**: Every metre of additional antenna height extends the radio horizon. On a single-story house, moving the antenna from a windowsill to the roof peak can double effective range.
- **Obstructions**: Buildings, trees, terrain, and even the structure the antenna is mounted on block or attenuate signals. A clear view of the sky in all directions is ideal.
- **Indoor vs outdoor**: Indoor placement behind walls, windows, and roofing material attenuates the signal by 3-10 dB or more depending on material. Metal roofing or foil-backed insulation can block reception almost entirely.
- **Coax routing**: Keep the antenna-to-SDR cable run as short as practical. Every metre of coax introduces loss.

---

## Coaxial Cable

The cable connecting your antenna to the SDR introduces signal loss that increases with frequency and cable length.

### Loss Comparison

| Cable type | Loss at 1090 MHz (per 10 m / 33 ft) | Notes |
|-----------|--------------------------------------|-------|
| RG-174 | ~3.5 dB | Very thin, high loss, avoid for runs over 1 m |
| RG-58 | ~2.5 dB | Common, moderate loss |
| RG-6 | ~1.8 dB | TV coax, decent performance, cheap, uses F connectors |
| LMR-195 | ~2.0 dB | Similar to RG-58 but better shielded |
| LMR-240 | ~1.4 dB | Good balance of size and loss |
| LMR-400 | ~0.7 dB | Low loss, thick and stiff, best for longer runs |
| Aircell 7 | ~1.1 dB | Premium, flexible, low loss |

At 978 MHz, losses are slightly lower than at 1090 MHz for the same cable, but the difference is small enough to be ignored in practice.

### Cable Recommendations

- Runs under 3 metres: RG-58 or RG-174 are acceptable.
- Runs of 3-10 metres: LMR-240 or equivalent.
- Runs over 10 metres: LMR-400 or place the SDR at the antenna (with USB extension or network-attached SDR) to eliminate most cable loss entirely.

Every connector (SMA, N-type, F-to-SMA adapter) introduces additional loss, typically 0.1-0.5 dB per connection. Minimise the number of adapters and connectors in the signal path.

### Weatherproofing

Outdoor connectors must be weatherproofed. Moisture in a connector causes corrosion, impedance mismatch, and signal loss that worsens over time. Use self-amalgamating tape or heat-shrink tubing over outdoor SMA or N-type connections.

---

## SDR Dongle Selection

### RTL-SDR v3 / v4

The most commonly used SDR for ADS-B reception. Inexpensive, widely supported, and well-documented. The v3 and v4 models both have a temperature-compensated crystal oscillator (TCXO) that reduces frequency drift.

Both dump1090-fa and dump978-fa assume RTL-SDR compatibility by default.

### FlightAware Pro Stick / Pro Stick Plus

Purpose-built for ADS-B with a built-in 1090 MHz low-noise amplifier (LNA) and bandpass filter (Pro Stick Plus). Provides better sensitivity at 1090 MHz than a generic RTL-SDR. The built-in filter reduces out-of-band interference.

The Pro Stick Plus is optimised for 1090 MHz and may not perform well at 978 MHz due to its built-in filter attenuating the 978 MHz band. If using a Pro Stick Plus for 1090, pair it with a separate generic RTL-SDR for 978 MHz.

### Nooelec NESDR Smart

Another quality RTL-SDR option with a TCXO and aluminium enclosure for better thermal management. Performs comparably to the RTL-SDR v3 for ADS-B.

### Dual-SDR Considerations

When running two dongles for simultaneous 1090 + 978 reception:

- Assign unique serials to each dongle (see [tuning-978.md](tuning-978.md) for instructions).
- Use a powered USB hub if the host cannot supply sufficient current for both dongles plus other peripherals.
- Separate the dongles physically if possible — they generate heat and RF interference that can affect each other when touching.

---

## Bandpass Filters

A bandpass filter passes signals within a narrow frequency window and rejects everything outside it. For ADS-B and UAT, filters reduce interference from nearby cell towers, FM radio, pagers, and other strong RF sources.

### When You Need a Filter

- **Urban environments**: Cell towers, commercial FM transmitters, and two-way radio systems can overload the SDR's front end, causing intermodulation products that appear as false signals or elevated noise floor.
- **Near broadcast towers**: If your antenna has line-of-sight to a high-power FM or TV transmitter, a filter is almost mandatory.
- **High gain settings**: Running at high gain without a filter amplifies out-of-band interference along with the desired signal.

### When You Might Not Need a Filter

- Rural locations far from broadcast infrastructure.
- Already using a Pro Stick Plus or comparable SDR with a built-in filter.
- Running at low gain where out-of-band signals are below the noise floor.

### Filter Types

**1090 MHz bandpass**
Passes roughly 1080-1100 MHz. Rejects cell (700-900 MHz, 1700-2100 MHz), FM (88-108 MHz), and most other interference. Multiple vendors offer these, including FlightAware, Nooelec, and generic cavity filters.

**978 MHz bandpass**
Passes roughly 968-988 MHz. Less commonly available commercially but can be sourced from Nooelec and other SDR accessory vendors. Essential if you are near strong 900 MHz ISM-band devices (cordless phones, IoT sensors, industrial equipment).

**Dual-band filter**
Some filters pass both 978 and 1090 MHz in a single unit. These are convenient for discone or broadband antenna setups but provide less rejection than separate single-band filters.

### Filter Placement

Place the filter between the antenna cable and the SDR dongle. If using an external LNA, the filter should go between the antenna and the LNA to prevent the LNA from amplifying interference.

---

## Low-Noise Amplifiers (LNA)

An external LNA boosts the signal before it reaches the SDR, improving sensitivity, especially on long cable runs where signal loss is significant.

### When an LNA Helps

- Cable runs over 5 metres where cable loss exceeds 2-3 dB.
- Locations where distant aircraft signals are just barely below the decode threshold.
- Antenna installations where the SDR cannot be mounted close to the antenna.

### When an LNA Hurts

- Short cable runs where signal strength is already adequate. Adding an LNA in this situation can overdrive the SDR's ADC, causing the same clipping problems as excessive gain.
- Without a bandpass filter: an LNA amplifies everything, including interference. Use a filter before the LNA if out-of-band signals are strong.

### Placement

The ideal signal chain is:

```
Antenna → Bandpass filter → LNA → Coax cable → SDR
```

Placing the LNA at the antenna end of the cable (mast-mounted) amplifies the signal before cable loss attenuates it. This produces the best signal-to-noise ratio.

If mast-mounting is impractical, placing the LNA at the SDR end still provides some benefit, but cable loss has already degraded the signal before amplification.

---

## Frequency-Specific Hardware Recommendations

### 1090 MHz Only

| Component | Recommended |
|-----------|------------|
| Antenna | 1090-tuned collinear or quarter-wave ground plane |
| SDR | FlightAware Pro Stick Plus (built-in filter + LNA) |
| Filter | Built into Pro Stick Plus; add external if near broadcast towers |
| Cable | LMR-240 or better for runs over 3m |

### 978 MHz Only

| Component | Recommended |
|-----------|------------|
| Antenna | 978-tuned quarter-wave ground plane |
| SDR | RTL-SDR v3/v4 or Nooelec NESDR |
| Filter | 978 MHz bandpass (Nooelec, generic) |
| Cable | Same as 1090 |

### Dual 1090 + 978

| Component | Recommended |
|-----------|------------|
| Antennas | Two separate antennas, each cut to frequency (preferred), or one discone/broadband with a splitter |
| SDRs | Pro Stick Plus for 1090, RTL-SDR v3/v4 for 978 |
| Filters | 1090 bandpass on the 1090 line, 978 bandpass on the 978 line |
| Cable | LMR-240+ for each run |
| Splitter | If using one antenna, a wideband splitter introduces ~3.5 dB loss on each port — usually acceptable only for short runs |

---

## Verifying Hardware Performance Through the Portal

After installing or changing hardware, use the portal graphs to confirm the change had the expected effect:

| Change | Expected graph impact |
|--------|----------------------|
| Better antenna or higher placement | Range increase, aircraft count increase, potentially higher message rate |
| Added bandpass filter | Noise floor drops in Signal graph, message rate may increase, strong-signal % may decrease |
| Added LNA | Signal levels increase across the board; monitor for clipping (signal > -1 dBFS) |
| Shorter or lower-loss cable | Signal level increases slightly, noise floor may decrease |
| Moved SDR to antenna mast | Same as shorter cable, plus reduced interference pickup from indoor electronics |

Always change one variable at a time and let the system run for at least 24 hours before comparing to the previous configuration.
