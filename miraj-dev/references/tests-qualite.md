# Testing and quality

## Environments

| Environment | Setup |
|---|---|
| Developer workstation | **Developer** or **Express** edition; `miraj-server --root .\data-dev --log` |
| Fast automated tests | **Embedded** mode: `miraj.connect(path=tmp_dir, dbname="test", create=True)` — no server, throwaway folder |
| Acceptance testing | Copy of a production backup: `RESTORE DATABASE recette FROM '…'` (never on production) |
| Production | Licensed Enterprise/Cluster edition, restricted application account, TLS |

## An ephemeral test server

```text
miraj-server --root %TEMP%\miraj-test --port 0 --log
```

`--port 0` lets the system choose a free port (shown at startup). Set `MIRAJ_INITIAL_ROOT_PASSWORD` to know the `root` password. Then stop **this** server only (by its process identifier), not all the `miraj-server` processes on the machine.

## Pytest (example)

```python
import miraj, pytest

@pytest.fixture
def conn(tmp_path):
    c = miraj.connect(path=str(tmp_path), dbname="test", create=True)
    cur = c.cursor()
    cur.execute("CREATE TABLE comptes (id INT PRIMARY KEY, solde DECIMAL(12,2) NOT NULL)")
    cur.execute("INSERT INTO comptes VALUES (1, 500), (2, 0)")
    c.commit()
    yield c
    c.close()

def test_virement(conn):
    cur = conn.cursor()
    cur.execute("UPDATE comptes SET solde = solde - 100 WHERE id = 1")
    cur.execute("UPDATE comptes SET solde = solde + 100 WHERE id = 2")
    conn.commit()
    cur.execute("SELECT SUM(solde) FROM comptes")
    assert cur.fetchone()[0] == 500
```

## Always test

- **Concurrency**: two connections modifying the same row; the second must receive 1213 and the replay code must succeed.
- **Constraints**: duplicate (`DupEntry`), foreign key, `CHECK`, out-of-range value (strict mode).
- **Volumes**: realistic dataset so that `EXPLAIN` reflects production.
- **Schema migrations**: apply the scripts in order on a copy, then rerun the tests.
- **Recovery**: application behaves correctly after a lost connection (broken link, `08S01`).
- **Rights**: the application account can only do what is intended (a `DROP TABLE` must be refused).

## Continuous integration

- Use embedded mode (no service to install on the agent).
- Data folder in a temporary directory deleted after the test.
- `miraj-cli --json` outputs usable for comparing results.
- If a load test fails in batches on a busy machine, rerun it **serially** and at rest before concluding there is a defect.

## Code review: questions to ask

1. Does every explicit transaction know how to be replayed on 1213?
2. Are all user values parameterized?
3. Is the connection account restricted? Is the password kept out of the repository?
4. Do frequent queries have an index (checked with `EXPLAIN`)?
5. Are bulk writes grouped?
6. Are schema scripts replayable and tested on a copy?
