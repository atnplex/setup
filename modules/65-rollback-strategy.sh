#!/usr/bin/env bash
# Module: 65-rollback-strategy
# Description: Rollback marker tracking system — log module success/failure.
#              Does NOT attempt automatic rollback; tracking only.
# Requires: stdlib (core/log)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log

: "${NAMESPACE_ROOT_DIR:?NAMESPACE_ROOT_DIR is required}"

stdlib::log::info "65-rollback-strategy: Reviewing module execution markers"

readonly ROLLBACK_DIR="${NAMESPACE_ROOT_DIR}/tmp/rollback"

# ── Ensure rollback directory exists ──────────────────────────────────
if [[ ! -d "$ROLLBACK_DIR" ]]; then
  mkdir -p "$ROLLBACK_DIR" 2>/dev/null || sudo mkdir -p "$ROLLBACK_DIR" 2>/dev/null || true
fi

# ── Scan for incomplete markers ───────────────────────────────────────
started=0
completed=0
failed_modules=()

shopt -s nullglob
for marker in "${ROLLBACK_DIR}"/*.started; do
  ((started++)) || true

  mod_name="$(basename "$marker" .started)"
  complete_marker="${ROLLBACK_DIR}/${mod_name}.complete"

  if [[ -f "$complete_marker" ]]; then
    ((completed++)) || true
  else
    failed_modules+=("$mod_name")
  fi
done

# ── Report results ────────────────────────────────────────────────────
if [[ "$started" -eq 0 ]]; then
  stdlib::log::ok "65-rollback-strategy: No previous execution markers found"
else
  stdlib::log::info "65-rollback-strategy: ${started} modules started, ${completed} completed"

  if [[ ${#failed_modules[@]} -gt 0 ]]; then
    for failed in "${failed_modules[@]}"; do
      stdlib::log::warn "65-rollback-strategy: Module did not complete: ${failed}"
    done
    stdlib::log::warn "65-rollback-strategy: ${#failed_modules[@]} module(s) may have failed in last run"
  else
    stdlib::log::ok "65-rollback-strategy: All previously started modules completed successfully"
  fi
fi

# ── Clean old markers for this run (fresh start) ──────────────────────
# Only clean if this is a complete fresh run (run.sh sets ROLLBACK_FRESH=true)
if [[ "${ROLLBACK_FRESH:-false}" == "true" ]]; then
  rm -f "${ROLLBACK_DIR}"/*.started "${ROLLBACK_DIR}"/*.complete 2>/dev/null || true
  stdlib::log::info "65-rollback-strategy: Cleared old markers for fresh run"
fi

stdlib::log::ok "65-rollback-strategy: Complete"
