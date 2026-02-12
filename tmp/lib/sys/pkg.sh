#!/usr/bin/env bash
# Module: sys/pkg
# Version: 0.1.0
# Provides: Cross-distro package management
# Requires: sys/os
[[ -n "${_STDLIB_PKG:-}" ]] && return 0
declare -g _STDLIB_PKG=1

# ── Internal State ─────────────────────────────────────────────────────
declare -g _PKG_MGR=""

# ── stdlib::pkg::manager ──────────────────────────────────────────────
# Detect the system package manager. Caches result.
# Returns: apt, dnf, yum, pacman, apk, zypper, brew
stdlib::pkg::manager() {
  if [[ -n "$_PKG_MGR" ]]; then
    printf '%s' "$_PKG_MGR"
    return 0
  fi

  local -a candidates=(apt-get dnf yum pacman apk zypper brew)
  for cmd in "${candidates[@]}"; do
    if command -v "$cmd" &>/dev/null; then
      _PKG_MGR="$cmd"
      # Normalize apt-get → apt for consistent naming
      [[ "$_PKG_MGR" == "apt-get" ]] && _PKG_MGR="apt"
      printf '%s' "$_PKG_MGR"
      return 0
    fi
  done

  echo "unknown"
  return 1
}

# ── stdlib::pkg::install ──────────────────────────────────────────────
# Install one or more packages. Cross-distro.
# Usage: stdlib::pkg::install curl git jq
stdlib::pkg::install() {
  local mgr
  mgr=$(stdlib::pkg::manager) || return 1
  local -a pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0

  case "$mgr" in
    apt)     sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}" ;;
    dnf)     sudo dnf install -y -q "${pkgs[@]}" ;;
    yum)     sudo yum install -y -q "${pkgs[@]}" ;;
    pacman)  sudo pacman -S --noconfirm --needed "${pkgs[@]}" ;;
    apk)     sudo apk add --no-cache "${pkgs[@]}" ;;
    zypper)  sudo zypper install -y "${pkgs[@]}" ;;
    brew)    brew install "${pkgs[@]}" ;;
    *)       echo "ERROR: Unknown package manager: $mgr" >&2; return 1 ;;
  esac
}

# ── stdlib::pkg::update ───────────────────────────────────────────────
# Update package index.
stdlib::pkg::update() {
  local mgr
  mgr=$(stdlib::pkg::manager) || return 1

  case "$mgr" in
    apt)     sudo apt-get update -qq ;;
    dnf|yum) sudo "$mgr" makecache -q ;;
    pacman)  sudo pacman -Sy ;;
    apk)     sudo apk update ;;
    zypper)  sudo zypper refresh ;;
    brew)    brew update ;;
  esac
}

# ── stdlib::pkg::installed ────────────────────────────────────────────
# Check if a package is installed. Returns 0 if yes.
stdlib::pkg::installed() {
  local pkg="$1"
  local mgr
  mgr=$(stdlib::pkg::manager) || return 1

  case "$mgr" in
    apt)     dpkg -s "$pkg" &>/dev/null ;;
    dnf|yum) rpm -q "$pkg" &>/dev/null ;;
    pacman)  pacman -Qi "$pkg" &>/dev/null ;;
    apk)     apk info -e "$pkg" &>/dev/null ;;
    zypper)  rpm -q "$pkg" &>/dev/null ;;
    brew)    brew list "$pkg" &>/dev/null ;;
    *)       return 1 ;;
  esac
}

# ── stdlib::pkg::remove ───────────────────────────────────────────────
# Remove one or more packages.
stdlib::pkg::remove() {
  local mgr
  mgr=$(stdlib::pkg::manager) || return 1
  local -a pkgs=("$@")

  case "$mgr" in
    apt)     sudo apt-get remove -y -qq "${pkgs[@]}" ;;
    dnf)     sudo dnf remove -y -q "${pkgs[@]}" ;;
    yum)     sudo yum remove -y -q "${pkgs[@]}" ;;
    pacman)  sudo pacman -Rns --noconfirm "${pkgs[@]}" ;;
    apk)     sudo apk del "${pkgs[@]}" ;;
    zypper)  sudo zypper remove -y "${pkgs[@]}" ;;
    brew)    brew uninstall "${pkgs[@]}" ;;
    *)       return 1 ;;
  esac
}

# ── stdlib::pkg::add_repo ─────────────────────────────────────────────
# Add a package repository. Primarily apt/dnf.
# Usage: stdlib::pkg::add_repo URL [GPG_KEY_URL]
stdlib::pkg::add_repo() {
  local url="$1"
  local key_url="${2:-}"
  local mgr
  mgr=$(stdlib::pkg::manager) || return 1

  case "$mgr" in
    apt)
      if [[ -n "$key_url" ]]; then
        curl -fsSL "$key_url" | sudo gpg --dearmor -o "/usr/share/keyrings/$(basename "$key_url" .asc).gpg" 2>/dev/null
      fi
      echo "$url" | sudo tee /etc/apt/sources.list.d/"$(echo "$url" | md5sum | cut -c1-8)".list >/dev/null
      sudo apt-get update -qq
      ;;
    dnf|yum)
      sudo "$mgr" config-manager --add-repo "$url" 2>/dev/null || \
        echo -e "[custom-repo]\nbaseurl=$url\nenabled=1\ngpgcheck=0" | sudo tee /etc/yum.repos.d/custom.repo >/dev/null
      ;;
    *)
      echo "WARN: add_repo not implemented for $mgr" >&2
      return 1
      ;;
  esac
}

# ── stdlib::pkg::install_batch ────────────────────────────────────────
# Batch install: update index first, then install all at once.
stdlib::pkg::install_batch() {
  stdlib::pkg::update
  stdlib::pkg::install "$@"
}
