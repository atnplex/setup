MODULE_ID="ssh"
MODULE_DESC="Configure SSH server and client defaults"
MODULE_ORDER=10

module_supports_os() { return 0; }
module_requires_root() { return 0; }

module_run() {
  log_info "Ensuring OpenSSH is installed..."
  ensure_pkg openssh-client
  if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    ensure_pkg openssh-server
    sudo systemctl enable ssh || true
    sudo systemctl start ssh || true
  fi

  log_info "Configuring ~/.ssh directory..."
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # You can add hardened sshd_config changes here, or leave as TODO.
}
