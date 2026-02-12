#!/usr/bin/env bash
# Module: core/meta
# Version: 0.1.0
# Provides: Module metadata, self-documentation, capability reporting
# Requires: core/import
[[ -n "${_STDLIB_META:-}" ]] && return 0
declare -g _STDLIB_META=1

# ── stdlib::meta::version ─────────────────────────────────────────────
# Print the stdlib version.
stdlib::meta::version() {
  printf '%s' "${STDLIB_VERSION:-unknown}"
}

# ── stdlib::meta::module_info ─────────────────────────────────────────
# Print metadata for a module (from its header comments).
# Usage: stdlib::meta::module_info category/module
stdlib::meta::module_info() {
  local mod="$1"
  local modfile="${STDLIB_ROOT}/${mod}.sh"

  [[ -f "$modfile" ]] || { echo "ERROR: Module not found: $mod" >&2; return 1; }

  # Extract header metadata (lines starting with # Module:, # Version:, etc.)
  echo "Module:   $mod"
  grep -E '^#\s*(Version|Provides|Requires):' "$modfile" | sed 's/^#\s*/  /'
  echo "  Loaded:   $(stdlib::import::loaded "$mod" && echo 'yes' || echo 'no')"
}

# ── stdlib::meta::list_functions ──────────────────────────────────────
# List all public functions in a module.
# Usage: stdlib::meta::list_functions category/module
stdlib::meta::list_functions() {
  local mod="$1"
  local modfile="${STDLIB_ROOT}/${mod}.sh"

  [[ -f "$modfile" ]] || { echo "ERROR: Module not found: $mod" >&2; return 1; }

  # Extract function declarations (stdlib::* pattern)
  grep -oP '^stdlib::[a-z_:]+(?=\(\))' "$modfile" | sort
}

# ── stdlib::meta::help ────────────────────────────────────────────────
# Print the docstring (comment block above) for a function.
# Usage: stdlib::meta::help function_name
stdlib::meta::help() {
  local func="$1"

  # Find which file contains this function
  local modfile
  modfile=$(grep -rlP "^${func}\(\)" "${STDLIB_ROOT}" 2>/dev/null | head -1)
  [[ -f "$modfile" ]] || { echo "ERROR: Function not found: $func" >&2; return 1; }

  # Extract comment block above the function definition
  awk -v fn="${func}()" '
    /^# \u2500\u2500/ { block=""; capturing=1; next }
    capturing && /^#/ { block=block "\n" $0; next }
    capturing && $0 ~ fn { print block; exit }
    capturing { capturing=0; block="" }
  ' "$modfile" | sed 's/^# //' | sed '/^$/d'
}

# ── stdlib::meta::capabilities ───────────────────────────────────────
# Emit full environment + module JSON.
stdlib::meta::capabilities() {
  local loaded
  loaded=$(stdlib::import::list 2>/dev/null | tr '\n' ',' | sed 's/,$//')

  cat <<-EOF
{
  "stdlib_version": "$(stdlib::meta::version)",
  "bash_version": "${BASH_VERSION}",
  "os": "$(uname -s)",
  "arch": "$(uname -m)",
  "hostname": "$(hostname)",
  "loaded_modules": [$(echo "$loaded" | sed 's/[^,]*/"&"/g')],
  "module_count": $(stdlib::import::list 2>/dev/null | wc -l)
}
EOF
}
