#!/usr/bin/env bash
# Module: core/config
# Version: 0.2.0
# Provides: Variables discovery, loading, resolution, seeding, BWS integration
# Requires: core/sanitize (for no-eval loading)
[[ -n "${_STDLIB_CONFIG:-}" ]] && return 0
declare -g _STDLIB_CONFIG=1

# ── stdlib::config::discover_files ────────────────────────────────────
# Search the top 4 directory levels under NAMESPACE_ROOT_DIR for:
#   variables.env, secrets.env, secrets.age
# Populates global variables: VARIABLES_ENV_FILE, SECRETS_ENV_FILE,
# ENCRYPTED_SECRETS_AGE_FILE
# Conventional search paths (in priority order):
#   1. .ignore/<filename>
#   2. <filename> (at root)
#   3. configs/<filename>
stdlib::config::discover_files() {
  local root="${NAMESPACE_ROOT_DIR:-}"
  [[ -z "$root" ]] && return 1

  local f

  # ── variables.env ──
  if [[ -z "${VARIABLES_ENV_FILE:-}" ]]; then
    for f in \
      "${root}/.ignore/variables.env" \
      "${root}/variables.env" \
      "${root}/configs/variables.env" \
      "/etc/bootstrap/variables.env"; do
      if [[ -f "$f" ]]; then
        VARIABLES_ENV_FILE="$f"
        break
      fi
    done
  fi
  export VARIABLES_ENV_FILE="${VARIABLES_ENV_FILE:-}"

  # ── secrets.env ──
  if [[ -z "${SECRETS_ENV_FILE:-}" ]]; then
    for f in \
      "${root}/.ignore/secrets.env" \
      "${root}/secrets.env" \
      "${root}/configs/secrets.env"; do
      if [[ -f "$f" ]]; then
        SECRETS_ENV_FILE="$f"
        break
      fi
    done
  fi
  export SECRETS_ENV_FILE="${SECRETS_ENV_FILE:-}"

  # ── secrets.age ──
  if [[ -z "${ENCRYPTED_SECRETS_AGE_FILE:-}" ]]; then
    for f in \
      "${root}/.ignore/secrets.age" \
      "${root}/secrets.age" \
      "${root}/.ignore/secrets/secrets.age" \
      "${root}/configs/secrets.age"; do
      if [[ -f "$f" ]]; then
        ENCRYPTED_SECRETS_AGE_FILE="$f"
        break
      fi
    done
  fi
  export ENCRYPTED_SECRETS_AGE_FILE="${ENCRYPTED_SECRETS_AGE_FILE:-}"

  # ── global.conf ──
  export GLOBAL_CONF_FILE="${GLOBAL_CONF_FILE:-${root}/configs/global.conf}"
}

# ── stdlib::config::load_chain ────────────────────────────────────────
# Load the full configuration chain in precedence order (last wins):
#   1. defaults.env (from repo)
#   2. BWS project "variables" (if available)
#   3. VARIABLES_ENV_FILE (discovered)
#   4. SECRETS_ENV_FILE (discovered, sensitive)
#   5. global.conf (user overrides — highest precedence)
#
# Uses stdlib::sanitize::load_file for no-eval, validated loading.
stdlib::config::load_chain() {
  local repo_dir="${1:-}"

  # Import sanitizer if available
  if declare -F stdlib::import &>/dev/null; then
    stdlib::import core/sanitize
  fi

  local loader="stdlib::sanitize::load_file"
  if ! declare -F "$loader" &>/dev/null; then
    loader="stdlib::config::_basic_load"
  fi

  # 1. Repo defaults
  if [[ -n "$repo_dir" && -f "${repo_dir}/defaults.env" ]]; then
    "$loader" "${repo_dir}/defaults.env" false
  fi

  # 2. BWS project "variables" (if available, writes to VARIABLES_ENV_FILE)
  stdlib::config::load_from_bws 2>/dev/null || true

  # 3. Discovered variables.env
  if [[ -n "${VARIABLES_ENV_FILE:-}" && -f "${VARIABLES_ENV_FILE}" ]]; then
    "$loader" "${VARIABLES_ENV_FILE}" true
  fi

  # 4. Discovered secrets.env
  if [[ -n "${SECRETS_ENV_FILE:-}" && -f "${SECRETS_ENV_FILE}" ]]; then
    "$loader" "${SECRETS_ENV_FILE}" true
  fi

  # 5. Global conf (highest precedence)
  if [[ -n "${GLOBAL_CONF_FILE:-}" && -f "${GLOBAL_CONF_FILE}" ]]; then
    "$loader" "${GLOBAL_CONF_FILE}" true
  fi
}

# ── stdlib::config::resolve_vars ──────────────────────────────────────
# Resolve all required bootstrap variables with automatic derivation.
# Usage: stdlib::config::resolve_vars [variables_file] [interactive]
stdlib::config::resolve_vars() {
  local vfile="${1:-}"
  local interactive="${2:-true}"

  # Load variables file if provided and exists
  if [[ -n "$vfile" && -f "$vfile" ]]; then
    if declare -F stdlib::sanitize::load_file &>/dev/null; then
      stdlib::sanitize::load_file "$vfile"
    else
      stdlib::config::_basic_load "$vfile"
    fi
  fi

  # ── NAMESPACE (required) ──
  if [[ -z "${NAMESPACE:-}" ]]; then
    if [[ "$interactive" == "true" ]]; then
      read -rp "  Namespace name (e.g., atn): " NAMESPACE </dev/tty 2>/dev/null || true
    fi
    [[ -z "${NAMESPACE:-}" ]] && {
      echo "FATAL: NAMESPACE is required" >&2
      return 1
    }
  fi
  # Normalize: lowercase, alphanumeric + underscore only
  NAMESPACE="${NAMESPACE,,}"
  export NAMESPACE

  # ── NAMESPACE_ROOT_DIR — INTERNAL, auto-derived, never user-settable ──
  NAMESPACE_ROOT_DIR="/${NAMESPACE}"
  export NAMESPACE_ROOT_DIR

  # ── GH_ORG — derived from NAMESPACE ──
  GH_ORG="${GH_ORG:-${NAMESPACE}plex}"
  export GH_ORG

  # ── SYSTEM_USERNAME — defaults to GH_ORG ──
  SYSTEM_USERNAME="${SYSTEM_USERNAME:-${GH_ORG}}"
  export SYSTEM_USERNAME

  # ── SYSTEM_GROUPNAME — defaults to SYSTEM_USERNAME ──
  SYSTEM_GROUPNAME="${SYSTEM_GROUPNAME:-${SYSTEM_USERNAME}}"
  export SYSTEM_GROUPNAME

  # ── SYSTEM_USER_UID — default 1234 ──
  if [[ -z "${SYSTEM_USER_UID:-}" ]]; then
    local current_uid
    current_uid="$(id -u "$SYSTEM_USERNAME" 2>/dev/null || true)"
    if [[ -n "$current_uid" && "$current_uid" -ne 0 ]]; then
      SYSTEM_USER_UID="$current_uid"
    else
      SYSTEM_USER_UID="1234"
    fi
  fi
  export SYSTEM_USER_UID

  # ── SYSTEM_GROUP_GID — defaults to SYSTEM_USER_UID ──
  SYSTEM_GROUP_GID="${SYSTEM_GROUP_GID:-${SYSTEM_USER_UID}}"
  export SYSTEM_GROUP_GID

  # ── Auto-derived (internal, not user-facing) ──
  DOCKER_NETWORK="${DOCKER_NETWORK:-${NAMESPACE}_bridge}"
  export DOCKER_NETWORK

  # ── Discover config/secret file paths ──
  stdlib::config::discover_files

  # Set defaults for file paths if not yet discovered
  VARIABLES_ENV_FILE="${VARIABLES_ENV_FILE:-${NAMESPACE_ROOT_DIR}/.ignore/variables.env}"
  export VARIABLES_ENV_FILE

  ENCRYPTED_SECRETS_AGE_FILE="${ENCRYPTED_SECRETS_AGE_FILE:-${NAMESPACE_ROOT_DIR}/.ignore/secrets/secrets.age}"
  export ENCRYPTED_SECRETS_AGE_FILE
}

# ── stdlib::config::seed_file ─────────────────────────────────────────
# Write current resolved values to the variables file for future runs.
# Idempotent: only writes if the file doesn't exist or is empty.
# Usage: stdlib::config::seed_file [target_path]
stdlib::config::seed_file() {
  local target="${1:-${VARIABLES_ENV_FILE:-}}"
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
GH_ORG=${GH_ORG:-}
SYSTEM_USERNAME=${SYSTEM_USERNAME:-}
SYSTEM_GROUPNAME=${SYSTEM_GROUPNAME:-}
SYSTEM_USER_UID=${SYSTEM_USER_UID:-}
SYSTEM_GROUP_GID=${SYSTEM_GROUP_GID:-}
DOCKER_NETWORK=${DOCKER_NETWORK:-}
SEED_EOF

  sudo chown "${SYSTEM_USERNAME:-root}:${SYSTEM_GROUPNAME:-root}" "$target" 2>/dev/null || true
  chmod 600 "$target" 2>/dev/null || true
}

# ── stdlib::config::ensure_global_conf ────────────────────────────────
# Create global.conf if missing — all settings commented out.
stdlib::config::ensure_global_conf() {
  local target="${GLOBAL_CONF_FILE:-${NAMESPACE_ROOT_DIR:-}/configs/global.conf}"
  [[ -f "$target" ]] && return 0

  local parent
  parent="$(dirname "$target")"
  [[ -d "$parent" ]] || sudo mkdir -p "$parent"

  cat >"$target" <<'CONF_EOF'
# Global Configuration — User Overrides
# Uncomment and modify any setting to override defaults.
# This file is loaded LAST and has the HIGHEST precedence.
#
# ── Namespace ──
# NAMESPACE=atn
#
# ── GitHub ──
# GH_ORG=atnplex
#
# ── System Identity ──
# SYSTEM_USERNAME=atnplex
# SYSTEM_GROUPNAME=atnplex
# SYSTEM_USER_UID=1234
# SYSTEM_GROUP_GID=1234
#
# ── Docker ──
# DOCKER_NETWORK=atn_bridge
#
# ── Runtime flags ──
# DRY_RUN=false
# SKIP_SERVICES=false
# INTERACTIVE=true
CONF_EOF

  sudo chown "${SYSTEM_USERNAME:-root}:${SYSTEM_GROUPNAME:-root}" "$target" 2>/dev/null || true
  chmod 644 "$target" 2>/dev/null || true
}

# ── stdlib::config::load_from_bws ─────────────────────────────────────
# Fetch all variables from BWS project "variables" and export them.
# Optionally writes them to the variables file for future offline runs.
# Requires: bws CLI + BWS_ACCESS_TOKEN
# Usage: stdlib::config::load_from_bws [target_file]
stdlib::config::load_from_bws() {
  local target="${1:-${VARIABLES_ENV_FILE:-}}"

  command -v bws &>/dev/null || return 1
  [[ -n "${BWS_ACCESS_TOKEN:-}" ]] || return 1
  command -v jq &>/dev/null || return 1

  # List all projects, find the one named "variables" (case-insensitive)
  local project_id
  project_id="$(bws project list 2>/dev/null |
    jq -r '.[] | select(.name | ascii_downcase == "variables") | .id' 2>/dev/null |
    head -1)" || return 1
  [[ -n "$project_id" ]] || return 1

  # Fetch all secrets in that project
  local secrets_json
  secrets_json="$(bws secret list --project-id "$project_id" 2>/dev/null)" || return 1

  # Parse and export
  local count=0 key val
  while IFS=$'\t' read -r key val; do
    [[ -z "$key" ]] && continue
    export "$key=$val"
    ((count++)) || true
  done < <(echo "$secrets_json" | jq -r '.[] | [.key, .value] | @tsv' 2>/dev/null)

  [[ $count -eq 0 ]] && return 1

  # Persist to variables file for offline future runs
  if [[ -n "$target" ]]; then
    local parent
    parent="$(dirname "$target")"
    [[ -d "$parent" ]] || sudo mkdir -p "$parent"

    {
      printf '# Bootstrap Variables — Fetched from BWS %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf '# Project: variables (%s)\n' "$project_id"
      echo "$secrets_json" | jq -r '.[] | "\(.key)=\(.value)"' 2>/dev/null
    } >"$target"

    sudo chown "${SYSTEM_USERNAME:-root}:${SYSTEM_GROUPNAME:-root}" "$target" 2>/dev/null || true
    chmod 600 "$target" 2>/dev/null || true
  fi

  return 0
}

# ── Internal: basic loader (fallback if sanitize not available) ───────
stdlib::config::_basic_load() {
  local filepath="$1"
  local override="${2:-false}"

  [[ -f "$filepath" ]] || return 1

  local key val
  while IFS='=' read -r key val; do
    key="${key%%#*}"
    key="$(echo "$key" | tr -d '[:space:]')"
    [[ -z "$key" ]] && continue

    val="${val#\"}"
    val="${val%\"}"
    val="${val#\'}"
    val="${val%\'}"

    if [[ "$override" == "true" ]] || [[ -z "${!key:-}" ]]; then
      export "$key=$val"
    fi
  done <"$filepath"
}
