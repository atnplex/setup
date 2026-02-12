#!/usr/bin/env bash
# Module: 60-backup-restore-test
# Description: Dry-run backup restore test — skip gracefully if not configured.
# Requires: stdlib (core/log)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log

stdlib::log::info "60-backup-restore-test: Checking backup integration"

# ── Gate: only proceed if backup is configured ────────────────────────
backup_enabled="${BACKUP_RESTORE_ENABLED:-false}"
backup_tool="${BACKUP_TOOL:-}"

if [[ "$backup_enabled" != "true" ]] || [[ -z "$backup_tool" ]]; then
  stdlib::log::ok "60-backup-restore-test: No backup integration configured — skipping"
  exit 0
fi

stdlib::log::info "60-backup-restore-test: Backup tool: ${backup_tool}"

# ── Dry-run restore test ──────────────────────────────────────────────
case "$backup_tool" in
restic)
  if command -v restic &>/dev/null; then
    if restic snapshots --latest 1 2>/dev/null | head -5; then
      stdlib::log::ok "60-backup-restore-test: restic snapshots accessible"
    else
      stdlib::log::warn "60-backup-restore-test: restic snapshot listing failed"
    fi
  else
    stdlib::log::warn "60-backup-restore-test: restic not installed"
  fi
  ;;
borgbackup | borg)
  if command -v borg &>/dev/null; then
    if borg list --last 1 "${BACKUP_REPO:-}" 2>/dev/null; then
      stdlib::log::ok "60-backup-restore-test: borg archives accessible"
    else
      stdlib::log::warn "60-backup-restore-test: borg list failed"
    fi
  else
    stdlib::log::warn "60-backup-restore-test: borg not installed"
  fi
  ;;
*)
  stdlib::log::warn "60-backup-restore-test: Unknown backup tool: ${backup_tool}"
  ;;
esac

stdlib::log::ok "60-backup-restore-test: Complete"
