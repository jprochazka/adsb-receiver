# ADS-B Portal Backup & Restore — v3 (Flask/Angular Portal)

These scripts back up and restore the **new Flask/Angular ADS-B Portal**
from the `cleanup` branch, served by Nginx with a Gunicorn backend.

For the legacy PHP/lighttpd portal see
[PORTAL_BACKUP_RESTORE_V2.md](PORTAL_BACKUP_RESTORE_V2.md).

---

## Scripts

| Script | Purpose |
|---|---|
| `portal_backup_v3.sh` | Create a timestamped backup archive |
| `portal_restore_v3.sh` | Restore from a backup archive |

---

## What is backed up

| Item | Detail |
|---|---|
| `config.yml` | All database credentials, RRD path, ACARS path, and JWT secret key. |
| SQLite database | `instance/adsbportal.sqlite3` — only present on **sqlite** installs. |
| MySQL database | Full `mysqldump` of the portal database — only present on **mysql** installs. |
| PostgreSQL database | Full `pg_dump` of the portal database — only present on **postgresql** installs. |
| RRD files | Each `.rrd` file under the configured `graphs.rrd_base` path is exported to XML using `rrdtool dump`. Stored as XML for portability across rrdtool versions. |
| OpenSky classification cache | `instance/opensky/` directory. Contains aircraft classification data fetched from OpenSky Network. Optional — the backend rebuilds this cache automatically if absent. |
| ACARS database | The SQLite database configured via `acars.database` in `config.yml`, if present. |
| Portal runtime env overrides | `PORTAL_BACKEND_VERSION`, `PORTAL_API_DOCS_ENABLED`, and `PORTAL_CORS_ORIGINS` from `adsb-portal-backend.service` are saved when explicitly set. |

**Not backed up:** The Angular frontend (`/var/www/adsb-portal`) is a build
artefact produced by `npm run build`. It is not backed up because it can
always be rebuilt from source and contains no user data.

---

## Backup

### Usage

```bash
bash portal_backup_v3.sh [--backend-dir /path/to/backend]
```

`--backend-dir` is optional. When omitted the script locates the backend
directory automatically (see [Backend directory discovery](#backend-directory-discovery)).

### Output

The backup is written to:

```
<current directory>/backups/adsb-portal_v3_YYYY-MM-DD-HHMMSS.tar.gz
```

### Archive layout

```
<archive>.tar.gz
└── ./
   ├── config.yml
   ├── systemd/
   │   └── portal_backend_env.list  # optional; saved PORTAL_* runtime overrides
   ├── instance/
   │   ├── adsbportal.sqlite3      # sqlite driver only
   │   ├── opensky/                # if present
   │   │   └── ...
   │   └── acarsdec.sqlite         # if configured and present
   ├── <mysql_database_name>.sql   # mysql driver only
   ├── <pgsql_database_name>.sql   # postgresql driver only
   └── rrd/
      └── <path_relative_to_backend_dir>/
         └── *.xml               # one XML file per RRD
```

### What happens during backup

1. The backend directory is located (see
   [Backend directory discovery](#backend-directory-discovery)).
2. `config.yml` is read to determine the database driver, RRD path, and
   ACARS database path.
3. The `adsb-portal-backend.service` systemd service is **stopped** to
   ensure a consistent snapshot with no in-flight writes.
4. `config.yml` is copied into the archive.
5. Data is archived according to the driver:
   - **sqlite** — the SQLite file is copied.
   - **mysql** — `mysqldump` produces a `.sql` file.
   - **postgresql** — `pg_dump` produces a `.sql` file (credentials passed
     via a temporary `.pgpass` file).
6. RRD files are exported to XML with `rrdtool dump`. Each file is stored
   at a path relative to the backend directory so restore can reconstruct
   the exact target location.
7. The OpenSky cache directory is copied if present.
8. The ACARS database is copied if configured and present.
9. Runtime env overrides (`PORTAL_BACKEND_VERSION`,
   `PORTAL_API_DOCS_ENABLED`, `PORTAL_CORS_ORIGINS`) are read from the
   systemd service unit and saved when present.
10. The backend service is **restarted**.
11. The staging directory is compressed to a `.tar.gz` archive and removed.

---

## Restore

### Usage

```bash
bash portal_restore_v3.sh /path/to/adsb-portal_v3_YYYY-MM-DD-HHMMSS.tar.gz \
    [--backend-dir /path/to/backend]
```

`--backend-dir` is optional. See
[Backend directory discovery](#backend-directory-discovery).

The script reads all configuration from the **backed-up `config.yml`**
inside the archive, not from the live install. This means restore works
correctly even if the live configuration is missing or different from what
was in use when the backup was taken.

### What happens during restore

1. The archive is extracted to a temporary directory under `/tmp`.
2. `config.yml` is located inside the extraction and used to determine the
   database driver, RRD path, and ACARS path.
3. You are prompted to confirm before any data is written.
4. The `adsb-portal-backend.service` is **stopped**.
5. `config.yml` is restored. The existing live copy is saved as a
   `.pre_restore.<date>.bak` file first.
6. The database is restored according to the driver:
   - **sqlite** — the SQLite file is copied back. Any existing database is
     saved as a `.pre_restore.<date>.bak` file first.
   - **mysql** — the `.sql` dump is restored via the `mysql` client. The
     target database must already exist.
   - **postgresql** — the `.sql` dump is restored via `psql`. The target
     database must already exist. Credentials are passed via a temporary
     `.pgpass` file.
7. `flask db upgrade` is run against the restored database to ensure the
   schema is current. This handles the case where the backup was taken on
   an older version of the portal and the installed code has newer
   migrations.
8. RRD XML exports are re-created as `.rrd` files using `rrdtool restore`.
   The relative path stored in the archive is used to reconstruct the
   correct target location under the backend directory. Any existing RRD
   file is saved as a `.pre_restore.<date>.bak` before being replaced.
9. The OpenSky cache directory is restored if present in the archive.
10. The ACARS database is restored if present in the archive.
11. If present in the archive, saved runtime env overrides are restored via
   a systemd drop-in at
   `/etc/systemd/system/adsb-portal-backend.service.d/portal-env.conf`, then
   `systemctl daemon-reload` is run.
12. Ownership is set to `www-data:www-data` on the `instance/` directory
    and the RRD base directory.
13. The `adsb-portal-backend.service` is restarted. If it fails to start,
    a `journalctl` command is shown for diagnosis.
14. The temporary extraction directory is removed.

### Pre-restore backups

Before overwriting any existing file the restore script saves it with a
timestamped suffix:

```
config.yml           →  config.yml.pre_restore.YYYY-MM-DD-HHMMSS.bak
adsbportal.sqlite3   →  adsbportal.sqlite3.pre_restore.YYYY-MM-DD-HHMMSS.bak
dump1090_messages.rrd  →  ...rrd.pre_restore.YYYY-MM-DD-HHMMSS.bak
```

These files are not removed automatically. Delete them manually once you
have confirmed the restore was successful.

---

## Backend directory discovery

Both scripts locate the backend directory using this order of precedence:

1. **`--backend-dir` argument** — use the path provided explicitly.
2. **systemd unit** — read the `WorkingDirectory` from
   `adsb-portal-backend.service` (works whether the service is running or
   enabled but stopped).
3. **Common install paths** — check in order:
   - `/usr/local/share/adsb-receiver/build/portal/backend`
   - `/opt/adsb-receiver/build/portal/backend`
   - `~/adsb-receiver/build/portal/backend`

If none of the above contain a `config.yml`, the script aborts and asks you
to specify the path manually with `--backend-dir`.

---

## Requirements

| Tool | Required for |
|---|---|
| `python3` with `PyYAML` | Reading `config.yml` |
| `rrdtool` | RRD export (backup) and import (restore) |
| `mysqldump` / `mysql` | MySQL backup and restore |
| `pg_dump` / `psql` | PostgreSQL backup and restore |
| `systemctl` | Service stop/start |
| `flask` (in `.venv`) | Schema migration check after restore |
| `tar`, `gzip` | Archive creation and extraction |

PyYAML is installed as part of the portal backend Python dependencies. If
running the backup scripts outside the normal portal environment, ensure
PyYAML is available to the `python3` on the system path, or activate the
portal venv first:

```bash
source /path/to/backend/.venv/bin/activate
bash portal_backup_v3.sh
```

---

## Notes

- **The backend service is stopped during both backup and restore** to
  prevent inconsistent snapshots or partial writes. On a busy system
  consider scheduling backups during low-traffic periods.
- **MySQL and PostgreSQL restores require the target database to exist.**
  The restore script does not create databases or users. Provision them
  before running a restore if starting from scratch.
- **PostgreSQL passwords** are passed via a temporary `.pgpass` file with
  `chmod 600` permissions. The file is deleted immediately after use and
  never appears in the process list or logs.
- **`flask db upgrade` is safe to run on an already-current schema.** It is
  a no-op if no new migrations are pending.
- **The OpenSky cache is optional.** If not present in the archive the
  backend will rebuild it automatically on next startup by fetching fresh
  data from OpenSky Network.
- **The Angular frontend is not restored** because it contains no user data.
  If the frontend files under `/var/www/adsb-portal` are missing or
  corrupted, rebuild them with:
  ```bash
  cd /path/to/build/portal/frontend
  npm ci
  npm run build -- --configuration production
  sudo rm -rf /var/www/adsb-portal/*
  sudo cp -r dist/frontend/browser/* /var/www/adsb-portal/
  sudo chown -R www-data:www-data /var/www/adsb-portal
  ```
