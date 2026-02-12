#!/usr/bin/env bash
# Module: 30-fail2ban
# Description: Install fail2ban, enable sshd jail with sane defaults.
# Requires: stdlib (core/log, sys/pkg, sys/service)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log
stdlib::import sys/pkg
stdlib::import sys/service

: "${NAMESPACE_ROOT_DIR:?NAMESPACE_ROOT_DIR is required}"

stdlib::log::info "30-fail2ban: Ensuring fail2ban with sshd jail"

# ── Install fail2ban ──────────────────────────────────────────────────
if ! command -v fail2ban-client &>/dev/null; then
  stdlib::pkg::install fail2ban
  stdlib::log::ok "30-fail2ban: Installed"
else
  stdlib::log::ok "30-fail2ban: Already installed"
fi

# ── Create sshd jail configuration ────────────────────────────────────
readonly F2B_LOCAL="/etc/fail2ban/jail.local"

if [[ ! -f "$F2B_LOCAL" ]]; then
  sudo tee "$F2B_LOCAL" >/dev/null <<'F2BEOF'
# fail2ban local overrides — managed by bootstrap
# Manual overrides go in ${NAMESPACE_ROOT_DIR}/configs/fail2ban/jail.local

[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
F2BEOF
  stdlib::log::ok "30-fail2ban: jail.local created with sshd jail"
else
  stdlib::log::ok "30-fail2ban: jail.local already exists"
fi

# ── Ensure namespace override directory exists ────────────────────────
ns_f2b_dir="${NAMESPACE_ROOT_DIR}/configs/fail2ban"
if [[ ! -d "$ns_f2b_dir" ]]; then
  sudo mkdir -p "$ns_f2b_dir"
  sudo chown "${SYSTEM_USER_UID:-0}:${SYSTEM_GROUP_GID:-0}" "$ns_f2b_dir" 2>/dev/null || true
  stdlib::log::info "30-fail2ban: Created override dir: ${ns_f2b_dir}"
fi

# ── Enable and start fail2ban ─────────────────────────────────────────
sudo systemctl enable fail2ban 2>/dev/null || true
sudo systemctl restart fail2ban 2>/dev/null || true

stdlib::log::ok "30-fail2ban: Complete"
