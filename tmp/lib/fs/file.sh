#!/usr/bin/env bash
# Module: fs/file
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::file::read, ::write, ::atomic_write, ::lock, ::unlock, ::checksum
# Description: File I/O with atomic writes, locking, and checksums.

[[ -n "${_STDLIB_LOADED_FS_FILE:-}" ]] && return 0
readonly _STDLIB_LOADED_FS_FILE=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::file::read -----------------------------------------------
# Read entire file content into a variable via nameref.
# Usage: stdlib::file::read content_var /path/to/file
stdlib::file::read() {
  local -n _content="$1"
  local filepath="${2:?filepath required}"
  [[ -f "$filepath" ]] || { printf 'stdlib::file::read: not a file: %s\n' "$filepath" >&2; return 1; }
  _content="$(< "$filepath")"
}

# ---------- stdlib::file::write ----------------------------------------------
# Write content to a file (truncate).
# Usage: stdlib::file::write /path/to/file "content"
stdlib::file::write() {
  local filepath="${1:?filepath required}" content="${2:-}"
  printf '%s' "$content" > "$filepath"
}

# ---------- stdlib::file::atomic_write ---------------------------------------
# Write to a temp file then atomically rename into place.
stdlib::file::atomic_write() {
  local filepath="${1:?filepath required}" content="${2:-}"
  local dir
  dir="$(dirname "$filepath")"
  local tmp
  tmp="$(mktemp "${dir}/.stdlib_atomic.XXXXXXXXXX")"
  printf '%s' "$content" > "$tmp"
  mv -f "$tmp" "$filepath"
}

# ---------- stdlib::file::lock -----------------------------------------------
# Acquire an exclusive flock on a file. Returns the FD for later unlock.
# Usage: stdlib::file::lock fd_var /path/to/lockfile [timeout_seconds]
stdlib::file::lock() {
  local -n _fd="$1"
  local lockfile="${2:?lockfile required}"
  local timeout="${3:-10}"

  exec {_fd}>"$lockfile"
  if ! flock -w "$timeout" "$_fd"; then
    printf 'stdlib::file::lock: timeout acquiring lock on %s\n' "$lockfile" >&2
    exec {_fd}>&-
    return 1
  fi
}

# ---------- stdlib::file::unlock ---------------------------------------------
# Release a previously acquired flock.
# Usage: stdlib::file::unlock fd_var
stdlib::file::unlock() {
  local -n _fd="$1"
  flock -u "$_fd" 2>/dev/null
  exec {_fd}>&-
}

# ---------- stdlib::file::checksum -------------------------------------------
# Compute SHA-256 checksum of a file. Prints hex digest to stdout.
stdlib::file::checksum() {
  local filepath="${1:?filepath required}"
  [[ -f "$filepath" ]] || { printf 'stdlib::file::checksum: not a file: %s\n' "$filepath" >&2; return 1; }
  if command -v sha256sum &>/dev/null; then
    sha256sum "$filepath" | cut -d' ' -f1
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$filepath" | cut -d' ' -f1
  else
    printf 'stdlib::file::checksum: no SHA-256 tool found\n' >&2
    return 1
  fi
}

# ---------- stdlib::file::size -----------------------------------------------
# Print file size in bytes.
stdlib::file::size() {
  local filepath="${1:?filepath required}"
  if stat --version &>/dev/null 2>&1; then
    stat -c '%s' "$filepath"   # GNU stat
  else
    stat -f '%z' "$filepath"   # BSD stat
  fi
}
