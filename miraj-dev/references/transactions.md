# Transactions and concurrency

## Model

MIRAJ isolates at the `SERIALIZABLE` level (the only one) through **optimistic multiversion control**: each transaction works on its own snapshot, **without row locks**.

| Situation | Behavior |
|---|---|
| `SELECT` while another session writes | Never blocks, never sees a half-written state, is never aborted |
| Two sessions modify the same row | The first to commit wins; the other is aborted right away (no waiting) |
| `SELECT … FOR UPDATE` on a held row | **Waits** for the holder to finish, then reads the committed value |
| Transactions not serializable together | One is aborted at its commit |
| `FOR UPDATE` deadlock | Detected immediately: 1213 for the one that would close the cycle |

`SET TRANSACTION ISOLATION LEVEL …` is accepted but has no effect.

## Autocommit and transactions

- By default `autocommit = 1`: each statement is its own transaction; on conflict, **the engine replays it** up to 3 times (50 µs, 200 µs, 800 µs).
- `START TRANSACTION` (or `autocommit = 0`): explicit transaction — **the engine cannot replay it**; it is aborted entirely with error **1213** (SQLSTATE `40001`).
- `START TRANSACTION READ ONLY`, `WITH CONSISTENT SNAPSHOT`, `SAVEPOINT` / `ROLLBACK TO SAVEPOINT` available. XA transactions supported.

## Golden rule: replay on 1213

```python
import miraj, random, time

def transaction(conn, work, attempts=5):
    for n in range(1, attempts + 1):
        try:
            with conn:                     # commits on exit, rolls back on exception
                return work(conn.cursor())
        except miraj.TransactionRollbackError:     # SQLSTATE 40…, including 1213
            conn.rollback()
            if n == attempts:
                raise
            time.sleep(random.uniform(0.005, 0.05) * n)

def virement(cur):
    cur.execute("UPDATE comptes SET solde = solde - %s WHERE id = %s", (100, 1))
    cur.execute("UPDATE comptes SET solde = solde + %s WHERE id = %s", (100, 2))

transaction(conn, virement)
```

- Replay the **whole transaction**, not just the last statement.
- The replayed work must be **idempotent on the application side** (no external effect — e-mail, HTTP call — before the `COMMIT`).
- Increasing random pause between two attempts; give up after a few attempts.

## Reducing conflicts

- **Write directly**: `UPDATE stock SET q = q - 1 WHERE id = 7` rather than reading `q` then writing `q-1`. MIRAJ handles these single-row `UPDATE`s designated by their key as **deferred updates** (re-evaluated at `COMMIT`), which avoids most conflicts on "hot" rows.
- **Short** transactions: do not keep a transaction open during user input or an external call.
- Touch rows **in the same order** in all transactions.
- `SELECT … FOR UPDATE` only when a row really must be reserved; it waits for the holder.
- Read-only: use `READ ONLY` or autocommit; these readers are never aborted.

## Table locks

`LOCK TABLES … READ|WRITE` / `UNLOCK TABLES` exist but wait up to `lock_wait_timeout` (50 s) then give **1205**. Avoid in everyday application code.

## Codes to know

| Code | Meaning | Action |
|---|---|---|
| 1213 (40001) | Conflict: transaction to replay | `ROLLBACK`, replay the whole transaction |
| 1205 | Table lock wait exceeded | Look for a `LOCK TABLES` or a statement that is too long |
| 1062 | Unique key duplicate | Handle in business logic (`ON DUPLICATE KEY UPDATE`) |
| 1146 | Table does not exist | Check current database and name |
| 1317 | Statement interrupted (`KILL QUERY`, Ctrl-C) | — |
| 1040 | Too many connections | Reduce the pool or raise `max_connections` |

Full list: manual, chapter 15.
