#!/usr/bin/env bash
# Module: core/import
# Version: 0.1.0
# Requires: (none — extension of stdlib.sh loader)
# Provides: stdlib::import::require, ::import::version
# Description: Extended import helpers — version queries and hard requirements.

[[ -n "${_STDLIB_LOADED_CORE_IMPORT:-}" ]] && return 0
readonly _STDLIB_LOADED_CORE_IMPORT=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::import::require ------------------------------------------
# Require a module; fatal error if loading fails.
stdlib::import::require() {
  local mod
  for mod in "$@"; do
    if ! stdlib::import "$mod"; then
      printf 'FATAL: required module "%s" could not be loaded\n' "$mod" >&2
      exit 78  # EX_CONFIG
    fi
  done
}

# ---------- stdlib::import::version ------------------------------------------
# Print the version of a loaded module. Returns 1 if not loaded.
stdlib::import::version() {
  local mod="${1:?module name required}"
  if [[ -n "${_STDLIB_MODULES[$mod]:-}" ]]; then
    printf '%s\n' "${_STDLIB_MODULES[$mod]}"
    return 0
  fi
  return 1
}

# ---------- stdlib::import::available ----------------------------------------
# List all discoverable modules under STDLIB_ROOT.
stdlib::import::available() {
  local f
  while IFS= read -r -d '' f; do
    local rel="${f#"${STDLIB_ROOT}/"}"
    rel="${rel%.sh}"
    printf '%s\n' "$rel"
  done < <(find "$STDLIB_ROOT" -name '*.sh' ! -name 'stdlib.sh' -print0 | sort -z)
}
