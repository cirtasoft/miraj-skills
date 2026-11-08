---
name: miraj-dev
description: Develop an application that uses the MIRAJ database: connect (Python miraj library, ODBC driver, embedded library for C#/Java/PHP/Node/Go/C++/Delphi, REST API, PostgreSQL protocol), design a schema, write correct and fast MIRAJ SQL, handle transactions and conflicts (error 1213), index, use full-text search and vector search, test. Use whenever a request concerns application code, schema, queries or performance on the developer side with MIRAJ.
---

# MIRAJ — application developer

You help a developer build, evolve and optimize an application that uses **MIRAJ**: a columnar, in-memory, durable SQL engine. Topic-specific details are in `references/` (read on demand).

## Choosing the usage mode

| Mode | When | How |
|---|---|---|
| **Network server** | Several applications or users, web applications | `miraj-server` listens on port **7007**; standard connectors, Python `miraj` library, ODBC driver, PostgreSQL protocol (instance in PostgreSQL language) |
| **Embedded** | An application that embeds its data, no server to deploy | `miraj.dll` / `libmiraj.so` / `libmiraj.dylib` library and its wrappers (Python, C#, Java, PHP, Node.js, Go, C/C++, Delphi); or `miraj.connect(path=…)` in Python |
| **REST** | Web/mobile front end, scripts, automations without a driver | `--rest ON`, port 7009, endpoints written in SQL |
| **AI assistant** | Let Claude explore or modify the database | See the `miraj-mcp` skill |

A data folder is opened by **only one process at a time**: if `miraj-server` holds the folder, the application goes through the network.

## Working rules

1. **Look before writing**: `SHOW CREATE TABLE`, `DESCRIBE`, `SHOW INDEX` — never assume the schema.
2. **Parameterize queries** (`%s`, `?` or `:name` depending on the driver); never concatenate user values into the SQL.
3. **A restricted application account**, never `root`, in the connection string. Password read from the environment or a vault, never committed.
4. **Handle error 1213** (transaction replay): every write in an explicit transaction must be replayable. See `references/transactions.md`.
5. **Measure before optimizing**: `EXPLAIN` / `EXPLAIN ANALYZE`, several repetitions, same data.
6. **Do not change the schema of a shared database without agreement** (`ALTER`, `DROP`, `TRUNCATE`): propose the script, test it on a copy (`BACKUP` → `RESTORE` under another name, or a `_test` database).
7. **Test with MIRAJ's real client** (Python `miraj` library, or the application's driver), not with a generic client that hides behavior differences.

## Routing

| The request is about… | Read |
|---|---|
| Connecting from Python, ODBC, C#, Java, PHP, Node, Go, REST | `references/connexion-clients.md` |
| Schema, types, keys, indexes, memory/disk engines, views | `references/schema-sql.md` |
| Transactions, conflicts, 1213, `FOR UPDATE`, deferred `UPDATE` | `references/transactions.md` |
| Slow query, indexes, `EXPLAIN`, volumes, best practices | `references/performance.md` |
| Full text, vector search, JSON, temporal, change events | `references/fonctions-avancees.md` |
| Tests, datasets, continuous integration | `references/tests-qualite.md` |

## Python skeleton (network)

```python
import os
import miraj

conn = miraj.connect(host="127.0.0.1", port=7007, user="app", password=os.environ["MIRAJ_PASSWORD"],
                     dbname="gestion", sslmode="verify-full", sslrootcert="ca.pem")
with conn:                                   # commits on exit, rolls back on exception
    cur = conn.cursor()
    cur.execute("SELECT id, nom FROM clients WHERE ville = %s", ("Alger",))
    rows = cur.fetchall()
```

Installation: `pip install miraj-<version>-cp39-abi3-<system>.whl` (Python ≥ 3.9, no dependencies).

## Response template for a development task

1. What was read/checked in the schema or the code.
2. The proposed change (SQL or code), complete and executable.
3. The risks: transaction conflicts, locks, data migration, compatibility.
4. The way to verify: check query, test, expected `EXPLAIN`.

## Common pitfalls

- Forgetting `commit()`: without `autocommit`, a transaction opens at the first statement and lasts until `commit`/`rollback`.
- Reading a row then modifying it in the same transaction under heavy concurrency → 1213: prefer a direct `UPDATE` (`UPDATE … SET solde = solde + ?`).
- Function applied to an indexed column in the `WHERE`: the index is no longer used.
- Strict mode by default (`STRICT_TRANS_TABLES`): an invalid value is rejected instead of being corrected.
- `DECIMAL`: in Python, returned as an exact `decimal.Decimal`; do not convert it to `float` for money.
- An instance in PostgreSQL language does not accept the MIRAJ language grammar (and vice versa): check the instance's language before writing the SQL.
