#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# sys/probe.sh — Environment detection and dependency verification
# ═══════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_PROBE:-}" ]] && return 0
readonly _STDLIB_MOD_PROBE=1
_STDLIB_MOD_VERSION="1.0.0"

stdlib::import core/log

# ── Run full environment probe ───────────────────────────────────────
stdlib::probe::run() {
  PROBE_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  export PROBE_OS

  PROBE_ARCH="$(uname -m)"
  export PROBE_ARCH

  PROBE_DISTRO="unknown"
  PROBE_DISTRO_VERSION="unknown"
  if [[ -f /etc/os-release ]]; then
    local ID="" VERSION_ID=""
    # shellcheck source=/dev/null
    source /etc/os-release
    PROBE_DISTRO="${ID:-unknown}"
    PROBE_DISTRO_VERSION="${VERSION_ID:-unknown}"
  fi
  export PROBE_DISTRO PROBE_DISTRO_VERSION

  PROBE_VIRT="none"
  PROBE_CONTAINER="false"
  if [[ -f /.dockerenv ]] || grep -qF docker /proc/1/cgroup 2>/dev/null; then
    PROBE_CONTAINER="true"
    PROBE_VIRT="docker"
  elif [[ -f /run/systemd/container ]]; then
    PROBE_CONTAINER="true"
    PROBE_VIRT="$(cat /run/systemd/container)"
  elif command -v systemd-detect-virt >/dev/null 2>&1; then
    PROBE_VIRT="$(systemd-detect-virt 2>/dev/null || echo 'none')"
    if [[ "${PROBE_VIRT}" != "none" ]]; then
      local virt_type
      virt_type="$(systemd-detect-virt --container 2>/dev/null || echo 'none')"
      [[ "${virt_type}" != "none" ]] && PROBE_CONTAINER="true"
    fi
  fi
  export PROBE_VIRT PROBE_CONTAINER

  stdlib::log::info "OS: ${PROBE_OS} | Arch: ${PROBE_ARCH} | Distro: ${PROBE_DISTRO} ${PROBE_DISTRO_VERSION}"
  stdlib::log::info "Virt: ${PROBE_VIRT} | Container: ${PROBE_CONTAINER}"
}

# ── Check if a command exists ────────────────────────────────────────
stdlib::probe::check_command() {
  command -v "${1:?command name required}" >/dev/null 2>&1
}

# ── Install required system dependencies ─────────────────────────────
stdlib::probe::deps() {
  local -a required=(docker tailscale gh jq rsync)
  local -a missing=()

  local cmd
  for cmd in "${required[@]}"; do
    if ! stdlib::probe::check_command "${cmd}"; then
      missing+=("${cmd}")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    stdlib::log::info "All dependencies present"
    return 0
  fi

  stdlib::log::info "Installing missing: ${missing[*]}"

  for cmd in "${missing[@]}"; do
    case "${cmd}" in
      docker)    _probe_install_docker ;;
      tailscale) _probe_install_tailscale ;;
      gh)        _probe_install_gh ;;
      jq)        apt-get install -yqq jq >/dev/null 2>&1 ;;
      rsync)     apt-get install -yqq rsync >/dev/null 2>&1 ;;
      *)         stdlib::log::warn "No installer for: ${cmd}" ;;
    esac
  done
}

# ── Internal installers ──────────────────────────────────────────────
_probe_install_docker() {
  if stdlib::probe::check_command docker; then return 0; fi
  stdlib::log::info "Installing Docker..."
  curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
  systemctl enable --now docker >/dev/null 2>&1 || true
}

_probe_install_tailscale() {
  if stdlib::probe::check_command tailscale; then return 0; fi
  stdlib::log::info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1
}

_probe_install_gh() {
  if stdlib::probe::check_command gh; then return 0; fi
  stdlib::log::info "Installing GitHub CLI..."
  local keyring="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    gpg --dearmor -o "${keyring}" 2>/dev/null
  printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' \
    "$(dpkg --print-architecture)" "${keyring}" > /etc/apt/sources.list.d/github-cli.list
  apt-get update -qq >/dev/null 2>&1
  apt-get install -yqq gh >/dev/null 2>&1
}
