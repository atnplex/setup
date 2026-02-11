#!/usr/bin/env bash
#
# ATN Server Bootstrap — Modular Entry Point
#
# One-liner: curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh | bash
# With args: curl -fsSL ... | bash -s -- --non-interactive --module docker --module tailscale
#
# This script:
#   1. Clones the setup repo (if not already cloned)
#   2. Sources the core library and registry
#   3. Runs all modules in order (or selected ones via --module flags)
#
# Environment variables (all optional, derived if not set):
#   NAMESPACE    — Root namespace (default: /atn)
#   SYNC_SOURCE      — Hostname or IP of server to sync state from
#   SYNC_BRAIN       — "true"/"false" to sync recent brain data (default: true)
#   GITHUB_PERSONAL_ACCESS_TOKEN — For gh auth + GitHub MCP
#   CLOUDFLARED_TOKEN — For Cloudflare Tunnel service install
#
set -euo pipefail

# Derive namespace
NAMESPACE="${NAMESPACE:-/atn}"
SETUP_REPO_DIR="${NAMESPACE}/github/setup"
LOG_DIR="${NAMESPACE}/logs"
RUN_LOG="${LOG_DIR}/bootstrap-$(date -u +%Y%m%dT%H%M%SZ).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║         ATN Server Bootstrap (Modular)               ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# Ensure base tools exist
ensure_base() {
  local missing=()
  for cmd in curl git python3 rsync; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${BLUE}[ATN]${NC} Installing base dependencies: ${missing[*]}"
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq curl git python3 rsync jq unzip ca-certificates gnupg lsb-release 2>/dev/null
  fi
}

# Clone or update the setup repo
ensure_repo() {
  mkdir -p "$(dirname "$SETUP_REPO_DIR")"
  if [[ -d "$SETUP_REPO_DIR/.git" ]]; then
    echo -e "${GREEN}[✓]${NC} Setup repo exists at $SETUP_REPO_DIR"
    cd "$SETUP_REPO_DIR" && git pull --quiet 2>/dev/null || true
  else
    echo -e "${BLUE}[ATN]${NC} Cloning setup repo..."
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
      gh repo clone atnplex/setup "$SETUP_REPO_DIR" -- --quiet
    else
      git clone https://github.com/atnplex/setup.git "$SETUP_REPO_DIR" 2>/dev/null || {
        echo -e "${RED}[✗]${NC} Failed to clone repo. Ensure gh auth or SSH key is configured."
        exit 1
      }
    fi
  fi
}

main() {
  banner

  # Create namespace root
  sudo mkdir -p "$NAMESPACE" "$LOG_DIR"
  sudo chown -R "$USER:$USER" "$NAMESPACE" 2>/dev/null || true

  ensure_base
  ensure_repo

  cd "$SETUP_REPO_DIR"
  export SETUP_REPO_DIR
  export NAMESPACE

  # Source the modular system
  # shellcheck source=lib/core.sh
  source lib/core.sh
  # shellcheck source=lib/registry.sh
  source lib/registry.sh

  detect_os
  parse_args "$@"
  load_config_if_any

  # Initialize module registry
  registry_init modules

  # Resolve which modules to run
  local run_dir="$LOG_DIR/run-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$run_dir"

  mapfile -t modules_to_run < <(resolve_modules_from_flags_or_config)
  emit_run_manifest "$run_dir/manifest.json" "${modules_to_run[@]}"

  log_info "Running ${#modules_to_run[@]} modules: ${modules_to_run[*]}"

  for mod in "${modules_to_run[@]}"; do
    run_module "$mod" "$run_dir"
  done

  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ATN Bootstrap Complete!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  Namespace: $NAMESPACE"
  echo "  Run log:   $run_dir/"
  echo ""
  echo "  Next steps:"
  echo "    1. Reload shell:  source ~/.bashrc"
  echo "    2. If needed:     gh auth login"
  echo "    3. If needed:     sudo tailscale up"
  echo ""
  if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
    echo "  ✓ Tailscale: $(tailscale ip -4 2>/dev/null || echo 'connected')"
  fi
  echo ""
}

main "$@"
