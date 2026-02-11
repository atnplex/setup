#!/usr/bin/env bash
#
# Server Bootstrap — Single Command Setup
#
# Usage (interactive — recommended, allows prompts):
#   bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh)
#
# Usage (with pre-set tokens — no prompts needed):
#   export BWS_ACCESS_TOKEN=... GH_TOKEN=ghp_...
#   bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh)
#
# Usage (select specific modules):
#   bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh) --module tailscale --module docker
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
    curl git jq rsync unzip python3 age keyutils \
    ca-certificates gnupg lsb-release \
    2>/dev/null
  ok "Base packages installed"
}

# ─── Install BWS CLI ─────────────────────────────────────────────────────
# Usage: install_bws [version] [--force]
#   version: explicit version (e.g. "1.0.0"), or empty for latest
#   --force: reinstall even if already present
install_bws() {
  local target_version="${1:-}"
  local force="${2:-}"

  if [[ "$force" != "--force" ]] && command -v bws &>/dev/null; then
    ok "BWS CLI already installed ($(bws --version 2>/dev/null || echo 'unknown'))"
    return 0
  fi

  # Detect architecture
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  case "$arch" in
  amd64) arch="x86_64" ;;
  arm64) arch="aarch64" ;;
  esac

  # Resolve version
  if [[ -z "$target_version" ]]; then
    log "Detecting latest BWS CLI version..."
    local api_response
    api_response="$(curl -fsSL "https://api.github.com/repos/bitwarden/sdk-sm/releases?per_page=10" 2>/dev/null || echo '')"
    if [[ -n "$api_response" ]]; then
      target_version="$(echo "$api_response" | jq -r '[.[] | select(.tag_name | startswith("bws-v"))][0].tag_name // ""' 2>/dev/null | sed 's/^bws-v//')"
    fi
    target_version="${target_version:-2.0.0}"
  fi

  log "Installing BWS CLI v${target_version}..."

  local url="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${target_version}/bws-${arch}-unknown-linux-gnu-${target_version}.zip"
  local dl_dir="$SETUP_TMPDIR/bws-${target_version}"
  rm -rf "$dl_dir"
  mkdir -p "$dl_dir"
  log "Downloading from: $url"
  if curl -fsSL "$url" -o "$dl_dir/bws.zip"; then
    unzip -oq "$dl_dir/bws.zip" -d "$dl_dir"
    local bws_bin
    bws_bin="$(find "$dl_dir" -name 'bws' -type f | head -1)"
    if [[ -n "$bws_bin" ]]; then
      sudo install -m 755 "$bws_bin" /usr/local/bin/bws
      ok "BWS CLI v${target_version} installed"
    else
      err "BWS binary not found in downloaded archive"
      return 1
    fi
  else
    err "Failed to download BWS CLI from $url"
    return 1
  fi
}

# ─── BWS: Initialize and cache all secrets ───────────────────────────────
BWS_SECRETS_JSON=""

_bws_init_secrets() {
  # Already initialized?
  if [[ -n "$BWS_SECRETS_JSON" && "$BWS_SECRETS_JSON" != "[]" ]]; then
    return 0
  fi

  # Fetch secrets — with automatic v1/v2 token compatibility fallback
  BWS_SECRETS_JSON="$(bws secret list -o json 2>"$SETUP_TMPDIR/.bws_err" || true)"

  # If we get the "decryption key" error, the token format doesn't match the CLI version
  if [[ -z "$BWS_SECRETS_JSON" ]] && grep -qi "decryption key" "$SETUP_TMPDIR/.bws_err" 2>/dev/null; then
    local current_ver
    current_ver="$(bws --version 2>/dev/null | awk '{print $NF}' || echo 'unknown')"
    if [[ "$current_ver" == 2.* ]]; then
      warn "BWS v2 can't decrypt your token — your token uses v1 format."
      warn "Auto-installing BWS v1.0.0 for compatibility..."
      install_bws "1.0.0" "--force" || true
      BWS_SECRETS_JSON="$(bws secret list -o json 2>"$SETUP_TMPDIR/.bws_err" || true)"
    elif [[ "$current_ver" == 1.* || "$current_ver" == 0.* ]]; then
      warn "BWS v1 can't decrypt your token — your token may use v2 format."
      warn "Auto-installing BWS v2.0.0 for compatibility..."
      install_bws "2.0.0" "--force" || true
      BWS_SECRETS_JSON="$(bws secret list -o json 2>"$SETUP_TMPDIR/.bws_err" || true)"
    fi
  fi

  # Also try project-scoped listing
  local project_secrets=""
  project_secrets="$(bws project list -o json 2>/dev/null || echo '[]')"
  if [[ -n "$project_secrets" && "$project_secrets" != "[]" ]]; then
    local project_ids
    project_ids="$(echo "$project_secrets" | jq -r '.[].id' 2>/dev/null || true)"
    while IFS= read -r pid; do
      [[ -z "$pid" ]] && continue
      local proj_secrets
      proj_secrets="$(bws secret list --project-id "$pid" -o json 2>/dev/null || true)"
      if [[ -n "$proj_secrets" && "$proj_secrets" != "[]" ]]; then
        if [[ -z "$BWS_SECRETS_JSON" || "$BWS_SECRETS_JSON" == "[]" ]]; then
          BWS_SECRETS_JSON="$proj_secrets"
        else
          BWS_SECRETS_JSON="$(echo "$BWS_SECRETS_JSON $proj_secrets" | jq -s 'add | unique_by(.id)' 2>/dev/null || echo "$BWS_SECRETS_JSON")"
        fi
      fi
    done <<<"$project_ids"
  fi

  if [[ -z "$BWS_SECRETS_JSON" || "$BWS_SECRETS_JSON" == "[]" ]]; then
    err "BWS secret list returned no data."
    [[ -s "$SETUP_TMPDIR/.bws_err" ]] && err "BWS error: $(cat "$SETUP_TMPDIR/.bws_err")"
    return 1
  fi

  return 0
}

# ─── BWS: Find a secret by exact name or fuzzy keywords ──────────────────
# Usage: _bws_find_secret "$json" "EXACT_NAME" "keyword1" "keyword2" ...
# Returns: the secret value, or empty string
_bws_find_secret() {
  local json="$1"
  local exact_name="$2"
  shift 2
  local keywords=("$@")

  # Strategy 1: Exact match
  local val
  val="$(echo "$json" | jq -r --arg name "$exact_name" \
    '.[] | select(.key == $name) | .value' 2>/dev/null | head -1)"
  [[ -n "$val" ]] && echo "$val" && return 0

  # Strategy 2: Case-insensitive exact match
  val="$(echo "$json" | jq -r --arg name "$exact_name" \
    '.[] | select(.key | ascii_downcase == ($name | ascii_downcase)) | .value' 2>/dev/null | head -1)"
  [[ -n "$val" ]] && echo "$val" && return 0

  # Strategy 3: Fuzzy keyword match
  if [[ ${#keywords[@]} -gt 0 ]]; then
    local kw_filter=""
    for kw in "${keywords[@]}"; do
      if [[ -n "$kw_filter" ]]; then
        kw_filter="$kw_filter or (\$k | contains(\"$kw\"))"
      else
        kw_filter="(\$k | contains(\"$kw\"))"
      fi
    done

    val="$(echo "$json" | jq -r --argjson dummy 0 "
      [.[] | select((.key | ascii_downcase) as \$k | $kw_filter)]
      | .[0].value // empty
    " 2>/dev/null || true)"
    [[ -n "$val" ]] && echo "$val" && return 0
  fi

  return 1
}

# ─── Detect Environment (OCI/Cloud vs VM vs Bare Metal) ──────────────────
MACHINE_TYPE=""     # "cloud", "vm", or "bare"
MACHINE_HOSTNAME="" # e.g. "vps1", "vm2"

detect_environment() {
  local vendor=""
  if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
  fi

  # Classify environment
  case "${vendor,,}" in
  *oracle* | *oraclecloud*) MACHINE_TYPE="cloud" ;;
  *amazon* | *xen* | *aws*) MACHINE_TYPE="cloud" ;;
  *google*) MACHINE_TYPE="cloud" ;;
  *digitalocean*) MACHINE_TYPE="cloud" ;;
  *hetzner*) MACHINE_TYPE="cloud" ;;
  *linode* | *akamai*) MACHINE_TYPE="cloud" ;;
  *vmware*) MACHINE_TYPE="vm" ;;
  *innotek* | *virtualbox*) MACHINE_TYPE="vm" ;;
  *parallels*) MACHINE_TYPE="vm" ;;
  *qemu* | *kvm* | *bochs*) MACHINE_TYPE="vm" ;;
  *microsoft*)
    # Azure = cloud, Hyper-V = vm
    if grep -qi "azure" /sys/class/dmi/id/product_name 2>/dev/null; then
      MACHINE_TYPE="cloud"
    else
      MACHINE_TYPE="vm"
    fi
    ;;
  *)
    # Check for VM via hypervisor
    if [[ -d /proc/xen ]] || grep -qi "hypervisor" /proc/cpuinfo 2>/dev/null; then
      MACHINE_TYPE="vm"
    else
      MACHINE_TYPE="bare"
    fi
    ;;
  esac

  # Determine hostname prefix
  local prefix
  case "$MACHINE_TYPE" in
  cloud) prefix="vps" ;;
  vm) prefix="vm" ;;
  bare) prefix="srv" ;;
  esac

  # Find next available number
  local num=1
  local current_host
  current_host="$(hostname 2>/dev/null || echo '')"

  # If current hostname already matches our pattern, keep it
  if [[ "$current_host" =~ ^(vps|vm|srv)[0-9]+$ ]]; then
    MACHINE_HOSTNAME="$current_host"
    log "Environment: $MACHINE_TYPE (vendor: ${vendor:-unknown}) — hostname: $MACHINE_HOSTNAME"
    return 0
  fi

  # Check existing Tailscale nodes to avoid conflicts
  local existing_names=""
  if command -v tailscale &>/dev/null && tailscale status &>/dev/null 2>&1; then
    existing_names="$(tailscale status --json 2>/dev/null | jq -r '.Peer[].HostName // empty' 2>/dev/null || true)"
  fi

  while true; do
    local candidate="${prefix}${num}"
    if ! echo "$existing_names" | grep -qx "$candidate"; then
      MACHINE_HOSTNAME="$candidate"
      break
    fi
    ((num++))
  done

  log "Environment: $MACHINE_TYPE (vendor: ${vendor:-unknown}) — assigning hostname: $MACHINE_HOSTNAME"

  # Set the system hostname
  sudo hostnamectl set-hostname "$MACHINE_HOSTNAME" 2>/dev/null ||
    sudo hostname "$MACHINE_HOSTNAME" 2>/dev/null || true

  # Update /etc/hostname
  echo "$MACHINE_HOSTNAME" | sudo tee /etc/hostname >/dev/null 2>&1 || true

  # Ensure /etc/hosts has the new hostname
  if ! grep -q "$MACHINE_HOSTNAME" /etc/hosts 2>/dev/null; then
    echo "127.0.1.1 $MACHINE_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null 2>&1 || true
  fi

  ok "Hostname set to $MACHINE_HOSTNAME"
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

  # 3. Try tiered secret resolution (env → keyctl → age file)
  #    This handles subsequent boots without needing BWS at all
  if type get_secret &>/dev/null; then
    _secrets_init 2>/dev/null || true
    log "Checking local secret stores for GitHub PAT..."
    if get_secret "$BWS_SECRET_NAME_GH_PAT" 2>/dev/null; then
      local cached_pat="${!BWS_SECRET_NAME_GH_PAT:-}"
      if [[ -n "$cached_pat" ]] && ([[ "$cached_pat" =~ ^(ghp_|github_pat_|gho_) ]] || [[ ${#cached_pat} -ge 30 ]]); then
        GH_TOKEN="$cached_pat"
        export GH_TOKEN GITHUB_TOKEN="$GH_TOKEN"
        ok "GitHub PAT resolved from local cache"
        CLONE_METHOD="https"
        return 0
      fi
    fi
  fi

  # 4. Fall through to BWS (remote, last resort)
  log "No local credentials found. Fetching from BWS..."

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

    # Try to read from terminal (handles both piped and interactive modes)
    if [[ -t 0 ]]; then
      # stdin is a terminal — read directly
      read -rsp "  BWS Access Token: " BWS_ACCESS_TOKEN
    elif [[ -r /dev/tty ]]; then
      # stdin is piped but /dev/tty is available
      read -rsp "  BWS Access Token: " BWS_ACCESS_TOKEN </dev/tty
    else
      echo ""
      err "Cannot read input — stdin is piped and /dev/tty is not available."
      err "Run interactively instead:"
      err "  bash <(curl -fsSL https://raw.githubusercontent.com/atnplex/setup/main/run.sh)"
      err "Or pre-set the token:"
      err "  export BWS_ACCESS_TOKEN=... && bash <(curl -fsSL ...)"
      return 1
    fi
    echo ""
    echo ""

    if [[ -z "$BWS_ACCESS_TOKEN" ]]; then
      die "No BWS token provided. Cannot fetch GitHub credentials."
    fi
  fi

  export BWS_ACCESS_TOKEN

  # Initialize secrets system (age key, keyctl) if not already done
  if type _secrets_init &>/dev/null; then
    _secrets_init 2>/dev/null || true
  fi

  # Initialize BWS secrets cache
  log "Fetching secrets from BWS..."
  if ! _bws_init_secrets; then
    die "Check your BWS access token."
  fi

  # Try get_secret (now with BWS available as tier 4)
  log "Looking for GitHub PAT..."
  local pat=""

  if type get_secret &>/dev/null && get_secret "$BWS_SECRET_NAME_GH_PAT" "github" "gh_pat" "personal_access" "pat" 2>/dev/null; then
    pat="${!BWS_SECRET_NAME_GH_PAT:-}"
  fi

  # Validate: does it look like a GitHub PAT?
  if [[ -n "$pat" ]] && ! [[ "$pat" =~ ^(ghp_|github_pat_|gho_) ]] && [[ ${#pat} -lt 30 ]]; then
    warn "Found a secret but it doesn't look like a GitHub PAT. Scanning all secrets..."
    pat=""
  fi

  # Fallback: scan ALL BWS secrets for GitHub PAT format
  if [[ -z "$pat" ]] && [[ -n "$BWS_SECRETS_JSON" ]]; then
    local all_vals
    all_vals="$(echo "$BWS_SECRETS_JSON" | jq -r '.[] | "\(.key)\t\(.value)"' 2>/dev/null || true)"
    while IFS=$'\t' read -r secret_key secret_val; do
      [[ -z "$secret_key" ]] && continue
      if [[ "$secret_val" =~ ^(ghp_|github_pat_|gho_) ]]; then
        log "Found GitHub PAT format in secret '$secret_key'"
        pat="$secret_val"
        if type _keyctl_set &>/dev/null; then
          _keyctl_set "$BWS_SECRET_NAME_GH_PAT" "$pat"
          _SECRETS_KNOWN["$BWS_SECRET_NAME_GH_PAT"]="$pat"
        fi
        break
      fi
    done <<<"$all_vals"
  fi

  if [[ -z "$pat" ]]; then
    err "Could not find a GitHub PAT in any BWS secret."
    warn "Available secrets ($(echo "$BWS_SECRETS_JSON" | jq 'length' 2>/dev/null || echo '?') total):"
    echo "$BWS_SECRETS_JSON" | jq -r '.[].key' 2>/dev/null | while read -r k; do
      warn "  • $k"
    done
    echo ""
    err "Either set the exact name: export BWS_SECRET_NAME_GH_PAT=YourSecretName"
    err "Or pre-set the token: export GH_TOKEN=ghp_yourtoken"
    die "Then re-run the script."
  fi

  GH_TOKEN="$pat"
  export GH_TOKEN GITHUB_TOKEN="$GH_TOKEN"
  ok "GitHub PAT retrieved from BWS"

  # Persist ALL fetched secrets to age file + keyctl for next boot
  if type secrets_persist &>/dev/null; then
    secrets_persist
  fi
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

# ─── Interactive post-bootstrap menu ─────────────────────────────────────
_post_bootstrap_menu() {
  local actions=()
  local action_labels=()
  local action_funcs=()

  # ── Detect pending actions ──────────────────────────────────────────
  _refresh_actions() {
    actions=()
    action_labels=()
    action_funcs=()

    # Tailscale not authenticated?
    if command -v tailscale &>/dev/null && ! tailscale status &>/dev/null 2>&1; then
      actions+=("tailscale")
      action_labels+=("Authenticate Tailscale (connects this machine to your network)")
      action_funcs+=("_action_tailscale")
    fi

    # GitHub CLI not authenticated?
    if command -v gh &>/dev/null && ! gh auth status &>/dev/null 2>&1; then
      actions+=("gh_auth")
      action_labels+=("Authenticate GitHub CLI")
      action_funcs+=("_action_gh_auth")
    fi
  }

  # ── Action handlers ─────────────────────────────────────────────────
  _action_tailscale() {
    echo ""

    # Try to get auth key via tiered resolution (env → keyctl → age → BWS)
    if type get_secret &>/dev/null; then
      local ts_key=""
      if get_secret "TAILSCALE_AUTH_KEY" "tailscale" "authkey" "auth_key" "ts_auth" 2>/dev/null; then
        ts_key="${TAILSCALE_AUTH_KEY:-}"
      fi
      if [[ -n "$ts_key" && "$ts_key" == tskey-auth-* ]]; then
        log "Found Tailscale auth key — authenticating automatically..."
        if sudo tailscale up --authkey="$ts_key" --accept-routes --ssh --hostname="${MACHINE_HOSTNAME:-}" 2>&1; then
          ok "Tailscale authenticated automatically! IP: $(tailscale ip -4 2>/dev/null)"
          echo ""
          return
        fi
        warn "Auto-auth failed, trying API key..."
      fi

      # Try generating an auth key via Tailscale API
      local ts_api_key=""
      if get_secret "TAILSCALE_API_KEY" "tailscale_api" "ts_api" 2>/dev/null; then
        ts_api_key="${TAILSCALE_API_KEY:-}"
      fi
      if [[ -n "$ts_api_key" ]]; then
        log "Found Tailscale API key — generating auth key..."
        local gen_key
        gen_key="$(curl -fsSL -X POST "https://api.tailscale.com/api/v2/tailnet/-/keys" \
          -u "$ts_api_key:" \
          -H 'Content-Type: application/json' \
          -d '{"capabilities":{"devices":{"create":{"reusable":false,"ephemeral":false,"preauthorized":true,"tags":["tag:server"]}}},"expirySeconds":300}' \
          2>/dev/null | jq -r '.key // empty' 2>/dev/null || true)"
        if [[ -n "$gen_key" ]]; then
          log "Generated one-time pre-authorized auth key"
          if sudo tailscale up --authkey="$gen_key" --accept-routes --ssh --hostname="${MACHINE_HOSTNAME:-}" 2>&1; then
            ok "Tailscale authenticated via generated key! IP: $(tailscale ip -4 2>/dev/null)"
            echo ""
            return
          fi
          warn "Generated key auth failed, falling back to interactive..."
        else
          warn "Could not generate auth key via API — check your TAILSCALE_API_KEY."
        fi
      fi
    fi

    # Fallback: interactive
    log "Starting Tailscale authentication (interactive)..."
    echo -e "  ${BOLD}Follow the URL below to authenticate.${NC}"
    echo ""
    if sudo tailscale up --accept-routes --ssh --hostname="${MACHINE_HOSTNAME:-}" 2>&1; then
      ok "Tailscale authenticated! IP: $(tailscale ip -4 2>/dev/null)"
    else
      warn "Tailscale authentication was cancelled or failed."
      warn "You can always run 'sudo tailscale up' later."
    fi
    echo ""
  }

  _action_gh_auth() {
    echo ""
    log "Authenticating GitHub CLI..."
    if [[ -n "${GH_TOKEN:-}" ]]; then
      echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null
      if gh auth status &>/dev/null 2>&1; then
        ok "GitHub CLI authenticated via token"
      else
        warn "Token auth failed. You can run 'gh auth login' manually."
      fi
    else
      warn "No GH_TOKEN available. Run 'gh auth login' manually."
    fi
    echo ""
  }

  # bashrc is now reloaded automatically — no menu item needed

  # ── Menu loop ───────────────────────────────────────────────────────
  while true; do
    _refresh_actions

    if [[ ${#actions[@]} -eq 0 ]]; then
      echo -e "  ${GREEN}All setup actions complete! You're all set.${NC}"
      echo ""
      break
    fi

    echo -e "${BOLD}  Remaining setup actions:${NC}"
    echo ""
    local i=1
    for label in "${action_labels[@]}"; do
      echo -e "    ${BOLD}${i})${NC} ${label}"
      ((i++))
    done
    echo ""
    echo -e "    ${BOLD}a)${NC} Run all remaining actions"
    echo -e "    ${BOLD}s)${NC} Skip — finish setup without running these"
    echo ""

    local choice
    read -rp "  Choose an option: " choice </dev/tty 2>/dev/null || choice="s"

    case "$choice" in
    [Ss] | skip | "")
      echo ""
      echo -e "  ${YELLOW}Skipped remaining actions.${NC} You can run them later:"
      for idx in "${!actions[@]}"; do
        case "${actions[$idx]}" in
        tailscale) echo "    • sudo tailscale up --accept-routes --ssh" ;;
        gh_auth) echo "    • gh auth login" ;;
        esac
      done
      echo ""
      break
      ;;
    [Aa] | all)
      for idx in "${!action_funcs[@]}"; do
        "${action_funcs[$idx]}"
      done
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#action_funcs[@]})); then
        "${action_funcs[$((choice - 1))]}"
      else
        warn "Invalid option. Try again."
      fi
      ;;
    esac
  done
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

  # Source secrets library (needed before repo clone for resolve_github_access)
  if [[ -f "$SETUP_REPO_DIR/lib/secrets.sh" ]]; then
    # shellcheck source=lib/secrets.sh
    source "$SETUP_REPO_DIR/lib/secrets.sh"
  else
    log "Loading secrets library..."
    local secrets_lib
    secrets_lib="$(curl -fsSL "https://raw.githubusercontent.com/${GH_ORG}/setup/main/lib/secrets.sh" 2>/dev/null || true)"
    if [[ -n "$secrets_lib" ]]; then
      eval "$secrets_lib"
    else
      warn "Could not load secrets library. Tiered resolution unavailable."
    fi
  fi

  # Detect environment type (OCI/cloud/VM/bare) and set hostname
  detect_environment

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
  echo "  Hostname:   ${MACHINE_HOSTNAME:-$(hostname)}"
  echo "  Type:       ${MACHINE_TYPE:-unknown}"
  echo "  Run log:    $run_dir/"
  echo "  OS:         $OS_ID $OS_VERSION"
  echo ""

  # Show installed services
  command -v tailscale &>/dev/null && {
    if tailscale status &>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Tailscale: $(tailscale ip -4 2>/dev/null || echo 'connected')"
    else
      echo -e "  ${YELLOW}!${NC} Tailscale: installed but not authenticated"
    fi
  }
  command -v docker &>/dev/null && echo -e "  ${GREEN}✓${NC} Docker: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
  command -v gh &>/dev/null && echo -e "  ${GREEN}✓${NC} GitHub CLI: $(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
  command -v syncthing &>/dev/null && echo -e "  ${GREEN}✓${NC} Syncthing: $(syncthing --version 2>/dev/null | awk '{print $2}')"
  echo ""

  # ─── Interactive post-bootstrap menu ─────────────────────────────────
  _post_bootstrap_menu

  # ─── Auto-reload shell environment ──────────────────────────────────
  log "Reloading shell environment..."
  # shellcheck disable=SC1090
  source ~/.bashrc 2>/dev/null || true
  export NAMESPACE_SOURCED=1
  ok "Shell environment reloaded"
  echo ""

  # Cleanup is handled by the EXIT trap (see cleanup() above)
}

main "$@"
