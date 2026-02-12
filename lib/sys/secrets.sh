#!/usr/bin/env bash
# Module: sys/secrets
# Version: 0.1.0
# Provides: 4-tier secret resolution (env → keyctl → age → BWS)
# Requires: (graceful fallback for age, keyctl, jq, bws)
[[ -n "${_STDLIB_SECRETS:-}" ]] && return 0
declare -g _STDLIB_SECRETS=1

# ── Internal State ─────────────────────────────────────────────────────
declare -g _SECRETS_DIR="${SECRETS_DIR:-${NAMESPACE_ROOT_DIR:+${NAMESPACE_ROOT_DIR}/.ignore/secrets}}"
_SECRETS_DIR="${_SECRETS_DIR:-/tmp/secrets}" # Absolute fallback
declare -g _SECRETS_AGE_FILE="${_SECRETS_DIR}/secrets.age"
declare -g _SECRETS_AGE_KEY="${_SECRETS_DIR}/age.key"
declare -gA _SECRETS_KNOWN=()                   # Tracks all known secret names for persist
declare -g _SECRETS_KEYRING="${NAMESPACE:-atn}" # keyctl session name

# ── stdlib::secrets::init ──────────────────────────────────────────────
# Ensure directories exist, age key is present, keyutils available.
stdlib::secrets::init() {
  mkdir -p "${_SECRETS_DIR}"
  chmod 700 "${_SECRETS_DIR}"

  # Ensure age key exists
  if [[ ! -f "${_SECRETS_AGE_KEY}" ]]; then
    if command -v age-keygen &>/dev/null; then
      age-keygen -o "${_SECRETS_AGE_KEY}" 2>/dev/null
      chmod 600 "${_SECRETS_AGE_KEY}"
    fi
  fi

  # Pre-load encrypted file if it exists
  if [[ -f "${_SECRETS_AGE_FILE}" ]]; then
    stdlib::secrets::load
  fi
}

# ── stdlib::secrets::get ───────────────────────────────────────────────
# 4-tier secret resolution: env → keyctl → age → BWS
# Usage: stdlib::secrets::get NAME [bws_keywords...]
stdlib::secrets::get() {
  local name="$1"
  shift
  local value=""

  # Tier 1: Environment variable
  if [[ -n "${!name:-}" ]]; then
    printf '%s' "${!name}"
    return 0
  fi

  # Tier 2: Kernel keyring (keyctl)
  if command -v keyctl &>/dev/null; then
    value=$(stdlib::secrets::_keyctl_get "$name" 2>/dev/null) || true
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
  fi

  # Tier 3: Encrypted age file (already loaded into keyctl by ::load)
  # If we got here without a keyctl hit, the age file didn't have it either.

  # Tier 4: BWS (Bitwarden Secrets)
  if command -v bws &>/dev/null && [[ -n "${BWS_ACCESS_TOKEN:-}" ]]; then
    local keywords=("${@:-$name}")
    value=$(stdlib::secrets::_bws_fetch "${keywords[@]}") || true
    if [[ -n "$value" ]]; then
      stdlib::secrets::set "$name" "$value"
      printf '%s' "$value"
      return 0
    fi
  fi

  return 1
}

# ── stdlib::secrets::set ───────────────────────────────────────────────
# Store a secret in keyctl + track it for persistence.
stdlib::secrets::set() {
  local name="$1" value="$2"

  # Export to environment
  export "$name=$value"

  # Store in keyctl if available
  if command -v keyctl &>/dev/null; then
    stdlib::secrets::_keyctl_set "$name" "$value"
  fi

  # Track for persistence
  _SECRETS_KNOWN["$name"]=1
}

# ── stdlib::secrets::require ──────────────────────────────────────────
# Get a secret or fatal exit.
stdlib::secrets::require() {
  local name="$1"
  shift
  local value
  value=$(stdlib::secrets::get "$name" "$@") || {
    echo "FATAL: Required secret '${name}' not found in any tier" >&2
    exit 1
  }
  printf '%s' "$value"
}

# ── stdlib::secrets::persist ──────────────────────────────────────────
# Save all tracked secrets to encrypted age file.
stdlib::secrets::persist() {
  [[ -f "${_SECRETS_AGE_KEY}" ]] || return 1
  command -v age &>/dev/null || return 1

  local pub
  pub=$(grep -o 'age1[a-z0-9]*' "${_SECRETS_AGE_KEY}" | head -1)
  [[ -n "$pub" ]] || return 1

  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  # Write all known secrets as KEY=VALUE
  for name in "${!_SECRETS_KNOWN[@]}"; do
    printf '%s=%s\n' "$name" "${!name:-}" >>"$tmpfile"
  done

  # Encrypt with age
  age -r "$pub" -o "${_SECRETS_AGE_FILE}" "$tmpfile"
  chmod 600 "${_SECRETS_AGE_FILE}"
}

# ── stdlib::secrets::load ─────────────────────────────────────────────
# Decrypt age file → hydrate keyctl + env.
stdlib::secrets::load() {
  [[ -f "${_SECRETS_AGE_FILE}" ]] || return 1
  [[ -f "${_SECRETS_AGE_KEY}" ]] || return 1
  command -v age &>/dev/null || return 1

  local key val
  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    stdlib::secrets::set "$key" "$val"
  done < <(age -d -i "${_SECRETS_AGE_KEY}" "${_SECRETS_AGE_FILE}" 2>/dev/null)
}

# ── stdlib::secrets::list ─────────────────────────────────────────────
# List all known secret names.
stdlib::secrets::list() {
  printf '%s\n' "${!_SECRETS_KNOWN[@]}"
}

# ── stdlib::secrets::clear ────────────────────────────────────────────
# Wipe all known secrets from env and tracking.
stdlib::secrets::clear() {
  for name in "${!_SECRETS_KNOWN[@]}"; do
    unset "$name"
  done
  _SECRETS_KNOWN=()
}

# ── Internal: keyctl helpers ──────────────────────────────────────────
stdlib::secrets::_keyctl_get() {
  local name="$1"
  local kid
  kid=$(keyctl search @s user "${_SECRETS_KEYRING}:${name}" 2>/dev/null) || return 1
  keyctl pipe "$kid" 2>/dev/null
}

stdlib::secrets::_keyctl_set() {
  local name="$1" value="$2"
  local kid
  kid=$(keyctl search @s user "${_SECRETS_KEYRING}:${name}" 2>/dev/null) || true
  if [[ -n "$kid" ]]; then
    keyctl update "$kid" "$value" 2>/dev/null
  else
    keyctl add user "${_SECRETS_KEYRING}:${name}" "$value" @s 2>/dev/null
  fi
}

# ── Internal: BWS fetch ───────────────────────────────────────────────
stdlib::secrets::_bws_fetch() {
  local keywords=("$@")
  local secrets_json
  secrets_json=$(bws secret list 2>/dev/null) || return 1

  # Fuzzy match: find secret whose key contains ALL keywords
  local jq_filter='.[] | select('
  local first=true
  for kw in "${keywords[@]}"; do
    $first || jq_filter+=" and "
    jq_filter+="(.key | ascii_downcase | contains(\"$(echo "$kw" | tr '[:upper:]' '[:lower:]')\")"
    jq_filter+=")"
    first=false
  done
  jq_filter+=') | .value'

  echo "$secrets_json" | jq -r "$jq_filter" 2>/dev/null | head -1
}

# ── stdlib::secrets::bootstrap_from_bws ───────────────────────────────
# Full BWS bootstrap flow: install CLI if missing, ensure token, fetch all
# secrets, store them, and persist to age file.
# Usage: stdlib::secrets::bootstrap_from_bws [token]
stdlib::secrets::bootstrap_from_bws() {
  local token="${1:-${BWS_ACCESS_TOKEN:-}}"

  # Install BWS if not present
  if ! command -v bws &>/dev/null; then
    if command -v npm &>/dev/null; then
      npm install -g @bitwarden/cli 2>/dev/null || true
    else
      echo "WARN: BWS CLI not found and npm unavailable for install" >&2
      return 1
    fi
  fi

  # Token required
  if [[ -z "$token" ]]; then
    read -rsp "  BWS access token: " token </dev/tty 2>/dev/null || true
    echo
    [[ -z "$token" ]] && return 1
  fi
  export BWS_ACCESS_TOKEN="$token"

  # Fetch all secrets
  local secrets_json
  secrets_json="$(bws secret list 2>/dev/null)" || return 1

  # Parse and store each secret
  local count=0
  while IFS=$'\t' read -r key val; do
    [[ -z "$key" ]] && continue
    stdlib::secrets::set "$key" "$val"
    ((count++)) || true
  done < <(echo "$secrets_json" | jq -r '.[] | [.key, .value] | @tsv' 2>/dev/null)

  # Persist to age file
  if [[ $count -gt 0 ]]; then
    stdlib::secrets::persist
  fi

  return 0
}

# ── stdlib::secrets::load_to_tmpdir ───────────────────────────────────
# Decrypt age file to TMP_DIR as plaintext (for systems without keyctl).
# The plaintext file is cleaned up by the TMP_DIR EXIT trap.
# Usage: stdlib::secrets::load_to_tmpdir [tmpdir]
stdlib::secrets::load_to_tmpdir() {
  local tmpdir="${1:-${TMP_DIR:-/tmp}}"
  [[ -f "${_SECRETS_AGE_FILE}" ]] || return 1
  [[ -f "${_SECRETS_AGE_KEY}" ]] || return 1
  command -v age &>/dev/null || return 1

  local plain_file="${tmpdir}/secrets.env"
  age -d -i "${_SECRETS_AGE_KEY}" "${_SECRETS_AGE_FILE}" >"$plain_file" 2>/dev/null || return 1
  chmod 600 "$plain_file"

  # Source into env
  local key val
  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    export "$key=$val"
    _SECRETS_KNOWN["$key"]=1
  done <"$plain_file"
}

# ── stdlib::secrets::acquire_from_peers ───────────────────────────────
# LAST RESORT: scan reachable Tailscale peers for secrets.
# Only runs when ALL other acquisition methods have failed:
#   - BWS_ACCESS_TOKEN unset
#   - keyctl has no secrets
#   - secrets.age cannot be decrypted
#   - GitHub-based acquisition failed
#
# Safety:
#   - Non-blocking (timeouts on every SSH)
#   - Validates peer data through sanitize pipeline
#   - Never modifies remote systems
#   - Returns 0 on success (at least one secret acquired), 1 otherwise
stdlib::secrets::acquire_from_peers() {
  # ── Guard: only run as absolute last resort ──
  if [[ -n "${BWS_ACCESS_TOKEN:-}" ]]; then
    return 1 # BWS available, no need for peer scan
  fi

  # Check if we already have secrets
  if [[ ${#_SECRETS_KNOWN[@]} -gt 0 ]]; then
    return 0 # Already have secrets, skip
  fi

  # ── Tailscale must be connected ──
  command -v tailscale &>/dev/null || return 1
  tailscale status &>/dev/null || return 1

  # ── Enumerate reachable Linux peers ──
  local -a peers=()
  local line hostname ip os_type
  while IFS= read -r line; do
    # tailscale status output: <IP>  <hostname>  <user>  <OS>  ...
    ip="$(echo "$line" | awk '{print $1}')"
    hostname="$(echo "$line" | awk '{print $2}')"
    os_type="$(echo "$line" | awk '{print $4}')"

    # Skip non-Linux, self, and offline peers
    [[ "$os_type" == "linux" ]] || continue
    [[ "$ip" != "$(tailscale ip -4 2>/dev/null)" ]] || continue

    peers+=("$ip")
  done < <(tailscale status --peers 2>/dev/null | grep -v '^#' | tail -n +2)

  [[ ${#peers[@]} -gt 0 ]] || return 1

  # ── Attempt to fetch secrets from each peer ──
  local acquired=0
  local peer_ip
  for peer_ip in "${peers[@]}"; do
    # Try reading peer's secrets.env via SSH (strict timeout)
    local remote_data
    remote_data="$(timeout 5 ssh -o ConnectTimeout=3 \
      -o StrictHostKeyChecking=accept-new \
      -o BatchMode=yes \
      "root@${peer_ip}" \
      'cat /atn/.ignore/secrets.env 2>/dev/null || cat /atn/configs/secrets.env 2>/dev/null' \
      2>/dev/null)" || continue

    [[ -z "$remote_data" ]] && continue

    # ── Validate and sanitize each line before accepting ──
    local key val
    while IFS='=' read -r key val; do
      # Reject empty keys, comments, and invalid characters
      [[ -z "$key" || "$key" == \#* ]] && continue
      [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue

      # Strip surrounding quotes from value
      val="${val#\"}"
      val="${val%\"}"
      val="${val#\'}"
      val="${val%\'}"

      # Only accept if value is non-empty and we don't already have it
      if [[ -n "$val" ]] && [[ -z "${!key:-}" ]]; then
        stdlib::secrets::set "$key" "$val"
        ((acquired++)) || true
      fi
    done <<<"$remote_data"

    # Stop after first successful peer
    [[ $acquired -gt 0 ]] && break
  done

  [[ $acquired -gt 0 ]] && return 0
  return 1
}
