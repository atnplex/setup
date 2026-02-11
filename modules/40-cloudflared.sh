MODULE_ID="cloudflared"
MODULE_DESC="Install and configure Cloudflare Tunnel (cloudflared)"
MODULE_ORDER=40

module_supports_os() {
  case "$OS_ID" in
    ubuntu|debian) return 0 ;;
    *) return 1 ;;
  esac
}

module_requires_root() { return 0; }

module_run() {
  # ── Idempotent install ──────────────────────────────────────────────
  if command -v cloudflared &>/dev/null; then
    local current_version
    current_version="$(cloudflared --version 2>/dev/null | awk '{print $3}')"
    log_info "cloudflared already installed: $current_version"

    # Check if an update is available
    local latest_deb="/tmp/cloudflared.deb"
    if curl -fsSL -o "$latest_deb" \
      "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$(dpkg --print-architecture 2>/dev/null || echo amd64).deb" 2>/dev/null; then
      local latest_version
      latest_version="$(dpkg-deb -f "$latest_deb" Version 2>/dev/null || echo '')"
      if [[ -n "$latest_version" && "$latest_version" != "$current_version" ]]; then
        log_info "Updating cloudflared: $current_version → $latest_version"
        sudo dpkg -i "$latest_deb" 2>/dev/null || sudo apt-get install -f -y
      else
        log_info "cloudflared is up to date"
      fi
      rm -f "$latest_deb"
    fi
  else
    log_info "Installing cloudflared..."
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    local deb_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb"

    if curl -fsSL -o /tmp/cloudflared.deb "$deb_url"; then
      sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
      rm -f /tmp/cloudflared.deb
      log_info "cloudflared installed: $(cloudflared --version 2>/dev/null | awk '{print $3}')"
    else
      log_error "Failed to download cloudflared"
      return 1
    fi
  fi

  # ── Idempotent tunnel configuration ─────────────────────────────────
  if [[ -z "${CLOUDFLARED_TOKEN:-}" ]]; then
    # Check if already configured as a service
    if systemctl is-active cloudflared &>/dev/null; then
      log_info "cloudflared service already running"
    elif systemctl is-enabled cloudflared &>/dev/null; then
      log_info "cloudflared service enabled but stopped — starting..."
      sudo systemctl start cloudflared || log_warn "Failed to start cloudflared"
    else
      log_warn "CLOUDFLARED_TOKEN not set and no existing service. Skipping tunnel setup."
      log_info "To configure later: sudo cloudflared service install <TOKEN>"
    fi
    return 0
  fi

  # Token provided — install service if not already running
  if systemctl is-active cloudflared &>/dev/null; then
    log_info "cloudflared tunnel already running"
  else
    log_info "Installing cloudflared tunnel service..."
    sudo cloudflared service install "$CLOUDFLARED_TOKEN"
    sudo systemctl enable cloudflared || true
    sudo systemctl start cloudflared || true
    log_info "cloudflared tunnel service started"
  fi
}
