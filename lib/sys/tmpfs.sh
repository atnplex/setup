#!/usr/bin/env bash
# Module: sys/tmpfs
# Version: 0.2.0
# Provides: Tmpfs detection, workspace selection, TMP_DIR contract,
#           percentage/unit-aware size parsing
# Requires: none
[[ -n "${_STDLIB_TMPFS:-}" ]] && return 0
declare -g _STDLIB_TMPFS=1
declare -g _STDLIB_MOD_VERSION="0.2.0"

# ── Internal State ─────────────────────────────────────────────────────
declare -g TMP_DIR="" # Exported after create_workspace

# ── stdlib::tmpfs::_parse_size ────────────────────────────────────────
# Parse a size specification into megabytes.
#
# Supported formats:
#   "50%"   → 50% of total RAM (from /proc/meminfo MemTotal)
#   "100M"  → 100 megabytes
#   "2G"    → 2048 megabytes
#   "auto"  → returns empty string (caller omits size= from mount opts)
#   "1024"  → 1024 megabytes (raw numeric, backward compatible)
#
# Usage: stdlib::tmpfs::_parse_size <spec>
# Prints: size in MB, or empty string for "auto"
stdlib::tmpfs::_parse_size() {
  local spec="${1:?size spec required}"

  # "auto" — let the kernel decide
  if [[ "$spec" == "auto" ]]; then
    echo ""
    return 0
  fi

  # Percentage of RAM — e.g. "50%"
  if [[ "$spec" =~ ^([0-9]+)%$ ]]; then
    local pct="${BASH_REMATCH[1]}"
    local total_kb
    total_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 2097152)"
    local total_mb=$((total_kb / 1024))
    echo $(( total_mb * pct / 100 ))
    return 0
  fi

  # Gigabytes — e.g. "2G" or "2g"
  if [[ "$spec" =~ ^([0-9]+)[gG]$ ]]; then
    echo $(( BASH_REMATCH[1] * 1024 ))
    return 0
  fi

  # Megabytes — e.g. "100M" or "100m"
  if [[ "$spec" =~ ^([0-9]+)[mM]$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  # Raw numeric — backward compatible (treated as MB)
  if [[ "$spec" =~ ^[0-9]+$ ]]; then
    echo "$spec"
    return 0
  fi

  printf 'stdlib::tmpfs::_parse_size: invalid size spec: %s\n' "$spec" >&2
  return 1
}

# ── stdlib::tmpfs::detect_candidates ──────────────────────────────────
# Inspect /proc/mounts for tmpfs mount points.
# Returns newline-separated list of tmpfs mountpoints.
stdlib::tmpfs::detect_candidates() {
  awk '$3 == "tmpfs" {print $2}' /proc/mounts 2>/dev/null | sort -u
}

# ── stdlib::tmpfs::select_best ────────────────────────────────────────
# Choose the best tmpfs mount point for temporary workspace.
# Priority: 1) $NAMESPACE_ROOT_DIR/tmp (if exists & tmpfs)
#           2) /dev/shm
#           3) /run
#           4) /tmp
# Requirements: writable, >= 50MB free
# Usage: stdlib::tmpfs::select_best [namespace_root]
stdlib::tmpfs::select_best() {
  local ns_root="${1:-}"
  local min_free_kb=51200 # 50MB minimum

  # Build preference list
  local -a candidates=()
  [[ -n "$ns_root" ]] && candidates+=("${ns_root}/tmp")
  candidates+=(/dev/shm /run /tmp)

  # Get actual tmpfs mounts
  local tmpfs_mounts
  tmpfs_mounts="$(stdlib::tmpfs::detect_candidates)"

  for candidate in "${candidates[@]}"; do
    # Must be a tmpfs mount
    if ! echo "$tmpfs_mounts" | grep -qx "$candidate"; then
      continue
    fi

    # Must be writable
    [[ -w "$candidate" ]] || continue

    # Must have sufficient free space
    local free_kb
    free_kb="$(df -k "$candidate" 2>/dev/null | awk 'NR==2 {print $4}')"
    [[ -n "$free_kb" && "$free_kb" -ge "$min_free_kb" ]] || continue

    echo "$candidate"
    return 0
  done

  # Fallback: /tmp even if not tmpfs (always available)
  echo "/tmp"
}

# ── stdlib::tmpfs::create_workspace ───────────────────────────────────
# Create a unique temporary workspace directory on the best tmpfs.
# Exports TMP_DIR and registers cleanup on EXIT.
# Usage: stdlib::tmpfs::create_workspace [namespace_root] [prefix]
stdlib::tmpfs::create_workspace() {
  local ns_root="${1:-}"
  local prefix="${2:-bootstrap}"

  local base
  base="$(stdlib::tmpfs::select_best "$ns_root")"

  TMP_DIR="$(mktemp -d "${base}/${prefix}-XXXXXX")"
  export TMP_DIR

  # Register cleanup — use eval-based trap so TMP_DIR is expanded at signal time
  trap 'rm -rf "${TMP_DIR}" 2>/dev/null || true' EXIT
  trap 'rm -rf "${TMP_DIR}" 2>/dev/null || true; exit 130' INT
  trap 'rm -rf "${TMP_DIR}" 2>/dev/null || true; exit 143' TERM
}

# ── stdlib::tmpfs::ensure_mount ───────────────────────────────────────
# High-level: ensure a tmpfs mount with fstab entry.
# Usage: stdlib::tmpfs::ensure_mount mountpoint size_spec mode [uid] [gid]
#
# size_spec accepts: "50%", "100M", "2G", "auto", or numeric MB
# Delegates to stdlib::fstab for the actual fstab/mount work.
stdlib::tmpfs::ensure_mount() {
  local mountpoint="$1"
  local size_spec="$2"
  local mode="${3:-1777}"
  local uid="${4:-}"
  local gid="${5:-}"

  # Parse size specification
  local size_mb
  size_mb="$(stdlib::tmpfs::_parse_size "$size_spec")"

  # Build options string
  local opts="defaults,noatime,nosuid,nodev,mode=${mode}"
  if [[ -n "$size_mb" ]]; then
    opts+=",size=${size_mb}m"
  fi
  [[ -n "$uid" ]] && opts+=",uid=${uid}"
  [[ -n "$gid" ]] && opts+=",gid=${gid}"

  local fstab_line="tmpfs  ${mountpoint}  tmpfs  ${opts}  0  0"

  # Ensure directory exists
  if [[ ! -d "$mountpoint" ]]; then
    sudo mkdir -p "$mountpoint"
  fi

  # Delegate to fstab module if loaded, otherwise inline
  if declare -F stdlib::fstab::ensure_entry &>/dev/null; then
    stdlib::fstab::ensure_entry "tmpfs" "$mountpoint" "tmpfs" "$opts"
  else
    # Inline fallback: add if missing, update if stale
    if grep -qsE "\\s${mountpoint}\\s" /etc/fstab; then
      local current
      current="$(grep -E "\\s${mountpoint}\\s" /etc/fstab)"
      if [[ "$current" != "$fstab_line" ]]; then
        sudo sed -i "\\|\\s${mountpoint}\\s|c\\${fstab_line}" /etc/fstab
      fi
    else
      echo "$fstab_line" | sudo tee -a /etc/fstab >/dev/null
    fi
  fi

  # Mount if not already mounted
  if ! mount | grep -qs " on ${mountpoint} "; then
    sudo mount "$mountpoint" 2>/dev/null || sudo mount -a
  fi

  # Set ownership after mount
  if [[ -n "$uid" ]]; then
    sudo chown "${uid}:${gid:-$uid}" "$mountpoint" 2>/dev/null || true
  fi
}
