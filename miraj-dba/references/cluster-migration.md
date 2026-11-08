# Cluster, migration, PostgreSQL language

## Migration from another SQL server: `miraj-migrate`

The source is read **read-only** through the network protocol: it is neither stopped nor modified, and the migration can be replayed before the cutover. Applications keep their connector: only the host and port change (the source's port becomes `7007`).

```text
miraj-migrate inspect --source-db <database> [source options]
miraj-migrate run     --source-db <database> [source and target options]
                      [--drop-existing] [--skip-data] [--batch-rows <n>] [--only t1,t2]
```

Procedure:

1. `inspect`: lists tables, rows, views and above all **the objects not migrated** (triggers, routines, events). Writes nothing.
2. Dress rehearsal: `run` to a test MIRAJ server; compare the `COUNT(*)` values and checksums on sensitive columns.
3. Recreate by hand: accounts and privileges, triggers, routines, events (they are not copied).
4. Cutover: stop writes on the source, final `run`, point the applications to MIRAJ, test.
5. Keep the source intact for a few days (rollback possible).

Exit code: `0` everything migrated and verified; `1` error or failed object. See the manual, chapter 17.

## Cluster edition

A **primary** node accepts writes; **secondaries** continuously replay its journal, **read-only**. A partitioned table can place partitions on a specific node.

- Monitoring: `SHOW CLUSTER STATUS;`, `information_schema.MIRAJ_NODES`, `MIRAJ_REPLICATION`.
- Accounts are created on the primary and received by the secondaries.
- Backup: on the primary. Restore: on a single node, then reintegrate it (procedure in the manual, chapter 12).
- Read distribution: the `miraj-proxy` proxy (Cluster archive) routes reads and writes to the right nodes; key infrastructure: `miraj-cluster-pki`.
- Test the failure of a node in a test environment before production. Never abruptly stop the primary "to see".

## Binary log replication

A MIRAJ can be a source or replica of a server in the reference format (Enterprise/Cluster/Developer editions): manual, chapter 12.13.

## Instance in PostgreSQL language

An instance speaks **a single** language: the MIRAJ language (default) or PostgreSQL (`POSTGRESQL` element in `sql_mode`, taken into account at restart). Same port 7007, same engine, same backups. In that case:

- connect with `psql`, PostgreSQL drivers, or `miraj-cli` (which detects the language);
- the MIRAJ tools (`miraj-cli`, `miraj-dump`, `miraj-backup`, `miraj-migrate`), the ODBC driver and the `miraj` Python library adapt automatically;
- software that speaks the "MIRAJ language" protocol requires an instance in that language.

Choice to confirm with the customer before installation: the two languages are not mixed on the same instance. See the manual, chapters 11.10 and 27.

## Remote access: MIRAJ Tunnel

For clients on another network, **MIRAJ Tunnel** (agent + Miraj Tunnel Manager) avoids opening port 7007 to the Internet. A token is issued by CIRTASOFT. Manual, chapter 24.

## REST API (all editions)

`--rest ON` opens port 7009 (disabled by default) with three separately opened families: **endpoints** (APIs written in SQL), **tables**, **free SQL**. For a DBA: open only `rest_endpoints` (default), leave `rest_tables`/`rest_sql` at `OFF` unless needed, and reserve `SQL` for a trusted internal tool. The account's SQL rights always apply. Outside loopback: TLS mandatory. Manual, chapter 23.
