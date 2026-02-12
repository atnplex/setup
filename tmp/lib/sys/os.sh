#!/usr/bin/env bash
# Module: sys/os
# Version: 0.2.0
# Provides: OS/arch/distro detection, environment classification
# Requires: none
[[ -n "${_STDLIB_OS:-}" ]] && return 0
declare -g _STDLIB_OS=1

# ── Internal Cache ─────────────────────────────────────────────
declare -g _OS_NAME=""
declare -g _OS_ARCH=""
declare -g _OS_DISTRO=""
declare -g _OS_VERSION=""
declare -g _OS_PKG_MGR=""
declare -g _OS_MACHINE_TYPE=""

# ── stdlib::os::name ──────────────────────────────────────────
# Returns: linux, darwin, freebsd, etc.
stdlib::os::name() {
  [[ -n "$_OS_NAME" ]] && { printf '%s' "$_OS_NAME"; return 0; }
  _OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
  printf '%s' "$_OS_NAME"
}

# ── stdlib::os::arch ──────────────────────────────────────────
# Normalised architecture: amd64, arm64, armv7, i386
stdlib::os::arch() {
  [[ -n "$_OS_ARCH" ]] && { printf '%s' "$_OS_ARCH"; return 0; }
  local raw
  raw=$(uname -m)
  case "$raw" in
    x86_64|amd64)   _OS_ARCH="amd64" ;;
    aarch64|arm64)   _OS_ARCH="arm64" ;;
    armv7l|armhf)    _OS_ARCH="armv7" ;;
    i686|i386)       _OS_ARCH="i386"  ;;
    *)               _OS_ARCH="$raw"  ;;
  esac
  printf '%s' "$_OS_ARCH"
}

# ── stdlib::os::distro ────────────────────────────────────────
stdlib::os::distro() {
  [[ -n "$_OS_DISTRO" ]] && { printf '%s' "$_OS_DISTRO"; return 0; }
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    _OS_DISTRO=$(. /etc/os-release && echo "${ID:-unknown}")
  elif command -v sw_vers &>/dev/null; then
    _OS_DISTRO="macos"
  else
    _OS_DISTRO="unknown"
  fi
  printf '%s' "$_OS_DISTRO"
}

# ── stdlib::os::version ───────────────────────────────────────
stdlib::os::version() {
  [[ -n "$_OS_VERSION" ]] && { printf '%s' "$_OS_VERSION"; return 0; }
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    _OS_VERSION=$(. /etc/os-release && echo "${VERSION_ID:-unknown}")
  elif command -v sw_vers &>/dev/null; then
    _OS_VERSION=$(sw_vers -productVersion)
  else
    _OS_VERSION="unknown"
  fi
  printf '%s' "$_OS_VERSION"
}

# ── stdlib::os::is_container ──────────────────────────────────
stdlib::os::is_container() {
  [[ -f /.dockerenv ]] && return 0
  grep -qsE '(docker|lxc|containerd)' /proc/1/cgroup 2>/dev/null && return 0
  [[ -n "${container:-}" ]] && return 0
  return 1
}

# ── stdlib::os::capabilities ──────────────────────────────────
# Emit JSON of detected capabilities.
stdlib::os::capabilities() {
  cat <<-EOF
{
  "os": "$(stdlib::os::name)",
  "arch": "$(stdlib::os::arch)",
  "distro": "$(stdlib::os::distro)",
  "version": "$(stdlib::os::version)",
  "container": $(stdlib::os::is_container && echo true || echo false),
  "pkg_manager": "$(stdlib::os::pkg_manager)",
  "machine_type": "$(stdlib::os::machine_type)",
  "hostname": "$(stdlib::os::hostname)",
  "memory_kb": $(stdlib::os::memory_kb),
  "cpu_count": $(stdlib::os::cpu_count)
}
EOF
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.2.0)
# ══════════════════════════════════════════════════════════════

# ── stdlib::os::pkg_manager ───────────────────────────────────
# Detect the system package manager (cached).
# Returns: apt, dnf, yum, pacman, apk, zypper, brew
stdlib::os::pkg_manager() {
  [[ -n "$_OS_PKG_MGR" ]] && { printf '%s' "$_OS_PKG_MGR"; return 0; }

  local -a candidates=(apt-get dnf yum pacman apk zypper brew)
  for cmd in "${candidates[@]}"; do
    if command -v "$cmd" &>/dev/null; then
      _OS_PKG_MGR="$cmd"
      [[ "$_OS_PKG_MGR" == "apt-get" ]] && _OS_PKG_MGR="apt"
      printf '%s' "$_OS_PKG_MGR"
      return 0
    fi
  done

  _OS_PKG_MGR="unknown"
  printf '%s' "$_OS_PKG_MGR"
}

# ── stdlib::os::machine_type ──────────────────────────────────
# Detect physical/virtual/cloud environment.
# Returns: cloud, vm, container, wsl, bare
stdlib::os::machine_type() {
  [[ -n "$_OS_MACHINE_TYPE" ]] && { printf '%s' "$_OS_MACHINE_TYPE"; return 0; }

  # Container check first
  if stdlib::os::is_container; then
    _OS_MACHINE_TYPE="container"
    printf '%s' "$_OS_MACHINE_TYPE"
    return 0
  fi

  # WSL check
  if [[ -f /proc/version ]] && grep -qi 'microsoft\|wsl' /proc/version 2>/dev/null; then
    _OS_MACHINE_TYPE="wsl"
    printf '%s' "$_OS_MACHINE_TYPE"
    return 0
  fi

  # VM/Cloud detection via DMI (requires root or readable DMI)
  local vendor=""
  if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]')
  fi

  case "$vendor" in
    *oracle*)          _OS_MACHINE_TYPE="cloud" ;;
    *amazon*|*ec2*)    _OS_MACHINE_TYPE="cloud" ;;
    *google*)          _OS_MACHINE_TYPE="cloud" ;;
    *microsoft*)       _OS_MACHINE_TYPE="cloud" ;;
    *hetzner*)         _OS_MACHINE_TYPE="cloud" ;;
    *digitalocean*)    _OS_MACHINE_TYPE="cloud" ;;
    *vmware*)          _OS_MACHINE_TYPE="vm"    ;;
    *qemu*|*kvm*|*bochs*) _OS_MACHINE_TYPE="vm" ;;
    *virtualbox*)      _OS_MACHINE_TYPE="vm"    ;;
    *xen*)             _OS_MACHINE_TYPE="vm"    ;;
    *)
      if command -v systemd-detect-virt &>/dev/null; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null || echo "none")
        if [[ "$virt" == "none" ]]; then
          _OS_MACHINE_TYPE="bare"
        else
          _OS_MACHINE_TYPE="vm"
        fi
      else
        _OS_MACHINE_TYPE="bare"
      fi
      ;;
  esac

  printf '%s' "$_OS_MACHINE_TYPE"
}

# ── stdlib::os::vendor ────────────────────────────────────────
# Returns the hardware/cloud vendor name.
stdlib::os::vendor() {
  local vendor=""
  if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    cat /sys/class/dmi/id/sys_vendor 2>/dev/null
  elif [[ -r /sys/class/dmi/id/board_vendor ]]; then
    cat /sys/class/dmi/id/board_vendor 2>/dev/null
  else
    echo "unknown"
  fi
}

# ── stdlib::os::hostname ──────────────────────────────────────
# Current hostname (normalized, lowercase).
stdlib::os::hostname() {
  hostname 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

# ── stdlib::os::memory_kb ─────────────────────────────────────
# Total RAM in KB.
stdlib::os::memory_kb() {
  if [[ -f /proc/meminfo ]]; then
    awk '/^MemTotal:/ {print $2}' /proc/meminfo
  elif command -v sysctl &>/dev/null; then
    sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024)}'
  else
    echo 0
  fi
}

# ── stdlib::os::cpu_count ─────────────────────────────────────
# Number of CPUs/cores.
stdlib::os::cpu_count() {
  nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1
}

# ── stdlib::os::is_wsl ────────────────────────────────────────
# Returns 0 if running under WSL.
stdlib::os::is_wsl() {
  [[ -f /proc/version ]] && grep -qi 'microsoft\|wsl' /proc/version 2>/dev/null
}
