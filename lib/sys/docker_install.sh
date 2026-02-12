#!/usr/bin/env bash
# Module: sys/docker_install
# Version: 0.1.0
# Provides: Idempotent Docker CE installation
# Requires: sys/os (for distro/codename), sys/pkg (for GPG key helpers)
[[ -n "${_STDLIB_DOCKER_INSTALL:-}" ]] && return 0
declare -g _STDLIB_DOCKER_INSTALL=1

# ── stdlib::docker_install::is_installed ──────────────────────────────
stdlib::docker_install::is_installed() {
  command -v docker &>/dev/null
}

# ── stdlib::docker_install::ensure ────────────────────────────────────
# Idempotent Docker CE installation using official apt repo.
# Usage: stdlib::docker_install::ensure [user_to_add_to_docker_group]
stdlib::docker_install::ensure() {
  local user="${1:-}"

  if stdlib::docker_install::is_installed; then
    # Ensure service is running
    if command -v systemctl &>/dev/null; then
      sudo systemctl enable --now docker 2>/dev/null || true
    fi
    # Add user to docker group if specified
    [[ -n "$user" ]] && stdlib::docker_install::_add_user "$user"
    return 0
  fi

  # Detect OS for apt-based installation
  local distro codename arch
  if declare -F stdlib::os::distro &>/dev/null; then
    distro="$(stdlib::os::distro)"
    codename="$(stdlib::os::codename)"
  elif [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    distro="$(. /etc/os-release && echo "${ID:-unknown}")"
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-stable}")"
  else
    echo "ERROR: Cannot detect OS for Docker installation" >&2
    return 1
  fi

  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"

  # Install prerequisites
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl gnupg >/dev/null 2>&1

  # Add Docker GPG key
  local keyring="/usr/share/keyrings/docker-archive-keyring.gpg"
  if [[ ! -f "$keyring" ]]; then
    sudo install -m 0755 -d /etc/apt/keyrings 2>/dev/null || true
    curl -fsSL "https://download.docker.com/linux/${distro}/gpg" |
      sudo gpg --dearmor -o "$keyring" 2>/dev/null
    sudo chmod a+r "$keyring"
  fi

  # Add Docker apt repository
  local repo_file="/etc/apt/sources.list.d/docker.list"
  if [[ ! -f "$repo_file" ]]; then
    echo "deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/${distro} ${codename} stable" |
      sudo tee "$repo_file" >/dev/null
  fi

  # Install Docker CE
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

  # Enable and start
  if command -v systemctl &>/dev/null; then
    sudo systemctl enable --now docker
  fi

  # Add user to docker group
  [[ -n "$user" ]] && stdlib::docker_install::_add_user "$user"
}

# ── stdlib::docker_install::ensure_network ────────────────────────────
# Create a Docker network if it doesn't exist.
# Usage: stdlib::docker_install::ensure_network network_name
stdlib::docker_install::ensure_network() {
  local name="$1"
  if ! docker network inspect "$name" &>/dev/null; then
    docker network create "$name" 2>/dev/null || true
  fi
}

# ── Internal ──────────────────────────────────────────────────────────
stdlib::docker_install::_add_user() {
  local user="$1"
  if ! id -nG "$user" 2>/dev/null | grep -qw docker; then
    sudo usermod -aG docker "$user" 2>/dev/null || true
  fi
}
