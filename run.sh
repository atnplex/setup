#!/usr/bin/env bash
#
# Server Bootstrap — Single Command Setup
#
# Usage (fresh Debian VM — public repo):
#   curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh | bash
#
# Usage (with pre-set tokens):
#   export BWS_ACCESS_TOKEN=... GH_TOKEN=ghp_...
#   curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh | bash
#
# Usage (select specific modules):
#   curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh | bash -s -- --module tailscale --module docker
#
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[SETUP]${NC} $*"; }
ok() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*"; }
die() {
  err "$@"
  exit 1
}

# ─── Defaults (inline — no file dependency for curl|bash) ───────────────
NAMESPACE="${NAMESPACE:-/atn}"
GH_ORG="${GH_ORG:-atnplex}"
DOCKER_NETWORK="${DOCKER_NETWORK:-atn_bridge}"
SETUP_REPO_DIR="${SETUP_REPO_DIR:-${NAMESPACE}/github/setup}"
LOG_DIR="${LOG_DIR:-${NAMESPACE}/logs}"
BWS_SECRET_NAME_GH_PAT="${BWS_SECRET_NAME_GH_PAT:-GITHUB_PERSONAL_ACCESS_TOKEN}"

export NAMESPACE GH_ORG DOCKER_NETWORK SETUP_REPO_DIR LOG_DIR

# ─── Temp workspace (tmpfs-backed, auto-cleaned) ────────────────────────
SETUP_TMPDIR=""
cleanup() {
  if [[ -n "$SETUP_TMPDIR" && -d "$SETUP_TMPDIR" ]]; then
    rm -rf "$SETUP_TMPDIR"
  fi
  # Clear sensitive variables
  unset BWS_ACCESS_TOKEN GH_TOKEN GITHUB_TOKEN 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Prefer tmpfs (/dev/shm) for in-memory temp files, fall back to /tmp
if [[ -d /dev/shm && -w /dev/shm ]]; then
  SETUP_TMPDIR="$(mktemp -d /dev/shm/atn-setup.XXXXXX)"
else
  SETUP_TMPDIR="$(mktemp -d /tmp/atn-setup.XXXXXX)"
fi

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

# ─── Install BWS CLI if needed ──────────────────────────────────────────
install_bws() {
  if command -v bws &>/dev/null; then
    ok "BWS CLI already installed ($(bws --version 2>/dev/null || echo 'unknown'))"
    return 0
  fi

  log "Installing Bitwarden Secrets CLI..."

  # Detect architecture
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  case "$arch" in
  amd64) arch="x86_64" ;;
  arm64) arch="aarch64" ;;
  esac

  # Dynamically fetch latest BWS version from GitHub API
  local bws_version=""
  local api_response
  api_response="$(curl -fsSL "https://api.github.com/repos/bitwarden/sdk/releases?per_page=10" 2>/dev/null || echo '')"
  if [[ -n "$api_response" ]]; then
    bws_version="$(echo "$api_response" | jq -r '[.[] | select(.tag_name | startswith("bws-v"))][0].tag_name // ""' 2>/dev/null | sed 's/^bws-v//')"
  fi
  # Fallback to known-good version
  bws_version="${bws_version:-2.0.0}"
  log "BWS CLI version: $bws_version"

  # Download from bitwarden/sdk-sm (where release binaries are hosted)
  local url="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${bws_version}/bws-${arch}-unknown-linux-gnu-${bws_version}.zip"
  local dl_dir="$SETUP_TMPDIR/bws"
  mkdir -p "$dl_dir"
  log "Downloading from: $url"
  if curl -fsSL "$url" -o "$dl_dir/bws.zip"; then
    unzip -q "$dl_dir/bws.zip" -d "$dl_dir"
    # Find the bws binary (might be in a subdirectory)
    local bws_bin
    bws_bin="$(find "$dl_dir" -name 'bws' -type f | head -1)"
    if [[ -n "$bws_bin" ]]; then
      sudo install -m 755 "$bws_bin" /usr/local/bin/bws
      ok "BWS CLI $bws_version installed"
    else
      err "BWS binary not found in downloaded archive"
      return 1
    fi
  else
    err "Failed to download BWS CLI from $url"
    return 1
  fi
}

# ─── Check GitHub SSH access ────────────────────────────────────────────
check_github_ssh() {
  log "Checking GitHub SSH access..."
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -qi "successfully authenticated"; then
    ok "GitHub SSH access working"
    return 0
  fi
  return 1
}

# ─── Check GitHub HTTPS access (via gh CLI or token) ────────────────────
check_github_https() {
  if [[ -n "${GH_TOKEN:-}" ]]; then
    ok "GH_TOKEN already set"
    export GITHUB_TOKEN="$GH_TOKEN"
    return 0
  fi
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    ok "GitHub CLI already authenticated"
    GH_TOKEN="$(gh auth token 2>/dev/null || echo '')"
    export GH_TOKEN GITHUB_TOKEN="${GH_TOKEN}"
    return 0
  fi
  return 1
}

# ─── Resolve GitHub access (SSH → HTTPS → BWS → prompt) ────────────────
resolve_github_access() {
  # 1. Try SSH
  if check_github_ssh; then
    CLONE_METHOD="ssh"
    return 0
  fi

  # 2. Try existing HTTPS token
  if check_github_https; then
    CLONE_METHOD="https"
    return 0
  fi

  # 3. Try BWS to fetch GitHub PAT
  log "No GitHub access found. Attempting to fetch credentials via BWS..."

  # Ensure BWS is installed
  install_bws || true

  if ! command -v bws &>/dev/null; then
    die "BWS CLI not available and no GitHub access configured. Cannot proceed."
  fi

  # Prompt for BWS access token if not set
  if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  GitHub access required — enter BWS access token below  ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  The BWS (Bitwarden Secrets) token will be used to fetch"
    echo -e "  your GitHub PAT. It is ${BOLD}not saved to disk${NC} — only held in"
    echo -e "  memory for the duration of this script."
    echo ""
    read -rsp "  BWS Access Token: " BWS_ACCESS_TOKEN
    echo ""
    echo ""

    if [[ -z "$BWS_ACCESS_TOKEN" ]]; then
      die "No BWS token provided. Cannot fetch GitHub credentials."
    fi
  fi

  export BWS_ACCESS_TOKEN

  # Fetch GitHub PAT from BWS
  log "Fetching GitHub PAT from BWS (secret: $BWS_SECRET_NAME_GH_PAT)..."
  local pat
  pat="$(bws secret list -t "$BWS_ACCESS_TOKEN" -o json 2>/dev/null |
    jq -r --arg name "$BWS_SECRET_NAME_GH_PAT" '.[] | select(.key == $name) | .value' 2>/dev/null || echo '')"

  if [[ -z "$pat" ]]; then
    die "Could not retrieve '$BWS_SECRET_NAME_GH_PAT' from BWS. Check your token and secret name."
  fi

  GH_TOKEN="$pat"
  export GH_TOKEN GITHUB_TOKEN="$GH_TOKEN"
  ok "GitHub PAT retrieved from BWS"
  CLONE_METHOD="https"
}

# ─── Clone the setup repo ───────────────────────────────────────────────
clone_repo() {
  local repo_url

  if [[ "${CLONE_METHOD:-https}" == "ssh" ]]; then
    repo_url="git@github.com:${GH_ORG}/setup.git"
  else
    repo_url="https://${GH_TOKEN}@github.com/${GH_ORG}/setup.git"
  fi

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

  # Create namespace
  sudo mkdir -p "$NAMESPACE" "$LOG_DIR"
  sudo chown -R "$(whoami):$(whoami)" "$NAMESPACE"

  # Resolve GitHub access (SSH → existing token → BWS prompt)
  resolve_github_access

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
  echo "  Next steps:"
  echo "    1. source ~/.bashrc"
  echo "    2. sudo tailscale up  (if not yet authenticated)"
  echo "    3. Open VS Code → Remote SSH → $(hostname)"
  echo ""

  # Cleanup is handled by the EXIT trap (see cleanup() above)
}

main "$@"
