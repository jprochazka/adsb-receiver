# ADS-B Portal Backup & Restore — v2 (Legacy PHP Portal)

These scripts back up and restore the **legacy PHP ADS-B Portal** served by
lighttpd. Use them when the installed portal is the original PHP/lighttpd
version from the `master` branch.

For the new Flask/Angular portal (cleanup branch) see
[PORTAL_BACKUP_RESTORE_V3.md](PORTAL_BACKUP_RESTORE_V3.md).

---

## Scripts

| Script | Purpose |
|---|---|
| `portal_backup_v2.sh` | Create a timestamped backup archive |
| `portal_restore_v2.sh` | Restore from a backup archive |

---

## What is backed up

| Item | Detail |
|---|---|
| `settings.class.php` | PHP configuration file containing the database driver, credentials, and prefix. Required to reconnect to the database on restore. |
| XML data files | `administrators.xml`, `blogPosts.xml`, `flightNotifications.xml`, `links.xml`, `settings.xml` — only present on **xml** (lite) installs. |
| SQLite database | `portal.sqlite` — only present on **sqlite** installs. |
| MySQL database | Full `mysqldump` of the portal database — only present on **mysql** installs. |
| PostgreSQL database | Full `pg_dump` of the portal database — only present on **pgsql** installs. |
| Collectd RRD files | Each `.rrd` file under `/var/lib/collectd/rrd` is exported to XML using `rrdtool dump`. Stored as XML for portability across rrdtool versions. |

**Not backed up:** lighttpd configuration, PHP source files, or any files
outside the document root. These are part of the installation, not the data.

---

## Backup

### Usage

```bash
bash portal_backup_v2.sh
```

Run from any directory. The script auto-detects the lighttpd document root
by querying `lighttpd -p`. If lighttpd is not installed or the config cannot
be read, it falls back to `/var/www/html`.

### Output

The backup is written to:

```
<current directory>/backups/adsb-receiver_data_YYYY-MM-DD-HHMMSS.tar.gz
```

### Archive layout

```
<archive>.tar.gz
└── backup_YYYY-MM-DD-HHMMSS/
    ├── <lighttpd_doc_root>/
    │   ├── classes/
    │   │   └── settings.class.php
    │   └── data/
    │       ├── administrators.xml      # xml driver only
    │       ├── blogPosts.xml           # xml driver only
    │       ├── flightNotifications.xml # xml driver only
    │       ├── links.xml               # xml driver only
    │       ├── settings.xml            # xml driver only
    │       └── portal.sqlite           # sqlite driver only
    ├── <mysql_database_name>.sql       # mysql driver only
    ├── <pgsql_database_name>.sql       # pgsql driver only
    └── var/lib/collectd/rrd/
        └── **/*.xml                    # one XML file per RRD
```

### What happens during backup

1. The lighttpd document root is resolved from `lighttpd -p`.
2. `settings.class.php` is read to determine the database driver and
   credentials.
3. `settings.class.php` is copied into the archive (needed for restore).
4. Collectd RRD files are exported to XML with `rrdtool dump`.
5. Data is archived according to the driver:
   - **xml** — XML data files are copied.
   - **sqlite** — the SQLite file is copied.
   - **mysql** — `mysqldump` produces a `.sql` file.
   - **pgsql** — `pg_dump` produces a `.sql` file (credentials passed via a
     temporary `.pgpass` file; never via command-line arguments).
6. The staging directory is compressed to a `.tar.gz` archive and removed.

---

## Restore

### Usage

```bash
bash portal_restore_v2.sh /path/to/adsb-receiver_data_YYYY-MM-DD-HHMMSS.tar.gz
```

The script reads all configuration from the **backed-up**
`settings.class.php` inside the archive, not from the live install. This
means restore works correctly even if the live portal configuration is
missing or different.

### What happens during restore

1. The archive is extracted to a temporary directory under `/tmp`.
2. `settings.class.php` is located inside the extraction and used to
   determine the database driver and credentials.
3. You are prompted to confirm before any data is written.
4. **lighttpd is stopped** before web files are written. It is restarted
   automatically when the restore is complete.
5. `settings.class.php` is restored to `<doc_root>/classes/`.
6. Data is restored according to the driver:
   - **xml** — XML data files are copied back to `<doc_root>/data/`.
   - **sqlite** — The SQLite file is copied back to its original path. Any
     existing database is saved as a `.pre_restore.<date>.bak` file first.
   - **mysql** — The `.sql` dump is restored via the `mysql` client. The
     target database must already exist.
   - **pgsql** — The `.sql` dump is restored via `psql`. The target database
     must already exist. Credentials are passed via a temporary `.pgpass`
     file.
7. RRD XML exports are re-created as `.rrd` files using `rrdtool restore`.
   Any existing RRD file is saved as a `.pre_restore.<date>.bak` before
   being replaced.
8. Ownership is set to `www-data:www-data` on all restored web files and
   RRD directories.
9. lighttpd is restarted.
10. The temporary extraction directory is removed.

### Pre-restore backups

Before overwriting any existing file the restore script saves it with a
timestamped suffix:

```
portal.sqlite  →  portal.sqlite.pre_restore.YYYY-MM-DD-HHMMSS.bak
dump1090_messages-local_accepted.rrd  →  ...rrd.pre_restore.YYYY-MM-DD-HHMMSS.bak
```

These files are not removed automatically. Delete them manually once you
have confirmed the restore was successful.

---

## Requirements

| Tool | Required for |
|---|---|
| `lighttpd` | Document root detection |
| `rrdtool` | RRD export (backup) and import (restore) |
| `mysqldump` / `mysql` | MySQL backup and restore |
| `pg_dump` / `psql` | PostgreSQL backup and restore |
| `tar`, `gzip` | Archive creation and extraction |

All other tools (`grep`, `cut`, `find`, `cp`, `systemctl`) are standard
Linux utilities.

---

## Notes

- **Source data is never modified.** The backup script is entirely
  read-only with respect to portal data files.
- **MySQL and PostgreSQL restores require the target database to exist.**
  The restore script does not create databases or users. Provision them
  before running a restore if starting from scratch.
- **PostgreSQL passwords** are passed via a temporary `.pgpass` file with
  `chmod 600` permissions. The file is deleted immediately after use.
- **XML data files** are only backed up for lite (xml driver) installs. SQL
  installs do not have XML data files.
- **lighttpd is stopped** during restore to prevent partial reads by the web
  server. It is restarted regardless of whether the restore succeeded or
  failed, to minimise downtime.
