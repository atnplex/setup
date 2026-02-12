#!/usr/bin/env bash
# Module: test/perf
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::perf::start, ::stop, ::elapsed, ::report, ::threshold
# Description: Timing, profiling, and performance assertions.

[[ -n "${_STDLIB_LOADED_TEST_PERF:-}" ]] && return 0
readonly _STDLIB_LOADED_TEST_PERF=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# Internal timer registry: [name]=start_nanoseconds
declare -gA _STDLIB_PERF_TIMERS=()
declare -gA _STDLIB_PERF_RESULTS=()  # [name]=elapsed_ms

# Get current time in nanoseconds (or milliseconds as fallback)
_stdlib_perf_now_ns() {
  if date '+%s%N' 2>/dev/null | grep -qE '^[0-9]+$'; then
    date '+%s%N'
  else
    # macOS fallback: seconds * 1000000000
    local s
    s="$(date '+%s')"
    printf '%s000000000' "$s"
  fi
}

# ---------- stdlib::perf::start ----------------------------------------------
# Start a named timer.
# Usage: stdlib::perf::start "my_operation"
stdlib::perf::start() {
  local name="${1:?timer name required}"
  _STDLIB_PERF_TIMERS["$name"]="$(_stdlib_perf_now_ns)"
}

# ---------- stdlib::perf::stop -----------------------------------------------
# Stop a named timer and record elapsed milliseconds.
stdlib::perf::stop() {
  local name="${1:?timer name required}"
  local end_ns
  end_ns="$(_stdlib_perf_now_ns)"
  local start_ns="${_STDLIB_PERF_TIMERS[$name]:-$end_ns}"
  local elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  _STDLIB_PERF_RESULTS["$name"]="$elapsed_ms"
  unset '_STDLIB_PERF_TIMERS[$name]'
}

# ---------- stdlib::perf::elapsed --------------------------------------------
# Print elapsed time in milliseconds for a completed timer.
stdlib::perf::elapsed() {
  local name="${1:?timer name required}"
  printf '%s' "${_STDLIB_PERF_RESULTS[$name]:-0}"
}

# ---------- stdlib::perf::report ---------------------------------------------
# Emit a JSON report of all recorded timings.
stdlib::perf::report() {
  local entries="" name
  for name in "${!_STDLIB_PERF_RESULTS[@]}"; do
    [[ -n "$entries" ]] && entries+=","
    entries+="$(printf '{"name":"%s","elapsed_ms":%s}' "$name" "${_STDLIB_PERF_RESULTS[$name]}")"
  done
  printf '{"timings":[%s]}\n' "$entries"
}

# ---------- stdlib::perf::threshold ------------------------------------------
# Assert that a timer did not exceed a threshold.
# Usage: stdlib::perf::threshold "my_op" 500   # must be under 500ms
stdlib::perf::threshold() {
  local name="${1:?timer name required}" max_ms="${2:?threshold_ms required}"
  local actual="${_STDLIB_PERF_RESULTS[$name]:-0}"
  if (( actual > max_ms )); then
    printf 'PERF THRESHOLD EXCEEDED: %s took %dms (max: %dms)\n' \
      "$name" "$actual" "$max_ms" >&2
    return 1
  fi
}
