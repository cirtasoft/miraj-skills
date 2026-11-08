# Accounts, privileges and security

## Principles

- An account = user + host: `'app'@'10.0.0.%'`.
- **One account per use** (an application, a person). Never a shared `root`.
- **Minimum necessary**: a read account has only `SELECT` on the databases it consults.
- The password can never be retrieved (only a verifier is kept): a forgotten one is fixed with `ALTER USER … IDENTIFIED BY`.

## Account management

```sql
CREATE USER 'app'@'10.0.0.%' IDENTIFIED BY 'strong-password';
ALTER USER 'app'@'10.0.0.%' IDENTIFIED BY 'new-password';
ALTER USER 'app'@'10.0.0.%' ACCOUNT LOCK;      -- locks without deleting
DROP USER 'app'@'10.0.0.%';
SELECT CURRENT_USER();
```

## Privileges (`GRANT` / `REVOKE`)

Levels: global (`*.*`), database (`gestion.*`), table (`gestion.clients`), column, routine.

```sql
-- Read-only on a database
CREATE USER 'rapport'@'10.0.0.%' IDENTIFIED BY '…';
GRANT SELECT ON gestion.* TO 'rapport'@'10.0.0.%';

-- Application: reads and writes, does not change the schema
GRANT SELECT, INSERT, UPDATE, DELETE ON gestion.* TO 'app'@'10.0.0.%';

-- Administrator of a single database, who can delegate
GRANT ALL ON gestion.* TO 'dba_gestion'@'localhost' WITH GRANT OPTION;

-- Withdrawal
REVOKE INSERT, UPDATE, DELETE ON gestion.* FROM 'rapport'@'10.0.0.%';

SHOW GRANTS FOR 'app'@'10.0.0.%';
```

- `EXECUTE` is required to call a routine or a REST endpoint.
- `BACKUP_ADMIN` is required for `BACKUP` / `RESTORE`.
- `RELOAD` for `FLUSH`, `FILE` for `LOAD_FILE` / `SELECT … INTO DUMPFILE` (grant only if indispensable).

### Roles

```sql
CREATE ROLE lecteur;
GRANT SELECT ON gestion.* TO lecteur;
GRANT lecteur TO 'alice'@'%';
SET ROLE lecteur;                 -- activates in the session
```

### Auditing rights

```sql
SELECT * FROM information_schema.USER_PRIVILEGES;
SELECT * FROM information_schema.SCHEMA_PRIVILEGES;
SELECT * FROM information_schema.TABLE_PRIVILEGES;
SELECT * FROM information_schema.APPLICABLE_ROLES;
```

## Hardening when opening a new folder

1. Immediately replace the temporary `root` password.
2. Create the restricted application accounts **before** opening listening to the network.
3. Keep `--require-password ON` (default): refuses an account without a password that is reachable remotely.
4. Enable TLS (`--tls-cert`, `--tls-key`) as soon as the server is not on loopback; on the client side, require verification (`--ssl-ca`, `sslmode=verify-full`).
5. `--local-infile OFF` if no application uses `LOAD DATA LOCAL`.
6. Leave `--secure-file-priv` empty (file-reading functions disabled) unless specifically needed.
7. Firewall: do not open ports 7007, 7008 (MCP), 7009 (REST) to the Internet. For remote access, use MIRAJ Tunnel rather than exposing the port.

## Account vault and key

- Accounts, passwords (verifiers) and privileges are in `miraj/accounts.mra`, encrypted (AES-256-GCM).
- The key that protects it is **outside the data folder** (Windows: protected by DPAPI in `%LOCALAPPDATA%\MIRAJ\keys` of the account running the server; elsewhere: file with `0600` permissions). `--key-dir` chooses another location.
- **Copying only the data folder is not enough** to reopen the accounts on another machine: also back up the key, protected like an administrator password.

## Lost `root` password

Emergency procedure, **destructive for accounts** (the databases remain): with the server stopped, then

```text
miraj-server --root D:\donnees --reset-accounts
```

recreates the vault with only the local `root` and a new password (displayed once, or the one from `MIRAJ_INITIAL_ROOT_PASSWORD`). All other accounts must be recreated — ask for confirmation and first advise a `miraj-dump --users` export if the server is still accessible.

## Encryption at rest (Enterprise and Cluster)

`--data-encryption ON` on a **new** folder; the passphrase is supplied by `MIRAJ_ENCRYPTION_PASSPHRASE` or `--encryption-passphrase-file`. Without the passphrase, the folder is unreadable: back it up separately. A copy of an encrypted database stays encrypted.

## Access tokens for AI assistants and API

- AI assistants (MCP, Enterprise/Cluster/Developer): `CREATE MCP TOKEN` — see the `miraj-mcp` skill. A token cannot be retrieved after creation; revoke with `DROP MCP TOKEN`.
- Always prefer the lowest access level (`STRUCTURE` < `READ` < `WRITE` < `ADMIN`), a `DATABASES (…)` scope and an expiry (`EXPIRE INTERVAL n DAY`).
