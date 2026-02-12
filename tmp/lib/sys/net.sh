#!/usr/bin/env bash
# Module: sys/net
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::net::http_get, ::http_post, ::port_open, ::dns_resolve,
#           ::retry, ::wait_for_port
# Description: Network utilities — HTTP, DNS, port checks, retry with backoff.

[[ -n "${_STDLIB_LOADED_SYS_NET:-}" ]] && return 0
readonly _STDLIB_LOADED_SYS_NET=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::net::http_get --------------------------------------------
# Simple HTTP GET. Prints response body to stdout, returns curl exit code.
# Usage: stdlib::net::http_get URL [extra_curl_args...]
stdlib::net::http_get() {
  local url="${1:?URL required}"; shift
  curl -fsSL --max-time 30 "$@" "$url"
}

# ---------- stdlib::net::http_post -------------------------------------------
# HTTP POST with data. Prints response body to stdout.
# Usage: stdlib::net::http_post URL data [content_type]
stdlib::net::http_post() {
  local url="${1:?URL required}" data="${2:-}" ct="${3:-application/json}"
  curl -fsSL --max-time 30 -X POST -H "Content-Type: ${ct}" -d "$data" "$url"
}

# ---------- stdlib::net::port_open -------------------------------------------
# Check if a TCP port is open on a host. Returns 0 if open.
# Usage: stdlib::net::port_open host port [timeout_seconds]
stdlib::net::port_open() {
  local host="${1:?host required}" port="${2:?port required}" timeout="${3:-3}"
  if command -v nc &>/dev/null; then
    nc -z -w "$timeout" "$host" "$port" &>/dev/null
  elif [[ -e /dev/tcp ]]; then
    (echo > "/dev/tcp/${host}/${port}") &>/dev/null
  else
    # Fallback: use bash /dev/tcp (works in most bash builds)
    timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" &>/dev/null
  fi
}

# ---------- stdlib::net::dns_resolve -----------------------------------------
# Resolve a hostname to IP address(es). Prints one IP per line.
stdlib::net::dns_resolve() {
  local host="${1:?hostname required}"
  if command -v dig &>/dev/null; then
    dig +short "$host" 2>/dev/null
  elif command -v host &>/dev/null; then
    host "$host" 2>/dev/null | awk '/has address/ {print $NF}'
  elif command -v getent &>/dev/null; then
    getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u
  else
    printf 'stdlib::net::dns_resolve: no DNS tool found\n' >&2
    return 1
  fi
}

# ---------- stdlib::net::retry -----------------------------------------------
# Retry a command with exponential backoff.
# Usage: stdlib::net::retry max_attempts initial_delay_sec command args...
stdlib::net::retry() {
  local max="${1:?max attempts required}" delay="${2:?initial delay required}"; shift 2
  local attempt=1
  while (( attempt <= max )); do
    if "$@"; then
      return 0
    fi
    if (( attempt < max )); then
      printf 'stdlib::net::retry: attempt %d/%d failed, retrying in %ds...\n' \
        "$attempt" "$max" "$delay" >&2
      sleep "$delay"
      delay=$(( delay * 2 ))
    fi
    (( attempt++ ))
  done
  printf 'stdlib::net::retry: all %d attempts failed\n' "$max" >&2
  return 1
}

# ---------- stdlib::net::wait_for_port ---------------------------------------
# Block until a TCP port becomes available or timeout.
# Usage: stdlib::net::wait_for_port host port [timeout_seconds] [interval]
stdlib::net::wait_for_port() {
  local host="${1:?host required}" port="${2:?port required}"
  local timeout="${3:-30}" interval="${4:-1}"
  local elapsed=0
  while (( elapsed < timeout )); do
    stdlib::net::port_open "$host" "$port" 1 && return 0
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
  done
  printf 'stdlib::net::wait_for_port: timeout waiting for %s:%s\n' "$host" "$port" >&2
  return 1
}
