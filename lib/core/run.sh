#!/usr/bin/env bash
# Module: core/run
# Version: 0.1.0
# Provides: Bootstrap orchestrator — the single entry point for system setup
# Requires: core/config, core/sanitize, sys/os, sys/user, sys/tmpfs, sys/fstab,
#           sys/secrets, sys/deps, sys/docker_install, sys/tailscale_install,
#           sys/service, sys/hostname, sys/locking, fs/layout
[[ -n "${_STDLIB_RUN:-}" ]] && return 0
declare -g _STDLIB_RUN=1

# ── Colours (guarded) ────────────────────────────────────────────────
declare -g _C_RESET='\033[0m' _C_BLUE='\033[1;34m' _C_GREEN='\033[1;32m'
declare -g _C_YELLOW='\033[1;33m' _C_RED='\033[1;31m' _C_CYAN='\033[0;36m'
if [[ ! -t 1 ]]; then
  _C_RESET='' _C_BLUE='' _C_GREEN='' _C_YELLOW='' _C_RED='' _C_CYAN=''
fi

# ── Logging helpers ──────────────────────────────────────────────────
_run_log() { echo -e "${_C_CYAN}[$(date -u +%H:%M:%S)]${_C_RESET} $*"; }
_run_ok() { echo -e "${_C_GREEN}  ✓${_C_RESET} $*"; }
_run_warn() { echo -e "${_C_YELLOW}  ⚠${_C_RESET} $*" >&2; }
_run_err() { echo -e "${_C_RED}  ✗${_C_RESET} $*" >&2; }

# ── stdlib::run::bootstrap_main ───────────────────────────────────────
# Top-level orchestrator. Called by thin bootstrap.sh.
# Usage: stdlib::run::bootstrap_main [--dry-run] [--skip-services] ...
stdlib::run::bootstrap_main() {
  local dry_run="${DRY_RUN:-false}"
  local skip_services="${SKIP_SERVICES:-false}"
  local variables_file="${VARIABLES_ENV_FILE_CLI:-}"
  local interactive="${INTERACTIVE:-true}"

  # Parse flags passed through from entrypoint
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    --skip-services)
      skip_services=true
      shift
      ;;
    --variables-file)
      variables_file="$2"
      shift 2
      ;;
    --non-interactive)
      interactive=false
      shift
      ;;
    *) shift ;;
    esac
  done

  export DRY_RUN="$dry_run"

  echo ""
  echo -e "${_C_BLUE}╔═══════════════════════════════════════════════════════════════╗${_C_RESET}"
  echo -e "${_C_BLUE}║          Modular Bootstrap — stdlib v0.1.0                   ║${_C_RESET}"
  echo -e "${_C_BLUE}╚═══════════════════════════════════════════════════════════════╝${_C_RESET}"
  echo ""

  [[ "$dry_run" == "true" ]] && _run_warn "DRY-RUN mode — no destructive changes"

  # Import required stdlib modules
  stdlib::import sys/locking
  stdlib::import core/sanitize
  stdlib::import core/config
  stdlib::import sys/os
  stdlib::import sys/user
  stdlib::import sys/tmpfs
  stdlib::import sys/fstab
  stdlib::import sys/secrets
  stdlib::import sys/hostname
  stdlib::import sys/deps
  stdlib::import sys/service
  stdlib::import sys/docker_install
  stdlib::import sys/tailscale_install
  stdlib::import fs/layout

  # ── Acquire bootstrap lock (prevents concurrent runs) ──
  local _lockfile="/tmp/.stdlib-bootstrap.lock"
  if ! stdlib::lock::acquire "$_lockfile" 5; then
    _run_err "Another bootstrap is running (lock: $_lockfile, owner: $(stdlib::lock::owner "$_lockfile"))"
    return 1
  fi
  _run_ok "Lock acquired: $_lockfile (PID $$)"

  # ── Phase 0: Tmpfs workspace ──
  _run_log "Phase 0: Creating tmpfs workspace..."
  stdlib::tmpfs::create_workspace "${NAMESPACE_ROOT_DIR:-}" "bootstrap"
  _run_ok "TMP_DIR=${TMP_DIR}"

  # ── Phase 1: Resolve variables ──
  _run_log "Phase 1: Resolving variables..."

  # Resolve core variables first (NAMESPACE, SYSTEM_*, paths)
  stdlib::config::resolve_vars "$variables_file" "$interactive"
  _run_ok "NAMESPACE=${NAMESPACE}, USER=${SYSTEM_USERNAME}, UID=${SYSTEM_USER_UID}"

  # Load full config chain: defaults → BWS → variables.env → secrets.env → global.conf
  local repo_dir
  repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  stdlib::config::load_chain "$repo_dir"
  _run_ok "Config chain loaded"

  # ── Phase 2: Probe environment ──
  _run_log "Phase 2: Probing environment..."
  stdlib::run::probe_environment

  # ── Phase 3: Ensure identity ──
  _run_log "Phase 3: Ensuring identity..."
  stdlib::run::ensure_identity

  # ── Phase 4: Ensure layout ──
  _run_log "Phase 4: Ensuring namespace layout..."
  stdlib::run::ensure_layout

  # ── Phase 5: Ensure tmpfs mounts ──
  _run_log "Phase 5: Ensuring tmpfs mounts..."
  stdlib::run::ensure_tmpfs

  # ── Phase 6: Secrets ──
  _run_log "Phase 6: Loading secrets..."
  stdlib::run::ensure_secrets_and_variables

  # ── Phase 7: Services ──
  if [[ "$skip_services" == "true" ]]; then
    _run_warn "Phase 7: Skipped (--skip-services)"
  else
    _run_log "Phase 7: Ensuring services..."
    stdlib::run::ensure_services
  fi

  # ── Phase 8: Seed variables + global config ──
  _run_log "Phase 8: Seeding variables file..."
  stdlib::config::seed_file
  stdlib::config::ensure_global_conf
  _run_ok "Seeded"

  # ── Release bootstrap lock ──
  stdlib::lock::release "$_lockfile"

  # ── Summary ──
  stdlib::run::print_summary
}

# ══════════════════════════════════════════════════════════════════════
# Phase Implementations
# ══════════════════════════════════════════════════════════════════════

# ── stdlib::run::probe_environment ────────────────────────────────────
stdlib::run::probe_environment() {
  if declare -F stdlib::os::detect &>/dev/null; then
    stdlib::os::detect
    _run_ok "OS: $(stdlib::os::distro 2>/dev/null || echo unknown) $(stdlib::os::codename 2>/dev/null || echo '')"
  fi

  if declare -F stdlib::os::machine_type &>/dev/null; then
    local mtype
    mtype="$(stdlib::os::machine_type 2>/dev/null || echo unknown)"
    _run_ok "Machine: ${mtype}"
  fi

  if declare -F stdlib::hostname::get &>/dev/null; then
    _run_ok "Hostname: $(stdlib::hostname::get 2>/dev/null || hostname)"
  fi
}

# ── stdlib::run::ensure_identity ──────────────────────────────────────
stdlib::run::ensure_identity() {
  if [[ "$DRY_RUN" == "true" ]]; then
    _run_ok "[dry-run] Would ensure ${SYSTEM_USERNAME}:${SYSTEM_GROUPNAME} (${SYSTEM_USER_UID}:${SYSTEM_GROUP_GID})"
    return 0
  fi

  stdlib::user::ensure_identity \
    "$SYSTEM_USERNAME" "$SYSTEM_GROUPNAME" \
    "$SYSTEM_USER_UID" "$SYSTEM_GROUP_GID" \
    "docker"

  _run_ok "Identity: ${SYSTEM_USERNAME}:${SYSTEM_GROUPNAME} (${SYSTEM_USER_UID}:${SYSTEM_GROUP_GID})"
}

# ── stdlib::run::ensure_layout ────────────────────────────────────────
stdlib::run::ensure_layout() {
  if [[ "$DRY_RUN" == "true" ]]; then
    _run_ok "[dry-run] Would create ${NAMESPACE_ROOT_DIR} with standard dirs"
    return 0
  fi

  stdlib::layout::ensure_all \
    "$NAMESPACE_ROOT_DIR" "$NAMESPACE" \
    "$SYSTEM_USERNAME" "$SYSTEM_GROUPNAME"

  _run_ok "Layout: ${NAMESPACE_ROOT_DIR}/{github,configs,appdata,scripts,.ignore}"
}

# ── stdlib::run::ensure_tmpfs ─────────────────────────────────────────
stdlib::run::ensure_tmpfs() {
  if [[ "$DRY_RUN" == "true" ]]; then
    _run_ok "[dry-run] Would configure tmpfs mounts"
    return 0
  fi

  # Calculate RAM-based sizes
  local total_ram_kb half_ram_mb
  total_ram_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 2097152)"
  half_ram_mb=$((total_ram_kb / 2 / 1024))

  # ── $NAMESPACE_ROOT_DIR/tmp — 50% RAM, sticky bit, noexec ──
  stdlib::tmpfs::ensure_mount "${NAMESPACE_ROOT_DIR}/tmp" "$half_ram_mb" "1777" \
    "${SYSTEM_USER_UID}" "${SYSTEM_GROUP_GID}"
  _run_ok "tmpfs: ${NAMESPACE_ROOT_DIR}/tmp (${half_ram_mb}M)"

  # ── $NAMESPACE_ROOT_DIR/logs — min(1G, 50% RAM), mode 0775 ──
  local cap_mb=1024
  local logs_mb=$((half_ram_mb < cap_mb ? half_ram_mb : cap_mb))
  stdlib::tmpfs::ensure_mount "${NAMESPACE_ROOT_DIR}/logs" "$logs_mb" "0775" \
    "${SYSTEM_USER_UID}" "${SYSTEM_GROUP_GID}"
  _run_ok "tmpfs: ${NAMESPACE_ROOT_DIR}/logs (${logs_mb}M)"
}

# ── stdlib::run::ensure_secrets_and_variables ─────────────────────────
stdlib::run::ensure_secrets_and_variables() {
  stdlib::secrets::init

  # Try to load secrets (env → keyctl → age)
  if stdlib::secrets::load 2>/dev/null; then
    _run_ok "Secrets loaded from age file"
    return 0
  fi

  # Fallback: BWS bootstrap
  if command -v bws &>/dev/null || [[ -n "${BWS_ACCESS_TOKEN:-}" ]]; then
    if stdlib::secrets::bootstrap_from_bws 2>/dev/null; then
      _run_ok "Secrets bootstrapped from BWS"
      return 0
    fi
  fi

  # Fallback: tmpdir-based decryption
  if [[ -n "${TMP_DIR:-}" ]] && stdlib::secrets::load_to_tmpdir "${TMP_DIR}" 2>/dev/null; then
    _run_ok "Secrets loaded to tmpdir"
    return 0
  fi

  _run_warn "No secrets loaded — some features may be unavailable"
}

# ── stdlib::run::ensure_services ──────────────────────────────────────
stdlib::run::ensure_services() {
  if [[ "$DRY_RUN" == "true" ]]; then
    _run_ok "[dry-run] Would install base packages, Docker, Tailscale"
    return 0
  fi

  # ── Base packages ──
  local -a base_pkgs=(
    curl git jq rsync unzip python3 ca-certificates gnupg
    lsb-release keyutils age
  )

  if declare -F stdlib::deps::ensure &>/dev/null; then
    stdlib::deps::ensure "${base_pkgs[@]}"
  elif declare -F stdlib::pkg::install &>/dev/null; then
    for pkg in "${base_pkgs[@]}"; do
      stdlib::pkg::install "$pkg" 2>/dev/null || true
    done
  else
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${base_pkgs[@]}" 2>/dev/null || true
  fi
  _run_ok "Base packages installed"

  # ── Docker ──
  stdlib::docker_install::ensure "${SYSTEM_USERNAME}"
  _run_ok "Docker CE installed/verified"

  # ── Docker network ──
  if [[ -n "${DOCKER_NETWORK:-}" ]]; then
    stdlib::docker_install::ensure_network "${DOCKER_NETWORK}"
    _run_ok "Docker network: ${DOCKER_NETWORK}"
  fi

  # ── Tailscale ──
  stdlib::tailscale_install::ensure
  _run_ok "Tailscale installed/verified"

  # ── GitHub CLI ──
  if ! command -v gh &>/dev/null; then
    if declare -F stdlib::pkg::install_gh &>/dev/null; then
      stdlib::pkg::install_gh
    else
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
        sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq gh 2>/dev/null || true
    fi
    _run_ok "GitHub CLI installed"
  else
    _run_ok "GitHub CLI verified"
  fi
}

# ── stdlib::run::print_summary ────────────────────────────────────────
stdlib::run::print_summary() {
  echo ""
  echo -e "${_C_BLUE}╔═══════════════════════════════════════════════════════════════╗${_C_RESET}"
  echo -e "${_C_BLUE}║                     Bootstrap Complete                       ║${_C_RESET}"
  echo -e "${_C_BLUE}╠═══════════════════════════════════════════════════════════════╣${_C_RESET}"
  printf "${_C_BLUE}║${_C_RESET}  %-16s ${_C_GREEN}%s${_C_RESET}\n" "Namespace:" "${NAMESPACE:-unset}"
  printf "${_C_BLUE}║${_C_RESET}  %-16s ${_C_GREEN}%s${_C_RESET}\n" "Root:" "${NAMESPACE_ROOT_DIR:-unset}"
  printf "${_C_BLUE}║${_C_RESET}  %-16s ${_C_GREEN}%s${_C_RESET}\n" "User:" "${SYSTEM_USERNAME:-unset}"
  printf "${_C_BLUE}║${_C_RESET}  %-16s ${_C_GREEN}%s${_C_RESET}\n" "UID/GID:" "${SYSTEM_USER_UID:-?}:${SYSTEM_GROUP_GID:-?}"
  printf "${_C_BLUE}║${_C_RESET}  %-16s ${_C_GREEN}%s${_C_RESET}\n" "TMP_DIR:" "${TMP_DIR:-none}"
  printf "${_C_BLUE}║${_C_RESET}  %-16s ${_C_GREEN}%s${_C_RESET}\n" "Dry-run:" "${DRY_RUN:-false}"
  echo -e "${_C_BLUE}╚═══════════════════════════════════════════════════════════════╝${_C_RESET}"
  echo ""

  # Emit stdlib manifest if available
  if declare -F stdlib::manifest &>/dev/null; then
    stdlib::manifest
  fi
}
