# ADS-B Portal — Bug Report & Improvement Plan

This document records bugs, risks, and needed changes found during a review
of the installer (`bash/extras/portal.sh`), backup/restore scripts
(`bash/tools/portal_backup_v*.sh`, `portal_restore_v*.sh`), the Flask
backend (`build/portal/backend/`), and the Angular frontend
(`build/portal/frontend/`).

No changes have been made. Every item below is a candidate for
implementation in a future phase.

Legend: `[bug]` confirmed bug, `[risk]` likely problem under specific
conditions, `[improvement]` quality/correctness improvement, `[security]`
security concern.

---

## 1. Installer — bash/extras/portal.sh

### 1.1 [bug] Status variables set inside `_install` are lost to the parent shell

`_install` is piped into `whiptail --gauge` on line 1006:

```bash
_install | whiptail --title "Installing ADSB Portal" --gauge ...
```

Because this runs `_install` in a subshell (left side of a pipe), all
variable assignments inside it — `RRD_MIGRATION_STATUS`,
`LEGACY_IMPORT_STATUS`, `LIGHTTPD_TAKEOVER_STATUS`, `DB_INSTALL_MODE` —
are invisible to the parent shell. The post-install whiptail status dialogs
(lines 1050–1079) will always show the initial default values, never the
actual outcome.

Fix: export final status values from `_install` to a temp file and read
them back in the parent after the pipe completes, or restructure to avoid
the pipe.

### 1.2 [security] MySQL passwords passed on the command line

Lines 749, 764, 767 pass the MySQL password as `-p"${MYSQL_PASS}"` directly
on the command line. This exposes the password in `ps` output and shell
history. MySQL warns about this with "Using a password on the command line
interface can be insecure."

Fix: write a temporary `~/.my.cnf` or use `--defaults-extra-file=` with a
temp file that contains `[client]\npassword=...`, similar to the pgpass
approach already used for PostgreSQL.

### 1.3 [bug] Nginx config hardcodes `/var/www/adsb-portal` instead of `${WEBROOT}`

Line 924 inside the nginx heredoc writes:

```nginx
root /var/www/adsb-portal;
```

The `WEBROOT` variable is defined at line 14 and used for all file
operations, but the nginx config itself does not expand it — it is a
literal string. If `WEBROOT` is ever changed, the nginx config will point
at the wrong directory.

Fix: use the variable: `root ${WEBROOT};`

### 1.4 [bug] `Type=notify` in systemd unit requires gunicorn `--notify` flag

Line 967 sets `Type=notify` in the systemd unit, which means systemd
expects gunicorn to send a `sd_notify` readiness signal. Without
`--preload` or the `gunicorn[setproctitle]` extra plus `sd_notify`
support, systemd will wait for a signal that never arrives and will time
out (default 90 s), causing service start to fail.

Fix: change to `Type=simple` and use `--bind` as-is, or add the
`sd_notify` shim that gunicorn supports via `gunicorn --config` with a
`when_ready` hook.

### 1.5 [risk] `DB_PASS` defaults to literal `"password"` when no password provided

Lines 595 and 601:

```bash
MYSQL_PASS="${DB_PASS:-password}"
PG_PASS="${DB_PASS:-password}"
```

When `DB_TYPE` is `sqlite`, `DB_PASS` is never set, so these fallbacks
silently produce `"password"` as the MySQL/PostgreSQL password. This is
then written verbatim into `config.yml`. On a reinstall where the user
picks sqlite the config will contain incorrect MySQL/PostgreSQL credentials
rather than empty values.

Fix: use an empty string as the default: `${DB_PASS:-}`.

### 1.6 [risk] Frontend directory checked twice, in wrong order

Line 327 checks that `$FRONTEND_DIR` exists before installation begins
(correct). Line 884 checks again after `npm ci` has already been run on
line 881. If the directory somehow doesn't exist at line 881, `npm ci`
would already have failed before reaching the second check.

Fix: remove the redundant check at line 884 — the early guard at line 327
is sufficient.

### 1.7 [risk] `sudo rm -rf "${WEBROOT:?}"/*` uses glob expansion not quoted removal

Line 910:

```bash
sudo rm -rf "${WEBROOT:?}"/*
```

The `*` glob is unquoted. If `WEBROOT` is empty or contains spaces, the
glob can match unexpected paths. The `:?` guard protects against an empty
variable but not against whitespace or unusual characters in the path.

Fix: use `sudo find "${WEBROOT}" -mindepth 1 -delete` or ensure `WEBROOT`
is validated to contain no special characters immediately after assignment.

### 1.8 [improvement] PostgreSQL provisioning missing `GRANT ON SCHEMA public`

Line 759 grants database-level privileges:

```sql
GRANT ALL PRIVILEGES ON DATABASE "adsbportal" TO "portaluser";
```

PostgreSQL 15+ changed the default schema privileges so that
database-level `GRANT ALL` no longer automatically includes
`GRANT ON SCHEMA public`. Without an explicit schema grant, Alembic
migrations will fail with `permission denied for schema public`.

Fix: add after the database grant:

```bash
sudo -u postgres psql -d "${PG_NAME}" \
    -c "GRANT ALL ON SCHEMA public TO \"${PG_USER}\";"
```

### 1.9 [risk] JWT secret written unescaped into YAML heredoc

Line 656 writes `${JWT_SECRET}` directly into the YAML heredoc:

```yaml
security:
    jwt_secret_key: "${JWT_SECRET}"
```

If the user enters a JWT secret containing `"` or `\`, the resulting YAML
will be syntactically invalid and the backend will fail to start.

Fix: sanitize or base64-encode the secret before embedding it, or write
config.yml using Python/python3 YAML dump instead of a heredoc.

### 1.10 [improvement] No validation that DB_NAME, DB_USER, DB_HOST are non-empty

The whiptail inputboxes for `DB_NAME`, `DB_USER`, and `DB_HOST` (lines
384–398) do not loop on empty input. A user clicking OK with an empty field
will proceed with an empty database name/user which will cause cryptic
failures later during provisioning.

Fix: wrap each inputbox in a while loop that re-prompts if the value is
empty, matching the existing pattern used for JWT_SECRET.

### 1.11 [improvement] `log_message` and `log_alert_message` called before whiptail gauge ends

Status messages via `log_message` inside `_install` write to stdout.
Since `_install` is piped to `whiptail --gauge`, these messages corrupt the
gauge protocol stream and can cause whiptail to display garbled output.

Fix: redirect all `log_message` calls inside `_install` to `${LOG_FILE}`
rather than stdout.

---

## 2. Backup & Restore Scripts

### 2.1 [bug] portal_backup_v3.sh — `_yaml_get` function is defined but barely used

Lines 112–122 define a `_yaml_get()` helper, but it is called only once
(line 152) for MySQL host as a fallback, while all other credential
extractions use inline `python3 -c` one-liners. The function itself invokes
python3 with positional arguments `section` and `key` but uses the wrong
YAML traversal (treats `database.mysql` as a top-level key rather than
nested). This would silently return an empty string for any call.

Fix: either fully adopt the `_yaml_get` helper for all credential reads
(fixing the nested traversal), or remove it and use only the inline
`python3 -c` calls.

### 2.2 [bug] portal_backup_v3.sh — RRD path stripping fails when `rrd_base` is absolute and not under `backend_dir`

Line 255:

```bash
rel_dir="${rrd_dir#${backend_dir}/}"
```

If `graphs.rrd_base` in `config.yml` is set to an absolute path outside
`backend_dir` (e.g. `/var/lib/adsb/rrd`), the string prefix strip produces
the full absolute path unchanged. The archive then stores
`rrd//var/lib/adsb/rrd/hostname/foo.xml`. The restore script strips
`${rrd_archive_dir}/` and prepends `${backend_dir}/`, producing
`${backend_dir}//var/lib/adsb/rrd/...rrd` which is an invalid path.

Fix: detect whether `rrd_base` is under `backend_dir` and store an
indicator in the archive (or store the absolute target path in a manifest
file) so the restore can reconstruct the correct target path regardless of
where `rrd_base` points.

### 2.3 [bug] portal_restore_v3.sh — same RRD path bug as 2.2

Line 319–320 reconstructs the RRD path as `${backend_dir}/${rel%.xml}.rrd`
which will double-embed the absolute path if `rrd_base` is not under
`backend_dir`. Affects any install where the operator configured a
non-default RRD location.

### 2.4 [risk] portal_backup_v2.sh — RRD export creates nested absolute path inside temp dir

Lines 99–102 create:

```bash
"${temporary_directory}/${rrd_file_directory}/${rrd_file_name}.xml"
```

Where `rrd_file_directory` is the full absolute path (e.g.
`/var/lib/collectd/rrd/localhost/dump1090`). This results in paths like:

```
/tmp/backup_DATE//var/lib/collectd/rrd/localhost/dump1090/foo.xml
```

The double slash is harmless, but the restore script in `portal_restore_v2.sh`
uses `grep -oP '(/var|/usr|/home|/opt|/srv|/run).*'` to recover the original
path. This heuristic will fail for RRD files stored under any path that
does not start with one of those prefixes (e.g. `/data/rrd`).

Fix: store a manifest file in the archive mapping XML paths to their
original RRD paths, so the restore does not rely on path heuristics.

### 2.5 [risk] portal_restore_v2.sh — `backed_up_temp_root` computed but never used

Line 110 computes `backed_up_temp_root` but it is never referenced
anywhere in the script. This is dead code and indicates a planned feature
that was not completed.

### 2.6 [risk] portal_restore_v2.sh — lighttpd restarted but not re-enabled when it was enabled before

Line 320 does `sudo systemctl start lighttpd` but never calls
`sudo systemctl enable lighttpd`. If lighttpd was enabled (to start on
boot) before the restore, after the restore it will run now but will not
survive a reboot.

Fix: check `lighttpd_was_enabled` (track this at the start, mirroring the
backup's `LIGHTTPD_ENABLED_BEFORE`) and call `systemctl enable lighttpd`
before `systemctl start`.

### 2.7 [risk] portal_backup_v3.sh — incomplete backup is not cleaned up or flagged on mysqldump failure

Lines 212–215: when `mysqldump` fails, the script prints a warning but
continues. The partial `.sql` file remains in the archive. A restore from
this archive would import an incomplete dump without warning.

Fix: on dump failure, remove the partial output file and either abort the
backup or mark the archive as incomplete in a manifest so the restore
script can detect and reject it.

### 2.8 [improvement] portal_backup_v3.sh — service stop/start should use `|| true` only for non-critical paths

Currently if `sudo systemctl stop` fails (service not found), the script
continues silently. On systems where the service name differs or is not
yet registered, this could leave the service running during backup.

Fix: check whether the service exists before attempting to stop it, and
warn clearly if it is running but cannot be stopped.

---

## 3. Flask Backend

### 3.1 [security] Passwords stored using Werkzeug `generate_password_hash` (pbkdf2:sha256 default)

The backend uses Werkzeug's default hashing (pbkdf2:sha256) for new user
passwords. This is acceptable but bcrypt or argon2 would be more resistant
to brute force. Not a bug but worth tracking as a future improvement given
that bcrypt hashes from imported legacy users are already in the DB.

### 3.2 [risk] `routes/users.py` — no rate limiting on login endpoint

The login route accepts unlimited password attempts. Without rate limiting
or account lockout enforcement on failed logins, the API is vulnerable to
credential brute force.

Fix: implement a failed-attempt counter per email address with temporary
lockout, or add a rate-limiting middleware (e.g. Flask-Limiter).

### 3.3 [risk] `routes/users.py` — user registration open by default

The registration endpoint appears to be accessible without authentication.
On a public-facing install this allows anyone to create accounts.

Fix: add a configurable setting (e.g. `allow_registration: true/false` in
`config.yml`) and gate the register endpoint behind it, or require an admin
invite token.

### 3.4 [risk] `routes/blog.py` — no maximum length enforced on blog post content

Blog post `content` is a `TEXT` column with no server-side length limit
enforced in the route. Extremely large posts could degrade database
performance or cause memory pressure during serialization.

Fix: enforce a reasonable maximum (e.g. 500 KB) in the route validator
before inserting.

### 3.5 [risk] `routes/settings.py` — any authenticated user can read and write all settings

Settings reads and writes do not check for admin role. A non-admin
authenticated user can modify portal-wide settings such as
`live_map_json_url` or `purge_older_data`.

Fix: add `@require_admin` (or equivalent) to the settings write endpoint.

### 3.6 [risk] `jobs/maintenance.py` — purge job deletes data based on a `settings` table value that may not exist

The maintenance job reads `days_to_save` from the settings table. If the
row does not exist (e.g. on a fresh install before the setting is seeded),
the job may raise an unhandled exception or use an unexpected default.

Fix: add a safe fallback default in code when the setting row is absent,
and log a warning.

### 3.7 [improvement] `jobs/rrd_data_collection.py` — `graphs_network_interface` setting hardcodes a fallback of `eth0`

The RRD data collection job falls back to `eth0` when the
`graphs_network_interface` setting is missing. On modern systems the
interface name is rarely `eth0` (e.g. `enp3s0`, `wlan0`). A missing
setting would silently produce empty graphs.

Fix: on first run, auto-detect the primary non-loopback interface and seed
the setting, then warn the user via the admin panel if the interface cannot
be detected.

### 3.8 [risk] `__init__.py` — no `SQLALCHEMY_POOL_RECYCLE` set for MySQL

MySQL closes idle connections after `wait_timeout` (default 8 hours).
Without `SQLALCHEMY_POOL_RECYCLE`, the app will hit "MySQL server has gone
away" errors on long-idle deployments.

Fix: set `SQLALCHEMY_POOL_RECYCLE = 3600` (or read from config) when the
database driver is `mysql`.

### 3.9 [improvement] `routes/dump1090.py` and `routes/dump978.py` — pagination `page` and `per_page` params not validated

These routes accept `page` and `per_page` from query strings without
validating that they are positive integers or capping `per_page`. A caller
passing `per_page=999999` would cause a massive DB query.

Fix: clamp `per_page` to a configurable maximum (e.g. 200) and ensure both
values are positive integers, returning 400 on invalid input.

### 3.10 [risk] `routes/tokens.py` — refresh token not invalidated on logout

On logout the access token is discarded client-side, but if a refresh
token is issued it may not be revoked server-side, leaving a window for
replay.

Fix: implement server-side refresh token tracking with a revocation list or
short TTL, or ensure the logout route explicitly invalidates the refresh
token.

### 3.11 [risk] `routes/common.py` — CORS is likely configured too permissively

Flask-CORS applied globally during development often allows all origins
(`*`). If this is left in place in production, any website can make
authenticated API requests using the user's browser cookies/tokens.

Fix: set `CORS(app, origins=["<explicit-domain>"])` based on a
`config.yml` value, defaulting to same-origin only.

### 3.12 [improvement] `routes/acars.py` — ACARS database path not validated before use

The ACARS route reads the database path directly from config without
checking that the file exists or is accessible. If the path is wrong, the
error will be an unhandled `OperationalError` returned as a 500.

Fix: check file existence on startup and return a clear 503 with a
descriptive message if the ACARS database is not reachable.

---

## 4. Angular Frontend

### 4.1 [bug] API base URL hardcoded as empty string, relying on nginx proxy

`data.service.ts` uses a relative base URL (e.g. `/api/`). This works when
served through nginx but breaks in local development unless a proxy config
is in place. The environment files (`environment.ts` /
`environment.production.ts`) do not define an `apiUrl`, so the base URL
cannot be overridden per environment.

Fix: add `apiUrl: ''` to both environment files and set it to
`http://localhost:8000` in the development environment, referencing
`environment.apiUrl` in `data.service.ts`.

### 4.2 [security] Auth token stored in `localStorage`

`auth-session.ts` stores the JWT in `localStorage`. This makes the token
accessible to any JavaScript on the page, including injected scripts
(XSS). `sessionStorage` provides marginally better isolation, but
in-memory storage (a service property) is the most secure option.

Fix: move token storage to a dedicated Angular service that holds the token
in memory. Accept a performance trade-off (token lost on page refresh) or
implement a silent refresh flow.

### 4.3 [risk] No Angular route guards on admin routes

Routes such as `/admin`, `/admin/users`, `/admin/blog` etc. are not
protected by an `AuthGuard` or `AdminGuard`. A user who knows the URL can
navigate directly to the admin panel; the API calls will fail with 401,
but the admin UI will render and may leak structural information.

Fix: implement a `canActivate` guard that checks `auth-session.isLoggedIn`
and `isAdmin`, and apply it to all `/admin/*` routes in `app.routes.ts`.

### 4.4 [risk] Missing error handling on the majority of HTTP calls in `data.service.ts`

Most service methods return the raw `Observable` with no `catchError`.
Component code typically subscribes without an error handler. A failed API
call will produce an unhandled error in the console and leave the
component in a loading/empty state with no user feedback.

Fix: add a global HTTP error interceptor that maps common status codes
(401, 403, 404, 500) to user-visible notifications, in addition to
per-call error handling for critical flows like login and data saves.

### 4.5 [risk] Subscriptions not cleaned up in several components

`live.component.ts` and `flights.component.ts` create interval-based or
long-lived subscriptions. If `ngOnDestroy` does not cancel all of them, a
navigated-away component continues polling in the background, leaking
memory and making API calls.

Fix: use a `Subject` + `takeUntil(this.destroy$)` pattern and call
`this.destroy$.next()` in `ngOnDestroy` for all components with
subscriptions.

### 4.6 [improvement] No input validation on registration and login forms

`register.component.ts` and `login.component.ts` rely on HTML5 `required`
attributes only. No minimum password length, no email format validation,
and no max-length enforcement is applied in the Angular form layer.

Fix: add `Validators.minLength(8)` for passwords and `Validators.email`
for email fields. Add `maxlength` attributes to all text inputs to match
backend limits.

### 4.7 [improvement] `console.log` calls present in production code paths

Several components contain `console.log` statements that are visible in
browser developer tools in production builds. These may leak internal
state or API response structure to users.

Fix: remove all `console.log` calls from production code, or replace them
with a `LogService` that is a no-op in the production environment.

### 4.8 [risk] Live map component polls for aircraft data on a fixed interval with no backoff

`live.component.ts` polls the dump1090 JSON feed on a fixed timer. If the
backend or dump1090 is unavailable, it will continue polling at the same
rate indefinitely, producing repeated 5xx errors in the console and
unnecessarily loading the server.

Fix: implement exponential backoff on consecutive failures, with a maximum
retry interval, and show a user-visible "connection lost" indicator.

### 4.9 [improvement] No loading indicators or skeleton states on data-heavy pages

Pages such as Flights and Devices fetch potentially large datasets with no
loading spinner or skeleton state. The page appears blank until data
arrives.

Fix: add a `loading` boolean flag in each component and show an Angular
`*ngIf`-gated spinner while the HTTP call is in flight.

---

## 5. Cross-cutting

### 5.1 [improvement] No Nginx `proxy_read_timeout` / `proxy_connect_timeout` set

The installer writes a minimal nginx config (lines 916–937) with no
timeout directives. On a slow backend startup or during a long-running API
call, nginx will use the system default (60 s), which may be appropriate
but is not explicitly documented or tunable.

Fix: add explicit timeout values and document them in the nginx config
comment.

### 5.2 [improvement] `config.yml` contains no `hostname` for graphs by default in installer

The installer writes `dump1090_instance: "localhost"` and
`dump978_instance: "localhost"` into config.yml without prompting the
user. If dump1090 runs on a different host, the graph data collection jobs
will silently fail.

Fix: add a whiptail prompt asking for the dump1090/dump978 host, defaulting
to `localhost`.

### 5.3 [improvement] No log rotation configured for the backend service

The gunicorn/Flask backend logs to stdout which systemd captures in the
journal. For high-traffic installs the journal can grow large. No
`journald` size limit or `logrotate` rule is configured by the installer.

Fix: add a `journald.conf.d` override capping the service's log size, or
configure gunicorn to write to a rotating log file.

### 5.4 [risk] Flask runs behind Nginx without `ProxyFix` middleware

When Flask is behind a reverse proxy it receives `127.0.0.1` as the
client IP for all requests unless `ProxyFix` (from Werkzeug) is applied.
This affects IP-based logging, rate limiting, and any future feature that
needs the real client IP.

Fix: add `from werkzeug.middleware.proxy_fix import ProxyFix` and apply it
in `__init__.py`:

```python
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)
```
