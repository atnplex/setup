#!/usr/bin/env bash
# Module: core/vars
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::vars::default, ::require, ::is_int, ::is_bool, ::is_set, ::to_bool
# Description: Variable validation, defaults, and type guards.

[[ -n "${_STDLIB_LOADED_CORE_VARS:-}" ]] && return 0
readonly _STDLIB_LOADED_CORE_VARS=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::vars::default --------------------------------------------
# Set a variable to a default value if it is currently unset or empty.
# Usage: stdlib::vars::default VARNAME "default_value"
stdlib::vars::default() {
  local -n _ref="${1:?variable name required}"
  local default="${2:-}"
  [[ -z "${_ref:-}" ]] && _ref="$default"
}

# ---------- stdlib::vars::require --------------------------------------------
# Fail if the named variable is unset or empty.
# Usage: stdlib::vars::require MY_VAR ["human-readable label"]
stdlib::vars::require() {
  local varname="${1:?variable name required}"
  local label="${2:-$varname}"
  local value="${!varname:-}"
  if [[ -z "$value" ]]; then
    printf 'FATAL: required variable "%s" is unset or empty\n' "$label" >&2
    return 1
  fi
}

# ---------- stdlib::vars::is_int ---------------------------------------------
# Returns 0 if value is a valid integer (positive, negative, or zero).
stdlib::vars::is_int() {
  local value="${1:-}"
  [[ "$value" =~ ^-?[0-9]+$ ]]
}

# ---------- stdlib::vars::is_bool --------------------------------------------
# Returns 0 if value is a recognized boolean string.
stdlib::vars::is_bool() {
  local value="${1:-}"
  case "${value,,}" in
    true|false|yes|no|1|0|on|off) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------- stdlib::vars::is_set ---------------------------------------------
# Returns 0 if the named variable is declared (even if empty).
stdlib::vars::is_set() {
  local varname="${1:?variable name required}"
  declare -p "$varname" &>/dev/null
}

# ---------- stdlib::vars::to_bool --------------------------------------------
# Normalize a truthy/falsy value to "true" or "false".
# Prints the result to stdout. Returns 1 on unrecognized input.
stdlib::vars::to_bool() {
  local value="${1:-}"
  case "${value,,}" in
    true|yes|1|on)  printf 'true\n';  return 0 ;;
    false|no|0|off) printf 'false\n'; return 0 ;;
    *) printf 'false\n'; return 1 ;;
  esac
}
