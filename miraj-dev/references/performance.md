# Performance on the developer side

MIRAJ keeps columns in memory: speed comes from the shape of queries, indexes and the volume read. **Measure before and after**, several repetitions, same data.

## Approach

1. Spot: `SELECT query, exec_count, avg_latency, rows_examined_avg, full_scan FROM sys.statement_analysis LIMIT 10;` (requires `GRANT SELECT ON sys.*`).
2. Read the plan: `EXPLAIN SELECT …;`
3. Actually measure: `EXPLAIN ANALYZE SELECT …;` — **executes** the query and returns rows and time per operator. `ANALYZE UPDATE|DELETE` really modifies the rows: never on production data without agreement.
4. Fix (index, rewrite, batch), then re-measure.

## Indexes

- Index the columns used for frequent filtering (`WHERE`), joining and sorting; composite index in order: equalities first, range after.
- An unnecessary index costs on every write: `SELECT * FROM sys.schema_unused_indexes;` after a representative period of activity.
- A **function applied to the column** in the `WHERE` (`WHERE YEAR(cree_le) = 2026`) prevents the index: write a range (`cree_le >= '2026-01-01' AND cree_le < '2027-01-01'`).
- Index on `VECTOR`: ordinary for equality; `VECTOR INDEX` vector index for (approximate) nearest neighbor.

## Queries

- Do not `SELECT *`: read only the useful columns (columnar storage: it is free for the ones you do not read).
- `LIMIT` for any paginated read; sort on an indexed column.
- Aggregation: let the engine do it (`SUM`, `GROUP BY`) rather than fetching the rows.
- Avoid one query per row (N+1): join or `IN (…)`.
- Functions in a `WHERE` on a large table: see manual, chapter 5 ("functions in a WHERE").

## Bulk writes

- Multi-row `INSERT … VALUES (…), (…), …` (or `execute_values`, `insert_rows` in Python) rather than row by row: by far the biggest gain.
- Load in bulk with `LOAD DATA` for files.
- A batch transaction of reasonable size (thousands of rows), neither one per row nor a giant one.
- Triggers: cost added to every written row; keep their body short.

## Engines and memory

- Hot and analytical tables: memory engine (default).
- Huge, rarely read histories: `ENGINE = DISK` (only indexes stay in memory).
- Watch the machine's RAM.

## Parallelism (Enterprise / Cluster)

Large reads (filters, aggregates, sorting, `DISTINCT`, joins) are spread over several cores, same results and same order. `EXPLAIN` shows the degree chosen. `SET max_parallel_degree = n;` bounds a session (background processing). Express: a single thread per query.

## Connections

- Pool bounded below `max_connections`; connections reused.
- One connection per worker thread (a connection can be shared but its calls are serialized).
- Network latency: group statements (stored procedure, batches) to reduce round trips.

## Measuring properly

- A dedicated timestamped client (Python `miraj` library), not a console that adds its own latency.
- Repeat, alternate A/B variants, discard the first pass (cold load).
- Shared machine: check that no other server or build is running during the measurement.
