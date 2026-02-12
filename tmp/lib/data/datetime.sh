#!/usr/bin/env bash
# Module: data/datetime
# Version: 0.1.0
# Provides: Date/time utilities (UTC-canonical, ISO 8601)
# Requires: none
[[ -n "${_STDLIB_DATETIME:-}" ]] && return 0
declare -g _STDLIB_DATETIME=1

# ── stdlib::datetime::now_utc ─────────────────────────────────────────
# ISO 8601 UTC timestamp.
stdlib::datetime::now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── stdlib::datetime::now_unix ────────────────────────────────────────
# Unix epoch seconds.
stdlib::datetime::now_unix() {
  date +%s
}

# ── stdlib::datetime::now_ms ──────────────────────────────────────────
# Millisecond timestamp (if date supports %N, otherwise seconds * 1000).
stdlib::datetime::now_ms() {
  local ns
  ns=$(date +%s%N 2>/dev/null)
  if [[ ${#ns} -gt 10 ]]; then
    echo $(( ns / 1000000 ))
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

# ── stdlib::datetime::format ──────────────────────────────────────────
# Format an epoch timestamp with a date format string.
# Usage: stdlib::datetime::format epoch_ts format_string
stdlib::datetime::format() {
  local ts="$1" fmt="$2"
  date -u -d "@${ts}" +"$fmt" 2>/dev/null || \
    date -u -r "$ts" +"$fmt" 2>/dev/null     # macOS fallback
}

# ── stdlib::datetime::elapsed ─────────────────────────────────────────
# Human-readable elapsed time since a given epoch timestamp.
# Usage: stdlib::datetime::elapsed start_epoch
stdlib::datetime::elapsed() {
  local start="$1"
  local now
  now=$(date +%s)
  local diff=$(( now - start ))

  if (( diff < 60 )); then
    printf '%ds' "$diff"
  elif (( diff < 3600 )); then
    printf '%dm%ds' $(( diff / 60 )) $(( diff % 60 ))
  elif (( diff < 86400 )); then
    printf '%dh%dm' $(( diff / 3600 )) $(( (diff % 3600) / 60 ))
  else
    printf '%dd%dh' $(( diff / 86400 )) $(( (diff % 86400) / 3600 ))
  fi
}

# ── stdlib::datetime::parse_iso ───────────────────────────────────────
# Parse an ISO 8601 timestamp to epoch seconds.
# Usage: stdlib::datetime::parse_iso "2024-01-15T10:30:00Z"
stdlib::datetime::parse_iso() {
  local ts="$1"
  date -u -d "$ts" +%s 2>/dev/null || \
    date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ts" +%s 2>/dev/null  # macOS
}

# ── stdlib::datetime::is_recent ───────────────────────────────────────
# Check if an epoch timestamp is within N seconds of now.
# Usage: stdlib::datetime::is_recent epoch_ts max_age_seconds
stdlib::datetime::is_recent() {
  local ts="$1" age="$2"
  local now
  now=$(date +%s)
  (( (now - ts) <= age ))
}
