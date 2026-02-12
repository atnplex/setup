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
            ├─ sys/secrets.sh        4-tier secrets (env → keyctl → age → BWS)
            ├─ sys/hostname.sh       hostname management
            ├─ sys/deps.sh           package dependency management
            ├─ sys/service.sh        systemd service management
            ├─ sys/docker_install.sh idempotent Docker CE install
            ├─ sys/tailscale_install.sh idempotent Tailscale install
            └─ fs/layout.sh          namespace dirs + symlinks
```

## Variables

Only user-settable variables are listed. All other values are auto-derived internally.

### User-Settable

| Variable           | Default            | Description                         |
| ------------------ | ------------------ | ----------------------------------- |
| `NAMESPACE`        | `atn`              | Namespace name                      |
| `GH_ORG`           | `${NAMESPACE}plex` | GitHub organization                 |
| `SYSTEM_USER_UID`  | `1234`             | System user UID                     |
| `BWS_ACCESS_TOKEN` | (env/keyctl)       | Bitwarden Secrets Manager token     |
| `DRY_RUN`          | `false`            | Print commands instead of executing |
| `SKIP_SERVICES`    | `false`            | Skip Docker/Tailscale install phase |
| `INTERACTIVE`      | `auto`             | Enable/disable interactive prompts  |

### Config Load Chain

Resolution order (last wins):

1. `defaults.env` (repo defaults)
2. BWS project `variables` (if available)
3. `variables.env` (auto-discovered)
4. `secrets.env` (auto-discovered, sensitive)
5. `global.conf` (highest precedence — user overrides)

Discovery searches `/<namespace>/.ignore/`, `/<namespace>/`, and `/<namespace>/configs/` for each file.

### Auto-Derived (Internal)

These are never user-settable and not documented as config options:

| Derived Variable     | Formula               |
| -------------------- | --------------------- |
| `NAMESPACE_ROOT_DIR` | `/${NAMESPACE}`       |
| `SYSTEM_USERNAME`    | `= GH_ORG`            |
| `SYSTEM_GROUPNAME`   | `= SYSTEM_USERNAME`   |
| `SYSTEM_GROUP_GID`   | `= SYSTEM_USER_UID`   |
| `DOCKER_NETWORK`     | `${NAMESPACE}_bridge` |

## Module Library

The `lib/` directory contains a complete Bash standard library:

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
