#!/usr/bin/env bash
# Module: sys/deps
# Version: 0.2.0
# Provides: Dependency checks, version requirements, install hints, auto-install
# Requires: none
[[ -n "${_STDLIB_DEPS:-}" ]] && return 0
declare -g _STDLIB_DEPS=1

# ── stdlib::deps::require ─────────────────────────────────────
# Verify a command is available, exit if not.
# Usage: stdlib::deps::require cmd [friendly_name]
stdlib::deps::require() {
  local cmd="$1"
  local name="${2:-$cmd}"

  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: Required command '$name' not found" >&2
    stdlib::deps::install_hint "$cmd" >&2
    return 1
  fi
}

# ── stdlib::deps::require_version ─────────────────────────────
# Check minimum version of a command.
# Usage: stdlib::deps::require_version cmd min_version [version_flag]
stdlib::deps::require_version() {
  local cmd="$1"
  local min="$2"
  local flag="${3:---version}"

  stdlib::deps::require "$cmd" || return 1

  local current
  current=$("$cmd" "$flag" 2>&1 | grep -oP '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
  [[ -z "$current" ]] && { echo "WARN: Cannot detect version for $cmd" >&2; return 0; }

  if ! _stdlib_deps_version_gte "$current" "$min"; then
    echo "ERROR: $cmd version $current < required $min" >&2
    return 1
  fi
}

# ── stdlib::deps::check_all ───────────────────────────────────
# Batch check for multiple commands.
# Usage: stdlib::deps::check_all cmd1 cmd2 cmd3...
stdlib::deps::check_all() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing commands: ${missing[*]}" >&2
    for cmd in "${missing[@]}"; do
      stdlib::deps::install_hint "$cmd" >&2
    done
    return 1
  fi
}

# ── stdlib::deps::install_hint ────────────────────────────────
# Suggest installation command for a missing binary.
stdlib::deps::install_hint() {
  local cmd="$1"
  local distro=""

  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    distro=$(. /etc/os-release && echo "${ID:-}")
  fi

  echo "  Install hint for '$cmd':"
  case "$distro" in
    ubuntu|debian)  echo "    sudo apt-get install -y $cmd" ;;
    fedora)         echo "    sudo dnf install -y $cmd" ;;
    centos|rhel)    echo "    sudo yum install -y $cmd" ;;
    arch|manjaro)   echo "    sudo pacman -S $cmd" ;;
    alpine)         echo "    sudo apk add $cmd" ;;
    *)
      if command -v brew &>/dev/null; then
        echo "    brew install $cmd"
      else
        echo "    (Consult your package manager)"
      fi
      ;;
  esac
}

# ── Internal: version comparison ──────────────────────────────
_stdlib_deps_version_gte() {
  local current="$1" required="$2"
  # Use sort -V for version comparison
  [[ "$(printf '%s\n%s' "$required" "$current" | sort -V | head -1)" == "$required" ]]
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.2.0)
# ══════════════════════════════════════════════════════════════

# ── stdlib::deps::ensure ──────────────────────────────────────
# Check for a command; if missing and pkg_name given, auto-install it.
# Usage: stdlib::deps::ensure cmd [pkg_name]
stdlib::deps::ensure() {
  local cmd="$1"
  local pkg="${2:-}"

  command -v "$cmd" &>/dev/null && return 0

  if [[ -z "$pkg" ]]; then
    echo "ERROR: Required command '$cmd' not found (no package name given for auto-install)" >&2
    return 1
  fi

  echo "INFO: Installing missing dependency: $pkg (provides $cmd)" >&2

  local distro=""
  [[ -f /etc/os-release ]] && distro=$(. /etc/os-release && echo "${ID:-}")

  case "$distro" in
    ubuntu|debian) sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" ;;
    fedora)        sudo dnf install -y -q "$pkg" ;;
    centos|rhel)   sudo yum install -y -q "$pkg" ;;
    arch|manjaro)  sudo pacman -S --noconfirm --needed "$pkg" ;;
    alpine)        sudo apk add --no-cache "$pkg" ;;
    *)
      if command -v brew &>/dev/null; then
        brew install "$pkg"
      else
        echo "ERROR: Cannot auto-install on this distro" >&2
        return 1
      fi
      ;;
  esac

  # Verify installation succeeded
  command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd still not found after installing $pkg" >&2; return 1; }
}

# ── stdlib::deps::ensure_all ──────────────────────────────────
# Batch ensure with cmd:pkg pairs.
# Usage: stdlib::deps::ensure_all "jq:jq" "curl:curl" "age:age"
stdlib::deps::ensure_all() {
  local pair cmd pkg
  for pair in "$@"; do
    cmd="${pair%%:*}"
    pkg="${pair##*:}"
    stdlib::deps::ensure "$cmd" "$pkg" || return 1
  done
}
