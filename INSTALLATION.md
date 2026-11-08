# Installation

Two parts: **1. MIRAJ** (the server, if not already installed) and **2. the skills** (for Claude).

---

## 1. Installing MIRAJ

### Choosing the edition

| Need | Edition |
|---|---|
| Trying it out, small workloads | **Express** (free, 20 GB) |
| Developing an application with all features | **Developer** (one core, 20 GB, 24 h between restarts) |
| Production, heavy queries, AI assistants over MCP | **Entreprise** (`miraj.lic` license) |
| Production with replication | **Cluster** (`miraj.lic` license) |

### Windows

**With the wizard** (Express or Entreprise): run `MIRAJ-<version>-Express-setup.exe` (or `…-Entreprise-setup.exe`). The wizard asks for:

1. the folders (program and data);
2. the port (7007 by default) and the instance's SQL language (MIRAJ by default, or PostgreSQL);
3. where to listen: *this computer only* (recommended to start with) or *the whole network*;
4. the password of the `root` account;
5. automatic start with Windows and shortcuts.

**Without the wizard** (all editions): unzip the archive `MIRAJ-<version>-<edition>-win64.zip` and run:

```powershell
.\miraj-server.exe --root D:\donnees --log
```

On first start, the temporary `root` password is **displayed only once**: write it down, then change it.

### Linux

```bash
sudo apt install ./MIRAJ-<version>-Express-linux-<arch>.deb      # Debian, Ubuntu
sudo dnf install ./MIRAJ-<version>-Express-linux-<arch>.rpm      # Fedora, RHEL, SUSE
sudo sh MIRAJ-<version>-Express-linux-<arch>.sh                  # other distributions
sudo miraj-setup                                                 # root password, starts the service
```

The service is called `miraj-express`; data lives in `/var/lib/miraj-express` and the configuration in `/etc/miraj-express/miraj_config.xml`.

### macOS

Open `MIRAJ-<version>-Express-macos-<arch>.pkg`, then **Miraj Manager** for the initial setup (`root` password, port, listening).

### License (Entreprise and Cluster)

```text
miraj-server --root D:\donnees --install-license miraj.lic
```

Without a valid license, the server runs with the limits of the Express edition.

### Verifying

```text
miraj-cli --host 127.0.0.1 --port 7007 --user root
```

```sql
SELECT @@miraj_edition, VERSION();
SHOW DATABASES;
```

### Recommended first settings

```sql
ALTER USER root@localhost IDENTIFIED BY 'a-strong-password';
CREATE USER 'app'@'localhost' IDENTIFIED BY 'app-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON gestion.* TO 'app'@'localhost';
```

For backups, start the server with `--backup-dir E:\sauvegardes` (a folder outside the data directory).

---

## 2. Installing the skills

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed (terminal, VS Code extension or desktop app).
- A reachable MIRAJ server (part 1) so that Claude can query it.
- Optional: `miraj-cli` in the `PATH` so that Claude can run queries; the `miraj` Python library for development.

### Option A — installation script (recommended)

From the `skill/` folder:

```powershell
# Windows (PowerShell) — for all your projects
.\install.ps1

# for the current project only (shared through the repository)
.\install.ps1 -Scope Project

# a single skill
.\install.ps1 -Skills miraj-dev

# uninstall
.\install.ps1 -Uninstall
```

```bash
# Linux, macOS, Git Bash
./install.sh
./install.sh --project
./install.sh miraj-dev
./install.sh --uninstall
```

If PowerShell refuses to run the script: `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

### Option B — manual copy

Copy the `miraj-dba`, `miraj-dev` and `miraj-mcp` folders:

| Scope | Destination |
|---|---|
| All your projects | `~/.claude/skills/` (Windows: `%USERPROFILE%\.claude\skills\`) |
| One project (shared with the team) | `<project>/.claude/skills/` |

Each skill is a folder containing a `SKILL.md`; do not separate `references/` from its `SKILL.md`.

### Verifying the installation

1. Restart Claude Code (new session).
2. Type `/skills`: `miraj-dba`, `miraj-dev` and `miraj-mcp` should appear.
3. Ask a test question: "How do I back up a MIRAJ database and verify the backup?" — Claude should mention `BACKUP DATABASE`, `miraj-backup verify --deep` and the `--backup-dir` option.

### Connecting Claude to your server (optional)

Depending on your need:

| Need | How |
|---|---|
| Claude runs queries through the console | Install `miraj-cli`, give it a restricted account; enter the password through `MIRAJ_PASSWORD` in the environment |
| Claude explores the database with dedicated tools (Entreprise, Cluster, Developer) | Enable MCP and create a token: see `miraj-mcp/SKILL.md`, part 2 |
| Python application | `pip install miraj-<version>-cp39-abi3-<system>.whl` |

MCP example, in two steps:

```text
miraj-server --root D:\donnees --log --mcp ON
```

```sql
CREATE MCP TOKEN assistant FOR 'app'@'localhost' ACCESS READ EXPIRE INTERVAL 90 DAY;
```

```text
claude mcp add --transport http miraj http://127.0.0.1:7008/mcp --header "Authorization: Bearer mjt_…"
```

The `mjt_…` secret is displayed only once.

### Updating and uninstalling

- **Update**: get the new version of the `skill/` folder and run the installation script again (it replaces the old files).
- **Uninstall**: `-Uninstall` / `--uninstall`, or delete the folders in `~/.claude/skills/`.

### Troubleshooting

| Symptom | Likely cause | Remedy |
|---|---|---|
| The skills do not appear in `/skills` | Session not restarted, or wrong folder | Start a new session; check that `SKILL.md` exists in `~/.claude/skills/<skill>/` |
| A skill does not activate on its own | The request does not mention MIRAJ | Name MIRAJ in the request, or invoke `/miraj-dba` |
| `Access denied` on connection | Account, host or password | Check the `'user'@'host'` account and its `GRANT`s |
| Connection refused | Server stopped, listening on loopback only, firewall | Check `--bind`, `--port` and the firewall |
| `miraj-cli` says the folder is already open (code 2) | A server holds the folder | Connect to the server with `--host` instead of `--root` |
| MCP endpoint missing | Express edition, `mcp` set to `OFF`, or invalid license | See the startup messages and `SHOW LICENSE` |
