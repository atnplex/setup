#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# run.sh — Modular bootstrap runner
# Purpose: Load configuration, derive variables, execute modules in order
#
# Config load chain:
#   1. defaults.env        — generic defaults (no identity values)
#   2. variables.env       — from BWS / operator overrides
#   3. secrets.env         — from BWS
#   4. global.conf         — user overrides (highest priority)
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Load defaults.env (generic, no identity values) ───────────────
if [[ -f "${SCRIPT_DIR}/defaults.env" ]]; then
  # shellcheck source=defaults.env
  source "${SCRIPT_DIR}/defaults.env"
fi

# Derive namespace root immediately (other paths depend on it)
NAMESPACE="${NAMESPACE:-atn}"
NAMESPACE_ROOT_DIR="/${NAMESPACE}"
export NAMESPACE NAMESPACE_ROOT_DIR

# ── 2. Load variables.env (from BWS or operator) ────────────────────
for _vars_candidate in \
  "${NAMESPACE_ROOT_DIR}/.ignore/variables.env" \
  "${NAMESPACE_ROOT_DIR}/configs/variables.env" \
  "${SCRIPT_DIR}/variables.env"; do
  if [[ -f "$_vars_candidate" ]]; then
    echo "📄 Loading variables from ${_vars_candidate}"
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      key="$(echo "$key" | xargs)"
      value="$(echo "$value" | xargs | sed "s/^[\"']//;s/[\"']$//")"
      export "$key=$value"
    done < "$_vars_candidate"
    break
  fi
done
unset _vars_candidate

# ── 3. Load secrets.env (from BWS) ──────────────────────────────────
for _secrets_candidate in \
  "${NAMESPACE_ROOT_DIR}/.ignore/secrets.env" \
  "${NAMESPACE_ROOT_DIR}/configs/secrets.env"; do
  if [[ -f "$_secrets_candidate" ]]; then
    echo "🔐 Loading secrets from ${_secrets_candidate}"
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      key="$(echo "$key" | xargs)"
      value="$(echo "$value" | xargs | sed "s/^[\"']//;s/[\"']$//")"
      export "$key=$value"
    done < "$_secrets_candidate"
    break
  fi
done
unset _secrets_candidate

# ── 4. Load global.conf (user overrides — highest priority) ─────────
if [[ -f "${NAMESPACE_ROOT_DIR}/configs/global.conf" ]]; then
  echo "📋 Loading overrides from ${NAMESPACE_ROOT_DIR}/configs/global.conf"
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs | sed "s/^[\"']//;s/[\"']$//")"
    export "$key=$value"
  done < "${NAMESPACE_ROOT_DIR}/configs/global.conf"
fi

# ── 5. Derive identity AFTER all config sources loaded ──────────────
# SYSTEM_USERNAME comes from variables.env/BWS; fall back to NAMESPACE+plex
export SYSTEM_USERNAME="${SYSTEM_USERNAME:-${NAMESPACE}plex}"
# SYSTEM_GROUPNAME derived from NAMESPACE, not from USERNAME
export SYSTEM_GROUPNAME="${SYSTEM_GROUPNAME:-${NAMESPACE}}"
# UID comes from variables.env/BWS; must be set there
export SYSTEM_USER_UID="${SYSTEM_USER_UID:-1114}"
# GID always tracks UID
export SYSTEM_GROUP_GID="${SYSTEM_GROUP_GID:-${SYSTEM_USER_UID}}"

# ── 6. Early TMPDIR export (derived, never hardcoded) ───────────────
TMPDIR="${NAMESPACE_ROOT_DIR}/tmp"
export TMPDIR
if [[ -d "$TMPDIR" ]]; then
  echo "⚡ Using RAM Disk at $TMPDIR"
fi

# ── Banner ────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          Modular Bootstrap Runner                            ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  NAMESPACE:  ${NAMESPACE}"
echo "║  ROOT:       ${NAMESPACE_ROOT_DIR}"
echo "║  USER:       ${SYSTEM_USERNAME} (${SYSTEM_USER_UID}:${SYSTEM_GROUP_GID})"
echo "║  GROUP:      ${SYSTEM_GROUPNAME}"
echo "║  TMPDIR:     ${TMPDIR}"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ── Execute modules in numeric order ─────────────────────────────────
MODULES_DIR="${SCRIPT_DIR}/modules"

if [[ ! -d "$MODULES_DIR" ]]; then
  echo "FATAL: modules/ directory not found at ${MODULES_DIR}" >&2
  exit 1
fi

module_count=0
for module in $(find "$MODULES_DIR" -maxdepth 1 -name '*.sh' -type f | sort -V); do
  module_name="$(basename "$module")"
  echo "━━━ Running: ${module_name} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  # shellcheck source=/dev/null
  source "$module"
  echo "━━━ Done:    ${module_name} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  ((module_count++)) || true
done

echo "✅ All ${module_count} modules executed successfully."
