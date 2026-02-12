#!/usr/bin/env bash
# Module: sys/os
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::os::name, ::arch, ::distro, ::version, ::is_container, ::capabilities
# Description: OS, architecture, and distro detection.

[[ -n "${_STDLIB_LOADED_SYS_OS:-}" ]] && return 0
readonly _STDLIB_LOADED_SYS_OS=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::os::name -------------------------------------------------
# Print normalized OS name: linux, darwin, freebsd, windows, unknown
stdlib::os::name() {
  local raw
  raw="$(uname -s 2>/dev/null || echo unknown)"
  case "${raw,,}" in
    linux*)   printf 'linux' ;;
    darwin*)  printf 'darwin' ;;
    freebsd*) printf 'freebsd' ;;
    msys*|mingw*|cygwin*) printf 'windows' ;;
    *)        printf 'unknown' ;;
  esac
}

# ---------- stdlib::os::arch -------------------------------------------------
# Print normalized architecture: x86_64, aarch64, armv7l, ...
stdlib::os::arch() {
  local raw
  raw="$(uname -m 2>/dev/null || echo unknown)"
  case "$raw" in
    x86_64|amd64)  printf 'x86_64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    armv7l|armhf)  printf 'armv7l' ;;
    *)             printf '%s' "$raw" ;;
  esac
}

# ---------- stdlib::os::distro -----------------------------------------------
# Print distro ID: debian, ubuntu, alpine, rhel, fedora, arch, opensuse, ...
stdlib::os::distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    local ID=""
    source /etc/os-release 2>/dev/null
    printf '%s' "${ID:-unknown}"
  elif [[ -f /etc/redhat-release ]]; then
    printf 'rhel'
  elif [[ -f /etc/alpine-release ]]; then
    printf 'alpine'
  else
    printf 'unknown'
  fi
}

# ---------- stdlib::os::version ----------------------------------------------
# Print distro version string.
stdlib::os::version() {
  if [[ -f /etc/os-release ]]; then
    local VERSION_ID=""
    # shellcheck source=/dev/null
    source /etc/os-release 2>/dev/null
    printf '%s' "${VERSION_ID:-unknown}"
  else
    uname -r
  fi
}

# ---------- stdlib::os::is_container -----------------------------------------
# Returns 0 if running inside a container (Docker, Podman, LXC).
stdlib::os::is_container() {
  # Check for .dockerenv
  [[ -f /.dockerenv ]] && return 0
  # Check for container env
  [[ -n "${container:-}" ]] && return 0
  # Check cgroup
  grep -qE '(docker|lxc|kubepods|containerd)' /proc/1/cgroup 2>/dev/null && return 0
  # Check for podman
  [[ -f /run/.containerenv ]] && return 0
  return 1
}

# ---------- stdlib::os::capabilities -----------------------------------------
# Emit a JSON object describing environment capabilities.
stdlib::os::capabilities() {
  local os arch distro ver container="false" bash_ver
  os="$(stdlib::os::name)"
  arch="$(stdlib::os::arch)"
  distro="$(stdlib::os::distro)"
  ver="$(stdlib::os::version)"
  bash_ver="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"
  stdlib::os::is_container && container="true"

  printf '{"os":"%s","arch":"%s","distro":"%s","distro_version":"%s","bash_version":"%s","container":%s,"user":"%s","pid":%d}\n' \
    "$os" "$arch" "$distro" "$ver" "$bash_ver" "$container" "$(whoami)" "$$"
}
