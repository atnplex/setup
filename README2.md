# 1.0 Directory layout

```text
setup/
  bootstrap.sh              # Single entrypoint
  lib/
    core.sh                 # OS detection, logging, helpers
    menu.sh                 # Interactive menu logic
    registry.sh             # Module registry + discovery
  modules/
    10-ssh.sh
    20-users-groups.sh
    30-tailscale.sh
    40-cloudflared.sh
  config/
    default.env
    example.env
  state/
    runs/                   # Run manifests + results
    cache/                  # Any cached detection
```

---














---

## 1. Design principles (aligned with your universal wrapper philosophy)

When you look across “good” Linux bootstrap repos, the ones that age well all converge on a few patterns that map cleanly to your style:

- **Single entrypoint, modular internals**
  - One `bootstrap.sh` (or `setup.sh`) that never hard‑codes behavior.
  - All real work lives in **modules** under `modules/`.

- **Explicit module contracts**
  - Each module is a self‑contained unit with:
    - `id`, `description`
    - `supports_os`, `requires_root`
    - `run_interactive`, `run_noninteractive`
  - No module assumes global state beyond a small, documented API.

- **OS detection + capability probing**
  - Detect distro, version, package manager, systemd presence, etc.
  - Modules declare what they support; the core decides if they’re runnable.

- **Config > flags > interactive**
  - Precedence:
    1. **Config file** (YAML/JSON/env) for reproducible runs.
    2. **CLI flags** to override config.
    3. **Interactive wizard** when nothing else is specified.

- **Idempotent, atomic operations**
  - Modules must be safe to re‑run.
  - Each module does one thing well (SSH, users, Tailscale, Cloudflared, etc.).

- **Auditability + artifacts**
  - Every run emits:
    - A **run manifest** (what was requested).
    - A **result manifest** (what actually happened).
    - Logs per module.

That’s exactly your mesh mindset, just applied to bootstrap.

---

## 2. Hybrid bootstrap architecture tailored to your automation mesh

Here’s the architecture I’d recommend for you.

### 2.1 Directory layout

```text
bootstrap/
  bootstrap.sh              # Single entrypoint
  lib/
    core.sh                 # OS detection, logging, helpers
    menu.sh                 # Interactive menu logic
    registry.sh             # Module registry + discovery
  modules/
    10-ssh.sh
    20-users-groups.sh
    30-tailscale.sh
    40-cloudflared.sh
  config/
    default.env
    example.env
  state/
    runs/                   # Run manifests + results
    cache/                  # Any cached detection
```

---

### 2.2 Core flow (bootstrap.sh)

High‑level steps:

1. Load core libs.
2. Detect OS + environment.
3. Parse CLI flags.
4. Load config (if provided).
5. Discover modules and build a **module registry**.
6. Decide mode:
   - Non‑interactive (flags/config specify modules).
   - Interactive menu (user picks modules).
7. Execute selected modules in order.
8. Emit run + result manifests.

---

## 3. Module contract (how each module should behave)

Each `modules/*.sh` implements a simple contract:

```bash
# Required: unique ID
MODULE_ID="ssh"
MODULE_DESC="Configure SSH server and client defaults"
MODULE_ORDER=10   # For deterministic ordering

# Optional: OS support declaration
module_supports_os() {
  # Return 0 if supported, 1 if not
  case "$OS_ID" in
    ubuntu|debian|fedora|centos) return 0 ;;
    *) return 1 ;;
  esac
}

# Optional: does this require root?
module_requires_root() {
  return 0  # 0 = yes, 1 = no
}

# Optional: interactive description
module_interactive_prompt() {
  echo "Configure SSH (hardened server, client config, keys)?"
}

# Required: main entrypoint
module_run() {
  # Use helper functions from core.sh: log_info, ensure_pkg, etc.
  log_info "Configuring SSH..."
  # ... do work ...
}
```

The core `registry.sh`:

- Sources all `modules/*.sh`.
- Builds an in‑memory registry (array or associative array).
- Filters by `module_supports_os` and `module_requires_root`.

---

## 4. Main bootstrap script skeleton

Here’s a concrete `bootstrap.sh` you can evolve:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load core libs
source "$ROOT_DIR/lib/core.sh"
source "$ROOT_DIR/lib/registry.sh"
source "$ROOT_DIR/lib/menu.sh"

main() {
  detect_os
  parse_args "$@"
  load_config_if_any

  registry_init "$ROOT_DIR/modules"

  if [[ "$MODE" == "interactive" ]]; then
    selected_modules=($(menu_select_modules))
  else
    selected_modules=($(resolve_modules_from_flags_or_config))
  fi

  run_id="$(date +%Y%m%d-%H%M%S)"
  run_dir="$ROOT_DIR/state/runs/$run_id"
  mkdir -p "$run_dir"

  emit_run_manifest "$run_dir/run-manifest.json" "${selected_modules[@]}"

  for module_id in "${selected_modules[@]}"; do
    run_module "$module_id" "$run_dir"
  done

  log_info "Bootstrap complete. Run artifacts: $run_dir"
}

main "$@"
```

---

## 5. Core helpers (OS detection, logging, flags)

### 5.1 `lib/core.sh`

```bash
#!/usr/bin/env bash

OS_ID=""
OS_VERSION_ID=""
PKG_MANAGER=""

log_info()  { printf '[INFO] %s\n' "$*" >&2; }
log_warn()  { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION_ID="$VERSION_ID"
  else
    OS_ID="unknown"
    OS_VERSION_ID="unknown"
  fi

  case "$OS_ID" in
    ubuntu|debian) PKG_MANAGER="apt" ;;
    fedora|centos|rhel) PKG_MANAGER="dnf" ;;
    arch) PKG_MANAGER="pacman" ;;
    *) PKG_MANAGER="unknown" ;;
  esac

  log_info "Detected OS: $OS_ID $OS_VERSION_ID (pkg: $PKG_MANAGER)"
}

ensure_pkg() {
  local pkg="$1"
  case "$PKG_MANAGER" in
    apt)   sudo apt-get update -y && sudo apt-get install -y "$pkg" ;;
    dnf)   sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -Sy --noconfirm "$pkg" ;;
    *) log_warn "Unknown package manager; please install $pkg manually." ;;
  esac
}

MODE="interactive"
CONFIG_FILE=""
MODULE_FLAGS=()

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --non-interactive|-y) MODE="noninteractive" ;;
      --config) CONFIG_FILE="$2"; shift ;;
      --module) MODULE_FLAGS+=("$2"); shift ;;
      --help|-h)
        echo "Usage: $0 [--non-interactive] [--config FILE] [--module ID ...]"
        exit 0
        ;;
      *) log_warn "Unknown argument: $1" ;;
    esac
    shift
  done
}

load_config_if_any() {
  if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    log_info "Loading config from $CONFIG_FILE"
    # simplest: source env-style config
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
  fi
}
```

---

## 6. Module registry + execution

### 6.1 `lib/registry.sh`

```bash
#!/usr/bin/env bash

declare -a MODULE_IDS=()
declare -A MODULE_ORDER_MAP=()

registry_init() {
  local modules_dir="$1"
  for f in "$modules_dir"/*.sh; do
    # shellcheck disable=SC1090
    source "$f"
    MODULE_IDS+=("$MODULE_ID")
    MODULE_ORDER_MAP["$MODULE_ID"]="$MODULE_ORDER"
  done

  # sort MODULE_IDS by MODULE_ORDER
  IFS=$'\n' MODULE_IDS=($(for id in "${MODULE_IDS[@]}"; do
    echo "${MODULE_ORDER_MAP[$id]}:$id"
  done | sort -n | cut -d: -f2))
  unset IFS
}

run_module() {
  local module_id="$1"
  local run_dir="$2"

  if ! module_supports_os 2>/dev/null; then
    log_info "Skipping $module_id (unsupported on $OS_ID)"
    return
  fi

  if module_requires_root 2>/dev/null; then
    if [[ $EUID -ne 0 ]]; then
      log_warn "Module $module_id requires root; skipping (not root)."
      return
    fi
  fi

  log_info "Running module: $module_id"
  local log_file="$run_dir/${module_id}.log"
  if module_run >"$log_file" 2>&1; then
    log_info "Module $module_id completed successfully."
  else
    log_error "Module $module_id failed. See $log_file"
  fi
}

resolve_modules_from_flags_or_config() {
  if [[ ${#MODULE_FLAGS[@]} -gt 0 ]]; then
    printf '%s\n' "${MODULE_FLAGS[@]}"
  else
    # default: run all modules
    printf '%s\n' "${MODULE_IDS[@]}"
  fi
}

emit_run_manifest() {
  local path="$1"; shift
  local modules=("$@")
  {
    echo '{'
    echo '  "timestamp": "'"$(date --iso-8601=seconds)"'",'
    echo '  "os_id": "'"$OS_ID"'",'
    echo '  "os_version": "'"$OS_VERSION_ID"'",'
    echo '  "modules": ['
    local first=1
    for m in "${modules[@]}"; do
      if [[ $first -eq 0 ]]; then echo ','; fi
      printf '    "%s"' "$m"
      first=0
    done
    echo
    echo '  ]'
    echo '}'
  } > "$path"
}
```

---

## 7. Interactive menu

### 7.1 `lib/menu.sh`

```bash
#!/usr/bin/env bash

menu_select_modules() {
  echo "Select modules to run (space-separated indices, empty = all):"
  local i=1
  for id in "${MODULE_IDS[@]}"; do
    echo "  [$i] $id"
    i=$((i+1))
  done
  printf 'Selection: '
  read -r selection

  if [[ -z "$selection" ]]; then
    printf '%s\n' "${MODULE_IDS[@]}"
    return
  fi

  local selected_ids=()
  for idx in $selection; do
    local pos=$((idx-1))
    selected_ids+=("${MODULE_IDS[$pos]}")
  done

  printf '%s\n' "${selected_ids[@]}"
}
```

You can later swap this for `fzf`/`gum`/`whiptail` without changing the contract.

---

## 8. Example modules

### 8.1 SSH module (`modules/10-ssh.sh`)

```bash
MODULE_ID="ssh"
MODULE_DESC="Configure SSH server and client defaults"
MODULE_ORDER=10

module_supports_os() { return 0; }
module_requires_root() { return 0; }

module_run() {
  log_info "Ensuring OpenSSH is installed..."
  ensure_pkg openssh-client
  if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    ensure_pkg openssh-server
    sudo systemctl enable ssh || true
    sudo systemctl start ssh || true
  fi

  log_info "Configuring ~/.ssh directory..."
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # You can add hardened sshd_config changes here, or leave as TODO.
}
```

---

### 8.2 Users/groups module (`modules/20-users-groups.sh`)

```bash
MODULE_ID="users-groups"
MODULE_DESC="Create standard users and groups"
MODULE_ORDER=20

module_supports_os() { return 0; }
module_requires_root() { return 0; }

module_run() {
  : "${BOOTSTRAP_USER:=}"  # from config/env if set
  if [[ -z "$BOOTSTRAP_USER" ]]; then
    log_info "No BOOTSTRAP_USER set; skipping user creation."
    return 0
  fi

  if id "$BOOTSTRAP_USER" >/dev/null 2>&1; then
    log_info "User $BOOTSTRAP_USER already exists."
  else
    log_info "Creating user $BOOTSTRAP_USER..."
    sudo useradd -m -s /bin/bash "$BOOTSTRAP_USER"
  fi
}
```

---

### 8.3 Tailscale module (`modules/30-tailscale.sh`)

```bash
MODULE_ID="tailscale"
MODULE_DESC="Install and configure Tailscale"
MODULE_ORDER=30

module_supports_os() {
  case "$OS_ID" in
    ubuntu|debian|fedora|centos|rhel) return 0 ;;
    *) return 1 ;;
  esac
}

module_requires_root() { return 0; }

module_run() {
  log_info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh

  if ! command -v tailscale >/dev/null 2>&1; then
    log_error "Tailscale not found after install."
    return 1
  fi

  if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
    log_warn "TAILSCALE_AUTHKEY not set; skipping automatic login."
    return 0
  fi

  sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --accept-routes --ssh || true
}
```

---

### 8.4 Cloudflared module (`modules/40-cloudflared.sh`)

```bash
MODULE_ID="cloudflared"
MODULE_DESC="Install and configure Cloudflare Tunnel (cloudflared)"
MODULE_ORDER=40

module_supports_os() {
  case "$OS_ID" in
    ubuntu|debian) return 0 ;;
    *) return 1 ;;
  esac
}

module_requires_root() { return 0; }

module_run() {
  log_info "Installing cloudflared..."
  curl -fsSL https://developers.cloudflare.com/cloudflare-one/static/documentation/connections/CloudflareTunnel-linux-amd64.deb -o /tmp/cloudflared.deb || true
  if [[ -f /tmp/cloudflared.deb ]]; then
    sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
  else
    log_warn "Could not download .deb; consider using repo-based install."
  fi

  if [[ -z "${CLOUDFLARED_TOKEN:-}" ]]; then
    log_warn "CLOUDFLARED_TOKEN not set; skipping tunnel creation."
    return 0
  fi

  sudo cloudflared service install "$CLOUDFLARED_TOKEN"
  sudo systemctl enable cloudflared || true
  sudo systemctl start cloudflared || true
}
```

---

## 9. How this fits your SSOT + mesh

- **Run manifests**: every bootstrap run produces machine‑readable artifacts your agents can ingest.
- **Module contracts**: mirror your action packs—atomic, explicit, self‑describing.
- **Config + flags + interactive**: supports wizard mode, non‑interactive CI, and agent‑driven runs.
- **OS detection + module registry**: future‑proof for cross‑platform; you can later add macOS/WSL modules without touching the core.

If you want, next step we can:

- Tighten the module API (e.g., add `module_id`, `module_version`, `module_tags`).
- Define a **formal run‑manifest schema** that matches your existing mesh.
- Add a **dry‑run mode** that only prints what would be done.
- Add **per‑module config files** (e.g., `config/tailscale.env`, `config/ssh.env`).
