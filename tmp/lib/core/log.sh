#!/usr/bin/env bash
# Module: core/log
# Version: 0.2.0
# Provides: Structured logging with levels, formats, file output
# Requires: none
[[ -n "${_STDLIB_LOG:-}" ]] && return 0
declare -g _STDLIB_LOG=1

# ── Log levels ──────────────────────────────────────────────────
declare -gA _LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4)
declare -g  _LOG_LEVEL="${LOG_LEVEL:-INFO}"
declare -g  _LOG_FORMAT="${LOG_FORMAT:-human}"   # human | json
declare -g  _LOG_FILE=""                         # parallel file output

# ── stdlib::log::level ────────────────────────────────────────
stdlib::log::level() {
  _LOG_LEVEL="${1:-INFO}"
}

# ── stdlib::log::format ───────────────────────────────────────
stdlib::log::format() {
  _LOG_FORMAT="${1:-human}"
}

# ── Internal: should_log ──────────────────────────────────────
_stdlib_log_should() {
  local level="$1"
  (( ${_LOG_LEVELS[$level]:-0} >= ${_LOG_LEVELS[$_LOG_LEVEL]:-0} ))
}

# ── Internal: emit ────────────────────────────────────────────
_stdlib_log_emit() {
  local level="$1"; shift
  local msg="$*"

  _stdlib_log_should "$level" || return 0

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [[ "$_LOG_FORMAT" == "json" ]]; then
    local json
    json=$(printf '{"ts":"%s","level":"%s","msg":"%s"}' "$ts" "$level" "${msg//\"/\\\"}")
    echo "$json" >&2
    [[ -n "$_LOG_FILE" ]] && echo "$json" >> "$_LOG_FILE"
  else
    local color="" reset="\033[0m"
    case "$level" in
      DEBUG) color="\033[0;37m" ;;
      INFO)  color="\033[0;34m" ;;
      WARN)  color="\033[0;33m" ;;
      ERROR) color="\033[0;31m" ;;
      FATAL) color="\033[1;31m" ;;
    esac
    local line
    line=$(printf '%b[%s]%b %s — %s' "$color" "$level" "$reset" "$ts" "$msg")
    echo -e "$line" >&2
    [[ -n "$_LOG_FILE" ]] && printf '[%s] %s — %s\n' "$level" "$ts" "$msg" >> "$_LOG_FILE"
  fi
}

# ── Public logging functions ──────────────────────────────────
stdlib::log::debug() { _stdlib_log_emit "DEBUG" "$@"; }
stdlib::log::info()  { _stdlib_log_emit "INFO"  "$@"; }
stdlib::log::warn()  { _stdlib_log_emit "WARN"  "$@"; }
stdlib::log::error() { _stdlib_log_emit "ERROR" "$@"; }
stdlib::log::fatal() { _stdlib_log_emit "FATAL" "$@"; exit 1; }

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.2.0)
# ══════════════════════════════════════════════════════════════

# ── stdlib::log::set_file ─────────────────────────────────────
# Enable parallel log file output. All subsequent log calls
# also append to this file (without ANSI colors).
stdlib::log::set_file() {
  _LOG_FILE="$1"
  [[ -n "$_LOG_FILE" ]] && touch "$_LOG_FILE"
}

# ── stdlib::log::ok ───────────────────────────────────────────
# Success message with green checkmark. Always emitted.
stdlib::log::ok() {
  local msg="$*"
  echo -e "\033[0;32m✓\033[0m ${msg}" >&2
  [[ -n "$_LOG_FILE" ]] && printf '✓ %s\n' "$msg" >> "$_LOG_FILE"
}

# ── stdlib::log::die ──────────────────────────────────────────
# Fatal error with red cross + exit.
# Usage: stdlib::log::die "message" [exit_code]
stdlib::log::die() {
  local msg="$1"
  local code="${2:-1}"
  echo -e "\033[1;31m✗ FATAL:\033[0m ${msg}" >&2
  [[ -n "$_LOG_FILE" ]] && printf '✗ FATAL: %s\n' "$msg" >> "$_LOG_FILE"
  exit "$code"
}

# ── stdlib::log::section ──────────────────────────────────────
# Visual section header for long-running scripts.
stdlib::log::section() {
  local title="$1"
  local line
  line=$(printf '═%.0s' {1..60})
  echo "" >&2
  echo -e "\033[1;36m${line}\033[0m" >&2
  echo -e "\033[1;36m  ${title}\033[0m" >&2
  echo -e "\033[1;36m${line}\033[0m" >&2
  echo "" >&2
  [[ -n "$_LOG_FILE" ]] && printf '\n%s\n  %s\n%s\n\n' "$line" "$title" "$line" >> "$_LOG_FILE"
}

# ── stdlib::log::banner ──────────────────────────────────────
# Boxed banner (like bootstrap header). Optional subtitle.
# Usage: stdlib::log::banner "Title" ["Subtitle"]
stdlib::log::banner() {
  local title="$1"
  local subtitle="${2:-}"
  local width=61

  echo "" >&2
  echo -e "\033[0;34m╔$(printf '═%.0s' $(seq 1 $width))╗\033[0m" >&2
  printf '\033[0;34m║\033[0m  %-*s\033[0;34m║\033[0m\n' "$((width - 2))" "$title" >&2
  if [[ -n "$subtitle" ]]; then
    printf '\033[0;34m║\033[0m  %-*s\033[0;34m║\033[0m\n' "$((width - 2))" "$subtitle" >&2
  fi
  echo -e "\033[0;34m╚$(printf '═%.0s' $(seq 1 $width))╝\033[0m" >&2
  echo "" >&2

  if [[ -n "$_LOG_FILE" ]]; then
    {
      echo ""
      printf '╔%s╗\n' "$(printf '═%.0s' $(seq 1 $width))"
      printf '║  %-*s║\n' "$((width - 2))" "$title"
      [[ -n "$subtitle" ]] && printf '║  %-*s║\n' "$((width - 2))" "$subtitle"
      printf '╚%s╝\n' "$(printf '═%.0s' $(seq 1 $width))"
      echo ""
    } >> "$_LOG_FILE"
  fi
}
