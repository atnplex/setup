#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# sys/service.sh — Service and systemd setup layer
# ═══════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_SERVICE:-}" ]] && return 0
readonly _STDLIB_MOD_SERVICE=1
_STDLIB_MOD_VERSION="1.0.0"

stdlib::import core/log
stdlib::import sys/probe

# ── Orchestrate all service setup ────────────────────────────────────
stdlib::service::setup() {
  stdlib::service::apt_update
  stdlib::service::ensure_cloudflared
  stdlib::service::ensure_tailscale
  stdlib::service::ensure_caddy
  stdlib::service::ensure_dns
}

# ── apt update + upgrade ─────────────────────────────────────────────
stdlib::service::apt_update() {
  stdlib::log::info "Updating system packages..."
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -yqq >/dev/null 2>&1
  stdlib::log::info "System packages updated"
}

# ── Cloudflared tunnel ───────────────────────────────────────────────
stdlib::service::ensure_cloudflared() {
  if ! stdlib::probe::check_command cloudflared; then
    stdlib::log::info "Installing cloudflared..."
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || echo 'amd64')"
    local deb_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb"
    local tmp_deb="${TMP_DIR:-/tmp}/cloudflared.deb"
    curl -fsSL "${deb_url}" -o "${tmp_deb}"
    dpkg -i "${tmp_deb}" >/dev/null 2>&1 || apt-get install -f -yqq >/dev/null 2>&1
    rm -f "${tmp_deb}"
  fi

  # Configure tunnel if token available
  local cf_token=""
  if command -v keyctl >/dev/null 2>&1; then
    cf_token="$(keyctl print "$(keyctl search @s user 'bootstrap:CF_TUNNEL_TOKEN' 2>/dev/null)" 2>/dev/null)" || true
  fi
  cf_token="${cf_token:-${CF_TUNNEL_TOKEN:-}}"

  if [[ -n "${cf_token}" ]]; then
    cloudflared service install "${cf_token}" 2>/dev/null || true
    systemctl enable --now cloudflared 2>/dev/null || true
    stdlib::log::info "cloudflared tunnel configured"
  else
    stdlib::log::warn "CF_TUNNEL_TOKEN not set — skipping tunnel setup"
  fi
}

# ── Tailscale ────────────────────────────────────────────────────────
stdlib::service::ensure_tailscale() {
  if ! stdlib::probe::check_command tailscale; then
    stdlib::log::warn "Tailscale not installed — install via probe::deps first"
    return 0
  fi

  systemctl enable --now tailscaled 2>/dev/null || true

  local ts_key=""
  if command -v keyctl >/dev/null 2>&1; then
    ts_key="$(keyctl print "$(keyctl search @s user 'bootstrap:TS_AUTH_KEY' 2>/dev/null)" 2>/dev/null)" || true
  fi
  ts_key="${ts_key:-${TS_AUTH_KEY:-}}"

  if [[ -n "${ts_key}" ]]; then
    tailscale up --authkey="${ts_key}" --ssh 2>/dev/null || true
    stdlib::log::info "Tailscale authenticated"
  else
    stdlib::log::info "Tailscale enabled (manual auth required)"
  fi
}

# ── Caddy ────────────────────────────────────────────────────────────
stdlib::service::ensure_caddy() {
  if ! stdlib::probe::check_command caddy; then
    stdlib::log::info "Installing Caddy..."
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || echo 'amd64')"
    curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=${arch}" \
      -o /usr/local/bin/caddy 2>/dev/null
    chmod +x /usr/local/bin/caddy
  fi

  systemctl enable caddy 2>/dev/null || true
  stdlib::log::info "Caddy configured"
}

# ── DNS resolver ─────────────────────────────────────────────────────
stdlib::service::ensure_dns() {
  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    if stdlib::probe::check_command tailscale; then
      local ts_dns
      ts_dns="$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' 2>/dev/null)" || true
      if [[ -n "${ts_dns}" ]]; then
        stdlib::log::info "DNS managed by Tailscale"
        return 0
      fi
    fi
  fi

  stdlib::log::info "DNS resolver verified"
}
