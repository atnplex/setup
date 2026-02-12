#!/usr/bin/env bash
# Module: sys/os
# Version: 0.3.0
# Provides: OS detection, machine info, RAM helpers, environment capabilities
# Requires: none
[[ -n "${_STDLIB_OS:-}" ]] && return 0
declare -g _STDLIB_OS=1

# ── stdlib::os::distro ────────────────────────────────────────
# Detect the Linux distribution ID (e.g., ubuntu, debian, fedora).
stdlib::os::distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    (. /etc/os-release && echo "${ID:-unknown}")
  else
    echo "unknown"
  fi
}

# ── stdlib::os::version ───────────────────────────────────────
# Distribution version string.
stdlib::os::version() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    (. /etc/os-release && echo "${VERSION_ID:-unknown}")
  else
    echo "unknown"
  fi
}

# ── stdlib::os::codename ──────────────────────────────────────
# Distribution codename (e.g., jammy, bookworm).
stdlib::os::codename() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    (. /etc/os-release && echo "${VERSION_CODENAME:-unknown}")
  else
    echo "unknown"
  fi
}

# ── stdlib::os::arch ──────────────────────────────────────────
# System architecture (x86_64, aarch64, armv7l, ...).
stdlib::os::arch() {
  uname -m
}

# ── stdlib::os::kernel ────────────────────────────────────────
# Kernel version string.
stdlib::os::kernel() {
  uname -r
}

# ── stdlib::os::is ────────────────────────────────────────────
# Check if running on a specific distro.
# Usage: stdlib::os::is ubuntu && ...
stdlib::os::is() {
  [[ "$(stdlib::os::distro)" == "$1" ]]
}

# ══════════════════════════════════════════════════════════════
# v0.2.0 — Machine detection, environment profiling
# ══════════════════════════════════════════════════════════════

# ── stdlib::os::machine_type ──────────────────────────────────
# Detect machine type: cloud, vm, container, wsl, bare.
stdlib::os::machine_type() {
  # Container detection (highest priority)
  if [[ -f /.dockerenv ]] || grep -q "docker\|lxc\|kubepods" /proc/1/cgroup 2>/dev/null; then
    echo "container"; return
  fi

  # WSL detection
  if grep -qi "microsoft\|WSL" /proc/version 2>/dev/null; then
    echo "wsl"; return
  fi

  local vendor=""
  if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
  fi

  case "${vendor,,}" in
    *oraclecloud*|*oracle*|*amazon*|*xen*|*aws*|*google*|*digitalocean*|*hetzner*|*linode*|*akamai*)
      echo "cloud"; return ;;
    *vmware*|*innotek*|*virtualbox*|*parallels*|*qemu*|*kvm*|*bochs*)
      echo "vm"; return ;;
    *microsoft*)
      if grep -qi "azure" /sys/class/dmi/id/product_name 2>/dev/null; then
        echo "cloud"
      else
        echo "vm"
      fi
      return ;;
  esac

  if [[ -d /proc/xen ]] || grep -qi "hypervisor" /proc/cpuinfo 2>/dev/null; then
    echo "vm"; return
  fi

  echo "bare"
}

# ── stdlib::os::vendor ────────────────────────────────────────
# System vendor string from DMI data.
stdlib::os::vendor() {
  if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

# ── stdlib::os::hostname ──────────────────────────────────────
# Normalized hostname (lowercase, alphanumeric + hyphen).
stdlib::os::hostname() {
  local raw
  raw="$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")"
  echo "${raw,,}" | tr -cd 'a-z0-9-'
}

# ── stdlib::os::memory_kb ────────────────────────────────────
# Total physical memory in KB.
stdlib::os::memory_kb() {
  awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0"
}

# ── stdlib::os::cpu_count ─────────────────────────────────────
# Number of CPU cores.
stdlib::os::cpu_count() {
  nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1"
}

# ── stdlib::os::is_wsl ────────────────────────────────────────
# Check if running inside WSL.
stdlib::os::is_wsl() {
  grep -qi "microsoft\|WSL" /proc/version 2>/dev/null
}

# ── stdlib::os::capabilities ──────────────────────────────────
# JSON summary of system capabilities.
stdlib::os::capabilities() {
  local distro arch kernel mem_kb cpus machine_type vendor
  distro="$(stdlib::os::distro)"
  arch="$(stdlib::os::arch)"
  kernel="$(stdlib::os::kernel)"
  mem_kb="$(stdlib::os::memory_kb)"
  cpus="$(stdlib::os::cpu_count)"
  machine_type="$(stdlib::os::machine_type)"
  vendor="$(stdlib::os::vendor)"

  cat <<EOF
{
  "distro": "$distro",
  "version": "$(stdlib::os::version)",
  "arch": "$arch",
  "kernel": "$kernel",
  "memory_kb": $mem_kb,
  "cpu_count": $cpus,
  "machine_type": "$machine_type",
  "vendor": "$vendor",
  "is_wsl": $(stdlib::os::is_wsl && echo "true" || echo "false"),
  "has_systemd": $(command -v systemctl &>/dev/null && echo "true" || echo "false"),
  "has_docker": $(command -v docker &>/dev/null && echo "true" || echo "false")
}
EOF
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.3.0) — RAM helpers for tmpfs sizing
# ══════════════════════════════════════════════════════════════

# ── stdlib::os::ram_available_kb ──────────────────────────────
# Available (free + cached) RAM in KB.
stdlib::os::ram_available_kb() {
  local avail
  avail="$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null)"
  if [[ -n "$avail" && "$avail" -gt 0 ]]; then
    echo "$avail"
  else
    # Fallback: free + buffers + cached
    awk '/MemFree/ {free=$2} /Buffers/ {buf=$2} /^Cached:/ {cache=$2} END {print free+buf+cache}' /proc/meminfo 2>/dev/null || echo "0"
  fi
}

# ── stdlib::os::ram_fraction_mb ───────────────────────────────
# Calculate a fraction of total RAM in MB.
# Usage: stdlib::os::ram_fraction_mb fraction [cap_mb]
# Example: stdlib::os::ram_fraction_mb 0.5        → half of total RAM in MB
#          stdlib::os::ram_fraction_mb 0.5 1024    → half of total RAM, capped at 1024 MB
stdlib::os::ram_fraction_mb() {
  local fraction="$1"
  local cap="${2:-0}"
  local total_kb
  total_kb="$(stdlib::os::memory_kb)"

  local result_mb
  result_mb=$(awk "BEGIN {printf \"%d\", ($total_kb * $fraction) / 1024}")

  if [[ "$cap" -gt 0 ]] && [[ "$result_mb" -gt "$cap" ]]; then
    result_mb="$cap"
  fi

  echo "$result_mb"
}
