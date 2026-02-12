#!/usr/bin/env bash
# Module: sys/proc
# Version: 0.1.0
# Provides: Process management — pid lookup, kill, wait, port checks
# Requires: none
[[ -n "${_STDLIB_PROC:-}" ]] && return 0
declare -g _STDLIB_PROC=1

# ── stdlib::proc::is_running ──────────────────────────────────
# Check if a process is running by name or PID.
# Usage: stdlib::proc::is_running name_or_pid
stdlib::proc::is_running() {
  local target="$1"

  if [[ "$target" =~ ^[0-9]+$ ]]; then
    # PID check
    kill -0 "$target" 2>/dev/null
  else
    # Name check
    pgrep -x "$target" &>/dev/null
  fi
}

# ── stdlib::proc::pid_of ──────────────────────────────────────
# Get PID(s) of a process by name. Prints one PID per line.
stdlib::proc::pid_of() {
  pgrep -x "$1" 2>/dev/null
}

# ── stdlib::proc::kill_user ───────────────────────────────────
# Kill all processes owned by a user.
# Usage: stdlib::proc::kill_user username [signal]
stdlib::proc::kill_user() {
  local user="$1"
  local signal="${2:-TERM}"

  if ! id "$user" &>/dev/null; then
    echo "WARN: User $user does not exist" >&2
    return 0
  fi

  sudo pkill -"$signal" -u "$user" 2>/dev/null || true
}

# ── stdlib::proc::wait_for ────────────────────────────────────
# Wait for a process to exit (by PID), with timeout.
# Usage: stdlib::proc::wait_for pid [timeout_seconds]
# Returns 0 if process exited, 1 if timed out.
stdlib::proc::wait_for() {
  local pid="$1"
  local timeout="${2:-30}"
  local elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= timeout )); then
      echo "WARN: Process $pid did not exit within ${timeout}s" >&2
      return 1
    fi
    sleep 1
    ((elapsed++))
  done
  return 0
}

# ── stdlib::proc::port_in_use ─────────────────────────────────
# Check if a TCP port is currently bound.
stdlib::proc::port_in_use() {
  local port="$1"

  if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null
  elif command -v netstat &>/dev/null; then
    netstat -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null
  else
    # Fallback: try to bind
    ! (echo >/dev/tcp/127.0.0.1/"$port") 2>/dev/null
  fi
}

# ── stdlib::proc::pid_on_port ─────────────────────────────────
# Get PID listening on a specific port.
stdlib::proc::pid_on_port() {
  local port="$1"

  if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep ":${port} " | grep -oP 'pid=\K[0-9]+' | head -1
  elif command -v lsof &>/dev/null; then
    lsof -ti :"$port" 2>/dev/null | head -1
  else
    echo "" 
    return 1
  fi
}
