# Portal Changelog

This document describes what changed between the legacy ADS-B Receiver Portal
(PHP/lighttpd, last release v2.8.10, `master` branch) and the new portal
(Flask/Angular/Nginx, `cleanup` branch).

---

## Overview

The portal has been rewritten from the ground up. The legacy portal was a
server-rendered PHP application backed by lighttpd. The new portal is a
decoupled architecture: a Python REST API backend (Flask) paired with a
compiled Angular single-page application served by Nginx.

---

## Architecture

| | Legacy Portal (v2.8.10) | New Portal (cleanup) |
|---|---|---|
| Language | PHP 7+ | Python 3.10+ / TypeScript |
| Backend framework | None (raw PHP classes) | Flask + Flask-RESTX |
| Frontend framework | Smarty templates + jQuery + Bootstrap 3 | Angular 22 + Angular Material |
| Web server | lighttpd | Nginx (static) + Gunicorn (API) |
| Process manager | None (PHP-FPM via lighttpd) | systemd (`adsb-portal-backend.service`) |
| API style | None (server-rendered pages + 3 thin PHP API endpoints) | Full REST API with Swagger/OpenAPI docs at `/api/docs/` |
| Authentication | PHP session cookies | JWT access + refresh tokens (Flask-JWT-Extended) |
| ORM | PDO (raw SQL) | SQLAlchemy 2 + Alembic migrations |
| Config file | `classes/settings.class.php` (PHP constants) | `config.yml` (YAML) |
| Schema management | Manual upgrade PHP scripts (`install/upgrade-v*.php`) | Alembic migration files |

---

## Database Support

| Driver | Legacy | New |
|---|---|---|
| XML (flat-file) | Yes (default) | No — removed |
| SQLite | Yes | Yes |
| MySQL / MariaDB | Yes | Yes |
| PostgreSQL | Yes | Yes |
| SQL Server (MSSQL) | Yes (PDO `sqlsrv`) | No — removed |

The XML flat-file driver has been removed. The new portal requires a proper
relational database. SQLite is the default for single-host installs.

---

## Authentication & Users

### Legacy
- Single administrator account. No role system.
- Plain-text or MD5 password hashing (PHP `password_hash()` with bcrypt in later
  versions via PDO class).
- Session-based login via `admin/login.php`.
- Password reset via emailed token (`admin/forgot.php`, `admin/reset.php`).
- Account management at `admin/account.php`.

### New
- Full multi-user system with two roles: **Admin** and **User**.
- bcrypt password hashing (Werkzeug `generate_password_hash`).
- JWT-based stateless authentication. Tokens returned on `POST /api/auth/login`.
- Access token (1 hour) + refresh token (30 days).
- All admin API endpoints require `Admin` role JWT claim.
- Locked account support — locked users cannot log in.
- Self-service account page (`/account`) for name/email/password changes.
- User registration endpoint (`POST /api/users/register`).
- Admin user management: create, update, lock/unlock, delete users
  (`/api/users/*`).
- No email-based password reset in this release.

---

## Flight Data Collection

### Legacy
- Two Python scripts (`build/portal/python/flights.py`,
  `build/portal/python/maintenance.py`) run externally as cron jobs or
  manually.
- ADS-B only (dump1090). No UAT/dump978 collection in the legacy codebase.
- No background scheduler; external cron required.

### New
- Background jobs run inside the Flask app via **APScheduler** — no external
  cron required.
- **dump1090** collection every 15 seconds.
- **dump978 / UAT** collection every 15 seconds (new — not present in legacy).
- **RRD data collection** every 30 seconds.
- **Maintenance / data purge** job runs daily at midnight.
- Aircraft classified by emitter category, message type, and optional
  **OpenSky Network** database lookup by ICAO hex or registration.
- `ignore_on_purge` flag per flight prevents accidental deletion of notable
  records.
- UTC-aware timestamps throughout.

---

## Flight History & Search

### Legacy
- `flights.php` — server-rendered table of past flights.
- Basic pagination only.

### New
- `/api/flights/*` — full REST flight history for ADS-B (dump1090).
- `/api/uat/*` — separate endpoint set for UAT (dump978) flights (new).
- Full-text search across callsign and ICAO hex.
- Pagination with configurable `offset` / `limit`.
- Per-flight position history with map plot view.
- Per-flight comments (threaded, with soft-delete and admin hard-delete).
- Aircraft classification metadata per flight (class, source, confidence).
- Bulk purge by age (`DELETE /api/flights/purge?days=N`).

---

## Live Map

### Legacy
- `dump1090.php` and `dump978.php` — server-rendered pages embedding the
  dump1090/dump978 static map UIs directly.
- Maps were iframes of the decoder's own web UI.

### New
- `/live` — unified live map Angular component using **OpenLayers**.
- Fetches live aircraft JSON from dump1090 and dump978 simultaneously and
  merges them into a single feed.
- Live aircraft data cached server-side with a short TTL to reduce upstream
  load.
- Configurable live map URL, center coordinates, zoom, and trail length via
  the admin settings panel.
- Optional theoretical range ring and HeyWhatsThat rings.
- Aircraft callsign notifications: watchlist of monitored callsigns with
  configurable lookback window.

---

## Graphs

### Legacy
- `graphs.php` — server-rendered page.
- `build/portal/graphs/make-collectd-graphs.sh` and `dump1090.py` generated
  static PNG images via collectd + rrdtool.
- Images served as static files.

### New
- `/api/graphs/*` — REST endpoints return time-series data as JSON arrays.
- Frontend renders interactive charts from the data using **Chart.js** (not static PNGs).
- RRD files read directly via `rrdtool fetch` called from Python.
- Metrics available: dump1090 aircraft/message counts, system CPU, memory,
  disk I/O, disk usage, network I/O, CPU temperature.
- Admin configurable: network interface name, RRD base path.

---

## Blog

### Legacy
- `blog.php` / `post.php` — server-rendered blog listing and post detail.
- `admin/blog/` — add, edit, delete posts via PHP admin pages.
- Data stored in `data/blogPosts.xml` (XML driver) or database table.

### New
- `/api/blog/*` — REST blog API.
- Threaded comments on posts with full create/edit/delete lifecycle.
- Comment soft-delete (content replaced with tombstone, author anonymised).
- Admin hard-delete of comments.
- Blog posts support tags, category, visibility toggle, and scheduled
  publishing (publish by date/time).
- Pagination and tag-based filtering on the post list.
- Angular frontend blog and single-post views.

---

## Links

### Legacy
- `admin/links/` — add, edit, delete links via PHP admin pages.
- Displayed in the sidebar nav.

### New
- `/api/links/*` — REST links API.
- Drag-and-drop sort order via `PUT /api/links/reorder` (stored as
  `sort_order` per row).
- Angular links page and admin links management panel.

---

## Notifications (Flight Watchlist)

### Legacy
- `html/api/notifications.php` — thin PHP endpoint to add/remove callsigns
  from `data/notifications.xml`.

### New
- `/api/notifications/*` — full REST watchlist API.
- Add/remove monitored callsigns (authenticated users and admins).
- `GET /api/notifications/recent` — returns matching flights seen within a
  configurable lookback window.
- Lookback duration configurable via admin settings (`notification_lookback_minutes`).

---

## ACARS

### Legacy
- `acars.php` — server-rendered ACARS page reading from an external acarsdec
  SQLite database.

### New
- `/api/acars/*` — full REST ACARS API.
- Flight list, per-flight message list, message counts, database info.
- Aircraft classification enrichment on ACARS flights using OpenSky database.
- Admin purge endpoint (`DELETE /api/acars/purge?days=N`).
- Configurable database path via `config.yml`.
- Angular ACARS page and admin ACARS management panel.

---

## System / Devices

### Legacy
- `system.php` — server-rendered page showing feeder device status.
- `html/api/system.php` — thin JSON endpoint for device info.

### New
- `/api/devices/*` — REST device status API.
- Angular devices page and admin devices panel.
- Separate admin feeders view.

---

## Admin Panel

### Legacy
- Separate PHP admin area at `/admin/` with individual pages for each concern.
- Bootstrap 3 + jQuery UI.
- Multi-step wizard installer at `/install/index.php`.
- Manual upgrade scripts at `/install/upgrade-v*.php`.

### New
- Single-page Angular admin area with sidebar navigation.
- Admin sections: Users, Blog, Flights, Links, Devices, Feeders, Live Map,
  Graphs, ACARS, Scheduler.
- Scheduler admin panel gives live visibility into APScheduler job status.
- No wizard installer in the browser — setup is handled entirely by the bash
  installer (`bash/extras/portal.sh`).
- Database schema managed by Alembic; `flask db upgrade` handles all
  migrations automatically.

---

## Installer

### Legacy
- `bash/extras/portal.sh` installed PHP, lighttpd, and the PHP portal files.
- No web server config management — lighttpd config written manually.
- No service management — lighttpd handled by the OS init.

### New
- `bash/extras/portal.sh` fully replaced:
  - Installs Python 3, Node.js, Nginx, Gunicorn, and all dependencies.
  - Writes `config.yml` from whiptail prompts.
  - Creates the virtualenv, installs Python packages, runs `flask db upgrade`.
  - Runs `npm ci && npm run build` to compile the Angular frontend.
  - Deploys compiled assets to the Nginx webroot.
  - Writes and enables the Nginx server block and systemd service.
  - Optional lighttpd-to-Nginx takeover: detects existing lighttpd, stops and
    disables it after Nginx is confirmed healthy; rolls lighttpd back on
    Nginx failure.
  - Optional legacy portal data import: discovers old PHP portal root,
    reads `settings.class.php`, prompts user to import data, runs
    `legacy_portal_import.py` after `flask db upgrade`.
  - Optional RRD file migration from multiple candidate source paths.

---

## Backup & Restore

### Legacy
- `bash/tools/portal_backup_v2.sh` — backs up lighttpd document root (XML/SQLite/
  MySQL/PostgreSQL data), `settings.class.php`, RRD files, and ACARS database.
- `bash/tools/portal_restore_v2.sh` — restores from a v2 backup archive.

### New
- `bash/tools/portal_backup_v3.sh` — backs up `config.yml`, the SQLite/MySQL/
  PostgreSQL database, RRD files, OpenSky classification cache, and ACARS database.
  Frontend (Angular build artefact) is excluded — it is rebuilt from source.
- `bash/tools/portal_restore_v3.sh` — restores from a v3 backup archive.
  Runs `flask db upgrade` after restoring the database to ensure schema is
  current relative to the installed migration head.

---

## API

### Legacy
Three thin PHP API endpoints existed for external consumers:

- `html/api/flight.php` — flight data
- `html/api/notifications.php` — notification watchlist
- `html/api/system.php` — device/system status

### New
Full REST API with interactive Swagger documentation at `/api/docs/`.
Every feature is exposed as a versioned JSON endpoint:

- `POST   /api/auth/login` — obtain JWT tokens
- `GET/PUT /api/users/*` — user management (admin)
- `GET/POST/PUT/DELETE /api/blog/*` — blog posts and comments
- `GET/POST/DELETE /api/links/*`, `PUT /api/links/reorder`
- `GET/POST/DELETE /api/notifications/*`, `GET /api/notifications/recent`
- `GET /api/flights/*`, `GET /api/uat/*` — flight history and positions
- `GET /api/live` — merged live aircraft feed
- `GET /api/graphs/*` — time-series system and decoder metrics
- `GET/DELETE /api/acars/*` — ACARS flights and messages
- `GET /api/devices/*` — device status
- `GET /api/setting/*`, `PUT /api/setting` — admin settings
- `GET /api/scheduler/*` — APScheduler job status (admin)

---

## Removed

The following are present in the legacy portal but not in the new portal:

- XML flat-file database driver.
- Browser-based installer wizard (`/install/`).
- Manual database upgrade PHP scripts (`/install/upgrade-v*.php`).
- Smarty template engine and all `.tpl` files.
- Bootstrap 3 / jQuery-based admin UI.
- lighttpd dependency — replaced by Nginx.
- `build/portal/graphs/make-collectd-graphs.sh` and `dump1090.py` graph
  generation scripts — replaced by RRD-reading Python job and JSON API.
- `build/portal/html/plot.php` — server-rendered historical flight track map —
  replaced by per-flight position view in the Angular flights component.
- dump978 static map assets bundled in `html/dump978/` (flags, OpenLayers,
  db JSON shards) — the new live map loads decoder data dynamically.
- `admin/import.php` PHP-based data import page.
