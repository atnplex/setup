#!/usr/bin/env bash

OS_ID=""
OS_VERSION_ID=""
PKG_MANAGER=""

log_info()  { printf '[INFO] %s\n' "$*" >&2; }
log_warn()  { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION_ID="$VERSION_ID"
  else
    OS_ID="unknown"
    OS_VERSION_ID="unknown"
  fi

  case "$OS_ID" in
    ubuntu|debian) PKG_MANAGER="apt" ;;
    fedora|centos|rhel) PKG_MANAGER="dnf" ;;
    arch) PKG_MANAGER="pacman" ;;
    *) PKG_MANAGER="unknown" ;;
  esac

  log_info "Detected OS: $OS_ID $OS_VERSION_ID (pkg: $PKG_MANAGER)"
}

ensure_pkg() {
  local pkg="$1"
  case "$PKG_MANAGER" in
    apt)   sudo apt-get update -y && sudo apt-get install -y "$pkg" ;;
    dnf)   sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -Sy --noconfirm "$pkg" ;;
    *) log_warn "Unknown package manager; please install $pkg manually." ;;
  esac
}

MODE="interactive"
CONFIG_FILE=""
MODULE_FLAGS=()

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --non-interactive|-y) MODE="noninteractive" ;;
      --config) CONFIG_FILE="$2"; shift ;;
      --module) MODULE_FLAGS+=("$2"); shift ;;
      --help|-h)
        echo "Usage: $0 [--non-interactive] [--config FILE] [--module ID ...]"
        exit 0
        ;;
      *) log_warn "Unknown argument: $1" ;;
    esac
    shift
  done
}

load_config_if_any() {
  if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    log_info "Loading config from $CONFIG_FILE"
    # simplest: source env-style config
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
  fi
}
