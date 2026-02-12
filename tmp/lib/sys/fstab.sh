#!/usr/bin/env bash
# Module: sys/fstab
# Version: 0.1.0
# Provides: Mount and fstab management helpers
# Requires: none
[[ -n "${_STDLIB_FSTAB:-}" ]] && return 0
declare -g _STDLIB_FSTAB=1

declare -g _FSTAB="/etc/fstab"

# ── stdlib::fstab::entry_exists ───────────────────────────────────────
# Check if an fstab entry exists for a given mountpoint.
stdlib::fstab::entry_exists() {
  local mountpoint="$1"
  grep -qsE "\s${mountpoint}\s" "$_FSTAB"
}

# ── stdlib::fstab::is_mounted ─────────────────────────────────────────
# Check if a path is currently mounted.
stdlib::fstab::is_mounted() {
  local mountpoint="$1"
  mount | grep -qs " on ${mountpoint} "
}

# ── stdlib::fstab::add_entry ──────────────────────────────────────────
# Add an fstab entry (idempotent — skips if exists).
# Usage: stdlib::fstab::add_entry spec mountpoint fstype options [dump] [pass]
stdlib::fstab::add_entry() {
  local spec="$1"
  local mountpoint="$2"
  local fstype="$3"
  local options="$4"
  local dump="${5:-0}"
  local pass="${6:-0}"

  if stdlib::fstab::entry_exists "$mountpoint"; then
    return 0  # Already present
  fi

  # Ensure mountpoint directory exists
  sudo mkdir -p "$mountpoint"

  # Append to fstab
  echo "${spec}  ${mountpoint}  ${fstype}  ${options}  ${dump}  ${pass}" | \
    sudo tee -a "$_FSTAB" >/dev/null
}

# ── stdlib::fstab::tmpfs ──────────────────────────────────────────────
# Create a tmpfs mount entry + mount it immediately.
# Usage: stdlib::fstab::tmpfs mountpoint size_mb [mode] [uid] [gid]
stdlib::fstab::tmpfs() {
  local mountpoint="$1"
  local size_mb="$2"
  local mode="${3:-1777}"
  local uid="${4:-}"
  local gid="${5:-}"

  local opts="defaults,noatime,nosuid,nodev,noexec,mode=${mode},size=${size_mb}m"
  [[ -n "$uid" ]] && opts+=",uid=${uid}"
  [[ -n "$gid" ]] && opts+=",gid=${gid}"

  stdlib::fstab::add_entry "tmpfs" "$mountpoint" "tmpfs" "$opts"

  if ! stdlib::fstab::is_mounted "$mountpoint"; then
    sudo mount "$mountpoint"
  fi
}

# ── stdlib::fstab::mount_all ──────────────────────────────────────────
# Mount all fstab entries.
stdlib::fstab::mount_all() {
  sudo mount -a
}
