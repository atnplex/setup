#!/usr/bin/env bash
# Module: fs/layout
# Version: 0.1.0
# Provides: Namespace directory structure, symlinks, and seeding
# Requires: fs/dir (for stdlib::dir::ensure, stdlib::dir::symlink, stdlib::dir::ensure_tree)
[[ -n "${_STDLIB_LAYOUT:-}" ]] && return 0
declare -g _STDLIB_LAYOUT=1

# ── stdlib::layout::ensure_root ───────────────────────────────────────
# Create the namespace root directory with proper ownership.
# Usage: stdlib::layout::ensure_root root_path owner:group [mode]
stdlib::layout::ensure_root() {
  local root="$1"
  local owner="${2:-root:root}"
  local mode="${3:-775}"

  if declare -F stdlib::dir::ensure &>/dev/null; then
    stdlib::dir::ensure "$root" "$owner" "$mode"
  else
    sudo mkdir -p "$root"
    sudo chown "$owner" "$root"
    sudo chmod "$mode" "$root"
  fi
}

# ── stdlib::layout::ensure_dirs ───────────────────────────────────────
# Create the standard namespace directory tree.
# Usage: stdlib::layout::ensure_dirs root_path owner:group
stdlib::layout::ensure_dirs() {
  local root="$1"
  local owner="${2:-root:root}"

  # Public directories (775)
  local -a public=(
    "${root}/github"
    "${root}/configs"
    "${root}/appdata"
    "${root}/scripts"
  )

  # Private directories (700)
  local -a private=(
    "${root}/.ignore"
    "${root}/.ignore/state"
    "${root}/.ignore/secrets"
  )

  if declare -F stdlib::dir::ensure_tree &>/dev/null; then
    stdlib::dir::ensure_tree "$owner" "775" "${public[@]}"
    stdlib::dir::ensure_tree "$owner" "700" "${private[@]}"
  else
    for d in "${public[@]}"; do
      sudo mkdir -p "$d"
      sudo chown "$owner" "$d"
      sudo chmod 775 "$d"
    done
    for d in "${private[@]}"; do
      sudo mkdir -p "$d"
      sudo chown "$owner" "$d"
      sudo chmod 700 "$d"
    done
  fi
}

# ── stdlib::layout::ensure_private ────────────────────────────────────
# Ensure private sub-directories exist with strict permissions.
# This is a convenience wrapper around ensure_dirs for the .ignore tree.
# Usage: stdlib::layout::ensure_private root_path owner:group
stdlib::layout::ensure_private() {
  local root="$1"
  local owner="${2:-root:root}"
  local -a dirs=(
    "${root}/.ignore"
    "${root}/.ignore/state"
    "${root}/.ignore/secrets"
  )

  for d in "${dirs[@]}"; do
    if declare -F stdlib::dir::ensure &>/dev/null; then
      stdlib::dir::ensure "$d" "$owner" "700"
    else
      sudo mkdir -p "$d"
      sudo chown "$owner" "$d"
      sudo chmod 700 "$d"
    fi
  done
}

# ── stdlib::layout::ensure_symlinks ───────────────────────────────────
# Create standard symlinks for the namespace.
# Usage: stdlib::layout::ensure_symlinks root_path namespace user
#   Creates:
#     /home/$user/$namespace → $root_path
#     /home/$user/repos      → $root_path/github (optional)
stdlib::layout::ensure_symlinks() {
  local root="$1"
  local namespace="$2"
  local user="$3"

  local home="/home/${user}"
  [[ -d "$home" ]] || return 0 # skip if no home directory

  # Primary: $HOME/$namespace → $root
  local link1="${home}/${namespace}"
  if [[ -L "$link1" ]]; then
    # Already a symlink — verify target
    local existing
    existing="$(readlink -f "$link1" 2>/dev/null || true)"
    if [[ "$existing" != "$(readlink -f "$root" 2>/dev/null)" ]]; then
      # Fix broken/wrong symlink
      if declare -F stdlib::dir::symlink &>/dev/null; then
        stdlib::dir::symlink "$root" "$link1"
      else
        ln -sfn "$root" "$link1"
      fi
    fi
  elif [[ ! -e "$link1" ]]; then
    # Doesn't exist — create
    if declare -F stdlib::dir::symlink &>/dev/null; then
      stdlib::dir::symlink "$root" "$link1"
    else
      ln -sfn "$root" "$link1"
    fi
  fi
  # If it's a real directory/file, do NOT overwrite — safety

  # Secondary: $HOME/repos → $root/github (only if not already something else)
  local link2="${home}/repos"
  if [[ ! -e "$link2" ]] || [[ -L "$link2" ]]; then
    if declare -F stdlib::dir::symlink &>/dev/null; then
      stdlib::dir::symlink "${root}/github" "$link2"
    else
      ln -sfn "${root}/github" "$link2"
    fi
  fi
}

# ── stdlib::layout::ensure_all ────────────────────────────────────────
# One-call convenience: root + dirs + private + symlinks.
# Usage: stdlib::layout::ensure_all root namespace user group
stdlib::layout::ensure_all() {
  local root="$1"
  local namespace="$2"
  local user="$3"
  local group="${4:-$user}"
  local owner="${user}:${group}"

  stdlib::layout::ensure_root "$root" "$owner" "775"
  stdlib::layout::ensure_dirs "$root" "$owner"
  stdlib::layout::ensure_symlinks "$root" "$namespace" "$user"
}
