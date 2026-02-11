MODULE_ID="github_cli"
MODULE_DESC="Install GitHub CLI and authenticate"
MODULE_ORDER=60

module_supports_os() {
  case "$OS_ID" in
  ubuntu | debian) return 0 ;;
  *) return 1 ;;
  esac
}

module_requires_root() { return 0; }

module_run() {
  if command -v gh &>/dev/null; then
    log_info "GitHub CLI already installed: $(gh --version | head -1)"
  else
    log_info "Installing GitHub CLI..."
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
      sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=${arch} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
      sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
    log_info "GitHub CLI installed"
  fi

  # Authenticate if token is available
  if gh auth status &>/dev/null; then
    log_info "GitHub CLI already authenticated"
  elif [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    echo "$GITHUB_PERSONAL_ACCESS_TOKEN" | gh auth login --with-token
    log_info "GitHub CLI authenticated via env token"
  else
    log_warn "GitHub CLI not authenticated. Run 'gh auth login' manually."
  fi
}
