#!/usr/bin/env bash
# Module: sys/secrets
# Version: 0.1.0
# Provides: 4-tier secret resolution (env → keyctl → age → BWS)
# Requires: (graceful fallback for age, keyctl, jq, bws)
[[ -n "${_STDLIB_SECRETS:-}" ]] && return 0
declare -g _STDLIB_SECRETS=1

# ── Internal State ─────────────────────────────────────────────────────
declare -g _SECRETS_DIR="${SECRETS_DIR:-/atn/.ignore/secrets}"
declare -g _SECRETS_AGE_FILE="${_SECRETS_DIR}/secrets.age"
declare -g _SECRETS_AGE_KEY="${_SECRETS_DIR}/age.key"
declare -gA _SECRETS_KNOWN=()      # Tracks all known secret names for persist
declare -g _SECRETS_KEYRING="atn"   # keyctl session name

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
  local name="$1"; shift
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
  local name="$1"; shift
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
    printf '%s=%s\n' "$name" "${!name:-}" >> "$tmpfile"
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

  local line key val
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
