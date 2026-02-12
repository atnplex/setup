#!/usr/bin/env bash
# Module: core/config
# Version: 0.1.0
# Provides: Variables file discovery, loading, resolution, and seeding
# Requires: none
[[ -n "${_STDLIB_CONFIG:-}" ]] && return 0
declare -g _STDLIB_CONFIG=1

# ── stdlib::config::discover_file ─────────────────────────────────────
# Locate the variables file using priority chain:
#   1. $1 (explicit path, e.g. from CLI --variables-file)
#   2. $VARIABLES_FILE environment variable
#   3. $NAMESPACE_ROOT/.ignore/variables.env
#   4. /etc/bootstrap/variables.env
# Prints the first found path, or empty if none exist.
stdlib::config::discover_file() {
  local explicit="${1:-}"

  # Priority 1: explicit path
  if [[ -n "$explicit" && -f "$explicit" ]]; then
    echo "$explicit"
    return 0
  fi

  # Priority 2: environment variable
  if [[ -n "${VARIABLES_FILE:-}" && -f "$VARIABLES_FILE" ]]; then
    echo "$VARIABLES_FILE"
    return 0
  fi

  # Priority 3: conventional location
  if [[ -n "${NAMESPACE_ROOT:-}" && -f "${NAMESPACE_ROOT}/.ignore/variables.env" ]]; then
    echo "${NAMESPACE_ROOT}/.ignore/variables.env"
    return 0
  fi

  # Priority 4: system fallback
  if [[ -f "/etc/bootstrap/variables.env" ]]; then
    echo "/etc/bootstrap/variables.env"
    return 0
  fi

  return 1
}

# ── stdlib::config::load_file ─────────────────────────────────────────
# Parse a KEY=VALUE file, exporting each variable.
# Skips comments (#), blank lines, and does not override existing env vars.
# Usage: stdlib::config::load_file path [override]
#   If override=true, existing env vars ARE overwritten.
stdlib::config::load_file() {
  local filepath="$1"
  local override="${2:-false}"

  [[ -f "$filepath" ]] || return 1

  local key val
  while IFS='=' read -r key val; do
    # Skip comments and blanks
    key="${key%%#*}"
    key="$(echo "$key" | tr -d '[:space:]')"
    [[ -z "$key" ]] && continue

    # Strip surrounding quotes from value
    val="${val#\"}"
    val="${val%\"}"
    val="${val#\'}"
    val="${val%\'}"

    # Only set if not already in env (unless override)
    if [[ "$override" == "true" ]] || [[ -z "${!key:-}" ]]; then
      export "$key=$val"
    fi
  done <"$filepath"
}

# ── stdlib::config::resolve_vars ──────────────────────────────────────
# Resolve all required bootstrap variables with fallback chain:
#   env → variables file → derived defaults → interactive prompt
# Usage: stdlib::config::resolve_vars [variables_file] [interactive]
stdlib::config::resolve_vars() {
  local vfile="${1:-}"
  local interactive="${2:-true}"

  # Load variables file if provided and exists
  if [[ -n "$vfile" && -f "$vfile" ]]; then
    stdlib::config::load_file "$vfile"
  fi

  # ── NAMESPACE (required) ──
  if [[ -z "${NAMESPACE:-}" ]]; then
    if [[ "$interactive" == "true" ]]; then
      read -rp "  Namespace short name (e.g., atn): " NAMESPACE </dev/tty 2>/dev/null || true
    fi
    [[ -z "${NAMESPACE:-}" ]] && {
      echo "FATAL: NAMESPACE is required" >&2
      return 1
    }
  fi
  export NAMESPACE

  # ── NAMESPACE_ROOT — derive from NAMESPACE if missing ──
  NAMESPACE_ROOT="${NAMESPACE_ROOT:-/${NAMESPACE}}"
  export NAMESPACE_ROOT

  # ── BOOTSTRAP_USER — detect from current user ──
  BOOTSTRAP_USER="${BOOTSTRAP_USER:-$(whoami 2>/dev/null || echo root)}"
  export BOOTSTRAP_USER

  # ── BOOTSTRAP_GROUP — derive from NAMESPACE ──
  BOOTSTRAP_GROUP="${BOOTSTRAP_GROUP:-${NAMESPACE}}"
  export BOOTSTRAP_GROUP

  # ── BOOTSTRAP_UID — detect or prompt ──
  if [[ -z "${BOOTSTRAP_UID:-}" ]]; then
    local current_uid
    current_uid="$(id -u "$BOOTSTRAP_USER" 2>/dev/null || true)"
    if [[ -n "$current_uid" && "$current_uid" -ne 0 ]]; then
      BOOTSTRAP_UID="$current_uid"
    elif [[ "$interactive" == "true" ]]; then
      read -rp "  UID for $BOOTSTRAP_USER: " BOOTSTRAP_UID </dev/tty 2>/dev/null || true
    fi
    [[ -z "${BOOTSTRAP_UID:-}" ]] && {
      echo "FATAL: BOOTSTRAP_UID is required" >&2
      return 1
    }
  fi
  export BOOTSTRAP_UID

  # ── BOOTSTRAP_GID — match UID by default ──
  BOOTSTRAP_GID="${BOOTSTRAP_GID:-${BOOTSTRAP_UID}}"
  export BOOTSTRAP_GID

  # ── Optional variables with defaults ──
  GH_ORG="${GH_ORG:-${NAMESPACE}plex}"
  export GH_ORG

  DOCKER_NETWORK="${DOCKER_NETWORK:-${NAMESPACE}_net}"
  export DOCKER_NETWORK

  # ── Derived paths ──
  VARIABLES_FILE="${VARIABLES_FILE:-${NAMESPACE_ROOT}/.ignore/variables.env}"
  export VARIABLES_FILE

  SECRETS_FILE="${SECRETS_FILE:-${NAMESPACE_ROOT}/.ignore/secrets/secrets.age}"
  export SECRETS_FILE
}

# ── stdlib::config::seed_file ─────────────────────────────────────────
# Write current resolved values to the variables file for future runs.
# Idempotent: only writes if the file doesn't exist or is empty.
# Usage: stdlib::config::seed_file [target_path]
stdlib::config::seed_file() {
  local target="${1:-${VARIABLES_FILE:-}}"
  [[ -z "$target" ]] && return 1

  # Don't overwrite existing populated file
  if [[ -f "$target" ]] && [[ -s "$target" ]]; then
    return 0
  fi

  local parent
  parent="$(dirname "$target")"
  [[ -d "$parent" ]] || sudo mkdir -p "$parent"

  cat >"$target" <<SEED_EOF
# Bootstrap Variables — Auto-generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Source of truth for non-secret environment values.
NAMESPACE=${NAMESPACE:-}
NAMESPACE_ROOT=${NAMESPACE_ROOT:-}
BOOTSTRAP_USER=${BOOTSTRAP_USER:-}
BOOTSTRAP_GROUP=${BOOTSTRAP_GROUP:-}
BOOTSTRAP_UID=${BOOTSTRAP_UID:-}
BOOTSTRAP_GID=${BOOTSTRAP_GID:-}
GH_ORG=${GH_ORG:-}
DOCKER_NETWORK=${DOCKER_NETWORK:-}
SEED_EOF

  sudo chown "${BOOTSTRAP_USER:-root}:${BOOTSTRAP_GROUP:-root}" "$target" 2>/dev/null || true
  chmod 600 "$target" 2>/dev/null || true
}
