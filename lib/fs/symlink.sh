#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# fs/symlink.sh — Symlink enforcement and repair
# ═══════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_SYMLINK:-}" ]] && return 0
readonly _STDLIB_MOD_SYMLINK=1
_STDLIB_MOD_VERSION="1.0.0"

stdlib::import core/log

# ── Enforce all expected symlinks ────────────────────────────────────
stdlib::symlink::enforce() {
  local user="${BOOTSTRAP_USER:?BOOTSTRAP_USER not set}"
  local ns_root="${NAMESPACE_ROOT:?NAMESPACE_ROOT not set}"
  local namespace="${NAMESPACE:?NAMESPACE not set}"

  local home_dir
  home_dir="$(getent passwd "${user}" | cut -d: -f6 2>/dev/null)" || home_dir="/home/${user}"

  # ~/namespace -> $NAMESPACE_ROOT
  stdlib::symlink::ensure_link "${home_dir}/${namespace}" "${ns_root}"

  # ~/repos -> $NAMESPACE_ROOT/github
  stdlib::symlink::ensure_link "${home_dir}/repos" "${ns_root}/github"

  # Scan for broken symlinks
  stdlib::symlink::detect_broken "${home_dir}"
}

# ── Ensure a single symlink ──────────────────────────────────────────
stdlib::symlink::ensure_link() {
  local link="$1"
  local target="$2"

  if [[ -L "${link}" ]]; then
    local current_target
    current_target="$(readlink -f "${link}" 2>/dev/null)" || true
    if [[ "${current_target}" == "${target}" ]]; then
      stdlib::log::info "Symlink OK: ${link} -> ${target}"
      return 0
    fi
    rm -f "${link}"
    stdlib::log::warn "Removed stale symlink: ${link}"
  elif [[ -e "${link}" ]]; then
    stdlib::log::warn "Path exists but is not a symlink: ${link} — skipping"
    return 0
  fi

  ln -s "${target}" "${link}"
  stdlib::log::info "Created symlink: ${link} -> ${target}"
}

# ── Detect and report broken symlinks ────────────────────────────────
stdlib::symlink::detect_broken() {
  local search_dir="${1:-.}"
  local broken
  while IFS= read -r -d '' broken; do
    stdlib::log::warn "Broken symlink: ${broken}"
  done < <(find "${search_dir}" -maxdepth 2 -xtype l -print0 2>/dev/null)
}
