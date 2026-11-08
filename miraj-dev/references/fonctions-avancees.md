# Advanced functions

## Full-text search

```sql
CREATE TABLE art (
  id INT PRIMARY KEY,
  designation VARCHAR(100),
  notes TEXT,
  FULLTEXT ft (designation WEIGHT 3, notes)       -- WEIGHT: per-column weight (MIRAJ extension)
);
SELECT id, designation FROM art WHERE MATCH(designation, notes) AGAINST ('stylo bleu');
```

- `CHAR`, `VARCHAR`, `TEXT`, `JSON` columns of the same collation.
- Not on a temporary table or a disk table.
- The index is in memory and rebuilt on open; `CHECK TABLE` checks it.
- Search tolerant of accents and case depending on the collation; fuzzy search and BM25 score: manual, chapters 7 (§7.22) and 5.

## Vector search (AI, embeddings)

```sql
CREATE TABLE document (
    id         INT PRIMARY KEY,
    titre      VARCHAR(200),
    plongement VECTOR(768) NOT NULL,
    VECTOR INDEX (plongement) M=16 DISTANCE=cosine
);

SELECT id, titre
FROM document
ORDER BY VEC_DISTANCE_COSINE(plongement, VEC_FromText('[0.12, -0.03, ...]'))
LIMIT 10;
```

- Without an index: **exact** result, cost proportional to the table. With `VECTOR INDEX`: a fraction of a millisecond, **approximate** result.
- Constraints: a single `VECTOR(n) NOT NULL` column, a single vector index per table, not on a disk table.
- Options: `M` (3–200, larger = better recall but more memory); `DISTANCE` = `euclidean`, `cosine`, `dot`. The query's metric must match the index's.
- Python: `miraj.extensions.to_vector()` converts a vector that was read.
- Manual, chapter 19.

## JSON

`JSON` columns and JSON functions (extraction, modification, aggregates, JSON tables): manual, chapter 8. Python: `miraj.extras.Json` to pass a document as a parameter.

## Temporal tables

Automatic row history (querying at a past date): manual, chapter 22.

## Change events

`LISTEN` on a table; the application receives the changes (key, columns, payload): in Python, `conn.wait_changes(timeout)`. Useful for updating a UI or a cache. Manual, chapter 20.

## Sequences and computed columns

`CREATE SEQUENCE`, generated columns, `AUTO_INCREMENT`: manual, chapter 5.

## Custom REST API: `CREATE ENDPOINT`

Publish an SQL query as an HTTP route with typed parameters (`GET /clients/{id}`), `EXECUTE` right for authorized accounts. The client application knows only the route, not the schema. Manual, chapter 23.

## AI assistants

Expose the database to an assistant (Claude Code…) with a limited-level token: `miraj-mcp` skill.
