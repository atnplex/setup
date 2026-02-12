#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# sys/tmpfs.sh — Tmpfs detection, workspace creation, and mount management
# ═══════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_TMPFS:-}" ]] && return 0
readonly _STDLIB_MOD_TMPFS=1
_STDLIB_MOD_VERSION="1.0.0"

stdlib::import core/log

# ── Detect tmpfs mount candidates ────────────────────────────────────
stdlib::tmpfs::detect_candidates() {
  _TMPFS_CANDIDATES=()

  if [[ ! -f /proc/mounts ]]; then
    stdlib::log::warn "No /proc/mounts — tmpfs detection unavailable"
    return 1
  fi

  local _dev mp fstype _opts _dump _pass
  while read -r _dev mp fstype _opts _dump _pass; do
    if [[ "${fstype}" == "tmpfs" && -d "${mp}" && -w "${mp}" ]]; then
      local size_kb
      size_kb="$(df -k "${mp}" 2>/dev/null | awk 'NR==2{print $4}')" || continue
      _TMPFS_CANDIDATES+=("${mp}:${size_kb:-0}")
    fi
  done < /proc/mounts
}

# ── Select the best (largest available) tmpfs ────────────────────────
stdlib::tmpfs::select_best() {
  stdlib::tmpfs::detect_candidates

  if [[ ${#_TMPFS_CANDIDATES[@]} -eq 0 ]]; then
    stdlib::log::warn "No writable tmpfs found — falling back to /tmp"
    _BEST_TMPFS="/tmp"
    return 0
  fi

  local best_mp="/tmp"
  local best_size=0
  local entry
  for entry in "${_TMPFS_CANDIDATES[@]}"; do
    local mp="${entry%%:*}"
    local size="${entry##*:}"
    if [[ "${size}" -gt "${best_size}" ]]; then
      best_size="${size}"
      best_mp="${mp}"
    fi
  done

  _BEST_TMPFS="${best_mp}"
  stdlib::log::info "Selected tmpfs: ${_BEST_TMPFS} (${best_size}KB free)"
}

# ── Create workspace on tmpfs + register cleanup trap ────────────────
stdlib::tmpfs::create_workspace() {
  stdlib::tmpfs::select_best

  TMP_DIR="$(mktemp -d "${_BEST_TMPFS}/bootstrap-XXXXXX")"
  export TMP_DIR

  # shellcheck disable=SC2064
  trap "rm -rf '${TMP_DIR}'" EXIT

  stdlib::log::info "Workspace: ${TMP_DIR}"
}

# ── Ensure permanent tmpfs mounts (fstab + mount) ────────────────────
stdlib::tmpfs::ensure_mounts() {
  local ns_root="${NAMESPACE_ROOT:?NAMESPACE_ROOT not set}"

  _tmpfs_ensure_mount "${ns_root}/tmp"  "50%" "1777"
  _tmpfs_ensure_mount "${ns_root}/logs" "1G"  "0775"
}

# ── Internal: ensure a single tmpfs mount ────────────────────────────
_tmpfs_ensure_mount() {
  local mount_point="$1"
  local size="$2"
  local mode="$3"

  local size_opt
  if [[ "${size}" == *% ]]; then
    local pct="${size%\%}"
    local ram_kb
    ram_kb="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
    local size_kb=$(( ram_kb * pct / 100 ))
    size_opt="${size_kb}k"
  else
    local ram_kb
    ram_kb="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
    local max_kb=$(( ram_kb / 2 ))
    local req_kb
    req_kb="$(_tmpfs_parse_size "${size}")"
    if [[ "${req_kb}" -gt "${max_kb}" ]]; then
      size_opt="${max_kb}k"
    else
      size_opt="${req_kb}k"
    fi
  fi

  mkdir -p "${mount_point}"

  local fstab_line="tmpfs ${mount_point} tmpfs defaults,noatime,nosuid,nodev,mode=${mode},size=${size_opt} 0 0"
  if ! grep -qF "${mount_point}" /etc/fstab 2>/dev/null; then
    printf '%s\n' "${fstab_line}" >> /etc/fstab
    stdlib::log::info "Added fstab entry: ${mount_point} (${size_opt})"
  fi

  if ! mountpoint -q "${mount_point}" 2>/dev/null; then
    mount "${mount_point}"
    stdlib::log::info "Mounted: ${mount_point}"
  else
    stdlib::log::info "Already mounted: ${mount_point}"
  fi

  chmod "${mode}" "${mount_point}"
}

# ── Internal: parse size string to KB ────────────────────────────────
_tmpfs_parse_size() {
  local size="$1"
  case "${size}" in
    *[Gg]) echo $(( ${size%[Gg]} * 1024 * 1024 )) ;;
    *[Mm]) echo $(( ${size%[Mm]} * 1024 )) ;;
    *[Kk]) echo "${size%[Kk]}" ;;
    *)     echo "${size}" ;;
  esac
}
