# setup

Modular server bootstrap — thin entrypoint, stdlib-based orchestrator, zero hard-coded values.

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/modular/bootstrap.sh)
```

Or with pre-set variables (no interactive prompts):

```bash
export BWS_ACCESS_TOKEN=... NAMESPACE=atn
bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/modular/bootstrap.sh) --dry-run
```

## Architecture

```text
bootstrap.sh              → 66-line thin entrypoint
  └─ lib/stdlib.sh        → module loader (lazy import, once-only)
       └─ lib/core/run.sh → 8-phase orchestrator
            ├─ core/sanitize.sh      no-eval config loader + validator
            ├─ core/config.sh        variables discovery & load chain
            ├─ sys/os.sh             OS/arch/RAM detection
            ├─ sys/user.sh           user/group/UID/GID enforcement
            ├─ sys/tmpfs.sh          tmpfs detection + TMP_DIR contract
            ├─ sys/fstab.sh          fstab entry management
            ├─ sys/secrets.sh        4-tier secrets (env → keyctl → age → BWS → peers)
            ├─ sys/hostname.sh       hostname management
            ├─ sys/deps.sh           package dependency management
            ├─ sys/service.sh        systemd service management
            ├─ sys/docker_install.sh idempotent Docker CE install
            ├─ sys/tailscale_install.sh idempotent Tailscale install
            └─ fs/layout.sh          namespace dirs + symlinks
```

## Variables

Only user-settable variables are listed. All other values are auto-derived internally.

| Variable           | Default            | Description                         |
| ------------------ | ------------------ | ----------------------------------- |
| `NAMESPACE`        | `atn`              | Namespace name                      |
| `GH_ORG`           | `${NAMESPACE}plex` | GitHub organization                 |
| `SYSTEM_USER_UID`  | `1234`             | System user UID                     |
| `BWS_ACCESS_TOKEN` | (env/keyctl)       | Bitwarden Secrets Manager token     |
| `DRY_RUN`          | `false`            | Print commands instead of executing |
| `SKIP_SERVICES`    | `false`            | Skip Docker/Tailscale install phase |
| `INTERACTIVE`      | `auto`             | Enable/disable interactive prompts  |

## Config Load Chain

Resolution order (last wins):

1. `defaults.env` — repo defaults
2. BWS project `variables` — if available
3. `variables.env` — auto-discovered
4. `secrets.env` — auto-discovered, sensitive
5. `global.conf` — **highest precedence** (user overrides)

### Discovery Rules

Config files (`variables.env`, `secrets.env`, `secrets.age`) are found automatically:

1. **Priority-ordered paths** (checked first, in order):
   - `/<namespace>/.ignore/<filename>` → highest priority
   - `/<namespace>/configs/<filename>`
   - `/<namespace>/<filename>`

2. **4-level `find` fallback** — searches `/` to a max depth of 4, excluding standard system directories:
   `/bin`, `/boot`, `/dev`, `/etc`, `/lib`, `/lib64`, `/media`, `/mnt`, `/opt`, `/proc`, `/root`, `/run`, `/sbin`, `/sys`, `/tmp`, `/usr`, `/var`

This ensures user/application directories (`/atn`, `/home/*`, `/srv`) are searched without polluting results with OS internals.

### Global Config (SSOT)

`global.conf` is stored at `/<namespace>/configs/global.conf` and loaded last (highest precedence).

If the file does not exist, the bootstrap will:

1. **Download** the canonical template from `https://github.com/atnplex/setup/configs/global.conf`
2. **Force-comment** all settings (safety guarantee)
3. **Fall back** to generating a local template if download fails

All settings in `global.conf` are commented out by default. Uncomment any line to override the corresponding default.

## Secret Acquisition

Secrets are acquired through a tiered fallback chain:

| Priority | Source           | Description                                |
| -------- | ---------------- | ------------------------------------------ |
| 1        | Environment vars | Pre-set via `export`                       |
| 2        | Kernel keyctl    | In-memory keyring                          |
| 3        | `secrets.age`    | Encrypted file (age)                       |
| 4        | BWS (Bitwarden)  | Fetched via `bws` CLI                      |
| 5        | Tailscale peers  | SSH to reachable Linux peers (last resort) |

The **Tailscale peer fallback** (priority 5) only runs when all other methods fail. It enumerates reachable Linux peers, attempts to read their `secrets.env` via SSH (with strict timeouts), validates every line, and stops after the first successful peer. It is safe, optional, and never blocks bootstrap.

## Module Library

| Category | Modules                                                                                                                       | Purpose               |
| -------- | ----------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `core/`  | assert, config, import, log, meta, run, sanitize, strict, vars                                                                | Foundation primitives |
| `data/`  | args, array, config, datetime, hash, json, semver, string                                                                     | Data manipulation     |
| `fs/`    | dir, file, find, layout, path                                                                                                 | Filesystem operations |
| `sys/`   | deps, docker, docker_install, download, fstab, hostname, net, os, pkg, proc, secrets, service, tailscale_install, tmpfs, user | System management     |
| `term/`  | ansi, menu, progress, prompt                                                                                                  | Terminal UI           |
| `test/`  | mock, perf, tap                                                                                                               | Testing framework     |

## License

Private repository — all rights reserved.
