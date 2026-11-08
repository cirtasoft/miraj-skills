# MIRAJ schema and SQL

## Design

- Primary key on every table; `AUTO_INCREMENT` for generated identifiers (`lastrowid` on the client side).
- Exact types: `DECIMAL(p,s)` for money, `DATE`/`DATETIME` for dates, bounded `VARCHAR(n)` for short texts, `BLOB`/`TEXT` for large content (a `BLOB` value beyond 8 KB leaves the table for a separate store), `JSON`, `VECTOR(n)` for embeddings.
- Foreign keys and `CHECK` constraints: enforced by the engine.
- Strict mode by default: plan for validation on the application side, invalid values are rejected.

## Example database

```sql
CREATE DATABASE gestion;
USE gestion;

CREATE TABLE clients (
    id      INT PRIMARY KEY AUTO_INCREMENT,
    nom     VARCHAR(100) NOT NULL,
    ville   VARCHAR(60),
    cree_le DATETIME NOT NULL,
    KEY (ville)
);

CREATE TABLE commandes (
    id        BIGINT PRIMARY KEY AUTO_INCREMENT,
    client_id INT NOT NULL,
    montant   DECIMAL(12,2) NOT NULL CHECK (montant >= 0),
    cree_le   DATETIME NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id),
    KEY (client_id, cree_le)
);
```

## Storage engines

| Engine | Where rows live | For |
|---|---|---|
| in-memory (default; `ENGINE` absent, `MIRAJ`, `InnoDB`, `MEMORY`) | RAM, compressed columns, `.mrj` for durability | frequently queried tables, analytical computations: the fastest |
| `ENGINE = DISK` (also `Aria`, `MyISAM`) | paged `.dmrj` file; only indexes in memory | large, rarely read history tables |

Same SQL, same transactions and durability for both. A disk table does not accept the vector index or the full-text index.

## Schema evolution

```sql
ALTER TABLE clients ADD COLUMN email VARCHAR(120);
CREATE INDEX idx_clients_nom ON clients (nom);
ALTER TABLE clients DROP INDEX idx_clients_nom;
SHOW CREATE TABLE clients;
```

- Evolve through numbered, replayable scripts, tested on a copy.
- `ALTER` on a large table: measure on a copy before production.

## Writing (DML)

```sql
INSERT INTO clients (nom, ville, cree_le) VALUES ('Alice', 'Alger', NOW());

-- Insert or update
INSERT INTO stock (article_id, quantite) VALUES (7, 5)
ON DUPLICATE KEY UPDATE quantite = quantite + VALUES(quantite);

-- Retrieve the written rows
INSERT INTO clients (nom, ville, cree_le) VALUES ('Bob', 'Oran', NOW()) RETURNING id;

UPDATE comptes SET solde = solde - 100 WHERE id = 1;
DELETE FROM commandes WHERE cree_le < '2020-01-01';
```

`REPLACE INTO` deletes then reinserts on conflict (beware of foreign keys and triggers). File loading: `LOAD DATA` (the `LOCAL` mode is set by `--local-infile`).

## Reading (SELECT)

Joins, aggregates, `GROUP BY` (relaxed: a column outside `GROUP BY` takes a value from the group), subqueries, CTEs, `WITH RECURSIVE`, window functions (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `QUALIFY`), `UNION`, `LIMIT`. See manual, chapters 7 and 8 (SQL functions).

```sql
SELECT c.ville, COUNT(*) AS nb, SUM(o.montant) AS total
FROM clients c JOIN commandes o ON o.client_id = c.id
WHERE o.cree_le >= '2026-01-01'
GROUP BY c.ville
ORDER BY total DESC
LIMIT 10;
```

## Views

```sql
CREATE VIEW v_clients_actifs AS SELECT id, nom FROM clients WHERE ville IS NOT NULL;
CREATE CACHED VIEW v_ca_mensuel AS SELECT …;   -- result kept, validated by stamp
REFRESH VIEW v_ca_mensuel;                       -- for a frozen view
```

## Routines, triggers, events

`CREATE PROCEDURE`, `CREATE FUNCTION`, `CREATE TRIGGER`, `CREATE EVENT` (scheduler: `--event-scheduler ON`). Avoid functions in a `WHERE` on a large table (performance); keep triggers short: they run inside the write's transaction.

## Sequences, temporal tables, partitions

`CREATE SEQUENCE`, history tables (chapter 22), partitioning (`PARTITION BY …`, chapter 5). Use only when specifically needed.

## Collations

Case- and accent-insensitive comparisons depending on the collation; a mix of collations takes the widest one (unicode > general > binary) without error. Chapter 25.
