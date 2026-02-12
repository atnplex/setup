#!/usr/bin/env bash
# Module: fs/path
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::path::resolve, ::normalize, ::relative, ::basename,
#           ::dirname, ::extension, ::temp_dir, ::temp_file
# Description: Path manipulation primitives (pure-bash where possible).

[[ -n "${_STDLIB_LOADED_FS_PATH:-}" ]] && return 0
readonly _STDLIB_LOADED_FS_PATH=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::path::resolve --------------------------------------------
# Resolve a path to an absolute path. If the path exists, uses realpath logic.
stdlib::path::resolve() {
  local target="${1:?path required}"
  if [[ -e "$target" ]]; then
    cd -P "$(dirname "$target")" 2>/dev/null && printf '%s/%s' "$(pwd)" "$(basename "$target")"
  elif [[ "$target" == /* ]]; then
    printf '%s' "$target"
  else
    printf '%s/%s' "$(pwd)" "$target"
  fi
}

# ---------- stdlib::path::normalize ------------------------------------------
# Remove redundant slashes, resolve . and .. components (string-only).
stdlib::path::normalize() {
  local path="$1"
  # Collapse multiple slashes
  while [[ "$path" == *//* ]]; do path="${path//\/\///}"; done
  # Remove trailing slash (except root)
  [[ "$path" != "/" ]] && path="${path%/}"

  # Resolve . and .. using a stack
  local -a parts=() IFS='/'
  local leading=""
  [[ "$path" == /* ]] && leading="/"
  read -ra segments <<< "$path"
  local seg
  for seg in "${segments[@]}"; do
    case "$seg" in
      ''|.) continue ;;
      ..) (( ${#parts[@]} > 0 )) && unset 'parts[-1]' || parts+=("$seg") ;;
      *)  parts+=("$seg") ;;
    esac
  done
  local result="${leading}$(IFS='/'; printf '%s' "${parts[*]}")"
  printf '%s' "${result:-/}"
}

# ---------- stdlib::path::relative -------------------------------------------
# Compute a relative path from 'from' to 'target'.
stdlib::path::relative() {
  local from="${1:?from path required}" target="${2:?target path required}"
  # Use Python as a reliable fallback for relative path computation
  if command -v python3 &>/dev/null; then
    python3 -c "import os.path; print(os.path.relpath('$target','$from'))"
  else
    # Simple fallback: just return target
    printf '%s' "$target"
  fi
}

# ---------- stdlib::path::basename -------------------------------------------
stdlib::path::basename() { printf '%s' "${1##*/}"; }

# ---------- stdlib::path::dirname --------------------------------------------
stdlib::path::dirname() {
  local path="$1"
  [[ "$path" == */* ]] && printf '%s' "${path%/*}" || printf '.'
}

# ---------- stdlib::path::extension ------------------------------------------
# Return the file extension (without dot). Empty if none.
stdlib::path::extension() {
  local name="${1##*/}"
  [[ "$name" == *.* ]] && printf '%s' "${name##*.}" || return 0
}

# ---------- stdlib::path::temp_dir -------------------------------------------
# Create a temporary directory and print its path.
stdlib::path::temp_dir() {
  local prefix="${1:-stdlib}"
  mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXXXXXX"
}

# ---------- stdlib::path::temp_file ------------------------------------------
# Create a temporary file and print its path.
stdlib::path::temp_file() {
  local prefix="${1:-stdlib}" suffix="${2:-}"
  mktemp "${TMPDIR:-/tmp}/${prefix}.XXXXXXXXXX${suffix}"
}
