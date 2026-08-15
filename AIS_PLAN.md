# AIS Decoding and Portal Integration Plan

## Objective

Add AIS-catcher as the first supported AIS decoder, using a dedicated RTL-SDR
and loopback `JSON_FULL` UDP output. A persistent Python ingest service will
normalize AIS events into the portal database.

The existing OpenLayers Live Map will display aircraft and AIS targets together
on the same map canvas. Existing aircraft icons and altitude colors will remain
unchanged. AIS vessels, SAR targets, base stations, buoys, and beacons will use
clearly different icons.

## Initial Scope

- Support AIS-catcher as the only AIS decoder in the first release.
- Require a dedicated, uniquely serialized RTL-SDR when other RTL-SDR decoders
  are active.
- Receive timestamped `JSON_FULL` events over loopback UDP.
- Persist normalized target, position, and voyage data in the portal database.
- Optionally retain raw NMEA/JSON messages for a short period.
- Show aircraft and AIS targets simultaneously on the existing Live Map.
- Provide AIS history, target details, tracks, status, and administration.
- Do not enable external AIS sharing or AIS-catcher's web interface by default.

## Phase 1: Decoder Contract

1. Pin a tested AIS-catcher release in `bash/variables.sh`. Do not build an
   unbounded upstream `main` branch.
2. Test AIS-catcher with a dedicated RTL-SDR and capture representative
   `JSON_FULL` packets for dynamic position, static/voyage, base station, SAR,
   aid-to-navigation, and long-range messages.
3. Add sanitized packets as backend test fixtures. The initial target set should
   include AIS message types 1/2/3, 4, 5, 9, 18, 19, 21, 24, and 27 when
   available.
4. Require receive timestamps and decoder metadata, including `rxuxtime`,
   `channel`, `mmsi`, `type`, `nmea`, and optional signal fields.
5. Define normalization rules for invalid coordinates, AIS sentinel values,
   partial static reports, unknown fields, and future message types.
6. Define a deterministic duplicate fingerprint from canonical NMEA sentences,
   receiver identity, and a bounded receive-time bucket. Verify that it rejects
   duplicate delivery without collapsing legitimate repeated reports.

## Phase 2: Installation and Services

1. Add `bash/decoders/ais-catcher.sh`, following `acarsdec.sh` for source builds
   and `dumpvdl2.sh` for external configuration.
2. Install the required compiler, CMake, `pkg-config`, RTL-SDR, and AIS-catcher
   dependencies through the existing package helpers.
3. Clone the pinned release, build a headless binary where supported, install
   it, and clean temporary build artifacts consistently with existing decoders.
4. Create an installer-owned `/etc/default/ais-catcher` or
   `/etc/AIS-catcher/config.cmd` configuration.
5. Configure AIS-catcher to:
   - Select the assigned RTL-SDR by stable serial using `-d`.
   - Decode both AIS channels.
   - Add receive timestamps and optional signal metadata.
   - Send `JSON_FULL` messages to `127.0.0.1:5556` over UDP.
   - Keep community sharing and the built-in web viewer disabled by default.
6. Install and enable a hardened `ais-catcher.service` with journal logging,
   restart policy, and the project's service user/group conventions.
7. Extend `install.sh`, `bash/main.sh`, and `bash/functions.sh` with AIS decoder
   selection, installed-version detection, reinstall/upgrade dispatch, and
   device assignment.
8. Display all decoder-to-device assignments before applying them. Reject a
   duplicate RTL-SDR assignment and preserve the AIS serial during reinstall.
9. Add an `install_ais_ingest_service()` helper, analogous to the ACARS ingest
   helper, and install `ais-ingest.service` when the portal is available.
10. Make all installation and service recreation steps idempotent.

### Hardware Guidance

- AIS needs its own RTL-SDR when dump1090, dump978, ACARS, or VDL2 is using
  another tuner.
- Assign unique serial numbers to every RTL-SDR. Enumeration indexes are not
  stable enough for a multi-receiver installation.
- Recommend an antenna suitable for the marine VHF AIS frequencies and document
  optional filtering, PPM correction, gain, AGC, and bias-tee configuration.
- Document `rtl_test`, device enumeration, service status, journal inspection,
  UDP loopback testing, reboot verification, upgrade, and rollback.
- State that this feature is for hobbyist/research use and must not be relied on
  for navigation or safety of life or property.

## Phase 3: Ingestion and Persistence

Add the following SQLAlchemy models to the main portal database:

### `AisTarget`

- Unique MMSI and target kind.
- Vessel/static identity, including IMO, callsign, name, vessel type, and
  dimensions.
- First and last seen timestamps.
- Latest valid coordinates, speed, course, heading, turn rate, navigation
  status, channel, and position timestamp.
- Target kinds for vessels, base stations, SAR aircraft, aids to navigation,
  and other AIS transmitters.

### `AisPosition`

- Target foreign key and receive timestamp.
- AIS message type and channel.
- Coordinates, speed, course, heading, turn rate, and navigation status.
- Signal metadata when supplied by AIS-catcher.
- Duplicate fingerprint with a uniqueness constraint.

### `AisVoyageReport`

- Target foreign key and report timestamp.
- Historical IMO, callsign, name, vessel type, and dimension snapshot.
- Destination, ETA components, and draught.

### `AisRawMessage`

- Optional original NMEA and/or decoded JSON payload.
- Receive metadata and expiry timestamp.
- Disabled by default and governed by an independent short retention period.

Create a new Alembic revision after `0001_initial_schema.py`; do not modify the
existing initial migration. Add indexes for MMSI, last-seen queries, target track
queries, live bounding/time queries, voyage history, and raw-message expiry.
Define foreign-key cascades and test both upgrade and downgrade paths.

### Ingest Service

Implement `backend/ais_ingest.py` as a persistent loopback UDP server, following
the lifecycle patterns in `acars_ingest.py` while using the main Flask app and
SQLAlchemy database.

The service must:

- Validate datagram size, JSON structure, field types, timestamps, and ranges.
- Normalize AIS sentinel and unavailable values.
- Classify each transmitter and message type.
- Merge Type 24 Part A and Part B reports in either arrival order.
- Update static identity without erasing previously known values when fields are
  absent from a later report.
- Append positions and voyage reports while atomically updating current target
  state.
- Batch commits to limit SQLite write contention.
- Roll back failed transactions and retry transient database locks with bounded
  backoff.
- Count received, accepted, duplicate, invalid, and failed messages.
- Handle future AIS-catcher fields without crashing.
- Shut down cleanly on `SIGTERM`.

Recommended retention defaults are 30 days for normalized position/voyage
history and 7 days for optional raw messages. Extend the maintenance job to
purge records in bounded batches and remove only inactive orphan targets.

## Phase 4: Backend API

Add and register an AIS Flask-RESTX namespace. Do not add a scheduled collection
job because UDP ingestion is event-driven.

Provide these endpoints:

- `GET /api/ais/live`: fresh targets with valid latest positions, optional
  bounding-box and target-type filters.
- `GET /api/ais/targets`: paginated history searchable by MMSI, IMO, name,
  callsign, target kind, vessel type, and seen range.
- `GET /api/ais/targets/{mmsi}`: current static and dynamic target summary.
- `GET /api/ais/targets/{mmsi}/positions`: bounded, paginated track history.
- `GET /api/ais/targets/{mmsi}/voyages`: paginated voyage/static history.
- `GET /api/ais/status`: last packet, last valid message, and ingest health.
- `GET /api/ais/stats`: target, message, and storage counts and rates.
- Authenticated settings and purge endpoints using existing authorization
  patterns.

Allowlist settings for AIS map visibility, live freshness, filters, history
retention, raw capture, and raw retention. Keep decoder service and RTL-SDR
configuration installer-owned in the first release rather than granting the web
process privileged configuration access.

## Phase 5: Shared Aircraft and AIS Live Map

There will be exactly one live map: the existing aircraft OpenLayers map in
`live.component.ts`.

1. Request aircraft and AIS live data in the same polling cycle.
2. Render both target groups on the existing map instance and canvas at the same
   time and make both visible by default.
3. Keep separate in-memory vector sources/layers for rendering, refresh, z-order,
   filtering, and failure isolation. These are implementation layers, not
   separate maps.
4. A failed aircraft request must not remove AIS targets, and a failed AIS
   request must not remove aircraft.
5. Preserve all existing aircraft icons, altitude colors, trails, selection, and
   flyout behavior.
6. Add visibly different AIS icons:
   - Vessel silhouettes, differentiated by vessel class where practical.
   - A rescue/SAR symbol for AIS SAR aircraft.
   - An antenna symbol for AIS base stations.
   - Buoy and beacon symbols for physical and virtual aids to navigation.
7. Rotate moving vessel and SAR icons using heading or course. Use an explicit
   stale treatment without reusing the aircraft altitude palette.
8. Add AIS visibility and target-type filters without hiding aircraft by
   default.
9. Use typed feature identities such as `aircraft:{hex}` and `ais:{mmsi}` so an
   ICAO address and MMSI cannot collide.
10. Generalize map selection and the flyout to show domain-specific details.
    AIS details should include MMSI, name, callsign, vessel/target type,
    navigation status, speed, course, heading, destination, ETA, draught, last
    seen, and recent track when known.
11. Keep the combined controls, map, and flyout usable on desktop and mobile.

## Phase 6: AIS History and Administration

Add `/ais` as a history and detail experience, not a second live map:

- Searchable and filterable target history.
- Target details with current identity and navigation state.
- Bounded position-track replay on a map.
- Voyage and static-report history.
- Graceful display when position reports arrive before static Type 5/24 data.

Add `/admin/ais` for:

- Shared-map AIS visibility and freshness defaults.
- History and raw-message retention.
- Raw capture enablement.
- Database counts and ingest status.
- Last valid message and error state.
- Confirmed purge operations.

Add setting-controlled AIS history and admin navigation using the existing
navbar and admin guard patterns.

## Phase 7: Tests and Verification

### Installer and Hardware

- Run `bash -n` and the repository shell linter, if configured.
- Test clean install, reinstall, pinned upgrade, failed-build recovery, and
  idempotent service recreation on supported Debian/Raspberry Pi architectures.
- Run dump1090 or dump978 and AIS-catcher simultaneously with uniquely
  serialized dongles.
- Verify assignments survive reboot and reinstall, and duplicate assignment is
  rejected before services restart.
- Verify both AIS channels produce timestamped `JSON_FULL` events over loopback.

### Backend

- Test every captured AIS message type and future/unknown fields.
- Test Type 24 merge order, invalid coordinates, sentinel values, timestamps,
  duplicates, transaction rollback, batching, and database-lock retry.
- Test live freshness, pagination, filters, authorization, retention boundaries,
  and bounded purge behavior.
- Test Alembic upgrades and downgrades against empty and populated databases.
- Run focused AIS pytest modules followed by the full backend test suite.
- Replay fixtures continuously to measure throughput, duplicate handling,
  database growth, and SQLite lock behavior.

### Frontend

- Test aircraft and AIS success/failure independently during shared polling.
- Test simultaneous rendering, layer toggles, filters, z-order, typed identity,
  icon classification, stale states, selection, flyouts, aircraft trails, and
  AIS tracks.
- Test history pagination, target details, admin authorization, settings, purge
  confirmation, and navbar visibility.
- Run focused Angular tests, the full headless suite, and a production build.
- Use browser screenshots and pixel checks at desktop and mobile sizes to verify
  that aircraft and distinct AIS icons appear together on one nonblank map with
  no overlapping controls or clipped text.

### Soak Test

Run an end-to-end hardware soak for at least 24 hours. Record message rate,
invalid and duplicate counts, CPU and memory, database growth, SQLite lock time,
API latency, combined aircraft/AIS marker count, browser responsiveness, service
restart recovery, and retention cleanup.

## Phase 8: Documentation and Release

1. Update `README.md`, `CHANGELOG.md`, `CREDITS.md`, and portal documentation.
2. Document AIS-catcher licensing and attribution, supported hardware, antenna
   guidance, storage growth, retention defaults, operations, and troubleshooting.
3. Extend portal backup and restore tooling for AIS tables and settings while
   preserving compatibility with backups created before AIS support.
4. Roll out through decoder-only, ingest/database, shared-map beta, and general
   release checkpoints.
5. Tune batching, indexes, freshness, retention, and frontend marker handling
   using soak-test evidence.

## Primary Files

- `install.sh`
- `bash/main.sh`
- `bash/variables.sh`
- `bash/functions.sh`
- `bash/decoders/ais-catcher.sh`
- `build/portal/backend/backend/models.py`
- `build/portal/backend/backend/ais_ingest.py`
- `build/portal/backend/backend/__init__.py`
- `build/portal/backend/backend/jobs/maintenance.py`
- `build/portal/backend/backend/routes/ais.py`
- `build/portal/backend/backend/routes/settings.py`
- `build/portal/backend/migrations/versions/`
- `build/portal/backend/tests/`
- `build/portal/frontend/src/app/shared/api-types.ts`
- `build/portal/frontend/src/app/service/data.service.ts`
- `build/portal/frontend/src/app/live/`
- `build/portal/frontend/src/app/ais/`
- `build/portal/frontend/src/app/admin-ais/`
- Portal backup and restore scripts and documentation

## Deferred Work

- Alternate AIS decoders and generic NMEA network receivers.
- External community/feed sharing.
- AIS-catcher managed web UI integration.
- AIS alerts and maritime geofences.
- Direct AIS-catcher PostgreSQL output.
- Arbitrary decoder command-line editing through the portal.
- Any navigation or safety-of-life use.