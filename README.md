# setup

Modular server bootstrap — thin entrypoint, stdlib-based orchestrator, zero hard-coded values.

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/modular/bootstrap.sh)
```

Or with pre-set tokens (no interactive prompts):

```bash
export BWS_ACCESS_TOKEN=... BOOTSTRAP_USER=myuser BOOTSTRAP_UID=1114
bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/modular/bootstrap.sh) --dry-run
```

## Architecture

```
bootstrap.sh              → 66-line thin entrypoint
  └─ lib/stdlib.sh        → module loader (lazy import, once-only)
       └─ lib/core/run.sh → 8-phase orchestrator
            ├─ core/config.sh        variables discovery & loading
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

All values are sourced from `defaults.env`, environment, or CLI flags. Nothing is hard-coded.

### Core Identity

| Variable          | Default           | Description                   |
| ----------------- | ----------------- | ----------------------------- |
| `NAMESPACE`       | `/atn`            | Root namespace path           |
| `NAMESPACE_ROOT`  | `$NAMESPACE`      | Alias used by stdlib modules  |
| `BOOTSTRAP_USER`  | (required)        | System user to create/enforce |
| `BOOTSTRAP_GROUP` | `$BOOTSTRAP_USER` | System group                  |
| `BOOTSTRAP_UID`   | (required)        | Desired UID                   |
| `BOOTSTRAP_GID`   | `$BOOTSTRAP_UID`  | Desired GID                   |

### Infrastructure

| Variable         | Default                                | Description                |
| ---------------- | -------------------------------------- | -------------------------- |
| `GH_ORG`         | `atnplex`                              | GitHub organization        |
| `DOCKER_NETWORK` | `atn_bridge`                           | Docker bridge network name |
| `SETUP_REPO`     | `https://github.com/atnplex/setup.git` | Bootstrap repo URL         |
| `SETUP_BRANCH`   | `modular`                              | Branch to clone            |
| `SETUP_REPO_DIR` | `$NAMESPACE/github/setup`              | Local repo clone path      |

### Config & Secrets

| Variable             | Default             | Description                     |
| -------------------- | ------------------- | ------------------------------- |
| `VARIABLES_FILE`     | auto-discovered     | Path to `variables.env` file    |
| `VARIABLES_FILE_CLI` | (none)              | Override via `--vars-file` flag |
| `SECRETS_FILE`       | auto-discovered     | Path to encrypted `.age` file   |
| `BWS_ACCESS_TOKEN`   | (env/keyctl)        | Bitwarden Secrets Manager token |
| `GH_TOKEN`           | (env/keyctl)        | GitHub personal access token    |
| `TMP_DIR`            | auto-detected tmpfs | Trap-cleaned volatile workspace |

### Runtime Flags

| Variable        | Default | Description                         |
| --------------- | ------- | ----------------------------------- |
| `DRY_RUN`       | `false` | Print commands instead of executing |
| `SKIP_SERVICES` | `false` | Skip Docker/Tailscale install phase |
| `INTERACTIVE`   | auto    | Enable/disable interactive prompts  |

## Module Library

The `lib/` directory contains a complete Bash standard library:

| Category | Modules                                                                                                                       | Purpose               |
| -------- | ----------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `core/`  | assert, config, import, log, meta, run, strict, vars                                                                          | Foundation primitives |
| `data/`  | args, array, config, datetime, hash, json, semver, string                                                                     | Data manipulation     |
| `fs/`    | dir, file, find, layout, path                                                                                                 | Filesystem operations |
| `sys/`   | deps, docker, docker_install, download, fstab, hostname, net, os, pkg, proc, secrets, service, tailscale_install, tmpfs, user | System management     |
| `term/`  | ansi, menu, progress, prompt                                                                                                  | Terminal UI           |
| `test/`  | mock, perf, tap                                                                                                               | Testing framework     |

## License

Private repository — all rights reserved.
