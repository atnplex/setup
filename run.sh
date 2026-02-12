#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# run.sh — Modular bootstrap runner
#
# Loads variables, exports TMPDIR early, then executes modules/*.sh
# in numeric sort order.
#
# Usage: sudo bash run.sh [--dry-run]
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Bash 4+ required ─────────────────────────────────────────────────
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "FATAL: Bash 4+ required (found ${BASH_VERSION})" >&2
  exit 1
fi

# ── Load defaults ─────────────────────────────────────────────────────
if [[ -f "${SCRIPT_DIR}/defaults.env" ]]; then
  # shellcheck source=defaults.env
  source "${SCRIPT_DIR}/defaults.env"
fi

# ── Discover and load variables.env ───────────────────────────────────
NAMESPACE="${NAMESPACE:-atn}"
NAMESPACE_ROOT_DIR="/${NAMESPACE}"
export NAMESPACE NAMESPACE_ROOT_DIR

# Derive identity variables with safe defaults
export SYSTEM_USERNAME="${SYSTEM_USERNAME:-${NAMESPACE}plex}"
export SYSTEM_GROUPNAME="${SYSTEM_GROUPNAME:-${SYSTEM_USERNAME}}"
export SYSTEM_USER_UID="${SYSTEM_USER_UID:-1234}"
export SYSTEM_GROUP_GID="${SYSTEM_GROUP_GID:-${SYSTEM_USER_UID}}"

# Try loading variables.env from standard locations
for _vars_candidate in \
  "${NAMESPACE_ROOT_DIR}/.ignore/variables.env" \
  "${NAMESPACE_ROOT_DIR}/configs/variables.env" \
  "${SCRIPT_DIR}/variables.env"; do
  if [[ -f "$_vars_candidate" ]]; then
    echo "📄 Loading variables from ${_vars_candidate}"
    # Safe line-by-line load (no eval)
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

# ── Early TMPDIR export ──────────────────────────────────────────────
# Prefer our tmpfs workspace if available
if [ -d "$NAMESPACE_ROOT_DIR/tmp" ]; then
    export TMPDIR="$NAMESPACE_ROOT_DIR/tmp"
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
echo "║  TMPDIR:     ${TMPDIR:-/tmp}"
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
