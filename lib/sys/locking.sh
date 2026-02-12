#!/usr/bin/env bash
# ─── sys/locking.sh — Atomic lockfile management with stacked trap cleanup ───
# Module version
_STDLIB_MOD_VERSION="1.0.0"

# ── Internal state ────────────────────────────────────────────────────
# Associative array: lockfile_path → owner_pid
declare -gA _STDLIB_LOCKS=()
# Flag to prevent re-entrant cleanup
declare -g _STDLIB_LOCK_CLEANING=false

# ── stdlib::lock::acquire ─────────────────────────────────────────────
# Atomically create a lockfile with owner PID.
# Returns 0 on success, 1 if already locked by another process.
#
# Usage: stdlib::lock::acquire /path/to/lockfile [timeout_seconds]
#
# The lockfile is created atomically via a temp file + mv (rename is atomic
# on the same filesystem). The file contains the owner PID for staleness
# detection. A cleanup trap is registered immediately after acquisition.
stdlib::lock::acquire() {
  local lockfile="${1:?lockfile path required}"
  local timeout="${2:-0}"
  local elapsed=0

  # Already held by us?
  if [[ -n "${_STDLIB_LOCKS[$lockfile]:-}" ]] && [[ "${_STDLIB_LOCKS[$lockfile]}" == "$$" ]]; then
    return 0
  fi

  # Check for stale locks (owner PID no longer running)
  if [[ -f "$lockfile" ]]; then
    local stale_pid
    stale_pid="$(cat "$lockfile" 2>/dev/null || true)"
    if [[ -n "$stale_pid" ]] && ! kill -0 "$stale_pid" 2>/dev/null; then
      rm -f "$lockfile" 2>/dev/null || true
    fi
  fi

  # Attempt atomic creation: write PID to temp, rename into place
  while true; do
    local tmpfile
    tmpfile="$(mktemp "${lockfile}.XXXXXX" 2>/dev/null)" || return 1
    printf '%d\n' "$$" >"$tmpfile"

    # ln(1) is atomic and fails if target exists — use it as the lock primitive
    if ln "$tmpfile" "$lockfile" 2>/dev/null; then
      rm -f "$tmpfile"
      _STDLIB_LOCKS["$lockfile"]="$$"
      # Register cleanup trap IMMEDIATELY after acquisition (no race window)
      _stdlib_lock_install_traps
      return 0
    fi

    rm -f "$tmpfile"

    # Lock held by another process
    if [[ "$timeout" -le 0 ]] || [[ "$elapsed" -ge "$timeout" ]]; then
      return 1
    fi

    sleep 1
    ((elapsed++))
  done
}

# ── stdlib::lock::release ─────────────────────────────────────────────
# Release a lock. Only removes the lockfile if our PID owns it.
# Idempotent — safe to call multiple times.
stdlib::lock::release() {
  local lockfile="${1:?lockfile path required}"

  # Not tracked by us? No-op.
  if [[ -z "${_STDLIB_LOCKS[$lockfile]:-}" ]]; then
    return 0
  fi

  # Only remove if we still own it (PID matches)
  if [[ -f "$lockfile" ]]; then
    local file_pid
    file_pid="$(cat "$lockfile" 2>/dev/null || true)"
    if [[ "$file_pid" == "$$" ]]; then
      rm -f "$lockfile"
    fi
  fi

  unset '_STDLIB_LOCKS[$lockfile]'
}

# ── stdlib::lock::release_all ─────────────────────────────────────────
# Release ALL locks held by this process. Called by trap handlers.
# Idempotent and re-entrance safe.
stdlib::lock::release_all() {
  # Guard against re-entrant calls from nested signals
  if [[ "$_STDLIB_LOCK_CLEANING" == "true" ]]; then
    return 0
  fi
  _STDLIB_LOCK_CLEANING=true

  local lockfile
  for lockfile in "${!_STDLIB_LOCKS[@]}"; do
    stdlib::lock::release "$lockfile"
  done

  _STDLIB_LOCK_CLEANING=false
}

# ── stdlib::lock::is_held ─────────────────────────────────────────────
# Check if a lockfile is held (by any process).
# Returns 0 if locked, 1 if free.
stdlib::lock::is_held() {
  local lockfile="${1:?lockfile path required}"

  if [[ ! -f "$lockfile" ]]; then
    return 1
  fi

  local file_pid
  file_pid="$(cat "$lockfile" 2>/dev/null || true)"
  if [[ -n "$file_pid" ]] && kill -0 "$file_pid" 2>/dev/null; then
    return 0
  fi

  # Stale lock — owner is dead
  return 1
}

# ── stdlib::lock::owner ───────────────────────────────────────────────
# Print the PID of the lock owner, or empty if unlocked.
stdlib::lock::owner() {
  local lockfile="${1:?lockfile path required}"
  if [[ -f "$lockfile" ]]; then
    cat "$lockfile" 2>/dev/null || true
  fi
}

# ── stdlib::lock::with ────────────────────────────────────────────────
# Run a command while holding a lock. Auto-releases on completion or error.
#
# Usage: stdlib::lock::with /path/to/lockfile command [args...]
stdlib::lock::with() {
  local lockfile="${1:?lockfile path required}"
  shift

  stdlib::lock::acquire "$lockfile" || {
    printf 'stdlib::lock::with: failed to acquire %s\n' "$lockfile" >&2
    return 1
  }

  local rc=0
  "$@" || rc=$?

  stdlib::lock::release "$lockfile"
  return "$rc"
}

# ── stdlib::lock::pre_daemonize ───────────────────────────────────────
# Release all locks before daemonizing / backgrounding.
# Call this BEFORE exec or & to ensure child processes don't inherit locks.
stdlib::lock::pre_daemonize() {
  stdlib::lock::release_all
}

# ── Internal: stacked trap installation ───────────────────────────────
# Installs cleanup traps WITHOUT overwriting existing traps.
# Uses the bash trap stacking pattern: save existing → prepend ours.
_stdlib_lock_install_traps() {
  # Only install once
  if [[ -n "${_STDLIB_LOCK_TRAPS_INSTALLED:-}" ]]; then
    return 0
  fi
  _STDLIB_LOCK_TRAPS_INSTALLED=1

  local sig
  for sig in EXIT ERR INT TERM; do
    # Capture any existing trap (strip the leading "trap -- '" and trailing "' SIG")
    local existing
    existing="$(trap -p "$sig" 2>/dev/null | sed "s/^trap -- '//;s/' ${sig}$//" || true)"

    # Build stacked trap: our cleanup runs first, then the original
    if [[ -n "$existing" ]]; then
      # shellcheck disable=SC2064
      trap "stdlib::lock::release_all; ${existing}" "$sig"
    else
      trap 'stdlib::lock::release_all' "$sig"
    fi
  done
}
