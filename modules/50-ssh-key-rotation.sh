#!/usr/bin/env bash
# Module: 50-ssh-key-rotation
# Description: Optional SSH host key rotation — only if explicitly enabled.
# Requires: stdlib (core/log)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log

: "${NAMESPACE_ROOT_DIR:?NAMESPACE_ROOT_DIR is required}"

stdlib::log::info "50-ssh-key-rotation: Checking SSH key rotation config"

# ── Gate: only proceed if explicitly enabled ──────────────────────────
ssh_rotation="${SSH_KEY_ROTATION_ENABLED:-false}"
if [[ "$ssh_rotation" != "true" ]]; then
  stdlib::log::ok "50-ssh-key-rotation: Disabled (set SSH_KEY_ROTATION_ENABLED=true to enable)"
  exit 0
fi

stdlib::log::info "50-ssh-key-rotation: SSH key rotation enabled — proceeding"

readonly BACKUP_DIR="${NAMESPACE_ROOT_DIR}/.ignore/state/ssh-backups"
readonly SSH_DIR="/etc/ssh"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
readonly TIMESTAMP

# ── Ensure backup directory exists ────────────────────────────────────
sudo mkdir -p "$BACKUP_DIR"
sudo chmod 700 "$BACKUP_DIR"

# ── Backup current host keys ─────────────────────────────────────────
backup_subdir="${BACKUP_DIR}/${TIMESTAMP}"
sudo mkdir -p "$backup_subdir"

key_count=0
for keyfile in "${SSH_DIR}"/ssh_host_*; do
  [[ -f "$keyfile" ]] || continue
  sudo cp -p "$keyfile" "$backup_subdir/"
  ((key_count++)) || true
done

if [[ "$key_count" -eq 0 ]]; then
  stdlib::log::warn "50-ssh-key-rotation: No host keys found to backup"
  exit 0
fi

stdlib::log::ok "50-ssh-key-rotation: Backed up ${key_count} key files to ${backup_subdir}"

# ── Regenerate host keys ──────────────────────────────────────────────
sudo rm -f "${SSH_DIR}"/ssh_host_*
sudo ssh-keygen -A 2>/dev/null
stdlib::log::ok "50-ssh-key-rotation: New host keys generated"

# ── Validate and restart sshd ─────────────────────────────────────────
if sudo sshd -t 2>/dev/null; then
  sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh 2>/dev/null || true
  stdlib::log::ok "50-ssh-key-rotation: sshd restarted with new keys"
else
  # Restore backup on validation failure
  stdlib::log::error "50-ssh-key-rotation: sshd config validation FAILED — restoring backup"
  sudo cp -p "${backup_subdir}"/ssh_host_* "${SSH_DIR}/"
  sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh 2>/dev/null || true
  stdlib::log::warn "50-ssh-key-rotation: Backup restored, sshd restarted"
fi

stdlib::log::ok "50-ssh-key-rotation: Complete"
