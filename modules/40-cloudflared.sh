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
  log_info "Installing cloudflared..."
  curl -fsSL https://developers.cloudflare.com/cloudflare-one/static/documentation/connections/CloudflareTunnel-linux-amd64.deb -o /tmp/cloudflared.deb || true
  if [[ -f /tmp/cloudflared.deb ]]; then
    sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
  else
    log_warn "Could not download .deb; consider using repo-based install."
  fi

  if [[ -z "${CLOUDFLARED_TOKEN:-}" ]]; then
    log_warn "CLOUDFLARED_TOKEN not set; skipping tunnel creation."
    return 0
  fi

  sudo cloudflared service install "$CLOUDFLARED_TOKEN"
  sudo systemctl enable cloudflared || true
  sudo systemctl start cloudflared || true
}
