# Backup and restore

## Which method?

| Need | Method |
|---|---|
| Fast daily backup, immediate restore | `BACKUP DATABASE` / `miraj-backup` (hot physical copy) |
| Scheduling on Windows without a script | Miraj Server Manager, Backups tab |
| Recover a few rows from yesterday | `RESTORE DATABASE copie FROM '…'` under a **different name**, then compare |
| Change machine or version, archive, keep the accounts | `miraj-dump --users` (the physical copy does not contain the accounts) |
| Server stopped | `miraj-backup … --root` or `miraj-dump … --root` |
| Cluster | `BACKUP` on the primary; restore on a single node |

## Preparing: `--backup-dir`

SQL `BACKUP` and `RESTORE` are refused (error 1290) as long as the server has no backup folder:

```text
miraj-server --root D:\donnees --backup-dir E:\sauvegardes --log
```

This folder: created if missing, **outside** the data folder (preferably on another disk), never inside the key folder or `--secure-file-priv`. The `BACKUP`/`RESTORE` paths are relative to it.

## Hot physical backup

```sql
BACKUP DATABASE gestion TO 'gestion-2026-10-29';
BACKUP DATABASE gestion, essai TO 'multi';     -- one subfolder per database
BACKUP ALL DATABASES TO 'complete-2026-10-29'; -- without the system database
```

- Required privilege: `BACKUP_ADMIN`. The destination folder must be **empty or nonexistent** (otherwise 9018).
- During the copy, writes wait only a few milliseconds; reads are never blocked. Result: a clean cut (no half-done transaction).
- Several databases: each is cut at its own instant (no common snapshot).
- A folder without `manifest.json` is an interrupted copy: unusable, to be deleted (with agreement).

## Restore

```sql
RESTORE DATABASE gestion_copie FROM 'gestion-2026-10-29';           -- under a new name
RESTORE DATABASE gestion FROM 'gestion-2026-10-29' REPLACE;          -- replaces: DESTRUCTIVE
```

- Without `REPLACE`, the name must be free (1007 otherwise).
- Automatic checks: sizes, sums, SHA-256, signature. A tampered backup is refused (9029) without touching anything; unsigned or signed elsewhere: accepted with a warning (9030/9031) — only restore backups of known provenance.
- Without `SUPER`, the definers of routines/triggers/views are reassigned to the restoring account (warning 9032).
- **Good practice for a human error**: restore under another name, compare, then copy the useful rows; do not `REPLACE` as a first reflex.

## The `miraj-backup` tool

```text
miraj-backup backup  --db a,b | --all  --to <folder>  [connection | --root <data>]
miraj-backup restore --from <folder> --db <name> [--replace]  [connection | --root <data>]
                     [--with-archive | --archive <folder>] [--until "YYYY-MM-DD hh:mm:ss" | --until-lsn <n>]
miraj-backup verify  --from <folder> [--deep]
miraj-backup list    --from <folder>
```

- Network mode (server running): the folder is the one **on the server**, relative to `--backup-dir`. Offline mode: `--root`, server stopped.
- Connection: `--host`, `--port`, `--user`, `--password` (masked input) or the `MIRAJ_PASSWORD` variable; TLS: `--ssl`, `--ssl-ca file.pem`.
- **`verify --deep` rereads every table**: run it regularly on the backups. Exit code `0` = success.
- `--until` replays the journal archive up to a point in time (point-in-time restore) when continuous archiving is enabled.

Daily scheduled task (password in the task's environment):

```text
miraj-backup backup --all --to quotidien-%DATE:~6,4%%DATE:~3,2%%DATE:~0,2%
```

## SQL export: `miraj-dump`

```text
miraj-dump --db gestion -r gestion.sql [connection]
miraj-dump --all --users -r tout.sql [connection]       # + accounts (verifiers, rights)
miraj-dump restore tout.sql [-d database] [--force] [connection]
```

Options: `--no-data`, `--no-create-info`, `--tables t1,t2`, `--no-routines`, `--no-triggers`, `--no-events`, `-x` (common snapshot of all databases, `RELOAD` privilege).

- The file is written under a temporary name then renamed: an interrupted export does not leave a truncated script.
- **A `--users` export is sensitive**: the password verifiers act as passwords. Store it like a secret; for a remote export, require TLS with `--ssl-ca`.
- A script produced by `miraj-dump` contains `DELIMITER`s: reload it with `miraj-dump restore`, never with `miraj-cli file.sql` on an open folder.

## Do not forget

- Back up **the account vault key too** (see `comptes-securite.md`), otherwise a restore on another machine does not have its accounts.
- Encrypted folder: the restore requires the same master key / passphrase.
- 3-2-1 rule: three copies, two media, one off-site.
- **Test**: restore under another name on a test machine, `CHECK TABLE`, compare the `COUNT(*)` values — record the date of the last successful test.

## Recovery after an abrupt stop

The write journal is replayed at restart; nothing to do in general. If startup fails or warns: read `miraj/server.log`, delete **nothing**, copy the data folder as is before any attempt, then restore the latest valid `verify --deep` backup if the files are really damaged. `CHECK TABLE t;` checks a table (a damaged page of a disk table is reported there).
