#!/usr/bin/env bash
# Module: sys/service
# Version: 0.1.0
# Provides: Systemd service management helpers
# Requires: none
[[ -n "${_STDLIB_SERVICE:-}" ]] && return 0
declare -g _STDLIB_SERVICE=1

# ── stdlib::service::exists ───────────────────────────────────────────
# Check if a systemd unit file exists.
stdlib::service::exists() {
  systemctl list-unit-files "$1.service" &>/dev/null
}

# ── stdlib::service::status ───────────────────────────────────────────
# Check if a service is active. Returns 0 if yes.
stdlib::service::status() {
  systemctl is-active --quiet "$1" 2>/dev/null
}

# ── stdlib::service::enable ───────────────────────────────────────────
stdlib::service::enable() {
  sudo systemctl enable "$1" 2>/dev/null
}

# ── stdlib::service::start ────────────────────────────────────────────
stdlib::service::start() {
  sudo systemctl start "$1"
}

# ── stdlib::service::stop ─────────────────────────────────────────────
stdlib::service::stop() {
  sudo systemctl stop "$1"
}

# ── stdlib::service::restart ──────────────────────────────────────────
stdlib::service::restart() {
  sudo systemctl restart "$1"
}

# ── stdlib::service::reload_daemon ────────────────────────────────────
# Reload systemd daemon (after unit file changes).
stdlib::service::reload_daemon() {
  sudo systemctl daemon-reload
}

# ── stdlib::service::create_unit ──────────────────────────────────────
# Write a systemd unit file and reload.
# Usage: stdlib::service::create_unit name type body
#   type: service, timer, mount, etc.
#   body: the full [Unit]/[Service]/[Install] content
stdlib::service::create_unit() {
  local name="$1"
  local type="${2:-service}"
  local body="$3"
  local unit_path="/etc/systemd/system/${name}.${type}"

  echo "$body" | sudo tee "$unit_path" >/dev/null
  sudo chmod 644 "$unit_path"
  stdlib::service::reload_daemon
}

# ── stdlib::service::create_simple ────────────────────────────────────
# Create a simple service unit with common defaults.
# Usage: stdlib::service::create_simple name description exec_start [user] [workdir]
stdlib::service::create_simple() {
  local name="$1"
  local desc="$2"
  local exec="$3"
  local user="${4:-root}"
  local workdir="${5:-}"

  local body="[Unit]
Description=${desc}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${user}
ExecStart=${exec}
Restart=on-failure
RestartSec=5"

  [[ -n "$workdir" ]] && body+="
WorkingDirectory=${workdir}"

  body+="

[Install]
WantedBy=multi-user.target"

  stdlib::service::create_unit "$name" "service" "$body"
}
