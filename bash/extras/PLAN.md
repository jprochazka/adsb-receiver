# ADS-B Portal Legacy Data Migration Plan

> This is a planning document only. Do not modify `portal.sh` or migration code until implementation is explicitly requested.

## Goal

Modify `bash/extras/portal.sh` so the new Flask/Angular portal installer can detect and optionally import data from the old PHP ADS-B Portal during installation, while preserving the current fresh-install path when no legacy data exists or the user declines import.

## Architecture

Keep `portal.sh` as the user-facing orchestrator and add small, testable helper scripts under `build/portal/backend` for actual data conversion. The installer should discover legacy PHP portal configuration/data, show the user exactly what was found, require explicit consent before import, back up existing/new target data before writing, then run the importer before/around Alembic migration stamping as appropriate. RRD file migration remains file-based and optional, but should search all known old graph/portal RRD locations and only copy files when legacy `.rrd` files exist.

## Source Context

Current new installer:
- `bash/extras/portal.sh`
  - Installs backend from `build/portal/backend`.
  - Installs frontend from `build/portal/frontend`.
  - Supports SQLite, MySQL/MariaDB, and PostgreSQL target databases.
  - Already has limited existing-new-schema reuse/stamp behavior and a narrow RRD migration check for `/usr/local/share/graphs1090/rrd`.

Old portal installer on `origin/master`:
- `bash/portal/install.sh`
  - Detects old install by reading `<document-root>/classes/settings.class.php`.
  - Old storage engines: `xml`, `sqlite`, `mysql`; install UI also contains PostgreSQL SQL in PHP (`pgsql`), so import design should account for PostgreSQL even if bash flow exposed fewer paths.
  - Old SQLite path default: `<document-root>/data/portal.sqlite`.
  - Old table prefix default: `adsb_`.
- `bash/portal/advanced.sh`
  - Emits old database settings JSON for advanced portal configuration.
- `build/portal/html/install/index.php`
  - Creates initial old XML files under `<document-root>/data`.
  - Creates old SQL tables: `administrators`, `aircraft`, `blogPosts`, `flights`, `links`, `flightNotifications`, `positions`, `settings` with prefix support.
  - Adds default settings and first administrator account.
- `build/portal/html/install/upgrade*.php`
  - Incremental PHP upgrade files up to `2.8.10`; inspect these before implementation to capture added/renamed settings or schema changes.

New backend schema reference:
- `build/portal/backend/backend/models.py`
- `build/portal/backend/migrations/versions/0001_initial_schema.py`

## Non-Goals

- Do not import anything automatically without a positive user choice.
- Do not delete old portal data.
- Do not overwrite target records without a backup and duplicate-handling strategy.
- Do not migrate PHP code or preserve old PHP UI behavior.
- Do not require legacy data for install success; a fresh install must remain the default when no importable data exists.
- Do not treat absence of legacy data as an error.

## Progress Checklist

Legend: `[ ]` not started, `[~]` in progress, `[x]` complete, `[!]` blocked.

Items are only complete after targeted validation and the relevant full verification pass.

- [ ] Phase 0 — Inventory legacy data formats and target schema mappings.
- [ ] Phase 1 — Add read-only legacy discovery to `portal.sh`.
- [ ] Phase 2 — Add explicit import/fresh-install decision flow.
- [ ] Phase 3 — Implement database/XML export helpers.
- [ ] Phase 4 — Implement target import helpers with backup and idempotency safeguards.
- [ ] Phase 5 — Integrate import timing with database creation, Alembic stamp/upgrade, and permissions.
- [ ] Phase 6 — Add lighttpd-to-Nginx takeover handling for upgrades from the old portal.
- [ ] Phase 7 — Expand optional RRD migration discovery/copy behavior.
- [ ] Phase 8 — Add tests/fixtures for every supported source and target path.
- [ ] Phase 9 — Run installer-level validation and document operator behavior.

## Commit Tracking

| Status | Phase | Commit SHA | Notes |
| --- | --- | --- | --- |
| [ ] | 0 |  | Legacy/source schema inventory and mapping notes. |
| [ ] | 1 |  | Read-only discovery helpers; no data writes. |
| [ ] | 2 |  | Whiptail decision flow for import vs fresh install. |
| [ ] | 3 |  | Legacy export helpers and fixtures. |
| [ ] | 4 |  | Target import helpers with backups/idempotency. |
| [ ] | 5 |  | `portal.sh` integration and migration ordering. |
| [ ] | 6 |  | Detect existing lighttpd, preserve legacy document root for import, then safely stop/disable it before Nginx takes port 80. |
| [ ] | 7 |  | RRD migration expansion. |
| [ ] | 8 |  | Automated tests and fixture coverage. |
| [ ] | 9 |  | Final validation and docs. |

## Data Detection Rules

### Legacy portal root detection

Add a helper in `portal.sh`, likely `find_legacy_portal_root()`, that checks candidate document roots for:

- `${lighttpd_document_root}/classes/settings.class.php` when lighttpd exists.
- `/var/www/html/classes/settings.class.php`.
- `/var/www/classes/settings.class.php`.
- `/usr/share/adsb-receiver/build/portal/html/classes/settings.class.php` if applicable.
- An optional manual path prompt when likely data is found but settings cannot be auto-located.

Detection must be read-only.

### Legacy settings parsing

Parse old PHP constants from `classes/settings.class.php`:

- `settings::db_driver`: `xml`, `sqlite`, `mysql`, and possibly `pgsql`.
- `settings::db_database`.
- `settings::db_username`.
- `settings::db_password`.
- `settings::db_host`.
- `settings::db_prefix`, defaulting to `adsb_` when absent.

Avoid brittle one-off `grep | cut` chains if possible. Prefer a small parser helper that reads constants robustly and emits JSON, e.g.:

- `build/portal/backend/tools/legacy_portal_discover.py`

Expected JSON shape:

```json
{
  "found": true,
  "root": "/var/www/html",
  "driver": "sqlite",
  "database": "/var/www/html/data/portal.sqlite",
  "host": "",
  "username": "",
  "prefix": "adsb_",
  "xml_files": {
    "administrators": "/var/www/html/data/administrators.xml",
    "blog_posts": "/var/www/html/data/blogPosts.xml",
    "links": "/var/www/html/data/links.xml",
    "settings": "/var/www/html/data/settings.xml",
    "notifications": "/var/www/html/data/flightNotifications.xml"
  },
  "counts": {
    "administrators": 1,
    "aircraft": 123,
    "flights": 456,
    "positions": 789,
    "links": 2,
    "settings": 30
  }
}
```

### Importable data threshold

Only offer import when at least one importable source contains real data:

- XML: one or more non-empty records in `administrators.xml`, `blogPosts.xml`, `links.xml`, `settings.xml`, or `flightNotifications.xml`.
- SQLite: file exists, is non-empty, can be opened, and contains at least one old table with row count > 0.
- MySQL/PostgreSQL: connection succeeds and at least one expected old table has row count > 0.
- RRD: at least one `*.rrd` file exists under a known legacy RRD path.

If no importable data is detected, skip all import prompts and continue fresh install.

## User Decision Flow

1. After selecting target DB type but before writing/destructive target changes, run legacy discovery.
2. If legacy database/XML data is found, show a summary:
   - legacy portal root
   - source driver
   - source database path/name/host where applicable
   - table/file counts
   - RRD source count/path if found
3. Ask:
   - `Import legacy portal data into the new portal?`
4. If user answers `No`:
   - Set `LEGACY_IMPORT_ENABLED=false`.
   - Continue fresh install.
   - Do not modify legacy source data.
5. If user answers `Yes`:
   - Set `LEGACY_IMPORT_ENABLED=true`.
   - Require confirmation that the target DB may receive imported records.
   - Create target backup when the target already has tables/data.
6. Separately ask about RRD import only if `.rrd` files exist:
   - User may import DB data but skip RRD, or import RRD but skip DB data.

## Legacy-to-New Data Mapping

### Administrators / users

Old SQL/XML:
- `administrators`: `id`, `name`, `email`, `login`, `password`, `token`.

New:
- `users`: `id`, `name`, `email`, `password`, `administrator`, `role`, `locked`, `created_at`.

Plan:
- Preserve password hashes as-is if they are PHP `password_hash` / bcrypt compatible with the new auth flow; verify before implementation.
- Set `administrator=1`, `role='admin'`, `locked=false`, `created_at=now()` when old data lacks created time.
- Prefer old `email` for uniqueness.
- Do not import `token` unless a matching new token model/route exists.
- Resolve duplicate emails by skipping duplicates and logging them, unless user explicitly approves replacement in a later enhancement.

### Blog posts

Old:
- `blogPosts`: `id`, `title`, `date`, `author`, `contents`.

New:
- `blog_posts`: `id`, `title`, `date`, `author`, `content`, `visible`, `tags`, `category`.

Plan:
- Map `contents -> content`.
- Set `visible=true`.
- Set `tags=''`, `category=''` or `uncategorized` depending on current UI expectations.
- Preserve old IDs only if safe in an empty target; otherwise insert with new IDs and log ID mapping.

### Links

Old:
- `links`: `id`, `name`, `address`.

New:
- `links`: `id`, `name`, `address`, `sort_order`.

Plan:
- Map `name`, `address` directly.
- Set `sort_order` by old `id` ordering or source order.

### Flight notifications

Old:
- `flightNotifications`: `id`, `flight`.

New:
- `notifications`: `id`, `flight`.

Plan:
- Map directly.
- Trim flight values and skip empty rows.

### Settings

Old:
- `settings`: `id`, `name`, `value`.
- XML `settings.xml` for lite installs.

New:
- `settings`: `id`, `name`, `value` with unique `name`.
- New config is mostly `config.yml`; not every old setting should become a new UI setting.

Plan:
- Import only settings still consumed by the new backend/frontend.
- Start with safe UI/user preferences:
  - `siteName`
  - measurement settings if still supported
  - map center latitude/longitude if still supported
  - feature toggles only when matching new settings exist
- Do not import obsolete PHP template/default-page settings unless the new app reads them.
- Record skipped settings in the log.

### Aircraft/flights/positions

Old:
- `aircraft`: `id`, `icao`, `firstSeen`, `lastSeen`.
- `flights`: `id`, `aircraft`, `flight`, `firstSeen`, `lastSeen`.
- `positions`: `id`, `flight`, `aircraft`, `time`, `message`, `squawk`, `latitude`, `longitude`, `track`, `altitude`, `verticleRate`, `speed`.

New dump1090 tables:
- `dump1090_aircraft`: `id`, `icao`, `first_seen`, `last_seen`.
- `dump1090_flights`: `id`, `aircraft`, `flight`, `first_seen`, `last_seen`, `emitter_category`, `message_type`, `aircraft_class`, `ignore_on_purge`.
- `dump1090_positions`: `id`, `flight`, `aircraft`, `time`, `message`, `squawk`, `latitude`, `longitude`, `track`, `altitude`, `vertical_rate`, `speed`.

Plan:
- Treat old portal flight data as dump1090 data unless discovery finds explicit UAT/dump978 source markers.
- Map `firstSeen -> first_seen`, `lastSeen -> last_seen`, `verticleRate -> vertical_rate`.
- Set `emitter_category=NULL`, `message_type=NULL`, `aircraft_class='unknown'`, `ignore_on_purge=false`.
- Preserve foreign-key relationships by building source-to-target ID maps for aircraft and flights.
- If target is empty, preserve IDs where safe; otherwise generate new IDs and remap dependent rows.
- Insert positions after aircraft/flights.
- Validate coordinates/ranges; skip malformed positions with a log entry rather than failing the entire import.

### UAT/dump978 data

The old PHP schema appears to have one generic aircraft/flights/positions set. The new schema has both dump1090 and dump978 tables.

Plan:
- Default import to dump1090 tables.
- Add a plan note/open question for whether any old portal installs stored UAT separately; if yes, add source detection and dump978 mapping.

### ACARS data

Old install settings include `acarsserv_database`, but old install schema does not create ACARS tables in `index.php`.

Plan:
- Discovery should detect configured ACARS database path if present.
- Do not import ACARS in the first implementation unless target schema and source format are confirmed.
- Log `ACARS source detected but not imported` and track follow-up if needed.

## RRD Migration Plan

Current `portal.sh` only searches:
- `/usr/local/share/graphs1090/rrd`

Expand discovery to include likely old graph locations:
- `/usr/local/share/graphs1090/rrd`
- `/var/lib/collectd/rrd`
- `/var/www/html/graphs/rrd`
- `/var/www/html/data/rrd`
- legacy portal root-relative `data/rrd`, `graphs/rrd`, and `rrd`

Rules:
- Only offer RRD migration if at least one `*.rrd` file exists.
- Use `rsync -a --ignore-existing` when available; otherwise `cp -an`.
- Preserve directory layout and timestamps.
- Do not overwrite new RRD files.
- Set ownership/permissions after copy: `www-data:www-data`, readable by backend service.
- Log copied count and skipped existing count.

## Implementation Phases

### Phase 0 — Inventory and fixture extraction

Objective: document all importable old data shapes before writing logic.

Files to inspect:
- `origin/master:bash/portal/install.sh`
- `origin/master:bash/portal/advanced.sh`
- `origin/master:build/portal/html/install/index.php`
- `origin/master:build/portal/html/install/upgrade*.php`
- `origin/master:build/portal/html/classes/*.class.php`
- `build/portal/backend/backend/models.py`
- `build/portal/backend/migrations/versions/0001_initial_schema.py`

Deliverables:
- Add/update mapping comments in this PLAN.md.
- Create test fixtures only when implementation starts, likely under `build/portal/backend/tests/fixtures/legacy_portal/`.

Validation:
- No production code changes in Phase 0.
- Confirm exact old table/file names and old setting names.

### Phase 1 — Read-only discovery helper

Objective: add safe source detection without import.

Likely files:
- Create `build/portal/backend/tools/legacy_portal_discover.py`.
- Modify `bash/extras/portal.sh` to call it after target DB choice.
- Add tests under `build/portal/backend/tests/test_legacy_portal_discover.py`.

Requirements:
- Parse PHP constants without executing PHP.
- Count XML records without mutating files.
- Count SQLite old tables with `sqlite3` read-only connection.
- For MySQL/PostgreSQL, use credentials only after user confirms probing remote DB is OK.
- Emit structured JSON and a human-readable summary.

Verification:
- Unit tests for XML, SQLite, and settings parser fixtures.
- `bash -n bash/extras/portal.sh`.
- Backend test subset for helper.

### Phase 2 — Installer decision flow

Objective: prompt only when data exists and preserve fresh-install behavior.

Modify:
- `bash/extras/portal.sh`

Requirements:
- Add variables:
  - `LEGACY_IMPORT_ENABLED=false`
  - `LEGACY_SOURCE_DRIVER=""`
  - `LEGACY_SOURCE_ROOT=""`
  - `LEGACY_SOURCE_SUMMARY=""`
  - `LEGACY_IMPORT_STATUS="No legacy database import requested"`
- Show prompt only when discovery reports importable data.
- If user declines, do nothing else and keep fresh install.
- If user accepts, retain discovery JSON path for importer.
- RRD prompt remains separate.

Verification:
- `bash -n bash/extras/portal.sh`.
- Use mocked helper output to test prompt branches where practical.

### Phase 3 — Legacy export helpers

Objective: normalize old XML/SQL data into one intermediate JSON/JSONL format.

Likely files:
- Create `build/portal/backend/tools/legacy_portal_export.py`.
- Tests in `build/portal/backend/tests/test_legacy_portal_export.py`.

Requirements:
- Support source drivers: `xml`, `sqlite`, `mysql`, `pgsql/postgresql` where possible.
- Respect old `db_prefix`, default `adsb_`.
- Export sections independently:
  - users/admins
  - blog posts
  - links
  - notifications
  - settings
  - aircraft/flights/positions
- Include source row IDs for relationship remapping.
- Never write to source.

Verification:
- Fixture-based tests compare normalized output for XML and SQLite.
- Optional MySQL/PostgreSQL tests can be marked/integration-gated unless containers are available.

### Phase 4 — Target import helper

Objective: import normalized data into the new SQLAlchemy models safely.

Likely files:
- Create `build/portal/backend/tools/legacy_portal_import.py`.
- Tests in `build/portal/backend/tests/test_legacy_portal_import.py`.

Requirements:
- Run after target database connection config exists.
- Ensure target schema exists via `flask db upgrade` before import unless using a controlled stamp path for legacy-new-schema reuse.
- Create a backup before import:
  - SQLite: copy `instance/adsbportal.sqlite3` to timestamped `.bak` if file exists.
  - MySQL/PostgreSQL: dump selected target tables if client tools exist (`mysqldump`, `pg_dump`); otherwise require extra confirmation and log that dump was unavailable.
- Insert in dependency order: users/settings/blog/links/notifications, then aircraft, flights, positions, comments if implemented later.
- Preserve IDs only when target tables are empty; otherwise remap IDs.
- Use transactions; rollback on fatal import errors.
- Produce summary counts imported/skipped/failed.

Verification:
- SQLite end-to-end test using temporary target DB.
- Duplicate handling tests.
- Relationship remapping tests for aircraft/flights/positions.

### Phase 5 — Integrate with database provisioning/migrations

Objective: make `portal.sh` execute import at the right time for all target DB choices.

Modify:
- `bash/extras/portal.sh`

Ordering recommendation:
1. Write `config.yml`.
2. Install packages and Python dependencies.
3. Create/provision target DB if needed.
4. Test target DB connectivity.
5. Run `flask db upgrade` to create new schema for fresh target DB.
6. If `LEGACY_IMPORT_ENABLED=true`, run export/import helper.
7. Run a final `flask db upgrade` or schema validation check.
8. Complete lighttpd-to-Nginx takeover handling after all legacy source data has been discovered/exported and before Nginx is restarted.
9. Continue permissions/frontend/nginx/systemd setup.

Notes:
- Do not try to Alembic-stamp an old PHP schema as if it were the new schema. Old tables use different names/columns and must be converted into the new schema.
- Existing current-new-schema reuse/stamp logic should remain separate from old-PHP import logic.
- If target database already contains new portal data, import should merge only after confirmation and backup.

Verification:
- `bash -n bash/extras/portal.sh`.
- Dry-run/mocked import command path.
- Full backend tests.

### Phase 6 — lighttpd-to-Nginx takeover

Objective: handle upgrades from the old PHP/lighttpd portal safely before Nginx takes ownership of port 80.

Modify:
- `bash/extras/portal.sh`

Requirements:
- Detect whether lighttpd is installed and/or active:
  - `dpkg-query -W lighttpd`
  - `systemctl is-active lighttpd`
  - `systemctl is-enabled lighttpd`
  - `ss -ltnp` or equivalent best-effort check for port 80 ownership.
- Determine the lighttpd document root before stopping lighttpd:
  - Prefer `/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root` when available.
  - Fall back to common paths such as `/var/www/html`.
- Feed the detected document root into legacy portal discovery so old data is inspected before any web-server takeover.
- If Nginx will be the selected/default web server and lighttpd is active on port 80:
  - Tell the user Nginx will replace lighttpd for the new Flask/Angular portal.
  - Stop and disable lighttpd after legacy data discovery/export is complete, but before `nginx -t`/Nginx restart.
  - Do not purge/remove lighttpd packages by default.
  - Keep old lighttpd document root files intact unless the user explicitly requests cleanup in a future phase.
- If stopping/disabling lighttpd fails, abort before restarting Nginx and show the log.
- If Nginx configuration/start fails after lighttpd was stopped, attempt a best-effort rollback:
  - re-enable/restart lighttpd if it was active/enabled before takeover;
  - log rollback success/failure clearly.
- Record final status in the installer completion dialog:
  - lighttpd not installed/not active;
  - lighttpd stopped and disabled;
  - lighttpd rollback attempted because Nginx failed.

Recommended variables:
- `LIGHTTPD_INSTALLED=false`
- `LIGHTTPD_ACTIVE_BEFORE=false`
- `LIGHTTPD_ENABLED_BEFORE=false`
- `LIGHTTPD_DOCROOT=""`
- `LIGHTTPD_TAKEOVER_STATUS="No lighttpd takeover needed"`

Verification:
- `bash -n bash/extras/portal.sh`.
- Mocked shell-function test or temporary script harness for these cases:
  - no lighttpd installed;
  - lighttpd installed but inactive;
  - lighttpd active and Nginx starts successfully;
  - lighttpd active and Nginx fails, triggering rollback attempt.
- Manual integration check on a VM/container with lighttpd listening on port 80 before running installer.

### Phase 7 — RRD migration expansion

Objective: migrate existing `.rrd` files only when present and approved.

Modify:
- `bash/extras/portal.sh`

Requirements:
- Expand `find_legacy_rrd_source()` candidates.
- Count `.rrd` files and show count/path in prompt.
- Copy with `rsync -a --ignore-existing` or `cp -an`.
- Log summary and set `RRD_MIGRATION_STATUS` accurately.

Verification:
- Shell syntax check.
- Temporary-directory test where candidate source has `.rrd` files and target receives copies without overwrites.

### Phase 8 — Test matrix

Automated/unit tests:
- Parser handles PHP constants with single quotes, spaces, and missing optional constants.
- XML fixtures import admins/blog/settings/links/notifications.
- SQLite fixture imports all old SQL tables.
- Target SQLite import maps old table names/columns to new schema.
- Duplicate users/settings are skipped or updated according to chosen strategy.
- Flight/position foreign keys are preserved through ID mapping.
- Empty source produces `found=false` or `importable=false` and no import prompt.

Manual/integration checks:
- Fresh install path: no old data present -> no import prompt -> new empty portal installed.
- User declines import -> no legacy DB/XML reads beyond discovery and no target import.
- SQLite old portal -> new SQLite target import.
- SQLite old portal -> new MySQL target import, if MySQL is available.
- MySQL old portal -> new SQLite target import, if source test DB is available.
- PostgreSQL target provisioning still works.
- RRD present/declined and RRD present/accepted.
- lighttpd installed/active before upgrade -> legacy document root detected -> lighttpd stopped/disabled only after legacy data handling -> Nginx starts on port 80.
- lighttpd installed/active and Nginx start fails -> best-effort lighttpd rollback is attempted and logged.

Commands:

```bash
bash -n bash/extras/portal.sh
cd build/portal/backend
python3 -m pytest tests/test_legacy_portal_discover.py tests/test_legacy_portal_export.py tests/test_legacy_portal_import.py -q
python3 -m pytest -q
cd ../frontend
npm ci
npm run build
```

### Phase 9 — Operator documentation and final handoff

Update installation messaging so users understand:
- Import is optional.
- Fresh install remains available.
- Source data is not deleted.
- Backups are created before target writes where possible.
- Old PHP portal settings not used by the new Angular/Flask app may be skipped.
- RRD migration copies existing files and does not overwrite new files.
- Nginx is the default web server for the new Flask/Angular portal.
- Existing lighttpd installs are treated as legacy sources: document root is inspected before takeover, lighttpd is stopped/disabled only when Nginx is ready to take port 80, and lighttpd packages/config are not purged by default.

Final validation:
- `bash -n bash/extras/portal.sh` passes.
- Backend tests pass.
- Frontend production build passes.
- Git working tree clean.
- Commit and push each phase separately.

## Risks and Tradeoffs

- Old XML mode stores a subset of data; it may not have aircraft/flights/positions. Import should handle partial data gracefully.
- Old SQL table prefix can vary; every query must use detected prefix.
- Old PostgreSQL support appears in PHP install SQL but may not be fully supported by old bash flow; treat as best-effort until verified with fixtures.
- Old password hashes must be verified against the new Python auth stack. If incompatible, import users as locked/admin-disabled and require password reset rather than silently creating unusable accounts.
- Importing large positions tables can be slow. Use batched inserts and progress logging.
- Existing target data creates merge conflicts. Default to skip duplicates and log them rather than destructive replacement.
- lighttpd may already own port 80 on old installs. The installer must discover/export legacy data before stopping it, and should disable rather than purge lighttpd by default so rollback remains possible.
- Nginx takeover can temporarily break the old portal if new Nginx config/start fails. Add best-effort rollback and clear failure messaging.
- RRD file compatibility depends on existing graph definitions. Copying files is low-risk, but graph readers must tolerate legacy filenames/layouts.

## Open Questions Before Implementation

- Does the new backend auth verify PHP `password_hash()` bcrypt hashes directly, or do imported users need forced password reset?
- Should old `administrators.login` be preserved anywhere, or is email the sole login identity in the new portal?
- Which old settings are still consumed by the new Angular/Flask app?
- Did any old installs store dump978/UAT data separately, or should all old aircraft/flights/positions import into dump1090 tables?
- Is ACARS migration required now, or should it remain a follow-up after source/target schema confirmation?
- Should target import allow merging into a non-empty new portal database, or should first implementation require an empty target for database data import?
