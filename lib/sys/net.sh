#!/usr/bin/env bash
# Module: sys/net
# Version: 0.2.0
# Provides: HTTP requests, port checks, DNS, retry, download
# Requires: none
[[ -n "${_STDLIB_NET:-}" ]] && return 0
declare -g _STDLIB_NET=1

# ── stdlib::net::http_get ─────────────────────────────────────
# GET request, returns body to stdout.
# Usage: stdlib::net::http_get url [header...]
stdlib::net::http_get() {
  local url="$1"; shift
  local -a headers=()
  for h in "$@"; do headers+=(-H "$h"); done

  if command -v curl &>/dev/null; then
    curl -fsSL "${headers[@]}" "$url"
  elif command -v wget &>/dev/null; then
    local -a wh=()
    for h in "$@"; do wh+=(--header="$h"); done
    wget -qO- "${wh[@]}" "$url"
  else
    echo "ERROR: Neither curl nor wget available" >&2
    return 1
  fi
}

# ── stdlib::net::http_post ────────────────────────────────────
# POST request with data.
# Usage: stdlib::net::http_post url data [content_type]
stdlib::net::http_post() {
  local url="$1"
  local data="$2"
  local ct="${3:-application/json}"

  if command -v curl &>/dev/null; then
    curl -fsSL -X POST -H "Content-Type: $ct" -d "$data" "$url"
  elif command -v wget &>/dev/null; then
    wget -qO- --post-data="$data" --header="Content-Type: $ct" "$url"
  else
    echo "ERROR: Neither curl nor wget available" >&2
    return 1
  fi
}

# ── stdlib::net::port_open ────────────────────────────────────
# Check if a TCP port is open on a host.
# Usage: stdlib::net::port_open host port [timeout_s]
stdlib::net::port_open() {
  local host="$1" port="$2" timeout="${3:-2}"
  timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
}

# ── stdlib::net::dns_resolve ──────────────────────────────────
# Resolve hostname to first IP.
stdlib::net::dns_resolve() {
  local host="$1"
  getent hosts "$host" 2>/dev/null | awk '{print $1; exit}' || \
    dig +short "$host" 2>/dev/null | head -1 || \
    nslookup "$host" 2>/dev/null | awk '/^Address:/{a=$2} END{print a}'
}

# ── stdlib::net::retry ────────────────────────────────────────
# Retry a command with exponential backoff.
# Usage: stdlib::net::retry [max_attempts] [initial_delay] cmd [args...]
stdlib::net::retry() {
  local max="${1:-3}"; shift
  local delay="${1:-1}"; shift
  local attempt=1

  while true; do
    if "$@"; then
      return 0
    fi

    if (( attempt >= max )); then
      echo "ERROR: Command failed after $max attempts: $*" >&2
      return 1
    fi

    echo "WARN: Attempt $attempt/$max failed, retrying in ${delay}s..." >&2
    sleep "$delay"
    (( attempt++ ))
    delay=$(( delay * 2 ))
  done
}

# ── stdlib::net::wait_for_port ────────────────────────────────
# Wait for a port to become available.
# Usage: stdlib::net::wait_for_port host port [timeout_s] [interval_s]
stdlib::net::wait_for_port() {
  local host="$1" port="$2" timeout="${3:-30}" interval="${4:-1}"
  local deadline=$(( $(date +%s) + timeout ))

  while (( $(date +%s) < deadline )); do
    if stdlib::net::port_open "$host" "$port" 1; then
      return 0
    fi
    sleep "$interval"
  done

  echo "ERROR: Port $host:$port not available after ${timeout}s" >&2
  return 1
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.2.0)
# ══════════════════════════════════════════════════════════════

# ── stdlib::net::download ─────────────────────────────────────
# Download a URL to a destination file with fallback + optional chmod.
# Usage: stdlib::net::download url dest [mode]
stdlib::net::download() {
  local url="$1" dest="$2" mode="${3:-}"

  if command -v curl &>/dev/null; then
    curl -fsSL -o "$dest" "$url"
  elif command -v wget &>/dev/null; then
    wget -qO "$dest" "$url"
  else
    echo "ERROR: Neither curl nor wget available" >&2
    return 1
  fi

  [[ -n "$mode" ]] && chmod "$mode" "$dest"
}

# ── stdlib::net::http_status ──────────────────────────────────
# Return only the HTTP status code for a URL.
# Usage: stdlib::net::http_status url
stdlib::net::http_status() {
  local url="$1"
  curl -o /dev/null -s -w '%{http_code}' "$url" 2>/dev/null || echo "000"
}

# ── stdlib::net::url_reachable ────────────────────────────────
# Test if a URL is reachable (HEAD request, status 2xx/3xx).
# Usage: stdlib::net::url_reachable url
stdlib::net::url_reachable() {
  local url="$1"
  local status
  status=$(stdlib::net::http_status "$url")
  [[ "$status" =~ ^[23] ]]
}
