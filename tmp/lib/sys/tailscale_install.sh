#!/usr/bin/env bash
# Module: sys/tailscale_install
# Version: 0.1.0
# Provides: Idempotent Tailscale installation
# Requires: sys/os (optional, for distro detection)
[[ -n "${_STDLIB_TAILSCALE_INSTALL:-}" ]] && return 0
declare -g _STDLIB_TAILSCALE_INSTALL=1

# ── stdlib::tailscale_install::is_installed ───────────────────────────
stdlib::tailscale_install::is_installed() {
  command -v tailscale &>/dev/null
}

# ── stdlib::tailscale_install::ensure ─────────────────────────────────
# Idempotent Tailscale installation using official installer.
stdlib::tailscale_install::ensure() {
  if stdlib::tailscale_install::is_installed; then
    # Ensure service is running
    if command -v systemctl &>/dev/null; then
      sudo systemctl enable --now tailscaled 2>/dev/null || true
    fi
    return 0
  fi

  # Use official installer script
  curl -fsSL https://tailscale.com/install.sh | sudo bash

  # Enable and start
  if command -v systemctl &>/dev/null; then
    sudo systemctl enable --now tailscaled 2>/dev/null || true
  fi
}

# ── stdlib::tailscale_install::is_connected ───────────────────────────
# Check if Tailscale is connected.
stdlib::tailscale_install::is_connected() {
  tailscale status &>/dev/null 2>&1
}
