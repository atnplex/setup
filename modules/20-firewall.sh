#!/usr/bin/env bash
# Module: 20-firewall
# Description: Local firewall baseline — install ufw but keep DISABLED.
#              OCI firewall is the primary; this is a safety net only.
# Requires: stdlib (core/log, sys/pkg)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log
stdlib::import sys/pkg

stdlib::log::info "20-firewall: Ensuring local firewall baseline"

# ── Install ufw if not present ────────────────────────────────────────
if ! command -v ufw &>/dev/null; then
  stdlib::pkg::install ufw
  stdlib::log::ok "20-firewall: ufw installed"
else
  stdlib::log::ok "20-firewall: ufw already installed"
fi

# ── Ensure ufw is DISABLED (OCI firewall is primary) ─────────────────
if sudo ufw status 2>/dev/null | grep -qi "active"; then
  sudo ufw disable 2>/dev/null || true
  stdlib::log::info "20-firewall: ufw disabled (OCI firewall is primary)"
else
  stdlib::log::ok "20-firewall: ufw already inactive"
fi

# ── Reset rules to ensure no conflicts with OCI ──────────────────────
# Only reset if there are user-added rules beyond defaults
rule_count="$(sudo ufw status numbered 2>/dev/null | grep -c '^\[' || true)"
if [[ "${rule_count:-0}" -gt 0 ]]; then
  stdlib::log::warn "20-firewall: ${rule_count} local rules found — leaving in place (review manually)"
fi

# ── Ensure logging is enabled but rate-limited ────────────────────────
sudo ufw logging low 2>/dev/null || true
stdlib::log::ok "20-firewall: Logging set to low (rate-limited)"

# ── Disable IPv6 firewall unless explicitly enabled ───────────────────
ipv6_enabled="${IPV6_FIREWALL_ENABLED:-false}"
ufw_default="/etc/default/ufw"
if [[ -f "$ufw_default" ]]; then
  if [[ "$ipv6_enabled" == "true" ]]; then
    sudo sed -i 's/^IPV6=.*/IPV6=yes/' "$ufw_default" 2>/dev/null || true
    stdlib::log::info "20-firewall: IPv6 firewall enabled"
  else
    sudo sed -i 's/^IPV6=.*/IPV6=no/' "$ufw_default" 2>/dev/null || true
    stdlib::log::ok "20-firewall: IPv6 firewall disabled"
  fi
fi

stdlib::log::ok "20-firewall: Complete"
