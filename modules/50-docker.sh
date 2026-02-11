MODULE_ID="docker"
MODULE_DESC="Install Docker Engine and Docker Compose plugin"
MODULE_ORDER=50

module_supports_os() {
  case "$OS_ID" in
  ubuntu | debian) return 0 ;;
  *) return 1 ;;
  esac
}

module_requires_root() { return 0; }

module_run() {
  if command -v docker &>/dev/null; then
    log_info "Docker already installed: $(docker --version)"
  else
    log_info "Installing Docker via official install script..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log_info "Docker installed. You may need to re-login for group membership."
  fi

  sudo systemctl enable docker
  sudo systemctl start docker

  # Create default bridge network
  if docker network inspect atn_bridge &>/dev/null; then
    log_info "Docker network atn_bridge already exists"
  else
    docker network create atn_bridge
    log_info "Created Docker network: atn_bridge"
  fi
}
