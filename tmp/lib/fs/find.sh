#!/usr/bin/env bash
# Module: fs/find
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::find::glob, ::walk, ::match
# Description: Safe file discovery with globbing and recursive walk.

[[ -n "${_STDLIB_LOADED_FS_FIND:-}" ]] && return 0
readonly _STDLIB_LOADED_FS_FIND=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::find::glob -----------------------------------------------
# Safe glob expansion into a nameref array. No matches → empty array (not error).
# Usage: stdlib::find::glob result_array "/path/to/*.sh"
stdlib::find::glob() {
  local -n _results="$1"
  local pattern="$2"
  _results=()

  # Save and set nullglob
  local prev_nullglob
  prev_nullglob="$(shopt -p nullglob 2>/dev/null || true)"
  shopt -s nullglob

  # shellcheck disable=SC2206
  _results=( $pattern )

  # Restore previous state
  eval "$prev_nullglob" 2>/dev/null || true
}

# ---------- stdlib::find::walk -----------------------------------------------
# Recursive directory walk. Calls a callback function for each entry.
# Usage: stdlib::find::walk /start/dir callback_func [max_depth]
# Callback receives: filepath, type ("file" or "dir"), depth
stdlib::find::walk() {
  local dir="${1:?directory required}"
  local callback="${2:?callback function required}"
  local max_depth="${3:-999}"

  _stdlib_find_walk_impl "$dir" "$callback" "$max_depth" 0
}

_stdlib_find_walk_impl() {
  local dir="$1" callback="$2" max_depth="$3" depth="$4"
  (( depth > max_depth )) && return 0

  local entry
  for entry in "$dir"/*; do
    [[ -e "$entry" ]] || continue
    if [[ -d "$entry" ]]; then
      "$callback" "$entry" "dir" "$depth"
      _stdlib_find_walk_impl "$entry" "$callback" "$max_depth" $(( depth + 1 ))
    else
      "$callback" "$entry" "file" "$depth"
    fi
  done
}

# ---------- stdlib::find::match ----------------------------------------------
# Find files matching a name pattern under a directory.
# Usage: stdlib::find::match result_array /start/dir "*.sh" [max_depth]
stdlib::find::match() {
  local -n _results="$1"
  local dir="${2:?directory required}"
  local pattern="${3:?pattern required}"
  local max_depth="${4:-10}"
  _results=()

  while IFS= read -r -d '' f; do
    _results+=("$f")
  done < <(find "$dir" -maxdepth "$max_depth" -name "$pattern" -print0 2>/dev/null)
}
