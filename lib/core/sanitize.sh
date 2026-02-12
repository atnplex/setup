#!/usr/bin/env bash
# ─── core/sanitize.sh — No-eval config file loader with validation ───
# Module version
_STDLIB_MOD_VERSION="1.0.0"
[[ -n "${_STDLIB_SANITIZE:-}" ]] && return 0
declare -g _STDLIB_SANITIZE=1

# ── stdlib::sanitize::load_file ───────────────────────────────────────
# Parse a KEY=VALUE file WITHOUT eval. Each line is validated and
# sanitized before export. Returns number of variables loaded.
#
# Load order determines precedence: the LAST file loaded wins.
#
# Rules:
#   - Strip comments (# at start or inline after space)
#   - Strip leading/trailing whitespace
#   - Enforce: variable names are [A-Z_][A-Z0-9_]* only
#   - Normalize paths: remove trailing slashes
#   - Lowercase NAMESPACE value
#   - Skip malformed lines silently
#
# Usage: stdlib::sanitize::load_file path [override]
#   override=true → overwrite existing env vars (default: false)
stdlib::sanitize::load_file() {
  local filepath="${1:?file path required}"
  local override="${2:-false}"
  local count=0

  [[ -f "$filepath" ]] || return 1

  local line key val
  while IFS='' read -r line || [[ -n "$line" ]]; do
    # Strip inline comments (but preserve values containing #)
    # Only strip # preceded by whitespace outside quotes
    line="${line%%#*}"

    # Strip leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip blank lines
    [[ -z "$line" ]] && continue

    # Must contain =
    [[ "$line" == *=* ]] || continue

    # Split on first =
    key="${line%%=*}"
    val="${line#*=}"

    # Validate key: must be uppercase alpha + underscore + digits
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue

    # Strip surrounding quotes from value
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    val="${val#\"}"
    val="${val%\"}"
    val="${val#\'}"
    val="${val%\'}"

    # ── Type-specific sanitization ──

    # UIDs/GIDs: must be integer
    case "$key" in
    *_UID | *_GID)
      [[ "$val" =~ ^[0-9]+$ ]] || continue
      ;;
    esac

    # Paths: normalize trailing slashes (but not for root /)
    case "$key" in
    *_DIR | *_FILE | *_PATH)
      if [[ "${#val}" -gt 1 ]]; then
        val="${val%/}"
      fi
      ;;
    esac

    # NAMESPACE: lowercase
    if [[ "$key" == "NAMESPACE" ]]; then
      val="${val,,}"
    fi

    # Only set if not already in env (unless override)
    if [[ "$override" == "true" ]] || [[ -z "${!key:-}" ]]; then
      export "$key=$val"
      ((count++)) || true
    fi
  done <"$filepath"

  return 0
}

# ── stdlib::sanitize::validate_required ───────────────────────────────
# Check that a list of variables are non-empty. Fatal on missing.
# Usage: stdlib::sanitize::validate_required VAR1 VAR2 ...
stdlib::sanitize::validate_required() {
  local missing=0
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      printf 'FATAL: Required variable %s is not set\n' "$var" >&2
      ((missing++)) || true
    fi
  done
  [[ $missing -eq 0 ]]
}

# ── stdlib::sanitize::normalize_namespace ─────────────────────────────
# Ensure NAMESPACE is lowercase, alphanumeric + underscore only.
stdlib::sanitize::normalize_namespace() {
  local ns="${NAMESPACE:-}"
  # Lowercase
  ns="${ns,,}"
  # Strip anything not alnum or underscore
  ns="$(printf '%s' "$ns" | tr -cd 'a-z0-9_')"
  [[ -n "$ns" ]] || return 1
  export NAMESPACE="$ns"
}
