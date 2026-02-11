#!/usr/bin/env bash
# ─── Tiered Secrets Resolution ───────────────────────────────────────────
# Resolution order: env var → keyctl → age file → BWS
# Write-back: BWS fetch → keyctl + age file
#
# Usage:
#   source lib/secrets.sh
#   _secrets_init              # one-time setup (age key, dirs)
#   val=$(get_secret "GITHUB_PERSONAL_ACCESS_TOKEN")
# ─────────────────────────────────────────────────────────────────────────

SECRETS_DIR="${SECRETS_DIR:-${HOME}/.config/atn/secrets}"
SECRETS_AGE_KEY="${SECRETS_DIR}/age.key"
SECRETS_AGE_PUB="${SECRETS_DIR}/age.pub"
SECRETS_AGE_FILE="${SECRETS_DIR}/secrets.age"

# Track which secrets we know about (for age file serialization)
declare -A _SECRETS_KNOWN 2>/dev/null || true

# ─── Init: ensure dirs, age key, install deps ────────────────────────────
_secrets_init() {
  # Create secrets dir with strict perms
  mkdir -p "$SECRETS_DIR"
  chmod 0700 "$SECRETS_DIR"

  # Ensure age is installed
  if ! command -v age &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y -qq age 2>/dev/null || _install_age_binary
    else
      _install_age_binary
    fi
  fi

  # Ensure keyutils is installed (provides keyctl)
  if ! command -v keyctl &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y -qq keyutils 2>/dev/null || true
    fi
  fi

  # Generate age key if missing
  if [[ ! -f "$SECRETS_AGE_KEY" ]]; then
    log "Generating age encryption key..."
    age-keygen 2>/dev/null | tee "$SECRETS_AGE_KEY" | grep "^# public key:" | awk '{print $NF}' >"$SECRETS_AGE_PUB"
    chmod 0600 "$SECRETS_AGE_KEY"
    chmod 0644 "$SECRETS_AGE_PUB"
    ok "Age key generated at $SECRETS_AGE_KEY"
  elif [[ ! -f "$SECRETS_AGE_PUB" ]]; then
    # Regenerate pub from existing key
    grep "^# public key:" "$SECRETS_AGE_KEY" | awk '{print $NF}' >"$SECRETS_AGE_PUB"
  fi
}

# ─── Install age binary (fallback if apt doesn't have it) ────────────────
_install_age_binary() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  case "$arch" in
  amd64) arch="amd64" ;;
  arm64 | aarch64) arch="arm64" ;;
  *) arch="amd64" ;;
  esac

  local url="https://dl.filippo.io/age/latest?for=linux/${arch}"
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" | tar -xz -C "$tmp" 2>/dev/null; then
    sudo install -m 755 "$tmp"/age/age "$tmp"/age/age-keygen /usr/local/bin/
    ok "Installed age from binary"
  else
    warn "Could not install age. Secrets tier 3 (age file) will be unavailable."
  fi
  rm -rf "$tmp"
}

# ─── Get secret: the main resolver ───────────────────────────────────────
# Usage: get_secret "SECRET_NAME" ["fallback_keyword1" "fallback_keyword2" ...]
# Returns: the secret value, or empty string
get_secret() {
  local name="$1"
  shift
  local keywords=("$@")
  local val=""

  # ── Tier 1: Environment variable ──
  val="${!name:-}"
  if [[ -n "$val" ]]; then
    _SECRETS_KNOWN["$name"]="$val"
    return 0
  fi

  # ── Tier 2: Kernel keyring (keyctl) ──
  val="$(_keyctl_get "$name")"
  if [[ -n "$val" ]]; then
    # Also export as env var for this session
    export "$name=$val"
    _SECRETS_KNOWN["$name"]="$val"
    return 0
  fi

  # ── Tier 3: Encrypted age file ──
  if [[ -f "$SECRETS_AGE_FILE" ]] && command -v age &>/dev/null && [[ -f "$SECRETS_AGE_KEY" ]]; then
    # Decrypt the entire file, load ALL secrets into keyctl
    _secrets_load_age
    # Re-check keyctl after loading
    val="$(_keyctl_get "$name")"
    if [[ -n "$val" ]]; then
      export "$name=$val"
      _SECRETS_KNOWN["$name"]="$val"
      return 0
    fi
  fi

  # ── Tier 4: BWS (remote, last resort) ──
  if [[ -n "${BWS_ACCESS_TOKEN:-}" ]] || [[ -n "${BWS_SECRETS_JSON:-}" ]]; then
    # Ensure BWS secrets are loaded
    if [[ -z "${BWS_SECRETS_JSON:-}" ]] || [[ "$BWS_SECRETS_JSON" == "[]" ]]; then
      _bws_init_secrets 2>/dev/null || true
    fi

    if [[ -n "$BWS_SECRETS_JSON" && "$BWS_SECRETS_JSON" != "[]" ]]; then
      val="$(_bws_find_secret "$BWS_SECRETS_JSON" "$name" "${keywords[@]}")" || true
      if [[ -n "$val" ]]; then
        log "Secret '$name' resolved from BWS"
        export "$name=$val"
        _SECRETS_KNOWN["$name"]="$val"

        # Write-back: update keyctl AND re-encrypt age file
        _keyctl_set "$name" "$val"
        _secrets_save_age
        return 0
      fi
    fi
  fi

  # Not found anywhere
  return 1
}

# ─── keyctl helpers ──────────────────────────────────────────────────────
_keyctl_get() {
  local name="$1"
  if ! command -v keyctl &>/dev/null; then
    return 1
  fi
  local key_id
  key_id="$(keyctl request user "$name" 2>/dev/null)" || return 1
  keyctl pipe "$key_id" 2>/dev/null || return 1
}

_keyctl_set() {
  local name="$1"
  local value="$2"
  if ! command -v keyctl &>/dev/null; then
    return 1
  fi
  echo -n "$value" | keyctl padd user "$name" @u >/dev/null 2>&1 || return 1
}

# ─── Age file: save all known secrets ────────────────────────────────────
_secrets_save_age() {
  if ! command -v age &>/dev/null || [[ ! -f "$SECRETS_AGE_PUB" ]]; then
    return 1
  fi

  local pub
  pub="$(cat "$SECRETS_AGE_PUB" 2>/dev/null)"
  if [[ -z "$pub" ]]; then
    return 1
  fi

  # Build JSON from known secrets
  local json="{"
  local first=true
  for key in "${!_SECRETS_KNOWN[@]}"; do
    local escaped_val
    escaped_val="$(printf '%s' "${_SECRETS_KNOWN[$key]}" | jq -Rs .)"
    if $first; then
      json+="\"$key\":$escaped_val"
      first=false
    else
      json+=",\"$key\":$escaped_val"
    fi
  done
  json+="}"

  # Encrypt and write
  echo "$json" | age -r "$pub" -o "${SECRETS_AGE_FILE}.tmp" 2>/dev/null
  if [[ -f "${SECRETS_AGE_FILE}.tmp" ]]; then
    mv "${SECRETS_AGE_FILE}.tmp" "$SECRETS_AGE_FILE"
    chmod 0600 "$SECRETS_AGE_FILE"
  fi
}

# ─── Age file: decrypt and load all secrets into keyctl ──────────────────
_secrets_load_age() {
  if [[ ! -f "$SECRETS_AGE_FILE" ]] || [[ ! -f "$SECRETS_AGE_KEY" ]]; then
    return 1
  fi

  local json
  json="$(age -d -i "$SECRETS_AGE_KEY" "$SECRETS_AGE_FILE" 2>/dev/null)" || return 1

  if [[ -z "$json" ]]; then
    return 1
  fi

  # Parse JSON and load each key into keyctl + env + tracking
  local keys
  keys="$(echo "$json" | jq -r 'keys[]' 2>/dev/null)" || return 1

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    local val
    val="$(echo "$json" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null)"
    if [[ -n "$val" ]]; then
      _keyctl_set "$key" "$val"
      export "$key=$val"
      _SECRETS_KNOWN["$key"]="$val"
    fi
  done <<<"$keys"

  log "Loaded $(echo "$keys" | wc -l | tr -d ' ') secrets from age file"
}

# ─── Persist current secret state (call after bootstrap) ─────────────────
secrets_persist() {
  # Save all known secrets to age file
  _secrets_save_age
  local count="${#_SECRETS_KNOWN[@]}"
  if [[ "$count" -gt 0 ]]; then
    ok "Persisted $count secrets to encrypted age file"
  fi
}
