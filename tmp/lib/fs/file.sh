#!/usr/bin/env bash
# Module: fs/file
# Version: 0.2.0
# Provides: File I/O, atomic writes, locking, checksums, templating, backup
# Requires: none
[[ -n "${_STDLIB_FILE:-}" ]] && return 0
declare -g _STDLIB_FILE=1

# ── stdlib::file::read ────────────────────────────────────────
# Read entire file content to stdout.
stdlib::file::read() {
  [[ -f "$1" ]] || { echo "ERROR: File not found: $1" >&2; return 1; }
  cat "$1"
}

# ── stdlib::file::write ───────────────────────────────────────
# Write content to a file (overwrite).
# Usage: stdlib::file::write path content
stdlib::file::write() {
  local path="$1" content="$2"
  local dir
  dir=$(dirname "$path")
  [[ -d "$dir" ]] || mkdir -p "$dir"
  printf '%s' "$content" > "$path"
}

# ── stdlib::file::atomic_write ────────────────────────────────
# Atomic write via temp file + mv (crash-safe).
stdlib::file::atomic_write() {
  local path="$1" content="$2"
  local dir
  dir=$(dirname "$path")
  [[ -d "$dir" ]] || mkdir -p "$dir"

  local tmpfile
  tmpfile=$(mktemp "${dir}/.tmp.XXXXXX")
  printf '%s' "$content" > "$tmpfile"
  mv -f "$tmpfile" "$path"
}

# ── stdlib::file::lock ────────────────────────────────────────
# Acquire an advisory lock on a file.
# Usage: stdlib::file::lock lockfile [timeout_s]
stdlib::file::lock() {
  local lockfile="$1"
  local timeout="${2:-10}"

  exec 9>"$lockfile"
  if ! flock -w "$timeout" 9; then
    echo "ERROR: Cannot acquire lock: $lockfile" >&2
    return 1
  fi
}

# ── stdlib::file::unlock ──────────────────────────────────────
stdlib::file::unlock() {
  exec 9>&-
}

# ── stdlib::file::checksum ────────────────────────────────────
# SHA-256 checksum of a file.
stdlib::file::checksum() {
  [[ -f "$1" ]] || return 1
  sha256sum "$1" | awk '{print $1}'
}

# ── stdlib::file::size ────────────────────────────────────────
# File size in bytes.
stdlib::file::size() {
  [[ -f "$1" ]] || { echo "0"; return 1; }
  stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.2.0)
# ══════════════════════════════════════════════════════════════

# ── stdlib::file::template ────────────────────────────────────
# Render a template file with variable substitution.
# Variables in the template use {{VAR_NAME}} syntax.
# Usage: stdlib::file::template src dest "KEY1=val1" "KEY2=val2"...
stdlib::file::template() {
  local src="$1" dest="$2"; shift 2
  [[ -f "$src" ]] || { echo "ERROR: Template not found: $src" >&2; return 1; }

  local content
  content=$(cat "$src")

  local pair key val
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    content="${content//\{\{${key}\}\}/${val}}"
  done

  stdlib::file::atomic_write "$dest" "$content"
}

# ── stdlib::file::append ──────────────────────────────────────
# Append content to a file (creates if not exists).
stdlib::file::append() {
  local path="$1" content="$2"
  local dir
  dir=$(dirname "$path")
  [[ -d "$dir" ]] || mkdir -p "$dir"
  printf '%s\n' "$content" >> "$path"
}

# ── stdlib::file::ensure_line ─────────────────────────────────
# Add a line to a file if it's not already present (idempotent).
# Usage: stdlib::file::ensure_line path "line content"
stdlib::file::ensure_line() {
  local path="$1" line="$2"

  if [[ -f "$path" ]]; then
    grep -qF "$line" "$path" && return 0
  fi

  local dir
  dir=$(dirname "$path")
  [[ -d "$dir" ]] || mkdir -p "$dir"
  printf '%s\n' "$line" >> "$path"
}

# ── stdlib::file::backup ──────────────────────────────────────
# Create a backup of a file before modification.
# Usage: stdlib::file::backup path [suffix]
# Default suffix is .bak.YYYYMMDD-HHMMSS
stdlib::file::backup() {
  local path="$1"
  local suffix="${2:-}"
  [[ -f "$path" ]] || return 0  # Nothing to back up

  if [[ -z "$suffix" ]]; then
    suffix=".bak.$(date -u +%Y%m%d-%H%M%S)"
  fi

  cp -a "$path" "${path}${suffix}"
}
