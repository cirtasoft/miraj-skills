# Connecting to MIRAJ from an application

## Common parameters

| Item | Value |
|---|---|
| Host / port | `127.0.0.1` / `7007` (default) |
| Account | a restricted application account (never `root`) |
| TLS | `sslmode=verify-full` + authority (`sslrootcert`) as soon as the server is not local |
| Database | `dbname` / `-d` / `USE base;` |
| Message language | server `--lang` (en, fr, zh, hi, es, ar, pt, ru, de, ja) |

## Python — `miraj` library (psycopg2 style, DB-API 2.0)

```python
import miraj
conn = miraj.connect("miraj://app:motdepasse@serveur:7007/gestion?sslmode=required")
# or: miraj.connect(host=…, port=7007, user=…, password=…, dbname=…)
# embedded, no server: miraj.connect(path="/srv/donnees", dbname="gestion", create=True)
```

- Parameters: `%s` (sequence) or `%(name)s` (dictionary). `autocommit=False` by default.
- Cursors: `miraj.extras.DictCursor`, `RealDictCursor`, `NamedTupleCursor`.
- Batches: `conn.insert_rows(table, columns, rows)` or `miraj.extras.execute_values(cur, sql, rows)`.
- Pool: `miraj.pool.ThreadedConnectionPool(min, max, …)` (`getconn()`, `putconn()`).
- Errors: `miraj.errors.DupEntry` (1062), `NoSuchTable` (1146)…, `TransactionRollbackError` (SQLSTATE `40…`, to be replayed), `IntegrityError` (23…).
- Types: `DECIMAL` → `decimal.Decimal`, `DATETIME` → `datetime`, `VECTOR(n)` → bytes (`miraj.extensions.to_vector()`).
- Live changes: `LISTEN` + `conn.wait_changes(timeout)` (change events).

## Embedded library (C#, Java, PHP, Node.js, Go, C/C++, Delphi)

All wrappers handle three objects: **Server** (opens a root folder), **Session** (`execute`, `query`, `?` or `:name` parameters, last auto-increment id, affected rows) and **Result** (columns, cells, iteration). An SQL error raises the language's exception (code, SQLSTATE).

The native library is searched for in this order: location given by the program, `MIRAJ_DLL` environment variable, then the system loader. Putting `miraj.dll` (or `libmiraj.so` / `libmiraj.dylib`) next to the executable avoids any ambiguity. Complete examples for each language are in the manual, chapter 14.

## ODBC

**"MIRAJ ODBC Driver"** (`miraj_odbc.dll`), registered with Windows by the installer (or the PowerShell scripts in the zip). Data source: server, port, account, password, database, TLS mode. It adapts to the instance's language. Manual, chapter 26.

## Standard market protocol (MIRAJ language)

Port 7007 speaks a standard SQL client/server protocol: administration tools, JDBC/PDO/ODBC connectors and common clients connect to it without adaptation. For a migration from another server, only the host and port change in the connection string.

## Instance in PostgreSQL language

If the instance is in PostgreSQL language: `psql`, psycopg2, pgjdbc, Npgsql connect directly, using PostgreSQL grammar (manual, chapter 27).

## REST (HTTP/JSON)

`miraj-server --rest ON` (port 7009, loopback by default; TLS mandatory elsewhere). Three families, opened separately by the DBA:

- **Endpoints** (recommended): APIs written in SQL (`CREATE ENDPOINT`), typed parameters; `GET /clients/42`.
- **Tables**: `/api/{base}/{table}[/{key}]` — filters, sorting, pagination (`rest_tables ON`).
- **Free SQL**: `POST /api/sql` (`rest_sql ON`) — trusted internal tool only.

Authentication: `Authorization: Bearer mja_…` (token) or `Basic` (account:password, limited to endpoints by default). The account's SQL rights, down to the column, always apply. Manual, chapter 23.

## `miraj-cli` console for application scripts

```text
miraj-cli --host 127.0.0.1 --user app -d gestion -e "SELECT COUNT(*) FROM clients" --json
miraj-cli --host 127.0.0.1 --user app -d gestion migration.sql
```

Exit code `0` = success, `1` = failed statement, `2` = connection impossible. `--json` returns JSON usable by a program.

## Connection string: checklist

- [ ] Restricted account, password outside the source code
- [ ] TLS verified off the local machine
- [ ] Connection timeout set (`connect_timeout`)
- [ ] Connection pool sized below the server's `max_connections` (151 by default)
- [ ] Reconnection and transaction replay on 1213 / broken link
