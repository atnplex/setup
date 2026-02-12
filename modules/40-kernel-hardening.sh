#!/usr/bin/env bash
# Module: 40-kernel-hardening
# Description: Kernel hardening — ptrace scope, core dumps, unprivileged BPF.
# Requires: stdlib (core/log)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log

stdlib::log::info "40-kernel-hardening: Applying kernel hardening"

readonly KERNEL_CONF="/etc/sysctl.d/99-atn-kernel.conf"

# ── Desired kernel hardening params ───────────────────────────────────
read -r -d '' KERNEL_CONTENT <<'KEOF' || true
# Kernel hardening — managed by bootstrap
# Do NOT edit manually; changes will be overwritten.

# Restrict ptrace to parent processes only
kernel.yama.ptrace_scope = 1

# Disable unprivileged BPF
kernel.unprivileged_bpf_disabled = 1

# Disable core dumps via sysctl
fs.suid_dumpable = 0
KEOF

# ── Write config (idempotent) ─────────────────────────────────────────
if [[ -f "$KERNEL_CONF" ]]; then
  existing="$(cat "$KERNEL_CONF")"
  if [[ "$existing" == "$KERNEL_CONTENT" ]]; then
    stdlib::log::ok "40-kernel-hardening: Config already up to date"
  else
    echo "$KERNEL_CONTENT" | sudo tee "$KERNEL_CONF" >/dev/null
    stdlib::log::info "40-kernel-hardening: Config updated"
  fi
else
  echo "$KERNEL_CONTENT" | sudo tee "$KERNEL_CONF" >/dev/null
  stdlib::log::info "40-kernel-hardening: Config created"
fi

# ── Disable core dumps via limits.conf ────────────────────────────────
readonly LIMITS_CONF="/etc/security/limits.d/99-atn-nocore.conf"
limits_content="# Disable core dumps — managed by bootstrap
*    hard    core    0
*    soft    core    0"

if [[ -f "$LIMITS_CONF" ]]; then
  existing_limits="$(cat "$LIMITS_CONF")"
  if [[ "$existing_limits" != "$limits_content" ]]; then
    echo "$limits_content" | sudo tee "$LIMITS_CONF" >/dev/null
    stdlib::log::info "40-kernel-hardening: Core dump limits updated"
  fi
else
  echo "$limits_content" | sudo tee "$LIMITS_CONF" >/dev/null
  stdlib::log::info "40-kernel-hardening: Core dump limits created"
fi

# ── Reload sysctl ─────────────────────────────────────────────────────
sudo sysctl --system >/dev/null 2>&1 || sudo sysctl -p "$KERNEL_CONF" 2>/dev/null || true
stdlib::log::ok "40-kernel-hardening: sysctl reloaded"

stdlib::log::ok "40-kernel-hardening: Complete"
