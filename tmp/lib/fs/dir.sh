#!/usr/bin/env bash
# Module: fs/dir
# Version: 0.1.0
# Provides: Directory operations — ensure, symlink, tree, empty-check, size
# Requires: none
[[ -n "${_STDLIB_DIR:-}" ]] && return 0
declare -g _STDLIB_DIR=1

# ── stdlib::dir::ensure ───────────────────────────────────────
# Create directory with ownership and permissions in one call.
# Usage: stdlib::dir::ensure path [owner:group] [mode]
stdlib::dir::ensure() {
  local path="$1"
  local owner="${2:-}"
  local mode="${3:-}"

  if [[ ! -d "$path" ]]; then
    if [[ -w "$(dirname "$path")" ]]; then
      mkdir -p "$path"
    else
      sudo mkdir -p "$path"
    fi
  fi

  if [[ -n "$owner" ]]; then
    sudo chown "$owner" "$path" 2>/dev/null || true
  fi

  if [[ -n "$mode" ]]; then
    sudo chmod "$mode" "$path" 2>/dev/null || true
  fi
}

# ── stdlib::dir::ensure_tree ──────────────────────────────────
# Batch-create multiple directories with the same owner and mode.
# Usage: stdlib::dir::ensure_tree owner:group mode dir1 dir2 dir3...
stdlib::dir::ensure_tree() {
  local owner="$1"; shift
  local mode="$1"; shift

  for dir in "$@"; do
    stdlib::dir::ensure "$dir" "$owner" "$mode"
  done
}

# ── stdlib::dir::symlink ──────────────────────────────────────
# Create an idempotent symlink (ln -sfn). Safe to call repeatedly.
# Usage: stdlib::dir::symlink target link_path
stdlib::dir::symlink() {
  local target="$1"
  local link_path="$2"

  # Already correct?
  if [[ -L "$link_path" ]] && [[ "$(readlink -f "$link_path")" == "$(readlink -f "$target")" ]]; then
    return 0
  fi

  local parent
  parent="$(dirname "$link_path")"
  [[ -d "$parent" ]] || mkdir -p "$parent"

  if [[ -w "$parent" ]]; then
    ln -sfn "$target" "$link_path"
  else
    sudo ln -sfn "$target" "$link_path"
  fi
}

# ── stdlib::dir::is_empty ─────────────────────────────────────
# Check if a directory is empty. Returns 0 if empty, 1 if not.
stdlib::dir::is_empty() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  [[ -z "$(ls -A "$path" 2>/dev/null)" ]]
}

# ── stdlib::dir::size ─────────────────────────────────────────
# Directory size in bytes.
stdlib::dir::size() {
  [[ -d "$1" ]] || { echo "0"; return 1; }
  du -sb "$1" 2>/dev/null | awk '{print $1}'
}

# ── stdlib::dir::copy ─────────────────────────────────────────
# Recursive copy preserving attributes.
# Usage: stdlib::dir::copy src dest
stdlib::dir::copy() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || { echo "ERROR: Source directory not found: $src" >&2; return 1; }
  cp -a "$src" "$dest"
}
