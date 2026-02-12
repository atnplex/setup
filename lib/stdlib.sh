#!/usr/bin/env bash
# =============================================================================
# stdlib.sh — Unified Bash Standard Library Loader
# Version: 0.1.0
# Description: Deterministic module loader with environment detection,
#              import deduplication, and run manifest emission.
# =============================================================================

# Fail fast if already loaded
[[ -n "${_STDLIB_LOADED:-}" ]] && return 0

# ---------- bootstrap strict mode (inline, before any module) ----------------
set -euo pipefail
IFS=$'\n\t'

# ---------- resolve library root ---------------------------------------------
_stdlib_resolve_root() {
  local source="${BASH_SOURCE[0]}"
  while [[ -L "$source" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ "$source" != /* ]] && source="$dir/$source"
  done
  cd -P "$(dirname "$source")" && pwd
}

readonly STDLIB_ROOT="${STDLIB_ROOT:-$(_stdlib_resolve_root)}"
readonly STDLIB_VERSION="0.1.0"
readonly _STDLIB_LOADED=1

# ---------- module registry --------------------------------------------------
declare -gA _STDLIB_MODULES=()       # [category/name]=version
declare -ga _STDLIB_LOAD_ORDER=()     # ordered list of loaded modules

# ---------- environment snapshot ---------------------------------------------
readonly _STDLIB_BASH_VERSION="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"
readonly _STDLIB_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
readonly _STDLIB_ARCH="$(uname -m)"
readonly _STDLIB_PID="$$"
readonly _STDLIB_START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%s)"

# ---------- stdlib::import ---------------------------------------------------
# Load one or more modules by category/name (e.g. "core/log" "data/string")
# Modules are sourced exactly once; subsequent calls are no-ops.
stdlib::import() {
  local mod
  for mod in "$@"; do
    # Already loaded?
    [[ -n "${_STDLIB_MODULES[$mod]:-}" ]] && continue

    local mod_path="${STDLIB_ROOT}/${mod}.sh"
    if [[ ! -f "$mod_path" ]]; then
      printf 'stdlib::import: module not found: %s (looked in %s)\n' \
        "$mod" "$mod_path" >&2
      return 1
    fi

    # shellcheck source=/dev/null
    source "$mod_path"

    _STDLIB_MODULES["$mod"]="${_STDLIB_MOD_VERSION:-0.0.0}"
    _STDLIB_LOAD_ORDER+=("$mod")
    unset _STDLIB_MOD_VERSION
  done
}

# ---------- stdlib::import::loaded -------------------------------------------
# Returns 0 if the given module is loaded, 1 otherwise.
stdlib::import::loaded() {
  [[ -n "${_STDLIB_MODULES[${1:?module name required}]:-}" ]]
}

# ---------- stdlib::import::list ---------------------------------------------
# Print loaded modules, one per line: category/name version
stdlib::import::list() {
  local mod
  for mod in "${_STDLIB_LOAD_ORDER[@]}"; do
    printf '%s %s\n' "$mod" "${_STDLIB_MODULES[$mod]}"
  done
}

# ---------- stdlib::import::manifest -----------------------------------------
# Emit a JSON run manifest to stdout.
stdlib::import::manifest() {
  local mods=""
  local mod
  for mod in "${_STDLIB_LOAD_ORDER[@]}"; do
    [[ -n "$mods" ]] && mods+=","
    mods+="$(printf '{"name":"%s","version":"%s"}' "$mod" "${_STDLIB_MODULES[$mod]}")"
  done

  printf '{"stdlib_version":"%s","bash_version":"%s","os":"%s","arch":"%s","pid":%d,"started":"%s","modules":[%s]}\n' \
    "$STDLIB_VERSION" \
    "$_STDLIB_BASH_VERSION" \
    "$_STDLIB_OS" \
    "$_STDLIB_ARCH" \
    "$_STDLIB_PID" \
    "$_STDLIB_START_TS" \
    "$mods"
}
