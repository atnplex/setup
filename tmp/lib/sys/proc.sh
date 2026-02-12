#!/usr/bin/env bash
# Module: sys/proc
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::proc::run_with_timeout, ::background, ::wait_all,
#           ::trap_signal, ::pid_alive
# Description: Process management, signals, timeouts, background job tracking.

[[ -n "${_STDLIB_LOADED_SYS_PROC:-}" ]] && return 0
readonly _STDLIB_LOADED_SYS_PROC=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# Internal background PID tracker
declare -ga _STDLIB_BG_PIDS=()

# ---------- stdlib::proc::run_with_timeout -----------------------------------
# Run a command with a timeout. Returns the command's exit code, or 124 on timeout.
stdlib::proc::run_with_timeout() {
  local seconds="${1:?timeout seconds required}"; shift
  if command -v timeout &>/dev/null; then
    timeout "$seconds" "$@"
  else
    # Fallback for systems without coreutils timeout (e.g. macOS)
    local pid
    "$@" &
    pid=$!
    (
      sleep "$seconds"
      kill -TERM "$pid" 2>/dev/null
    ) &
    local watchdog=$!
    wait "$pid" 2>/dev/null
    local rc=$?
    kill "$watchdog" 2>/dev/null
    wait "$watchdog" 2>/dev/null
    return "$rc"
  fi
}

# ---------- stdlib::proc::background -----------------------------------------
# Run a command in the background and track its PID.
# Usage: stdlib::proc::background pid_var command args...
stdlib::proc::background() {
  local -n _pid="$1"; shift
  "$@" &
  _pid=$!
  _STDLIB_BG_PIDS+=("$_pid")
}

# ---------- stdlib::proc::wait_all -------------------------------------------
# Wait for all tracked background PIDs. Returns 0 only if all succeed.
stdlib::proc::wait_all() {
  local overall=0 pid
  for pid in "${_STDLIB_BG_PIDS[@]}"; do
    wait "$pid" 2>/dev/null || overall=1
  done
  _STDLIB_BG_PIDS=()
  return "$overall"
}

# ---------- stdlib::proc::trap_signal ----------------------------------------
# Register a handler for one or more signals.
# Usage: stdlib::proc::trap_signal handler_func SIGINT SIGTERM
stdlib::proc::trap_signal() {
  local handler="$1"; shift
  local sig
  for sig in "$@"; do
    # shellcheck disable=SC2064
    trap "$handler" "$sig"
  done
}

# ---------- stdlib::proc::pid_alive ------------------------------------------
# Returns 0 if the given PID is running.
stdlib::proc::pid_alive() {
  local pid="${1:?PID required}"
  kill -0 "$pid" 2>/dev/null
}
