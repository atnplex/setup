#!/usr/bin/env bash
#
# Server Bootstrap — Modular Entry Point
#
# One-liner (private repo, requires gh auth):
#   curl -fsSL https://raw.githubusercontent.com/${GH_ORG}/setup/main/run.sh | bash
#
# With args:
#   curl -fsSL ... | bash -s -- --non-interactive --module docker --module tailscale
#
# Environment variables (all optional, derived from defaults.env):
#   NAMESPACE        — Root namespace path
#   GH_ORG           — GitHub organization
#   SYNC_SOURCE      — Hostname or IP of server to sync state from
#   SYNC_BRAIN       — "true"/"false" to sync recent brain data (default: true)
#   GITHUB_PERSONAL_ACCESS_TOKEN — For gh auth + GitHub MCP
#   CLOUDFLARED_TOKEN — For Cloudflare Tunnel service install
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load defaults (single source of truth for all default values)
load_defaults() {
  if [[ -f "$SCRIPT_DIR/defaults.env" ]]; then
    # shellcheck source=defaults.env
    source "$SCRIPT_DIR/defaults.env"
  elif [[ -f "${SETUP_REPO_DIR:-}/defaults.env" ]]; then
    source "${SETUP_REPO_DIR}/defaults.env"
  else
    # Minimal fallback when running via curl|bash before repo is cloned
    NAMESPACE="${NAMESPACE:-/atn}"
    GH_ORG="${GH_ORG:-atnplex}"
    DOCKER_NETWORK="${DOCKER_NETWORK:-atn_bridge}"
  fi
  LOG_DIR="${LOG_DIR:-${NAMESPACE}/logs}"
  SETUP_REPO_DIR="${SETUP_REPO_DIR:-${NAMESPACE}/github/setup}"
}

banner() {
  echo ""
  echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║            Server Bootstrap (Modular)                ║${NC}"
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
    echo -e "${BLUE}[SETUP]${NC} Installing base dependencies: ${missing[*]}"
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
    echo -e "${BLUE}[SETUP]${NC} Cloning setup repo..."
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
      gh repo clone "${GH_ORG}/setup" "$SETUP_REPO_DIR" -- --quiet
    else
      git clone "https://github.com/${GH_ORG}/setup.git" "$SETUP_REPO_DIR" 2>/dev/null || {
        echo -e "${RED}[✗]${NC} Failed to clone repo. Ensure gh auth or SSH key is configured."
        exit 1
      }
    fi
  fi
  # Re-source defaults from cloned repo (now has full defaults.env)
  if [[ -f "$SETUP_REPO_DIR/defaults.env" ]]; then
    source "$SETUP_REPO_DIR/defaults.env"
  fi
}

main() {
  load_defaults
  banner

  # Create namespace root
  sudo mkdir -p "$NAMESPACE" "$LOG_DIR"
  sudo chown -R "$USER:$USER" "$NAMESPACE" 2>/dev/null || true

  ensure_base
  ensure_repo

  cd "$SETUP_REPO_DIR"
  export SETUP_REPO_DIR NAMESPACE GH_ORG DOCKER_NETWORK LOG_DIR

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
  echo -e "${GREEN}  Bootstrap Complete!${NC}"
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
