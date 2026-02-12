#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# data/config.sh — Configuration loading chain (no eval)
# ═══════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_DATA_CONFIG:-}" ]] && return 0
readonly _STDLIB_MOD_DATA_CONFIG=1
_STDLIB_MOD_VERSION="1.0.0"

stdlib::import core/log

# ── Load the full config chain ───────────────────────────────────────
# Order: defaults.env -> variables.env -> global.conf
# Later sources override earlier ones.
stdlib::config::load_chain() {
  # 1. defaults.env (shipped with repo)
  local defaults_file="${REPO_DIR:-.}/defaults.env"
  if [[ -f "${defaults_file}" ]]; then
    stdlib::config::safe_parse "${defaults_file}"
    stdlib::log::info "Loaded: ${defaults_file}"
  fi

  # Derive NAMESPACE_ROOT immediately (other paths depend on it)
  NAMESPACE="${NAMESPACE:-atn}"
  NAMESPACE_ROOT="/${NAMESPACE}"
  export NAMESPACE NAMESPACE_ROOT

  # 2. variables.env (from BWS or operator)
  local vars_candidate
  for vars_candidate in \
    "${NAMESPACE_ROOT}/.ignore/variables.env" \
    "${NAMESPACE_ROOT}/configs/variables.env" \
    "${REPO_DIR:-.}/variables.env"; do
    if [[ -f "${vars_candidate}" ]]; then
      stdlib::config::safe_parse "${vars_candidate}"
      stdlib::log::info "Loaded: ${vars_candidate}"
      break
    fi
  done

  # 3. global.conf (user overrides — highest priority)
  local global_conf="${NAMESPACE_ROOT}/configs/global.conf"
  if [[ -f "${global_conf}" ]]; then
    stdlib::config::safe_parse "${global_conf}"
    stdlib::log::info "Loaded: ${global_conf}"
  fi
}

# ── Safe KEY=VALUE parser (no eval) ──────────────────────────────────
stdlib::config::safe_parse() {
  local file="${1:?file path required}"
  [[ -f "${file}" ]] || return 1

  local line key value
  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Strip inline comments
    line="${line%%\#*}"
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "${line}" ]] && continue

    # Split on first =
    key="${line%%=*}"
    value="${line#*=}"

    # Trim key
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    # Trim value + strip surrounding quotes
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value#\"}"; value="${value%\"}"
    value="${value#\'}"; value="${value%\'}"

    # Validate key is a safe identifier
    if [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "${key}=${value}"
    fi
  done < "${file}"
}

# ── Derive identity variables from config ────────────────────────────
stdlib::config::derive_identity() {
  local namespace="${NAMESPACE:?NAMESPACE not set}"

  BOOTSTRAP_USER="${BOOTSTRAP_USER:-${namespace}plex}"
  BOOTSTRAP_GROUP="${BOOTSTRAP_GROUP:-${namespace}}"
  BOOTSTRAP_UID="${BOOTSTRAP_UID:-1114}"
  BOOTSTRAP_GID="${BOOTSTRAP_GID:-${BOOTSTRAP_UID}}"
  export BOOTSTRAP_USER BOOTSTRAP_GROUP BOOTSTRAP_UID BOOTSTRAP_GID

  stdlib::log::info "Identity: ${BOOTSTRAP_USER}:${BOOTSTRAP_GROUP} (${BOOTSTRAP_UID}:${BOOTSTRAP_GID})"
}
