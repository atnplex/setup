#!/usr/bin/env bash
# Module: data/json
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::json::object, ::array, ::string, ::kv, ::merge
# Description: Pure-bash JSON builder — construct JSON from shell data.

[[ -n "${_STDLIB_LOADED_DATA_JSON:-}" ]] && return 0
readonly _STDLIB_LOADED_DATA_JSON=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::json::string ---------------------------------------------
# Safely escape a value for JSON string embedding.
stdlib::json::string() {
  local s="$1"
  s="${s//\\/\\\\}"      # backslash
  s="${s//\"/\\\"}"      # double quote
  s="${s//$'\n'/\\n}"    # newline
  s="${s//$'\r'/\\r}"    # carriage return
  s="${s//$'\t'/\\t}"    # tab
  printf '"%s"' "$s"
}

# ---------- stdlib::json::kv -------------------------------------------------
# Emit a single JSON key:value pair.
# Usage: stdlib::json::kv "key" "value" [type]
# type: string (default), number, bool, null, raw
stdlib::json::kv() {
  local key="$1" value="$2" type="${3:-string}"
  local jkey
  jkey="$(stdlib::json::string "$key")"
  case "$type" in
    string) printf '%s:%s' "$jkey" "$(stdlib::json::string "$value")" ;;
    number) printf '%s:%s' "$jkey" "$value" ;;
    bool)   printf '%s:%s' "$jkey" "$value" ;;
    null)   printf '%s:null' "$jkey" ;;
    raw)    printf '%s:%s' "$jkey" "$value" ;;
    *)      printf '%s:%s' "$jkey" "$(stdlib::json::string "$value")" ;;
  esac
}

# ---------- stdlib::json::object ---------------------------------------------
# Build a JSON object from key=value pairs.
# Usage: stdlib::json::object "name=Alice" "age:number=30" "active:bool=true"
stdlib::json::object() {
  local result="{" first=1
  local pair
  for pair in "$@"; do
    local key_typed="${pair%%=*}"
    local value="${pair#*=}"
    local key="$key_typed" type="string"

    # Parse type annotation: "key:type"
    if [[ "$key_typed" == *":"* ]]; then
      key="${key_typed%%:*}"
      type="${key_typed#*:}"
    fi

    (( first )) || result+=","
    first=0
    result+="$(stdlib::json::kv "$key" "$value" "$type")"
  done
  result+="}"
  printf '%s\n' "$result"
}

# ---------- stdlib::json::array ----------------------------------------------
# Build a JSON array from positional arguments.
# Usage: stdlib::json::array "a" "b" "c"  OR  stdlib::json::array --type=number 1 2 3
stdlib::json::array() {
  local type="string"
  if [[ "${1:-}" == --type=* ]]; then
    type="${1#--type=}"
    shift
  fi

  local result="[" first=1
  local item
  for item in "$@"; do
    (( first )) || result+=","
    first=0
    case "$type" in
      string) result+="$(stdlib::json::string "$item")" ;;
      number|bool|raw) result+="$item" ;;
      null)   result+="null" ;;
    esac
  done
  result+="]"
  printf '%s\n' "$result"
}

# ---------- stdlib::json::merge ----------------------------------------------
# Merge two JSON object strings (shallow). Second wins on conflict.
# Requires both inputs to be flat `{"k":"v",...}` objects.
stdlib::json::merge() {
  local a="${1#\{}" b="${2#\{}" 
  a="${a%\}}" b="${b%\}}"
  local merged=""
  [[ -n "$a" ]] && merged="$a"
  if [[ -n "$b" ]]; then
    [[ -n "$merged" ]] && merged+=","
    merged+="$b"
  fi
  printf '{%s}\n' "$merged"
}
