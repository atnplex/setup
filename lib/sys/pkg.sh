#!/usr/bin/env bash
# Module: sys/pkg
# Version: 0.3.0
# Provides: Cross-distro package management, GPG key + signed repo support
# Requires: none
[[ -n "${_STDLIB_PKG:-}" ]] && return 0
declare -g _STDLIB_PKG=1

declare -g _PKG_MGR=""

# ── stdlib::pkg::manager ──────────────────────────────────────
# Detect and cache the system package manager.
stdlib::pkg::manager() {
  if [[ -n "$_PKG_MGR" ]]; then
    echo "$_PKG_MGR"
    return 0
  fi

  if command -v apt-get &>/dev/null; then  _PKG_MGR="apt"
  elif command -v dnf &>/dev/null; then    _PKG_MGR="dnf"
  elif command -v yum &>/dev/null; then    _PKG_MGR="yum"
  elif command -v pacman &>/dev/null; then _PKG_MGR="pacman"
  elif command -v apk &>/dev/null; then    _PKG_MGR="apk"
  elif command -v zypper &>/dev/null; then _PKG_MGR="zypper"
  elif command -v brew &>/dev/null; then   _PKG_MGR="brew"
  else                                     _PKG_MGR="unknown"
  fi

  echo "$_PKG_MGR"
}

# ── stdlib::pkg::update ───────────────────────────────────────
# Update package index.
stdlib::pkg::update() {
  local mgr
  mgr="$(stdlib::pkg::manager)"

  case "$mgr" in
    apt)     sudo apt-get update -qq ;;
    dnf)     sudo dnf check-update -q || true ;;
    yum)     sudo yum check-update -q || true ;;
    pacman)  sudo pacman -Sy --noconfirm ;;
    apk)     sudo apk update ;;
    zypper)  sudo zypper refresh -q ;;
    brew)    brew update ;;
  esac
}

# ── stdlib::pkg::install ──────────────────────────────────────
# Install one or more packages.
stdlib::pkg::install() {
  local mgr
  mgr="$(stdlib::pkg::manager)"

  case "$mgr" in
    apt)     sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" ;;
    dnf)     sudo dnf install -y -q "$@" ;;
    yum)     sudo yum install -y -q "$@" ;;
    pacman)  sudo pacman -S --noconfirm --needed "$@" ;;
    apk)     sudo apk add --no-cache "$@" ;;
    zypper)  sudo zypper install -y "$@" ;;
    brew)    brew install "$@" ;;
    *)       echo "ERROR: Unknown package manager" >&2; return 1 ;;
  esac
}

# ── stdlib::pkg::is_installed ─────────────────────────────────
# Check if a package is installed.
stdlib::pkg::is_installed() {
  local pkg="$1"
  local mgr
  mgr="$(stdlib::pkg::manager)"

  case "$mgr" in
    apt)    dpkg -l "$pkg" 2>/dev/null | grep -q ^ii ;;
    dnf)    rpm -q "$pkg" &>/dev/null ;;
    yum)    rpm -q "$pkg" &>/dev/null ;;
    pacman) pacman -Q "$pkg" &>/dev/null ;;
    apk)    apk info -e "$pkg" &>/dev/null ;;
    zypper) rpm -q "$pkg" &>/dev/null ;;
    brew)   brew list "$pkg" &>/dev/null ;;
    *)      return 1 ;;
  esac
}

# ── stdlib::pkg::remove ──────────────────────────────────────
stdlib::pkg::remove() {
  local mgr
  mgr="$(stdlib::pkg::manager)"

  case "$mgr" in
    apt)     sudo apt-get remove -y -qq "$@" ;;
    dnf)     sudo dnf remove -y -q "$@" ;;
    yum)     sudo yum remove -y -q "$@" ;;
    pacman)  sudo pacman -R --noconfirm "$@" ;;
    apk)     sudo apk del "$@" ;;
    zypper)  sudo zypper remove -y "$@" ;;
    brew)    brew uninstall "$@" ;;
  esac
}

# ── stdlib::pkg::add_repo ────────────────────────────────────
# Add a package repository (distro-specific).
stdlib::pkg::add_repo() {
  local repo="$1"
  local mgr
  mgr="$(stdlib::pkg::manager)"

  case "$mgr" in
    apt)    sudo add-apt-repository -y "$repo" 2>/dev/null || echo "$repo" | sudo tee -a /etc/apt/sources.list.d/custom.list >/dev/null ;;
    dnf)    sudo dnf config-manager --add-repo "$repo" ;;
    yum)    sudo yum-config-manager --add-repo "$repo" ;;
    *)      echo "WARN: add_repo not implemented for $mgr" >&2 ;;
  esac
}

# ── stdlib::pkg::install_all ──────────────────────────────────
# Batch install with a single update + multiple installs.
stdlib::pkg::install_all() {
  stdlib::pkg::update
  stdlib::pkg::install "$@"
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.2.0)
# ══════════════════════════════════════════════════════════════

# ── stdlib::pkg::ensure ───────────────────────────────────────
# Check for a command; if missing and pkg_name given, auto-install.
# (Delegated from sys/deps for direct package-level usage)
stdlib::pkg::ensure() {
  local cmd="$1"
  local pkg="${2:-$cmd}"

  command -v "$cmd" &>/dev/null && return 0
  stdlib::pkg::install "$pkg"
  command -v "$cmd" &>/dev/null
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.3.0) — GPG key + signed repository support
# ══════════════════════════════════════════════════════════════

# ── stdlib::pkg::add_gpg_key ─────────────────────────────────
# Download a GPG key and install it to a keyring path.
# Used for the modern `signed-by` APT repository pattern.
# Usage: stdlib::pkg::add_gpg_key url keyring_path
stdlib::pkg::add_gpg_key() {
  local url="$1"
  local keyring="$2"

  [[ -z "$url" || -z "$keyring" ]] && { echo "ERROR: Usage: add_gpg_key url keyring_path" >&2; return 1; }

  # Skip if keyring already exists
  [[ -f "$keyring" ]] && return 0

  local keyring_dir
  keyring_dir="$(dirname "$keyring")"
  sudo mkdir -p "$keyring_dir"

  if [[ "$url" == *.asc ]]; then
    # ASCII-armored key — dearmor it
    curl -fsSL "$url" | sudo gpg --dearmor -o "$keyring" 2>/dev/null
  else
    # Binary GPG key — download directly
    curl -fsSL "$url" | sudo tee "$keyring" >/dev/null
  fi

  sudo chmod go+r "$keyring"
}

# ── stdlib::pkg::add_signed_repo ──────────────────────────────
# Add an APT repository with signed-by keyring (modern pattern).
# Usage: stdlib::pkg::add_signed_repo key_url keyring_path repo_line list_file
# Example:
#   stdlib::pkg::add_signed_repo \
#     "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
#     "/usr/share/keyrings/githubcli-archive-keyring.gpg" \
#     "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
#     "/etc/apt/sources.list.d/github-cli.list"
stdlib::pkg::add_signed_repo() {
  local key_url="$1"
  local keyring="$2"
  local repo_line="$3"
  local list_file="$4"

  # Install the GPG key
  stdlib::pkg::add_gpg_key "$key_url" "$keyring" || return 1

  # Add the repository if not already present
  if [[ ! -f "$list_file" ]] || ! grep -qF "$repo_line" "$list_file" 2>/dev/null; then
    echo "$repo_line" | sudo tee "$list_file" >/dev/null
  fi

  # Refresh package index
  sudo apt-get update -qq 2>/dev/null || true
}
