# shellcheck disable=SC2034
MODULE_ID="tailscale"
MODULE_DESC="Install and configure Tailscale"
MODULE_ORDER=30

module_supports_os() {
  case "$OS_ID" in
  ubuntu | debian | fedora | centos | rhel) return 0 ;;
  *) return 1 ;;
  esac
}

module_is_installed() {
  command -v tailscale >/dev/null 2>&1
}

module_requires_root() { return 0; }

module_run() {
  log_info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh

  if ! command -v tailscale >/dev/null 2>&1; then
    log_error "Tailscale not found after install."
    return 1
  fi

  # Try tiered secret resolution for auth key
  if [[ -z "${TAILSCALE_AUTHKEY:-}" ]] && type get_secret &>/dev/null; then
    get_secret "TAILSCALE_AUTH_KEY" "tailscale" "authkey" "ts_auth" 2>/dev/null || true
    TAILSCALE_AUTHKEY="${TAILSCALE_AUTH_KEY:-}"
  fi

  if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
    log_warn "TAILSCALE_AUTHKEY not set; skipping automatic login."
    return 0
  fi

  sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --accept-routes --accept-dns --ssh --hostname="${MACHINE_HOSTNAME:-}" || true
}
