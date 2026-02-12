#!/usr/bin/env bash
# Module: sys/deps
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::deps::require, ::require_version, ::check_all, ::install_hint
# Description: Command availability checks and version requirement validation.

[[ -n "${_STDLIB_LOADED_SYS_DEPS:-}" ]] && return 0
readonly _STDLIB_LOADED_SYS_DEPS=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::deps::require --------------------------------------------
# Fail if a command is not available in PATH.
# Usage: stdlib::deps::require curl jq git
stdlib::deps::require() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      printf 'FATAL: required command "%s" not found in PATH\n' "$cmd" >&2
      stdlib::deps::install_hint "$cmd" >&2
      return 1
    fi
  done
}

# ---------- stdlib::deps::require_version ------------------------------------
# Fail if the installed version of a command is below the minimum.
# Usage: stdlib::deps::require_version bash 4.3 "bash --version"
stdlib::deps::require_version() {
  local cmd="${1:?command required}"
  local min_ver="${2:?minimum version required}"
  local ver_cmd="${3:-$cmd --version}"

  command -v "$cmd" &>/dev/null || {
    printf 'FATAL: command "%s" not found\n' "$cmd" >&2
    return 1
  }

  local raw_ver
  raw_ver="$(eval "$ver_cmd" 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
  if [[ -z "$raw_ver" ]]; then
    printf 'WARN: could not determine version of "%s"\n' "$cmd" >&2
    return 0
  fi

  if ! _stdlib_deps_ver_gte "$raw_ver" "$min_ver"; then
    printf 'FATAL: %s version %s is below minimum %s\n' "$cmd" "$raw_ver" "$min_ver" >&2
    return 1
  fi
}

# Compare two dotted version strings: returns 0 if a >= b
_stdlib_deps_ver_gte() {
  local a="$1" b="$2"
  # Pad to 3 components
  local IFS='.'
  read -ra av <<< "$a"
  read -ra bv <<< "$b"
  local i
  for (( i=0; i<3; i++ )); do
    local ai="${av[$i]:-0}" bi="${bv[$i]:-0}"
    (( ai > bi )) && return 0
    (( ai < bi )) && return 1
  done
  return 0
}

# ---------- stdlib::deps::check_all ------------------------------------------
# Batch-check: reads command names from a newline-separated list.
# Returns 0 only if ALL commands are available.
stdlib::deps::check_all() {
  local missing=() cmd
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'Missing commands: %s\n' "${missing[*]}" >&2
    return 1
  fi
}

# ---------- stdlib::deps::install_hint ---------------------------------------
# Print a distro-appropriate install suggestion.
stdlib::deps::install_hint() {
  local cmd="$1"
  local distro="unknown"
  [[ -f /etc/os-release ]] && distro="$(. /etc/os-release && echo "$ID")"

  printf 'Install hint for "%s":\n' "$cmd"
  case "$distro" in
    debian|ubuntu)  printf '  sudo apt-get install -y %s\n' "$cmd" ;;
    fedora)         printf '  sudo dnf install -y %s\n' "$cmd" ;;
    rhel|centos|rocky|alma) printf '  sudo yum install -y %s\n' "$cmd" ;;
    alpine)         printf '  sudo apk add %s\n' "$cmd" ;;
    arch|manjaro)   printf '  sudo pacman -S %s\n' "$cmd" ;;
    opensuse*)      printf '  sudo zypper install %s\n' "$cmd" ;;
    *)              printf '  Please install "%s" using your system package manager\n' "$cmd" ;;
  esac
}
