#!/usr/bin/env bash
# Module: 28-timesync
# Description: Time synchronization — ensure chrony or systemd-timesyncd,
#              set timezone, verify NTP sync.
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

stdlib::log::info "28-timesync: Ensuring time synchronization"

readonly TARGET_TZ="America/Los_Angeles"

# ── Set timezone ──────────────────────────────────────────────────────
current_tz="$(timedatectl show --property=Timezone --value 2>/dev/null || true)"
if [[ "$current_tz" != "$TARGET_TZ" ]]; then
  sudo timedatectl set-timezone "$TARGET_TZ"
  stdlib::log::ok "28-timesync: Timezone set to ${TARGET_TZ}"
else
  stdlib::log::ok "28-timesync: Timezone already ${TARGET_TZ}"
fi

# ── Install and enable time sync service ──────────────────────────────
if command -v chronyd &>/dev/null || stdlib::pkg::is_installed chrony 2>/dev/null; then
  # Chrony available — prefer it
  stdlib::log::ok "28-timesync: chrony already installed"
  sudo systemctl enable chrony 2>/dev/null || true
  sudo systemctl start chrony 2>/dev/null || true
elif command -v chronyc &>/dev/null; then
  stdlib::log::ok "28-timesync: chrony already installed"
  sudo systemctl enable chrony 2>/dev/null || true
  sudo systemctl start chrony 2>/dev/null || true
else
  # Try installing chrony first
  if stdlib::pkg::install chrony 2>/dev/null; then
    stdlib::log::ok "28-timesync: chrony installed"
    sudo systemctl enable chrony 2>/dev/null || true
    sudo systemctl start chrony 2>/dev/null || true
  else
    # Fall back to systemd-timesyncd
    stdlib::log::info "28-timesync: chrony unavailable, using systemd-timesyncd"
    sudo systemctl enable systemd-timesyncd 2>/dev/null || true
    sudo systemctl start systemd-timesyncd 2>/dev/null || true
  fi
fi

# ── Enable NTP sync ───────────────────────────────────────────────────
sudo timedatectl set-ntp true 2>/dev/null || true
stdlib::log::ok "28-timesync: NTP sync enabled"

# ── Verify sync status (informational) ────────────────────────────────
if command -v chronyc &>/dev/null; then
  sync_status="$(chronyc tracking 2>/dev/null | head -3 || true)"
  stdlib::log::info "28-timesync: chrony tracking: ${sync_status}"
else
  sync_status="$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || true)"
  stdlib::log::info "28-timesync: NTP synchronized: ${sync_status}"
fi

stdlib::log::ok "28-timesync: Complete"
