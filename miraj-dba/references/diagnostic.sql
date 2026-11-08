-- MIRAJ check queries for a DBA.
-- Run with: miraj-cli --host 127.0.0.1 --user root diagnostic.sql   (or with "source diagnostic.sql" in the console)
-- All are read-only.

-- 1. Server identity ----------------------------------------------------------
SELECT @@miraj_edition AS edition, @@version_comment AS commentaire, VERSION() AS version;
SHOW DATABASES;
SHOW GLOBAL STATUS LIKE 'Uptime';
SHOW VARIABLES LIKE 'save_%';
SHOW VARIABLES LIKE 'max_connections';

-- 2. Current activity ---------------------------------------------------------
SHOW FULL PROCESSLIST;
SELECT * FROM information_schema.INNODB_TRX;          -- open transactions
SELECT * FROM information_schema.MIRAJ_CONCURRENCY;   -- model, active transactions, oldest transaction
SELECT * FROM information_schema.MIRAJ_PARALLELISM;   -- budget threads and busy threads

-- 3. Most expensive queries since startup ------------------------------------
SELECT query, db, exec_count, total_latency, avg_latency, rows_examined_avg, full_scan
FROM sys.statement_analysis
LIMIT 10;

-- 4. Indexes never read (interpret after a representative period of activity)
SELECT * FROM sys.schema_unused_indexes;

-- 5. Transaction conflicts -----------------------------------------------------
SELECT INTENTS_RECORDED, ROWS_APPLIED, COMMIT_FAILURES, FAILED_READ_VALIDATION,
       ENGINE_RETRIES, NORMAL_KEY, NORMAL_TRIGGER
FROM information_schema.MIRAJ_DEFERRED_UPDATE;

-- 6. Table size (largest first) -----------------------------------------------
SELECT table_schema, table_name, table_rows, engine
FROM information_schema.TABLES
WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'sys', 'miraj')
ORDER BY table_rows DESC
LIMIT 20;

-- 7. Accounts and rights -------------------------------------------------------
SELECT * FROM information_schema.USER_PRIVILEGES;
SELECT * FROM information_schema.SCHEMA_PRIVILEGES;

-- 8. Cluster (Cluster edition only) -------------------------------------------
-- SHOW CLUSTER STATUS;
-- SELECT * FROM information_schema.MIRAJ_NODES;
-- SELECT * FROM information_schema.MIRAJ_REPLICATION;

-- 9. MCP tokens (Enterprise, Cluster, Developer editions) ----------------------
-- SHOW MCP TOKENS;
