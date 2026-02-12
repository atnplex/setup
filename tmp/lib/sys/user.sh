#!/usr/bin/env bash
# Module: sys/user
# Version: 0.1.0
# Provides: User/group identity management, sudo helpers
# Requires: none
[[ -n "${_STDLIB_USER:-}" ]] && return 0
declare -g _STDLIB_USER=1

# ── Internal State ─────────────────────────────────────────────────────
declare -g _SUDO_AVAILABLE=""  # cached: "yes", "no", or ""

# ── stdlib::user::exists ──────────────────────────────────────────────
# Check if a user exists on the system.
stdlib::user::exists() {
  id "$1" &>/dev/null
}

# ── stdlib::user::uid ─────────────────────────────────────────────────
# Get the UID of a user.
stdlib::user::uid() {
  id -u "$1" 2>/dev/null
}

# ── stdlib::user::create ──────────────────────────────────────────────
# Create a user with optional specific UID/GID/shell.
# Usage: stdlib::user::create name [uid] [gid] [shell]
stdlib::user::create() {
  local name="$1"
  local uid="${2:-}"
  local gid="${3:-}"
  local shell="${4:-/bin/bash}"

  stdlib::user::exists "$name" && return 0

  local -a args=()
  [[ -n "$uid" ]] && args+=(-u "$uid")
  [[ -n "$gid" ]] && args+=(-g "$gid")
  args+=(-s "$shell" -m)

  sudo useradd "${args[@]}" "$name"
}

# ── stdlib::user::modify ──────────────────────────────────────────────
# Modify user properties.
# Usage: stdlib::user::modify name [--uid N] [--groups G] [--shell S]
stdlib::user::modify() {
  local name="$1"; shift
  local -a args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uid)    args+=(-u "$2"); shift 2 ;;
      --groups) args+=(-aG "$2"); shift 2 ;;
      --shell)  args+=(-s "$2"); shift 2 ;;
      *)        shift ;;
    esac
  done

  sudo usermod "${args[@]}" "$name"
}

# ── stdlib::user::group_exists ────────────────────────────────────────
stdlib::user::group_exists() {
  getent group "$1" &>/dev/null
}

# ── stdlib::user::group_create ────────────────────────────────────────
# Create a group with optional GID.
stdlib::user::group_create() {
  local name="$1"
  local gid="${2:-}"

  stdlib::user::group_exists "$name" && return 0

  local -a args=()
  [[ -n "$gid" ]] && args+=(-g "$gid")

  sudo groupadd "${args[@]}" "$name"
}

# ── stdlib::user::ensure_sudo ─────────────────────────────────────────
# Grant passwordless sudo to a user.
stdlib::user::ensure_sudo() {
  local name="$1"
  local sudoers_file="/etc/sudoers.d/${name}"

  if [[ ! -f "$sudoers_file" ]]; then
    echo "${name} ALL=(ALL) NOPASSWD:ALL" | sudo tee "$sudoers_file" >/dev/null
    sudo chmod 440 "$sudoers_file"
  fi
}

# ── stdlib::user::is_root ─────────────────────────────────────────────
# Returns 0 if running as root.
stdlib::user::is_root() {
  [[ $(id -u) -eq 0 ]]
}

# ── stdlib::user::check_sudo ──────────────────────────────────────────
# Check if sudo is available (cached).
stdlib::user::check_sudo() {
  if [[ -n "$_SUDO_AVAILABLE" ]]; then
    [[ "$_SUDO_AVAILABLE" == "yes" ]]
    return $?
  fi

  if stdlib::user::is_root; then
    _SUDO_AVAILABLE="yes"
    return 0
  fi

  if sudo -n true 2>/dev/null; then
    _SUDO_AVAILABLE="yes"
    return 0
  fi

  _SUDO_AVAILABLE="no"
  return 1
}

# ── stdlib::user::run_as_root ─────────────────────────────────────────
# Execute a command as root (sudo-aware).
stdlib::user::run_as_root() {
  if stdlib::user::is_root; then
    "$@"
  elif stdlib::user::check_sudo; then
    sudo "$@"
  else
    echo "ERROR: Cannot execute as root — sudo unavailable" >&2
    return 1
  fi
}

# ── stdlib::user::sudo_keepalive ──────────────────────────────────────
# Start background sudo credential refresh.
stdlib::user::sudo_keepalive() {
  stdlib::user::check_sudo || return 1

  # Refresh sudo timestamp in background
  while true; do
    sudo -n true 2>/dev/null
    sleep 50
  done &
  disown $!
}
