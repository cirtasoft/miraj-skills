# MIRAJ Skills

Ready-to-use skills that teach how to **operate** and **develop with** the [MIRAJ](https://cirtasoft.com/mirajdb) database (CIRTASOFT): a columnar, in-memory and durable SQL engine optimized for artificial intelligence.

## What you get

Three independent skills, which your AI model activates on its own depending on your request:

| Skill | For whom | It knows how to… |
|---|---|---|
| **`miraj-dba`** | Database administrator | Install and start the server, create accounts and privileges, secure (TLS, account vault, `root` password), back up and restore, monitor, diagnose a slowdown or a block, migrate, manage a cluster |
| **`miraj-dev`** | Application developer | Connect (Python, ODBC, embedded libraries, REST, PostgreSQL), design the schema, write correct and fast SQL, manage transactions and conflicts (error 1213), index, use full-text and vector search, test |
| **`miraj-mcp`** | User of an AI assistant connected to MIRAJ | Explore and modify a database through the MCP tools according to the token level; on the administrator side, open the MCP endpoint and create a token |

## Example requests

**As a DBA**

- "The server has been slow since this morning, help me find out why."
- "Set up a daily backup and check that we know how to restore it."
- "Create a read-only account for the reporting service on the `gestion` database."
- "I lost the `root` password: what can I do, without losing the data?"
- "Prepare the migration of our current database to MIRAJ."

**As a developer**

- "Write the Python access layer for these tables, with transaction replay on conflict."
- "This query takes 4 seconds: analyze the plan and suggest the right index."
- "Add similarity search on the documents with a vector index."
- "Set up a test suite with an embedded MIRAJ database."

**With an assistant connected through MCP**

- "List the tables of the `ventes` database and describe their structure."
- "How many orders per city this quarter?"

## Principles the skills enforce

- **Data integrity first**, then stability, then speed.
- **No destructive action without explicit agreement** (`DROP`, `TRUNCATE`, `RESTORE … REPLACE`, `--reset-accounts`, `KILL`).
- **Restricted accounts** rather than `root`, **passwords never on a command line** or in code.
- **Verify before asserting**: query the server (`SHOW …`, `SELECT @@…`) rather than assume.
- **Measure before optimizing** (`EXPLAIN`, `EXPLAIN ANALYZE`).
- **Test restores**: a backup that has never been restored is not a backup.

## Folder contents

```text
skill/
├── README.md                      This overview
├── INSTALLATION.md                Install the skills and prepare MIRAJ
├── install.ps1  /  install.sh     One-command installation (Windows / Linux, macOS)
├── miraj-dba/
│   ├── SKILL.md
│   └── references/                exploitation, comptes-securite, sauvegarde-restauration,
│                                  supervision-diagnostic, cluster-migration, diagnostic.sql
├── miraj-dev/
│   ├── SKILL.md
│   └── references/                connexion-clients, schema-sql, transactions, performance,
│                                  fonctions-avancees, tests-qualite
└── miraj-mcp/
    └── SKILL.md
```

Each `SKILL.md` is short and acts as a router; the details are in `references/`, which the model only loads when the request requires it. This keeps the context light.

## Quick start

1. Install MIRAJ (see [INSTALLATION.md](INSTALLATION.md), part 1).
2. Install the skills: `./install.ps1` (Windows) or `./install.sh` (Linux, macOS).
3. Restart Claude Code and ask a question, for example: "Connect to my MIRAJ server on 127.0.0.1:7007 and tell me which edition is running."

## MIRAJ editions and functions used by the skills

| Edition | Particulars |
|---|---|
| Express (free) | One thread per query, 20 GB, no MCP |
| Developer | All functions, one core, 20 GB, 24 h of service: development only |
| Enterprise | Parallel queries, MCP, encryption at rest (license) |
| Cluster | Enterprise + multi-node replication (license) |

The skills state the required edition each time.

## Sources and updates

The skills draw on the **MIRAJ user manual** (`docs/manuel` folder): the chapter numbers cited refer to it. After a new MIRAJ version, re-read the relevant chapters and update the references. To suggest a correction, edit the Markdown files directly: no generation tool is needed.

## Limits

- The skills guide the LLM model; they do not replace the manual or an administrator for production decisions.
- The LLM model acts with the rights of the account and token you give it: give it the minimum necessary.
- The manual's functions marked "planned" (for example the `miraj-mcp` bridge for stdio clients) are not yet available.
