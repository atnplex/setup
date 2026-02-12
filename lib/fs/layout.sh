#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# fs/layout.sh — Directory layout and symlink enforcement
# ═══════════════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_LAYOUT:-}" ]] && return 0
readonly _STDLIB_MOD_LAYOUT=1
_STDLIB_MOD_VERSION="1.0.0"

stdlib::import core/log
stdlib::import fs/symlink

# ── Ensure the standard directory layout ──────────────────────────────────────
stdlib::layout::ensure_directories() {
  local ns_root="${NAMESPACE_ROOT:?NAMESPACE_ROOT not set}"
  local user="${BOOTSTRAP_USER:?BOOTSTRAP_USER not set}"
  local group="${BOOTSTRAP_GROUP:?BOOTSTRAP_GROUP not set}"

  local -a dirs=(
    "${ns_root}"
    "${ns_root}/github"
    "${ns_root}/configs"
    "${ns_root}/appdata"
    "${ns_root}/scripts"
    "${ns_root}/.ignore"
    "${ns_root}/.ignore/state"
    "${ns_root}/.ignore/secrets"
  )

  local dir
  for dir in "${dirs[@]}"; do
    if [[ ! -d "${dir}" ]]; then
      mkdir -p "${dir}"
      stdlib::log::info "Created: ${dir}"
    fi
    chown "${user}:${group}" "${dir}"
  done

  # Ensure variables.env exists
  local vars_file="${ns_root}/.ignore/variables.env"
  if [[ ! -f "${vars_file}" ]]; then
    touch "${vars_file}"
    chmod 0600 "${vars_file}"
    chown "${user}:${group}" "${vars_file}"
    stdlib::log::info "Created: ${vars_file}"
  fi

  stdlib::log::info "Directory layout enforced: ${ns_root}"
}

# ── Ensure all expected symlinks ──────────────────────────────────────────────
stdlib::layout::ensure_symlinks() {
  local user="${BOOTSTRAP_USER:?BOOTSTRAP_USER not set}"
  local ns_root="${NAMESPACE_ROOT:?NAMESPACE_ROOT not set}"
  local namespace="${NAMESPACE:?NAMESPACE not set}"

  local home_dir
  home_dir="$(getent passwd "${user}" | cut -d: -f6 2>/dev/null)" || home_dir="/home/${user}"

  # ~/namespace -> $NAMESPACE_ROOT
  stdlib::symlink::ensure_link "${home_dir}/${namespace}" "${ns_root}"

  # ~/repos -> $NAMESPACE_ROOT/github
  stdlib::symlink::ensure_link "${home_dir}/repos" "${ns_root}/github"

  # Detect + fix broken symlinks
  stdlib::symlink::detect_broken "${home_dir}"
}
