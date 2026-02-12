#!/usr/bin/env bash
# Module: 35-sysctl-baseline
# Description: Minimal, stability-focused sysctl baseline.
# Requires: stdlib (core/log)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log

stdlib::log::info "35-sysctl-baseline: Applying stability-focused sysctl baseline"

readonly SYSCTL_CONF="/etc/sysctl.d/99-atn.conf"

# ── Desired baseline ──────────────────────────────────────────────────
read -r -d '' SYSCTL_CONTENT <<'SYSCTL_EOF' || true
# Stability-focused sysctl baseline — managed by bootstrap
# Do NOT edit manually; changes will be overwritten.

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1

# Reverse path filtering (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Restrict kernel pointer exposure
kernel.kptr_restrict = 1

# Restrict dmesg access to root
kernel.dmesg_restrict = 1
SYSCTL_EOF

# ── Write config (idempotent — compare before writing) ────────────────
if [[ -f "$SYSCTL_CONF" ]]; then
  existing="$(cat "$SYSCTL_CONF")"
  if [[ "$existing" == "$SYSCTL_CONTENT" ]]; then
    stdlib::log::ok "35-sysctl-baseline: Config already up to date"
  else
    echo "$SYSCTL_CONTENT" | sudo tee "$SYSCTL_CONF" >/dev/null
    stdlib::log::info "35-sysctl-baseline: Config updated"
  fi
else
  echo "$SYSCTL_CONTENT" | sudo tee "$SYSCTL_CONF" >/dev/null
  stdlib::log::info "35-sysctl-baseline: Config created"
fi

# ── Reload sysctl ─────────────────────────────────────────────────────
sudo sysctl --system >/dev/null 2>&1 || sudo sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
stdlib::log::ok "35-sysctl-baseline: sysctl reloaded"

stdlib::log::ok "35-sysctl-baseline: Complete"
