#!/usr/bin/env bash
# Module: 55-service-health
# Description: Informational health check — never fails bootstrap.
# Requires: stdlib (core/log)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log

: "${NAMESPACE_ROOT_DIR:?NAMESPACE_ROOT_DIR is required}"

stdlib::log::info "55-service-health: Running service health checks"

readonly HEALTH_LOG="${NAMESPACE_ROOT_DIR}/tmp/health.log"

# ── Ensure log directory exists ───────────────────────────────────────
health_dir="$(dirname "$HEALTH_LOG")"
if [[ ! -d "$health_dir" ]]; then
  mkdir -p "$health_dir" 2>/dev/null || sudo mkdir -p "$health_dir" 2>/dev/null || true
fi

# ── Health check helper ───────────────────────────────────────────────
_check_service() {
  local name="$1"
  local status="unknown"
  local detail=""

  if systemctl is-active --quiet "$name" 2>/dev/null; then
    status="active"
  elif systemctl is-enabled --quiet "$name" 2>/dev/null; then
    status="enabled-but-inactive"
  elif systemctl list-unit-files "${name}.service" 2>/dev/null | grep -q "$name"; then
    status="installed-but-disabled"
  else
    status="not-installed"
  fi

  detail="$(systemctl show "$name" --property=ActiveState,SubState --no-pager 2>/dev/null | tr '\n' ' ' || true)"

  printf '[%s] %-24s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" "$status" "$detail"
}

# ── Run checks ────────────────────────────────────────────────────────
{
  echo "# Service Health Report — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# ──────────────────────────────────────────────────────"

  # SSH daemon (try both names)
  if systemctl list-unit-files sshd.service 2>/dev/null | grep -q sshd; then
    _check_service sshd
  else
    _check_service ssh
  fi

  # Time sync (chrony or timesyncd)
  if systemctl list-unit-files chrony.service 2>/dev/null | grep -q chrony; then
    _check_service chrony
  elif systemctl list-unit-files chronyd.service 2>/dev/null | grep -q chronyd; then
    _check_service chronyd
  else
    _check_service systemd-timesyncd
  fi

  # Unattended upgrades
  _check_service unattended-upgrades

  # Fail2ban
  _check_service fail2ban

} | tee "$HEALTH_LOG" 2>/dev/null || true

stdlib::log::ok "55-service-health: Health report written to ${HEALTH_LOG}"
stdlib::log::ok "55-service-health: Complete"
