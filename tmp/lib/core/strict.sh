#!/usr/bin/env bash
# Module: core/strict
# Version: 0.1.0
# Requires: (none — bootstrapped by stdlib.sh)
# Provides: stdlib::strict::enable, ::trap_err, ::trap_exit, ::register_cleanup
# Description: Strict mode, ERR/EXIT traps with stack traces, cleanup hooks.

[[ -n "${_STDLIB_LOADED_CORE_STRICT:-}" ]] && return 0
readonly _STDLIB_LOADED_CORE_STRICT=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# Internal cleanup registry (module-scoped array)
declare -ga _STDLIB_CLEANUP_HOOKS=()

# ---------- stdlib::strict::enable -------------------------------------------
# Activate strict mode: errexit, nounset, pipefail, safe IFS.
stdlib::strict::enable() {
  set -euo pipefail
  IFS=$'\n\t'
}

# ---------- stdlib::strict::trap_err -----------------------------------------
# Install an ERR trap that prints a stack trace to stderr.
stdlib::strict::trap_err() {
  trap '_stdlib_err_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR
}

_stdlib_err_handler() {
  local source="$1" line="$2" func="$3" code="$4"
  printf '\n=== STDLIB ERR TRAP ===\n' >&2
  printf 'Command exited with status %s\n' "$code" >&2
  printf 'Location: %s:%s in %s()\n' "$source" "$line" "$func" >&2
  printf 'Stack trace:\n' >&2
  local i
  for (( i=0; i < ${#FUNCNAME[@]}; i++ )); do
    printf '  [%d] %s() at %s:%s\n' \
      "$i" "${FUNCNAME[$i]:-main}" "${BASH_SOURCE[$i]:-unknown}" "${BASH_LINENO[$i]:-?}" >&2
  done
  printf '======================\n\n' >&2
}

# ---------- stdlib::strict::trap_exit ----------------------------------------
# Install an EXIT trap that runs all registered cleanup hooks in LIFO order.
stdlib::strict::trap_exit() {
  trap '_stdlib_exit_handler' EXIT
}

_stdlib_exit_handler() {
  local i
  for (( i=${#_STDLIB_CLEANUP_HOOKS[@]}-1; i>=0; i-- )); do
    eval "${_STDLIB_CLEANUP_HOOKS[$i]}" 2>/dev/null || true
  done
}

# ---------- stdlib::strict::register_cleanup ---------------------------------
# Register a command string to run at exit (LIFO order).
# Usage: stdlib::strict::register_cleanup "rm -f /tmp/lockfile"
stdlib::strict::register_cleanup() {
  local cmd="${1:?cleanup command required}"
  _STDLIB_CLEANUP_HOOKS+=("$cmd")
}
