#!/usr/bin/env bash
#
# Server Bootstrap — Single Command Setup
#
# Usage (fresh Debian VM):
#   export GH_TOKEN=ghp_xxx
#   curl -fsSL -H "Authorization: token $GH_TOKEN" \
#     https://raw.githubusercontent.com/atnplex/setup/main/run.sh | bash
#
# Or with BWS token:
#   export GH_TOKEN=ghp_xxx BWS_ACCESS_TOKEN=bws_xxx
#   curl -fsSL -H "Authorization: token $GH_TOKEN" \
#     https://raw.githubusercontent.com/atnplex/setup/main/run.sh | bash
#
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[SETUP]${NC} $*"; }
ok() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*"; }
die() {
  err "$@"
  exit 1
}

# ─── Validate ────────────────────────────────────────────────────────────
GH_TOKEN="${GH_TOKEN:-${GITHUB_PERSONAL_ACCESS_TOKEN:-}}"
[[ -n "$GH_TOKEN" ]] || die "GH_TOKEN or GITHUB_PERSONAL_ACCESS_TOKEN must be set"
export GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"

# ─── Detect OS ───────────────────────────────────────────────────────────
detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
  else
    die "Cannot detect OS — /etc/os-release not found"
  fi
  log "Detected OS: $OS_ID $OS_VERSION"
}

# ─── Install base packages ──────────────────────────────────────────────
install_base() {
  log "Installing base packages..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    curl git jq rsync unzip python3 \
    ca-certificates gnupg lsb-release \
    2>/dev/null
  ok "Base packages installed"
}

# ─── Clone the setup repo ───────────────────────────────────────────────
clone_repo() {
  local repo_url="https://${GH_TOKEN}@github.com/${GH_ORG}/setup.git"

  if [[ -d "$SETUP_REPO_DIR/.git" ]]; then
    ok "Setup repo already at $SETUP_REPO_DIR"
    cd "$SETUP_REPO_DIR" && git pull --quiet 2>/dev/null || true
  else
    log "Cloning setup repo..."
    mkdir -p "$(dirname "$SETUP_REPO_DIR")"
    git clone --quiet "$repo_url" "$SETUP_REPO_DIR"
    ok "Cloned to $SETUP_REPO_DIR"
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║            Server Bootstrap                          ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
  echo ""

  detect_os
  [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]] || die "Only Debian/Ubuntu supported (got: $OS_ID)"

  install_base

  # Source defaults from local copy or use inline fallbacks
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd || echo "")"
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/defaults.env" ]]; then
    source "$SCRIPT_DIR/defaults.env"
  fi
  # Apply defaults (matches defaults.env but avoids dependency on it for curl|bash)
  NAMESPACE="${NAMESPACE:-/atn}"
  GH_ORG="${GH_ORG:-atnplex}"
  DOCKER_NETWORK="${DOCKER_NETWORK:-atn_bridge}"
  SETUP_REPO_DIR="${SETUP_REPO_DIR:-${NAMESPACE}/github/setup}"
  LOG_DIR="${LOG_DIR:-${NAMESPACE}/logs}"
  export NAMESPACE GH_ORG DOCKER_NETWORK SETUP_REPO_DIR LOG_DIR

  # Create namespace
  sudo mkdir -p "$NAMESPACE" "$LOG_DIR"
  sudo chown -R "$(whoami):$(whoami)" "$NAMESPACE"

  clone_repo

  # Re-source full defaults from cloned repo
  if [[ -f "$SETUP_REPO_DIR/defaults.env" ]]; then
    source "$SETUP_REPO_DIR/defaults.env"
  fi

  cd "$SETUP_REPO_DIR"

  # Source modular system
  source lib/core.sh
  source lib/registry.sh

  detect_os
  parse_args "$@"
  load_config_if_any

  # Initialize and run all modules
  registry_init modules

  local run_dir="$LOG_DIR/run-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$run_dir"

  local modules_to_run
  mapfile -t modules_to_run < <(resolve_modules_from_flags_or_config)
  emit_run_manifest "$run_dir/manifest.json" "${modules_to_run[@]}"

  log "Running ${#modules_to_run[@]} modules: ${modules_to_run[*]}"

  for mod in "${modules_to_run[@]}"; do
    run_module "$mod" "$run_dir"
  done

  # ─── Summary ─────────────────────────────────────────────────────────
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  Bootstrap Complete!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  Namespace:  $NAMESPACE"
  echo "  Run log:    $run_dir/"
  echo "  OS:         $OS_ID $OS_VERSION"
  echo ""
  if command -v tailscale &>/dev/null; then
    if tailscale status &>/dev/null; then
      echo "  ✓ Tailscale: $(tailscale ip -4 2>/dev/null || echo 'connected')"
    else
      echo "  ! Tailscale: installed but not authenticated"
      echo "    → Run: sudo tailscale up"
    fi
  fi
  if command -v docker &>/dev/null; then
    echo "  ✓ Docker: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
  fi
  if command -v gh &>/dev/null; then
    echo "  ✓ GitHub CLI: $(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
  fi
  echo ""
  echo "  Next: source ~/.bashrc && sudo tailscale up"
  echo ""
}

main "$@"
