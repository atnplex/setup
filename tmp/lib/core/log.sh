#!/usr/bin/env bash
# Module: core/log
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::log, ::log::debug/info/warn/error/fatal, ::log::set_level, ::log::set_format
# Description: Structured logging with JSON and human-readable output.

[[ -n "${_STDLIB_LOADED_CORE_LOG:-}" ]] && return 0
readonly _STDLIB_LOADED_CORE_LOG=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# Log levels: 0=DEBUG 1=INFO 2=WARN 3=ERROR 4=FATAL
declare -gA _STDLIB_LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4)
declare -g _STDLIB_LOG_LEVEL=1          # default: INFO
declare -g _STDLIB_LOG_FORMAT="human"    # human | json

# ---------- stdlib::log::set_level -------------------------------------------
stdlib::log::set_level() {
  local level="${1:?level required}"
  level="${level^^}"
  if [[ -z "${_STDLIB_LOG_LEVELS[$level]:-}" ]]; then
    printf 'stdlib::log::set_level: unknown level "%s"\n' "$level" >&2
    return 1
  fi
  _STDLIB_LOG_LEVEL="${_STDLIB_LOG_LEVELS[$level]}"
}

# ---------- stdlib::log::set_format ------------------------------------------
stdlib::log::set_format() {
  local fmt="${1:?format required}"
  case "$fmt" in
    human|json) _STDLIB_LOG_FORMAT="$fmt" ;;
    *) printf 'stdlib::log::set_format: unknown format "%s"\n' "$fmt" >&2; return 1 ;;
  esac
}

# ---------- stdlib::log (core) -----------------------------------------------
# Usage: stdlib::log LEVEL "message" [key=value ...]
stdlib::log() {
  local level="${1:?level required}"; shift
  local msg="${1:?message required}"; shift
  level="${level^^}"

  local level_num="${_STDLIB_LOG_LEVELS[$level]:-1}"
  (( level_num < _STDLIB_LOG_LEVEL )) && return 0

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%s)"

  if [[ "$_STDLIB_LOG_FORMAT" == "json" ]]; then
    local extra=""
    local kv
    for kv in "$@"; do
      local k="${kv%%=*}" v="${kv#*=}"
      # Escape double quotes in values
      v="${v//\\/\\\\}"
      v="${v//\"/\\\"}"
      extra+="$(printf ',"%s":"%s"' "$k" "$v")"
    done
    printf '{"ts":"%s","level":"%s","msg":"%s"%s}\n' \
      "$ts" "$level" "${msg//\"/\\\"}" "$extra" >&2
  else
    local color="" reset="\033[0m"
    case "$level" in
      DEBUG) color="\033[2;37m" ;;
      INFO)  color="\033[0;36m" ;;
      WARN)  color="\033[0;33m" ;;
      ERROR) color="\033[0;31m" ;;
      FATAL) color="\033[1;31m" ;;
    esac
    local extra=""
    [[ $# -gt 0 ]] && extra=" ($(IFS=" "; printf '%s' "$*"))"
    printf '%b[%s] %-5s%b %s%s\n' \
      "$color" "$ts" "$level" "$reset" "$msg" "$extra" >&2
  fi

  [[ "$level" == "FATAL" ]] && exit 1
  return 0
}

# ---------- convenience wrappers ---------------------------------------------
stdlib::log::debug() { stdlib::log DEBUG "$@"; }
stdlib::log::info()  { stdlib::log INFO  "$@"; }
stdlib::log::warn()  { stdlib::log WARN  "$@"; }
stdlib::log::error() { stdlib::log ERROR "$@"; }
stdlib::log::fatal() { stdlib::log FATAL "$@"; }
