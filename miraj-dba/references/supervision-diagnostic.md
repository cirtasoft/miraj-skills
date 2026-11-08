# Monitoring and diagnostics

All the queries below are also in `diagnostic.sql`.

## Where to look

| Question | Source |
|---|---|
| Who is connected, what are they doing? | `SHOW FULL PROCESSLIST;`, `sys.session`, `information_schema.PROCESSLIST` |
| Which queries cost the most? | `sys.statement_analysis` (fingerprints sorted by cost), `performance_schema.events_statements_summary_by_digest` |
| Is an index used? | `sys.schema_unused_indexes` (after a representative period of activity), `performance_schema.table_io_waits_summary_by_index_usage` |
| Open transactions / conflicts | `information_schema.INNODB_TRX`, `information_schema.MIRAJ_CONCURRENCY`, `information_schema.MIRAJ_DEFERRED_UPDATE` |
| Parallelism | `information_schema.MIRAJ_PARALLELISM`, `SHOW STATUS LIKE 'Miraj_parallel_%'` |
| Activity counters | `SHOW GLOBAL STATUS;` (or `SHOW STATUS` for the session) |
| Settings | `SHOW VARIABLES LIKE '…';` / `SELECT @@name;` |
| Slow queries | `--slow-query-log`, table `miraj.slow_log`, counter `Slow_queries`, `long_query_time` |
| Server errors | `<data>/miraj/server.log` (server started with `--log`) |
| Cluster | `SHOW CLUSTER STATUS;`, `information_schema.MIRAJ_NODES`, `MIRAJ_REPLICATION` |

`performance_schema` and `sys` are read-only and require a privilege: `GRANT SELECT ON performance_schema.* TO …` (same for `sys`).

## Method: a query is slow

1. **Identify**: `SELECT query, db, exec_count, total_latency, avg_latency, rows_examined_avg, full_scan FROM sys.statement_analysis LIMIT 10;`
2. **Understand**: `EXPLAIN SELECT …;` then, if you accept actually running it, `EXPLAIN ANALYZE SELECT …;` (returns the real times and rows per operator). Warning: `ANALYZE UPDATE|DELETE` really modifies the rows.
3. **Look for**: full scan of a large table (`full_scan`), no index on the filter or the join, a function applied to a column in the `WHERE` (prevents the index), large-volume sort, needless `SELECT *`.
4. **Fix**: suitable index (`CREATE INDEX …`), query rewrite, statistics (`ANALYZE TABLE t;`). Rarely read history tables can move to the **disk** engine (`ENGINE = DISK`) to free memory.
5. **Prove**: rerun `EXPLAIN` and measure before/after with the same load (several repetitions: a shared machine skews an isolated measurement).

## Method: everything is slow / saturated

- `SHOW FULL PROCESSLIST;`: spot a very long statement or many concurrent sessions.
- `SELECT * FROM information_schema.MIRAJ_PARALLELISM;`: budget threads vs busy threads; a high `Miraj_parallel_queries_serialized_load` = as many statements as threads (normal under heavy load).
- Shared machine: reduce `--parallel-threads` or cap with `SET max_parallel_degree = n` for background jobs.
- Memory: the engine keeps tables in memory; watch the machine's RAM and consider `ENGINE = DISK` for large cold tables. Memory and disk-space safeguards exist (see the manual, chapter 11.4.5).

## Method: conflicts and blocking

MIRAJ does **not use row locks**: optimistic multiversion control.

- A `SELECT` never blocks and is never cancelled.
- Two writes on the same row: the first to commit wins, the second is aborted immediately.
- **Error 1213 (SQLSTATE 40001)** = "replay the transaction": to be handled on the application side (see the `miraj-dev` skill). Isolated statements in autocommit are replayed automatically by the engine.
- `SELECT … FOR UPDATE` waits for the holder; a deadlock is detected immediately (1213 for the one that would close the cycle).
- `1205`: table lock wait exceeded (`--lock-wait-timeout`, 50 s) — look for a `LOCK TABLES` or a very long statement.
- Many 1213: consult `MIRAJ_DEFERRED_UPDATE` (`COMMIT_FAILURES`, `FAILED_READ_VALIDATION`); a high `FAILED_READ_VALIDATION` value signals transactions that read a row before updating it — to be rewritten as a direct `UPDATE`.
- Stopping a query: `KILL QUERY <id>;` (the id comes from `SHOW PROCESSLIST`) — ask for agreement first.

## Regular maintenance

```sql
CHECK TABLE t1, t2;          -- consistency check
ANALYZE TABLE t1;            -- statistics for the planner
OPTIMIZE TABLE t1;           -- space of deleted rows (in-memory table)
```

A **disk** table (`.dmrj`) does not shrink with `OPTIMIZE TABLE`. `FLUSH SLOW LOGS` reopens the slow-query file after rotation.

## Alerts to set up

| Signal | Indicative threshold |
|---|---|
| Disk space of the data folder and of `--backup-dir` | < 20 % free |
| Last successful backup | > 24 h |
| `verify --deep` of a backup | last test > 30 days |
| Errors in `server.log` | any new error line |
| Connections | > 80 % of `max_connections` |
| Express/Developer edition | approaching 20 GB (errors 9005/9011) |
| Cluster: replication lag | growing in `MIRAJ_REPLICATION` |
