#!/usr/bin/env bash
# Module: 25-unattended-upgrades
# Description: Automatic security updates — install and configure unattended-upgrades.
# Requires: stdlib (core/log, sys/pkg)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log
stdlib::import sys/pkg

stdlib::log::info "25-unattended-upgrades: Configuring automatic security updates"

# ── Install packages ──────────────────────────────────────────────────
stdlib::pkg::ensure apt unattended-upgrades 2>/dev/null ||
  stdlib::pkg::install unattended-upgrades
stdlib::pkg::ensure apt apt-listchanges 2>/dev/null ||
  stdlib::pkg::install apt-listchanges 2>/dev/null || true

stdlib::log::ok "25-unattended-upgrades: Package installed"

# ── Configure: security updates only, no auto-reboot ──────────────────
readonly UU_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
readonly UU_AUTO="/etc/apt/apt.conf.d/20auto-upgrades"

# 50unattended-upgrades — security origins only
if [[ -f "$UU_CONF" ]]; then
  # Ensure security updates are enabled (they usually are by default)
  # Ensure automatic reboot is disabled
  if grep -q 'Unattended-Upgrade::Automatic-Reboot' "$UU_CONF"; then
    sudo sed -i 's|^.*Unattended-Upgrade::Automatic-Reboot .*|Unattended-Upgrade::Automatic-Reboot "false";|' "$UU_CONF"
  else
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee -a "$UU_CONF" >/dev/null
  fi
  # Ensure Remove-Unused-Kernel-Packages is enabled for safety
  if ! grep -q 'Unattended-Upgrade::Remove-Unused-Kernel-Packages' "$UU_CONF"; then
    echo 'Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";' | sudo tee -a "$UU_CONF" >/dev/null
  fi
else
  # Create minimal config
  sudo tee "$UU_CONF" >/dev/null <<'UUEOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
UUEOF
fi

stdlib::log::ok "25-unattended-upgrades: Security-only config applied, auto-reboot disabled"

# ── 20auto-upgrades — enable periodic updates ─────────────────────────
sudo tee "$UU_AUTO" >/dev/null <<'AUTOEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
AUTOEOF

stdlib::log::ok "25-unattended-upgrades: Periodic updates enabled"

# ── Ensure log directory exists ───────────────────────────────────────
sudo mkdir -p /var/log/unattended-upgrades
stdlib::log::ok "25-unattended-upgrades: Log directory ensured"

# ── Enable the service ────────────────────────────────────────────────
sudo systemctl enable unattended-upgrades 2>/dev/null || true
sudo systemctl start unattended-upgrades 2>/dev/null || true

stdlib::log::ok "25-unattended-upgrades: Complete"
