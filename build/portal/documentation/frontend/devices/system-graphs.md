# System Graphs — Host Health

Seven RRD-backed charts tracking the health of the machine running your receiver.
These appear at the bottom of the **Receiver** tab and help you distinguish radio or antenna problems from computer hardware limitations.

System graphs use the portal's built-in RRD writer and read from the configured `graphs.rrd_base` directory (default: `instance/rrd`).
If no RRD files are present yet, charts will be empty until data collection runs.
Legacy RRD files from older portal setups can be migrated during portal installation.

---

## Why Host Health Matters for SDR Tuning

A receiver running on constrained hardware — a Raspberry Pi, an Orange Pi, or a low-power single-board computer — can be limited by the host before the radio chain becomes the bottleneck:

- CPU saturation causes dump1090 to fall behind on demodulation, dropping messages silently.
- Thermal throttling reduces clock speed, compounding CPU issues during the hottest part of the day.
- Low memory triggers swap, adding latency to database writes and potentially stalling data collection.
- SD card I/O limitations can back up RRD writes and database commits.

If tuning changes to gain, antenna, or filters do not produce the improvements you expect, check the system graphs first — the host may be the constraint.

---

## Overall CPU Utilization

- **RRD metric**: `cpu` (decoder: `devices`)
- **Datasets**: `idle`, `user`, `system`, `nice`, `interrupt`, `softirq`, `steal`, `wait`
- **Y-axis**: CPU percentage (aggregated across all cores)

Total system processor load broken into categories. The chart stacks all categories so the total reads 100%.

**Reading the chart**:

- On a dedicated receiver with nothing else running, expect `user` and `system` to account for most of the non-idle time, driven by dump1090-fa, data collection jobs, the web server, and RRD updates.
- Sustained idle below 20% (meaning 80%+ busy) on single-board hardware warrants investigation. Run `top` or `htop` to identify the processes consuming the most time.
- `wait` (I/O wait) indicates the CPU is idle but blocked on disk operations. High I/O wait correlates with slow storage — a worn SD card, a busy USB disk, or heavy database writes.
- `steal` above zero indicates the host is a virtual machine and the hypervisor is reclaiming CPU cycles. This is normal in cloud environments but can affect decode performance.
- Correlate CPU spikes with the dump1090 CPU graph: if both spike together, the decoder workload is the cause. If system CPU spikes independently, look for cron jobs, package updates (`apt`), log rotation, or feeder software.

---

## Temperature

- **RRD metric**: `temperature` (decoder: `devices`)
- **Datasets**: Temperature sensor reading
- **Y-axis**: Degrees Fahrenheit or Celsius (configurable in Settings)
- **Note**: The raw RRD data is stored in millidegrees Celsius and converted for display.

CPU or SoC die temperature over time. On Raspberry Pi hardware, this reads from the built-in thermal sensor.

**Reading the chart**:

- Most ARM-based single-board computers begin to throttle at 80-85 C. The chart does not show throttling directly, but if temperature reaches this zone and sustains, assume clock speed is being reduced.
- A healthy daily pattern shows temperatures rising through the afternoon (higher ambient temperatures, higher air traffic driving CPU load) and falling overnight. If the peak touches throttle territory, improve cooling before investing time in radio tuning.
- An idle temperature substantially above ambient suggests insufficient passive cooling. Heatsinks on the CPU and, separately, on the SDR dongle make a measurable difference.
- Abrupt temperature spikes not correlated with CPU load changes may indicate restricted airflow — check that vents are not blocked and the enclosure is not sealed without ventilation.

---

## Memory Utilization

- **RRD metric**: `memory` (decoder: `devices`)
- **Datasets**: Memory breakdown (used, buffered, cached, free)
- **Y-axis**: Bytes
- **Chart type**: Stacked bar

Memory consumption over time. The stacked bars show how the operating system allocates physical RAM across active processes, filesystem cache, and free pools.

**Reading the chart**:

- Linux aggressively uses available memory for filesystem caching. A system reporting only 50 MB "free" out of 1 GB total may still be perfectly healthy if most of the remainder is in cache, which can be reclaimed instantly.
- A slowly growing "used" segment that never releases may indicate a memory leak in a long-running service. If you suspect this, restart the suspect service and watch whether the used segment resets.
- If swap usage begins growing (visible if the system has swap configured), the machine is running out of physical RAM for active processes. On a Pi with 1 GB or less, this is common when running dump1090, dump978, a web server, a database, and multiple feeder clients simultaneously. Consider disabling feeders you do not actively use.

---

## Network Bandwidth

- **RRD metric**: `network` (decoder: `devices`)
- **Datasets**: Transmit and receive traffic on the configured interface
- **Y-axis**: Bytes per second
- **Interface**: Determined by the `graphs_network_interface` setting (default: `eth0`)

Network throughput on the selected interface.

**Reading the chart**:

- Baseline network traffic for a receiver includes: feeder uploads (FlightAware, ADS-B Exchange, etc.), web portal HTTP requests, NTP time sync, and SSH sessions.
- Sustained high bandwidth typically corresponds to feeder uploads, which continuously stream aircraft data to aggregation services. This is normal.
- Sudden spikes may coincide with system updates (`apt upgrade`), database backups, or log transfers.
- If you are connected via Wi-Fi and network throughput is erratic with bursts and gaps, consider switching to wired Ethernet. Inconsistent connectivity can cause feeders to buffer and retry, creating bursty patterns.

---

## Disk Usage (/)

- **RRD metric**: `disk-usage` (decoder: `devices`)
- **Datasets**: Used, reserved, and free space on the root filesystem
- **Y-axis**: Bytes
- **Chart type**: Stacked bar

Root filesystem capacity over time. On most installations, this is the SD card or eMMC on single-board hardware, or the primary disk on larger systems.

**Reading the chart**:

- Steady, gradual growth reflects the accumulation of flight records in the portal database, RRD files, and system logs. On a busy receiver, the database can grow by several megabytes per day.
- If used space approaches the total, disk writes will begin to fail — RRD updates, database inserts, and log rotation will all break. Set up maintenance jobs to purge old flight data periodically.
- Sudden jumps correspond to large writes: package installations, database migrations, or archive creation.
- Check the Database Size card on the Portal tab for a quick snapshot of how much disk space the portal database alone consumes.

---

## Disk I/O — IOPS

- **RRD metric**: `disk-io-iops` (decoder: `devices`)
- **Datasets**: Read and write operation counts
- **Y-axis**: IOPS (I/O operations per second)

How many individual read and write operations the storage device handles per second.

**Reading the chart**:

- On SD-card-based installations, sustained write IOPS are the primary concern for card longevity. SD cards have a limited number of write-erase cycles, and constant small writes from RRD updates (every 60 seconds) and database commits accelerate wear.
- Periodic IOPS spikes aligned with the data collection interval (roughly every 60 seconds) are expected — the system writes RRD updates and commits any new flight data in batches.
- If read IOPS are consistently high, something is querying the database or filesystem aggressively. On single-board hardware, this can compete with write operations and slow down data recording.
- Consider moving write-intensive paths (database, RRD data directory) to a USB-attached SSD or HDD if IOPS on the SD card are consistently high.

---

## Disk I/O — Bandwidth

- **RRD metric**: `disk-io-bandwidth` (decoder: `devices`)
- **Datasets**: Read and write throughput
- **Y-axis**: Bytes per second

The total data volume moved to and from storage per second.

**Reading the chart**:

- Write bandwidth is dominated by RRD updates (many small files updated frequently) and database inserts (flight positions arriving every 15 seconds from each decoder).
- Read bandwidth is driven by graph queries — when you load the Devices page, the backend reads from multiple RRD files to assemble each chart. On slow storage, this can take noticeably longer for wider time windows.
- Persistent high write bandwidth without corresponding portal activity may indicate another process logging aggressively. Check `/var/log/` for runaway log files.
- On eMMC or NVMe storage, I/O bandwidth is rarely a bottleneck. On SD cards with Class 10 or slower ratings, it can become the limiting factor for how quickly the Devices page loads.
