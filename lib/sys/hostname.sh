#!/usr/bin/env bash
# Module: sys/hostname
# Version: 0.1.0
# Provides: Hostname management — get, set, auto-assign
# Requires: none
[[ -n "${_STDLIB_HOSTNAME:-}" ]] && return 0
declare -g _STDLIB_HOSTNAME=1

# ── stdlib::hostname::get ─────────────────────────────────────
# Get current hostname.
stdlib::hostname::get() {
  hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown"
}

# ── stdlib::hostname::set ─────────────────────────────────────
# Set hostname via hostnamectl + /etc/hostname + /etc/hosts.
# Usage: stdlib::hostname::set new_hostname
stdlib::hostname::set() {
  local name="$1"
  [[ -z "$name" ]] && { echo "ERROR: Hostname cannot be empty" >&2; return 1; }

  # hostnamectl (preferred)
  if command -v hostnamectl &>/dev/null; then
    sudo hostnamectl set-hostname "$name" 2>/dev/null || true
  else
    sudo hostname "$name" 2>/dev/null || true
  fi

  # Persist to /etc/hostname
  echo "$name" | sudo tee /etc/hostname >/dev/null 2>&1 || true

  # Ensure /etc/hosts has a loopback entry
  if ! grep -qF "$name" /etc/hosts 2>/dev/null; then
    echo "127.0.1.1 $name" | sudo tee -a /etc/hosts >/dev/null 2>&1 || true
  fi
}

# ── stdlib::hostname::matches_pattern ─────────────────────────
# Check if hostname matches the ATN naming convention: (vps|vm|srv)N
# Usage: stdlib::hostname::matches_pattern [hostname]
stdlib::hostname::matches_pattern() {
  local name="${1:-$(stdlib::hostname::get)}"
  [[ "$name" =~ ^(vps|vm|srv)[0-9]+$ ]]
}

# ── stdlib::hostname::auto_assign ─────────────────────────────
# Generate next available hostname with given prefix.
# Checks against a newline-separated list of existing names.
# Usage: stdlib::hostname::auto_assign prefix [existing_names_string]
# Returns: prints the chosen hostname (e.g., "vps3")
stdlib::hostname::auto_assign() {
  local prefix="$1"
  local existing="${2:-}"

  local num=1
  while true; do
    local candidate="${prefix}${num}"
    if [[ -z "$existing" ]] || ! echo "$existing" | grep -qx "$candidate"; then
      echo "$candidate"
      return 0
    fi
    ((num++))
  done
}

# ── stdlib::hostname::prefix_for_type ─────────────────────────
# Map machine type to hostname prefix.
# Usage: stdlib::hostname::prefix_for_type machine_type
stdlib::hostname::prefix_for_type() {
  case "$1" in
    cloud)  echo "vps" ;;
    vm)     echo "vm" ;;
    bare)   echo "srv" ;;
    *)      echo "host" ;;
  esac
}
