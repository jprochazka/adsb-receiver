# ADS-B Portal — Bug Report & Improvement Plan

This document records bugs, risks, and needed changes found during a review
of the installer (`bash/extras/portal.sh`), backup/restore scripts
(`bash/tools/portal_backup_v*.sh`, `portal_restore_v*.sh`), the Flask
backend (`build/portal/backend/`), and the Angular frontend
(`build/portal/frontend/`).

No changes have been made. Every item below is a candidate for
implementation in a future phase.

Severity legend:
- `[critical]` — functional breakage or total security compromise
- `[security]` — exploitable vulnerability
- `[bug]` — confirmed incorrect behaviour
- `[risk]` — likely problem under specific conditions
- `[improvement]` — quality/correctness improvement

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

### 1.4 [bug] `Type=notify` in systemd unit requires gunicorn `sd_notify` support

Line 967 sets `Type=notify` in the systemd unit, which means systemd
expects gunicorn to send a readiness signal. Without the `sd_notify` shim,
systemd will wait for a signal that never arrives and time out (default 90
s), causing service start to fail.

Fix: change to `Type=simple`, or add a gunicorn `when_ready` hook that
calls `sd_notify(0, "READY=1")`.

### 1.5 [risk] `DB_PASS` defaults to literal `"password"` when no password provided

Lines 595 and 601:

```bash
MYSQL_PASS="${DB_PASS:-password}"
PG_PASS="${DB_PASS:-password}"
```

When `DB_TYPE` is `sqlite`, `DB_PASS` is never set, so these fallbacks
produce `"password"` as the MySQL/PostgreSQL password. This is then written
verbatim into `config.yml`.

Fix: use an empty string as the default: `${DB_PASS:-}`.

### 1.6 [risk] Frontend directory checked twice, in wrong order

Line 327 checks that `$FRONTEND_DIR` exists before installation begins
(correct). Line 884 checks again after `npm ci` has already been run on
line 881. The second check is unreachable in practice.

Fix: remove the redundant check at line 884.

### 1.7 [risk] `sudo rm -rf "${WEBROOT:?}"/*` unquoted glob

Line 910 uses an unquoted `*` glob after the variable. If `WEBROOT`
contains spaces or unusual characters, the glob can match unexpected paths.

Fix: use `sudo find "${WEBROOT}" -mindepth 1 -delete`.

### 1.8 [improvement] PostgreSQL provisioning missing `GRANT ON SCHEMA public`

Line 759 grants database-level privileges only. PostgreSQL 15+ changed
defaults so database-level `GRANT ALL` no longer includes schema access.
Alembic migrations will fail with `permission denied for schema public`.

Fix: add after the database grant:

```bash
sudo -u postgres psql -d "${PG_NAME}" \
    -c "GRANT ALL ON SCHEMA public TO \"${PG_USER}\";"
```

### 1.9 [security] JWT secret written unescaped into YAML heredoc

Line 656 writes `${JWT_SECRET}` directly into the YAML heredoc. If the
user enters a secret containing `"` or `\`, the resulting YAML is
syntactically invalid and the backend will fail to start.

Fix: sanitize the secret before embedding, or write `config.yml` using
`python3 -c "import yaml; ..."` instead of a heredoc.

### 1.10 [improvement] No validation that DB_NAME, DB_USER, DB_HOST are non-empty

The whiptail inputboxes for `DB_NAME`, `DB_USER`, and `DB_HOST` do not
loop on empty input. A user clicking OK with an empty field proceeds with
empty values causing cryptic failures during provisioning.

Fix: wrap each inputbox in a `while` loop that re-prompts if the value is
empty, matching the pattern already used for JWT_SECRET.

### 1.11 [bug] `log_message` calls inside `_install` corrupt the whiptail gauge stream

Status messages via `log_message` inside `_install` write to stdout. Since
`_install` is piped to `whiptail --gauge`, these messages corrupt the gauge
protocol stream and can cause garbled output.

Fix: redirect all `log_message` calls inside `_install` to `${LOG_FILE}`.

---

## 2. Backup & Restore Scripts

### 2.1 [bug] portal_backup_v3.sh — `_yaml_get` function broken and almost unused

Lines 112–122 define `_yaml_get()` with incorrect nested traversal (treats
`database.mysql` as a top-level key). It is called only once (line 152) as
a fallback for MySQL host. All other reads use inline `python3 -c` calls.

Fix: remove `_yaml_get` and use inline `python3 -c` calls consistently.

### 2.2 [bug] portal_backup_v3.sh — RRD path stripping fails when `rrd_base` is outside `backend_dir`

Line 255:

```bash
rel_dir="${rrd_dir#${backend_dir}/}"
```

If `graphs.rrd_base` is an absolute path not under `backend_dir` (e.g.
`/var/lib/adsb/rrd`), the strip is a no-op and the archive stores the full
absolute path. The restore then prepends `${backend_dir}/` producing an
invalid double-absolute path.

Fix: store the original absolute RRD path in a manifest file inside the
archive so restore can reconstruct the correct target regardless of
`rrd_base` location.

### 2.3 [bug] portal_restore_v3.sh — same RRD path reconstruction bug as 2.2

Line 319–320 reconstructs the RRD path as `${backend_dir}/${rel%.xml}.rrd`
which doubles-embeds the absolute path when `rrd_base` is not under
`backend_dir`.

### 2.4 [risk] portal_backup_v2.sh — RRD restore path heuristic is fragile

The restore script uses `grep -oP '(/var|/usr|/home|/opt|/srv|/run).*'`
to recover the original RRD path. This fails for any path that does not
start with one of those prefixes (e.g. `/data/rrd`, `/media/rrd`).

Fix: store a manifest file in the archive mapping XML paths to original
RRD paths.

### 2.5 [risk] portal_restore_v2.sh — `backed_up_temp_root` computed but never used

Line 110 computes `backed_up_temp_root` but it is never referenced. Dead
code from an incomplete feature.

### 2.6 [risk] portal_restore_v2.sh — lighttpd not re-enabled after restore

Line 320 calls `sudo systemctl start lighttpd` but never calls
`sudo systemctl enable lighttpd`. If lighttpd was enabled before the
restore, it will not survive a reboot.

Fix: track whether lighttpd was enabled before stopping it, and re-enable
it during restore.

### 2.7 [risk] portal_backup_v3.sh — partial dump not cleaned up on mysqldump failure

When `mysqldump` fails, the script warns but continues. The partial `.sql`
file is included in the archive. A restore from this archive imports an
incomplete dump without warning.

Fix: on dump failure, remove the partial file and either abort the backup
or write a manifest marking the archive as incomplete.

### 2.8 [improvement] portal_backup_v3.sh — service stop failure is silently ignored

If `sudo systemctl stop` fails, the script continues and backs up a
potentially inconsistent database.

Fix: verify the service actually stopped before proceeding, and warn
clearly if it cannot be stopped.

---

## 3. Flask Backend — Core / Auth / Users / Blog / Links / Notifications

### 3.1 [critical] `__init__.py` lines 122–126 — Database password is the literal string `***`

The MySQL and PostgreSQL connection URIs are built as:

```python
f"mysql://{mysql_config['user']}:***@{mysql_config['host']}/..."
f"postgresql://{pg_config['user']}:***@{pg_config['host']}/..."
```

The literal string `***` is used as the password — the actual value from
`mysql_config['password']` is never substituted. Any deployment using MySQL
or PostgreSQL **cannot connect to the database at all**. This is a
critical blocker for all non-SQLite installations.

Fix: replace `***` with `{mysql_config['password']}` and
`{pg_config['password']}`.

### 3.2 [critical] `routes/users.py` lines 383–412 — User deletion causes FK constraint violation

`DELETE FROM users WHERE id = ?` bypasses ORM cascades. `FlightComment`
and `UatFlightComment` both have non-nullable `user_id` FK columns with no
`ON DELETE CASCADE`. Deleting a user who has flight comments raises an
integrity error. Only `BlogComment` is handled before deletion.

Fix: handle `FlightComment` and `UatFlightComment` rows the same way
`BlogComment` rows are handled (reassign or soft-delete) before issuing
the user delete.

### 3.3 [critical] `routes/dump1090_data_collection.py` lines 42–43 — NoneType crash after failed `read_json()`

`read_json()` returns `None` on any network or parse error. The next line
unconditionally subscripts `data["aircraft"]`, raising `TypeError:
'NoneType' object is not subscriptable` and crashing the collection job.
`dump978_data_collection.py` handles this correctly; dump1090 does not.

Fix: add `if not data: return` after `read_json()`.

### 3.4 [critical] `dump1090_data_collection.py` line 53 vs 96 — `process_flight` called twice per aircraft

`process_aircraft()` internally calls `self.process_flight()` at line 96.
`process_all_aircraft()` then also calls `self.process_flight()` at line 53
unconditionally after `process_aircraft()` returns. Every aircraft with a
flight callsign is processed twice per collection cycle, doubling DB
queries and position inserts.

Fix: remove the duplicate `process_flight` call from `process_all_aircraft`.

### 3.5 [security] `routes/settings.py` lines 192–209 — Unauthenticated setting read

`GET /setting/<name>` has no authentication decorator. Any anonymous
visitor can read any setting by name, including sensitive configuration.

Fix: add `@require_user_or_admin()` to this endpoint.

### 3.6 [security] `routes/settings.py` lines 116–128 — Filesystem paths leaked to unauthenticated callers

`_build_opensky_status()` returns absolute filesystem paths (`db_path`,
`metadata_path`, `notice_path`). This endpoint is reachable without
authentication.

Fix: move path information behind admin-only authentication, or strip paths
from the public response.

### 3.7 [security] `routes/notifications.py` lines 82–116 and 134–230 — Unauthenticated watchlist and alert access

Both the watchlist (`GET /notifications`) and recent-alerts
(`GET /notifications/recent`) endpoints are accessible without
authentication. Anyone can enumerate monitored callsigns and see which
flights triggered alerts.

Fix: add `@require_user_or_admin()` to both endpoints.

### 3.8 [security] `auth.py` lines 20–43 — `require_role()` skips the `locked` check

`require_admin()` and `require_user_or_admin()` both check
`current_user.locked`. `require_role()` does not. A locked user with a
valid token and matching role can still access routes protected only by
`@require_role(...)`.

Fix: add the locked check to `require_role()`.

### 3.9 [security] `auth.py` lines 101–107 — `create_token_identity()` identity/email mismatch

`create_token_identity()` returns a dict (`{'email': ..., 'role': ...,
'user_id': ...}`). `get_current_user()` retrieves the identity with
`get_jwt_identity()` and immediately uses it as a plain email string in
`filter_by(email=current_user_email)`. If `create_token_identity()` is
used to create tokens, all auth lookups will fail and return 401.

Fix: ensure token creation uses only the email string as the identity, or
update `get_current_user()` to extract email from the dict.

### 3.10 [security] `__init__.py` line 73 — CORS wildcard allows any origin

```python
CORS(app, resources={r"/api/*": {"origins": "*"}})
```

Any website can make cross-origin API requests. In production this should
be restricted to known origins.

Fix: make allowed origins configurable via `config.yml`.

### 3.11 [security] `tokens.py` lines 65–69 — Lock check after password check leaks credential validity

A 403 response to a locked account with a correct password, vs a 401 for a
wrong password, allows an attacker to determine whether a locked account's
credentials are valid.

Fix: check `user.locked` before checking the password, or return the same
error code and message for both cases.

### 3.12 [security] `routes/settings.py` — Settings writable by any authenticated user

Settings writes are not gated behind an admin check. Any logged-in user
can modify portal-wide settings such as `live_map_json_url` or
`purge_older_data`.

Fix: add `@require_admin()` to all settings write endpoints.

### 3.13 [bug] `dump1090_data_collection.py` line 196 — Wrong vertical-rate field (`geom_rate` instead of `baro_rate`)

Dump1090 provides `baro_rate` for barometric vertical rate. The data
collection job uses `geom_rate` (a UAT/dump978 field). For most real
dump1090 aircraft `geom_rate` will be absent, causing
`aircraft_has_position_fields()` to return `False` and silently skipping
position storage.

Fix: use `baro_rate` for dump1090, consistent with `live.py` line 142.

### 3.14 [bug] `routes/users.py` line 76 — `password` incorrectly marked `required=True` in update schema

`UpdateUserRequestSchema` requires `password`, but `_apply_user_updates`
treats it as optional. Any PUT to `/users/user/<id>` that omits `password`
(e.g. a name-only update) is rejected with a 400 validation error.

Fix: set `required=False` for `password` in `UpdateUserRequestSchema`.

### 3.15 [bug] HTTP 204 returned with a response body

RFC 9110 requires clients to discard any body on a 204 response. Several
routes return `{'msg': '...'}` with status 204:

- `routes/blog.py` lines 424, 449, 649, 657
- `routes/links.py` lines 106, 129, 226
- `routes/dump1090.py` line 549
- `routes/dump978.py` line 552

Fix: use 200 with a body, or 204 with an empty body (`return '', 204`).

### 3.16 [bug] `jobs/maintenance.py` lines 79–91 — Silent partial deletes committed on error

`_delete_related_comments()` and `_delete_related_positions()` catch all
exceptions internally and log them. If comments are deleted but the
subsequent position deletion fails silently, `db.session.commit()` commits
the partial state, leaving orphaned data.

Fix: do not catch exceptions inside the helpers; let them propagate so the
outer transaction can roll back.

### 3.17 [bug] `jobs/maintenance.py` line 22 — Module-level global `now` is set but never read

`now = None` at module level is overwritten inside `maintenance_job()` but
then never referenced. It is dead code and also a potential data race if
the scheduler ever runs concurrent job instances.

Fix: remove the module-level global; use a local variable inside the job
function.

### 3.18 [bug] Naive (non-UTC) datetimes mixed with UTC-aware datetimes

`blog.py` line 169 and `maintenance.py` lines 60, 66 use `datetime.now()`
(naive, local time). Other parts of the codebase and the purge route cutoff
calculations use `datetime.now(timezone.utc)`. On any server not running
UTC, purge cutoffs and scheduled-post calculations will be wrong.

Fix: use `datetime.now(timezone.utc)` consistently throughout.

### 3.19 [bug] `jobs/maintenance.py` lines 62–70 — No guard on non-integer `days_to_save` value

`int(days_setting.value)` raises `ValueError` for a non-numeric string.
The exception is caught and returns `None`, silently aborting the purge
without any meaningful error message.

Fix: validate and log the bad value explicitly before the `int()` call.

### 3.20 [bug] `acars.py` lines 137–140 — New SQLAlchemy engine created on every request

`_get_acars_engine()` is called inside every ACARS handler, each time
creating a new engine and connection pool. Engines are expensive objects
intended to be created once at startup.

Fix: create the ACARS engine once at application startup (or at first use
with a module-level singleton) and reuse it.

### 3.21 [bug] `acars.py` lines 111–116 — Raw SQL built with string interpolation

```python
placeholders = ','.join(str(fid) for fid in old_flight_ids)
conn.execute(text(f"DELETE FROM Messages WHERE FlightID IN ({placeholders})"))
```

Flight IDs are not coerced to `int` before interpolation. If the ORM ever
returns a non-integer, this is a SQL injection vector.

Fix: use SQLAlchemy's `in_()` operator with bound parameters.

### 3.22 [risk] `jobs/rrd_data_collection.py` — Hardcoded Raspberry Pi disk name `mmcblk0`

The disk path `disk-mmcblk0` is specific to Raspberry Pi eMMC/SD storage.
On any other platform (NUC, VM, x86 SSD), this path matches nothing and
disk graphs will be empty with no error.

Fix: auto-detect the primary block device at job startup, or make it
configurable via `config.yml`.

### 3.23 [risk] `dump1090_data_collection.py` / `dump978_data_collection.py` — No timeout on `urlopen`

Both jobs call `urlopen(url)` with no timeout. If the local web server is
slow or stalled, the background job thread hangs indefinitely, blocking the
APScheduler thread pool.

Fix: add `urlopen(url, timeout=10)`.

### 3.24 [risk] `dump1090_data_collection.py` / `dump978_data_collection.py` — Collection URLs hardcoded

Both jobs hardcode `http://127.0.0.1/dump1090/data/aircraft.json` and
`http://127.0.0.1/dump978/data/aircraft.json` at the module level, not
reading from `config.yml`. The live map reads its URL from the DB setting
`live_map_json_url`, creating an inconsistency.

Fix: read dump URLs from `config.yml` (already has `dump1090_url` and
`dump978_url` under `rrd_writer`) or a dedicated config key.

### 3.25 [risk] `live.py` lines 61–82 — Non-thread-safe module-level cache

The aircraft data cache dict is read and written from multiple request
threads with no lock. Under concurrent requests, two threads can
simultaneously detect a cache miss and both overwrite the result.

Fix: protect cache reads and writes with a `threading.Lock()`.

### 3.26 [risk] `tokens.py` lines 72–73 — Role fix-up not persisted to database

When a user has an invalid/missing role, it is corrected in-memory and
included in the JWT, but `db.session.commit()` is never called. Every
subsequent login repeats the same fix-up without ever writing it back.

Fix: add `db.session.commit()` after the role correction.

### 3.27 [risk] `graphs.py` — No authentication on system-data endpoints

All `/graphs/devices/*` endpoints (CPU, disk, memory, temperature, network)
are publicly accessible with no authentication. This exposes system
hardware and performance information to unauthenticated users.

Fix: add `@require_user_or_admin()` to graph endpoints.

### 3.28 [risk] `graphs.py` line 179 — `subprocess.run(rrdtool)` not wrapped in try/except

If `rrdtool` is not installed, `FileNotFoundError` propagates uncaught. If
rrdtool hangs, `subprocess.TimeoutExpired` propagates uncaught. Both cause
unhandled 500 errors.

Fix: wrap in `try/except (FileNotFoundError, subprocess.TimeoutExpired)`.

### 3.29 [risk] `routes/users.py` / `routes/notifications.py` — TOCTOU race on duplicate check

Both user creation and notification creation use check-then-insert without
a transaction lock. Two concurrent identical requests can both pass the
existence check and both reach the insert. The second insert will fail with
an `IntegrityError` that is caught as a generic 500 rather than a 409
Conflict.

Fix: catch `IntegrityError` explicitly and return 409.

### 3.30 [risk] `__init__.py` lines 147–148 — JWT expiry values hardcoded

```python
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=1)
app.config["JWT_REFRESH_TOKEN_EXPIRES"] = timedelta(days=30)
```

Token lifetimes cannot be tuned per deployment without code changes.

Fix: read from `get_security_config()`.

### 3.31 [risk] No JWT token revocation

No token blocklist is implemented. Locking a user account or changing a
password does not invalidate existing access tokens, which remain usable
for up to 1 hour.

Fix: implement a server-side token revocation list, or shorten the access
token TTL significantly.

### 3.32 [risk] `models.py` — `User.password` is nullable but login code does not guard against it

`password = db.Column(db.String(255))` with no `nullable=False`. If a user
row has `password=None`, `check_password_hash(user.password, input)` raises
`TypeError`.

Fix: add `nullable=False` to the column, or guard in the login route with
`if not user.password: return 401`.

### 3.33 [improvement] N+1 query: links reorder endpoint

`LinksReorderResource.put()` in `routes/links.py` issues one `SELECT`
query per link ID in the reorder list. For N links, this is N queries.

Fix: use `select(Link).where(Link.id.in_(payload['ids']))` and build a
lookup dict before setting `sort_order`.

### 3.34 [improvement] N+1 query: blog comments missing `joinedload` on `user`

The comments query in `routes/blog.py` does not eagerly load the `user`
relationship. For N comments, `to_dict()` issues N additional `SELECT`
queries for user data.

Fix: add `.options(joinedload(BlogComment.user))` to the comments query.

### 3.35 [improvement] `__init__.py` — No `SQLALCHEMY_POOL_RECYCLE` for MySQL

MySQL closes idle connections after `wait_timeout` (default 8 hours).
Without pool recycling, the app gets "MySQL server has gone away" errors
after long idle periods.

Fix: set `SQLALCHEMY_POOL_RECYCLE = 3600` when `db_driver == "mysql"`.

### 3.36 [improvement] `acars.py` — `get_acars_config()` called inconsistently

`_get_acars_engine()` calls `get_acars_config()` with no argument.
`_get_database_info()` calls it with a pre-loaded config. The two calls
may return different configurations.

Fix: standardise on one calling pattern throughout.

### 3.37 [improvement] `routes/blog.py` line 272 — Tag LIKE matching too permissive

`BlogPost.tags.contains(tag)` generates `LIKE '%<tag>%'`. A tag of `%` or
`_` matches every post. Tags are comma-separated values; exact-segment
matching is more appropriate.

Fix: filter in Python after fetching, or use a JSON column with a proper
contains check.

### 3.38 [improvement] No `ProxyFix` middleware

Flask running behind Nginx receives `127.0.0.1` as the client IP for all
requests. IP-based logging and any future rate limiting will see only the
proxy address.

Fix: add `from werkzeug.middleware.proxy_fix import ProxyFix` and apply it
in `__init__.py`.

---

## 4. Angular Frontend

### 4.1 [critical] `app.routes.ts` lines 25–33 — No route guards on any admin or account routes

Every admin route (`/admin/*`) and the `/account` route has no `canActivate`
guard. There are no guard files anywhere in the project. An unauthenticated
user can navigate directly to any admin page; the UI renders before the API
401 triggers a redirect, briefly exposing the admin interface structure.

Fix: implement `AuthGuard` and `AdminGuard` using
`inject(Router)` and `hasValidAccessToken()` / `isAdminAccessToken()` from
`auth-session.ts`, and apply to all admin and account routes.

### 4.2 [security] JWT stored in `localStorage`

`auth-session.ts` line 11 stores the JWT in `localStorage`, accessible to
any JavaScript on the page. The refresh token is also stored in
`localStorage` (login.component.ts line 32) but is **never used** — there
is no refresh flow in the codebase. Storing an unused credential is
unnecessary exposure.

Fix: use `sessionStorage` as a minimum improvement, or in-memory storage
with a silent refresh flow. Remove refresh token storage until a refresh
flow is implemented.

### 4.3 [bug] `ChangeDetectionStrategy.Eager` is not a valid Angular enum value

All major components set `changeDetection: ChangeDetectionStrategy.Eager`.
This enum value does not exist in Angular. At runtime it evaluates to
`undefined`, which Angular silently treats as `Default`, meaning no
`OnPush` optimisation is applied. The components are running in a mode
different from what was intended.

Affected files: `login.component.ts` line 12, `register.component.ts` line
12, `admin-users.component.ts` line 12, `admin-blog.component.ts` line 20,
`admin-flights.component.ts` line 25, `live.component.ts` line 93,
`flights.component.ts` line 40, and others.

Fix: replace `ChangeDetectionStrategy.Eager` with `ChangeDetectionStrategy.Default`
(if that is the intended behaviour) or `ChangeDetectionStrategy.OnPush`
(if change detection optimisation is desired, with appropriate `markForCheck`
usage).

### 4.4 [bug] `flights.component.ts` lines 172–266 — `combineLatest` subscription never unsubscribed

The `combineLatest([this.route.paramMap, this.route.queryParamMap]).subscribe(...)`
subscription is never stored and `ngOnDestroy` does not cancel it. Since
these observables never complete, each navigation away and back to the
flights page accumulates an additional active subscription, doubling HTTP
calls per collection cycle with each visit.

Fix: store the subscription and call `.unsubscribe()` in `ngOnDestroy`, or
use `takeUntilDestroyed()`.

### 4.5 [bug] `login.component.ts` lines 28–38 — `loading` flag not reset on successful login

`this.loading = true` is set before the HTTP call. On success the component
navigates away but never sets `this.loading = false`. If navigation is
cancelled or blocked, the form remains permanently disabled.

Fix: set `this.loading = false` before calling `this.router.navigate(...)`.

### 4.6 [bug] `data.service.ts` lines 15–18 — `authHeaders()` sends `"Bearer null"` when no token

If `localStorage.getItem('access_token')` returns `null`, the header is set
to `Authorization: Bearer null` (the string "null"). This causes a 401
which triggers the interceptor redirect loop.

Fix: guard against null: `if (!token) return {};` before constructing the
header.

### 4.7 [risk] Missing error handling on several critical HTTP calls

- `flights.component.ts` line 366–367: position fetch inside `forkJoin` has
  no `catchError`. A failed positions call errors the entire join; `loading`
  stays `true` indefinitely.
- `flights.component.ts` lines 245–263: inner `forkJoin` for flight list
  has no `catchError`; spinner never clears on error.
- `admin-blog.component.ts` lines 207–228: unbounded recursive HTTP fetch
  with no error handler; a persistent server error triggers infinite retries.

Fix: add `catchError(() => of(null))` to independent fetches, and add a
depth/count guard to the recursive post-snapshot loader.

### 4.8 [risk] `admin-blog.component.ts` — Unbounded recursive HTTP fetching

`loadAllPostsSnapshot` recursively fires paginated requests until all posts
are loaded. If `reportedTotal` is unexpectedly large or the server keeps
returning data, this can fire an unbounded number of requests.

Fix: add a maximum page count guard; cancel in-flight requests on component
destroy using `takeUntil`.

### 4.9 [risk] `flights.component.ts` lines 285–305 — Unbounded parallel requests in `loadTopFlights`

For large datasets with many pages, `forkJoin` fires all paginated requests
simultaneously with no cap. On page 100 of a 10,000-flight dataset this
generates 100 concurrent HTTP requests.

Fix: use `concatMap` or limit parallelism with `mergeMap(..., concurrency)`.

### 4.10 [risk] `auth.interceptor.ts` lines 22–28 — Blanket logout on any 401

Every 401 response from any endpoint clears the session and redirects to
login. Some endpoints may legitimately return 401 for resource-level
authorization failures. This can log out a valid user unexpectedly.

Fix: only clear the session and redirect on 401 responses from the token
or login endpoints; for other 401s, surface an error message without
logging out.

### 4.11 [improvement] No Angular route guard files exist

There are no `auth.guard.ts` or equivalent files in the project. The
missing guards (item 4.1) cannot be implemented without creating these
files.

### 4.12 [improvement] Missing input validation on forms

- `login.component.ts`: no email format check, no empty-field guard.
- `admin-users.component.ts` lines 166–194: no email format validation.
- `admin-blog.component.ts` lines 372–398: no maximum content length check.

Fix: add `Validators.email`, `Validators.minLength(8)` for passwords, and
`Validators.maxLength(...)` limits matching backend column sizes.

### 4.13 [improvement] API environment variable missing for external Planespotters URL

`data.service.ts` line 203 hardcodes `https://api.planespotters.net/pub/photos/hex/`.
If this endpoint changes or needs to be proxied, there is no single place
to update it.

Fix: move to `environment.ts` as `planespottersApiUrl`.

### 4.14 [improvement] `app.config.ts` — `withXhr()` is redundant

Line 13 calls `withXhr()` which is the default and redundant when no
`withFetch()` is used. It may conflict with future adoption of `withFetch()`.

Fix: remove `withXhr()`.

### 4.15 [improvement] No central admin settings panel

The `data.service.ts` exposes `getSetting` and `updateSetting` but there is
no `/admin/settings` route or `AdminSettingsComponent`. Portal-wide settings
are scattered across individual admin pages with no unified management view.

---

## 5. Cross-cutting

### 5.1 [improvement] No `proxy_read_timeout` / `proxy_connect_timeout` in Nginx config

The installer writes a minimal nginx config with no timeout directives.
On a slow backend startup, nginx uses the system default (60 s) with no
documentation.

Fix: add explicit timeout values with comments.

### 5.2 [improvement] dump1090/dump978 host not prompted during install

The installer writes `dump1090_instance: "localhost"` and
`dump978_instance: "localhost"` into `config.yml` without asking the user.
If dump1090 runs on a different host, graph data collection silently fails.

Fix: add whiptail prompts for dump1090/dump978 host, defaulting to
`localhost`.

### 5.3 [improvement] No log rotation configured for the backend service

The gunicorn backend logs to stdout captured by systemd journal. No journal
size limit or logrotate rule is configured.

Fix: add a `journald.conf.d` override or configure gunicorn to write to a
rotating log file.

### 5.4 [improvement] No `ProxyFix` middleware (also listed as 3.38)

Covered under 3.38 above.
