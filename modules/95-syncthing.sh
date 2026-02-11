MODULE_ID="syncthing"
MODULE_DESC="Install Syncthing and auto-configure sync with Tailscale peers"
MODULE_ORDER=95

module_supports_os() {
  case "$OS_ID" in
    ubuntu|debian) return 0 ;;
    *) return 1 ;;
  esac
}

module_requires_root() { return 0; }

# ─── Helpers ─────────────────────────────────────────────────────────────

_st_api() {
  # Syncthing REST API call via CLI (no API key needed)
  syncthing cli "$@" 2>/dev/null
}

_st_wait_ready() {
  local max_wait=30
  local waited=0
  while [[ $waited -lt $max_wait ]]; do
    if syncthing cli show system 2>/dev/null | grep -q "myID"; then
      return 0
    fi
    sleep 1
    ((waited++))
  done
  return 1
}

_st_get_device_id() {
  syncthing cli show system 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('myID', ''))
" 2>/dev/null
}

_st_device_exists() {
  local device_id="$1"
  syncthing cli config devices list 2>/dev/null | grep -q "$device_id"
}

_st_folder_exists() {
  local folder_id="$1"
  syncthing cli config folders list 2>/dev/null | grep -q "$folder_id"
}

_ts_discover_peers() {
  # Find online Linux peers on the Tailscale mesh (excluding self)
  local self_hostname
  self_hostname="$(hostname -s)"
  tailscale status --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
peers = data.get('Peer', {})
self_host = '$self_hostname'
for peer_id, peer in peers.items():
    if peer.get('Online', False):
        name = peer.get('HostName', 'unknown')
        ip = peer.get('TailscaleIPs', [''])[0]
        os_val = peer.get('OS', '')
        if os_val == 'linux' and name != self_host:
            print(f'{name}={ip}')
" 2>/dev/null
}

_remote_st_device_id() {
  local user="$1" ip="$2"
  ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
    "${user}@${ip}" "syncthing cli show system 2>/dev/null" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('myID', ''))
except:
    pass
" 2>/dev/null
}

_remote_add_device() {
  local user="$1" ip="$2" device_id="$3" device_name="$4"
  ssh -o ConnectTimeout=10 -o BatchMode=yes \
    "${user}@${ip}" "
    if syncthing cli config devices list 2>/dev/null | grep -q '$device_id'; then
      echo 'ALREADY_EXISTS'
    else
      syncthing cli config devices add --device-id '$device_id' --name '$device_name' 2>/dev/null && echo 'ADDED' || echo 'FAILED'
    fi
  " 2>/dev/null
}

_remote_share_folder() {
  local user="$1" ip="$2" folder_id="$3" device_id="$4"
  ssh -o ConnectTimeout=10 -o BatchMode=yes \
    "${user}@${ip}" "
    if syncthing cli config folders '$folder_id' devices list 2>/dev/null | grep -q '$device_id'; then
      echo 'ALREADY_SHARED'
    else
      syncthing cli config folders '$folder_id' devices add --device-id '$device_id' 2>/dev/null && echo 'SHARED' || echo 'FAILED'
    fi
  " 2>/dev/null
}

# ─── Main module ─────────────────────────────────────────────────────────

module_run() {
  local atn_root="${NAMESPACE:?NAMESPACE must be set}"

  # ── Step 1: Install Syncthing (idempotent) ──────────────────────────
  if command -v syncthing &>/dev/null; then
    local current_version
    current_version="$(syncthing --version 2>/dev/null | awk '{print $2}')"
    log_info "Syncthing already installed: $current_version"
  else
    log_info "Installing Syncthing from official Debian repo..."

    # Add Syncthing release PGP key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://syncthing.net/release-key.gpg | sudo tee /etc/apt/keyrings/syncthing-archive-keyring.gpg >/dev/null

    # Add the stable channel repo
    echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" \
      | sudo tee /etc/apt/sources.list.d/syncthing.list >/dev/null

    sudo apt-get update -qq
    sudo apt-get install -y syncthing
    log_info "Syncthing installed: $(syncthing --version 2>/dev/null | awk '{print $2}')"
  fi

  # ── Step 2: Enable and start as systemd user service (idempotent) ───
  if systemctl --user is-active syncthing &>/dev/null; then
    log_info "Syncthing service already running"
  else
    log_info "Enabling Syncthing systemd user service..."
    # Enable lingering so user services run without active session
    sudo loginctl enable-linger "$USER" 2>/dev/null || true
    systemctl --user enable syncthing 2>/dev/null || true
    systemctl --user start syncthing 2>/dev/null || true

    if systemctl --user is-active syncthing &>/dev/null; then
      log_info "Syncthing service started"
    else
      log_warn "Syncthing service failed to start. Trying direct start..."
      # Fallback: start syncthing directly to generate config
      syncthing serve --no-browser --no-default-folder &>/dev/null &
      local st_pid=$!
      sleep 5
      kill "$st_pid" 2>/dev/null || true
      systemctl --user start syncthing 2>/dev/null || true
    fi
  fi

  # Wait for Syncthing API to be ready
  log_info "Waiting for Syncthing to be ready..."
  if ! _st_wait_ready; then
    log_error "Syncthing API not responding after 30s"
    return 1
  fi

  local my_device_id
  my_device_id="$(_st_get_device_id)"
  local my_hostname
  my_hostname="$(hostname -s)"
  log_info "Local device ID: ${my_device_id:0:12}..."

  # ── Step 3: Configure shared folders (idempotent) ───────────────────
  declare -A SYNC_FOLDERS=(
    ["atn-brain"]="${atn_root}/.gemini/antigravity/brain"
    ["atn-scratch"]="${atn_root}/.gemini/antigravity/scratch"
    ["atn-knowledge"]="${HOME}/.gemini/antigravity/knowledge"
  )

  for folder_id in "${!SYNC_FOLDERS[@]}"; do
    local folder_path="${SYNC_FOLDERS[$folder_id]}"
    mkdir -p "$folder_path"

    if _st_folder_exists "$folder_id"; then
      log_info "Folder '$folder_id' already configured"
    else
      log_info "Adding folder '$folder_id' → $folder_path"
      syncthing cli config folders add \
        --id "$folder_id" \
        --path "$folder_path" \
        --label "$folder_id" 2>/dev/null

      # Set folder to "send & receive" and ignore permissions
      syncthing cli config folders "$folder_id" set \
        --type "sendreceive" \
        --ignore-perms true 2>/dev/null || true

      log_info "Folder '$folder_id' added"
    fi
  done

  # ── Step 4: Discover and pair with Tailscale peers (idempotent) ─────
  if ! command -v tailscale &>/dev/null; then
    log_warn "Tailscale not available. Skipping peer discovery."
    log_info "Syncthing installed and running — add devices manually via GUI at http://localhost:8384"
    return 0
  fi

  log_info "Discovering Tailscale peers..."
  local peers
  peers="$(_ts_discover_peers)"

  if [[ -z "$peers" ]]; then
    log_info "No online Linux peers found on Tailscale. You can add them later."
    return 0
  fi

  while IFS='=' read -r peer_name peer_ip; do
    [[ -z "$peer_name" ]] && continue
    log_info "Checking peer: $peer_name ($peer_ip)..."

    # Try to get peer's Syncthing device ID
    local peer_device_id
    peer_device_id="$(_remote_st_device_id "$USER" "$peer_ip")"

    if [[ -z "$peer_device_id" ]]; then
      # Try as root (for Unraid)
      peer_device_id="$(_remote_st_device_id "root" "$peer_ip")"
    fi

    if [[ -z "$peer_device_id" ]]; then
      log_info "  → Syncthing not running on $peer_name. Skipping."
      continue
    fi

    log_info "  → Device ID: ${peer_device_id:0:12}..."

    # Add peer's device locally (idempotent)
    if _st_device_exists "$peer_device_id"; then
      log_info "  → Device already known locally"
    else
      log_info "  → Adding device to local config..."
      syncthing cli config devices add \
        --device-id "$peer_device_id" \
        --name "$peer_name" \
        --address "tcp://${peer_ip}:22000" 2>/dev/null
      log_info "  → Device added"
    fi

    # Share folders with peer (idempotent)
    for folder_id in "${!SYNC_FOLDERS[@]}"; do
      local shared
      shared=$(syncthing cli config folders "$folder_id" devices list 2>/dev/null | grep -c "$peer_device_id" || echo "0")
      if [[ "$shared" -gt 0 ]]; then
        log_info "  → Folder '$folder_id' already shared with $peer_name"
      else
        syncthing cli config folders "$folder_id" devices add \
          --device-id "$peer_device_id" 2>/dev/null
        log_info "  → Shared folder '$folder_id' with $peer_name"
      fi
    done

    # Add this device to the remote peer (bidirectional, idempotent)
    log_info "  → Setting up bidirectional sync on $peer_name..."
    local remote_user="$USER"
    # Check if peer is Unraid (typically uses root)
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${peer_ip}" "test -d /mnt/user" 2>/dev/null; then
      remote_user="root"
    fi

    local add_result
    add_result="$(_remote_add_device "$remote_user" "$peer_ip" "$my_device_id" "$my_hostname")"
    case "$add_result" in
      ALREADY_EXISTS) log_info "  → This device already known on $peer_name" ;;
      ADDED)          log_info "  → This device added to $peer_name" ;;
      *)              log_warn "  → Could not add this device to $peer_name: $add_result" ;;
    esac

    # Share folders on the remote side too
    for folder_id in "${!SYNC_FOLDERS[@]}"; do
      local share_result
      share_result="$(_remote_share_folder "$remote_user" "$peer_ip" "$folder_id" "$my_device_id")"
      case "$share_result" in
        ALREADY_SHARED) log_info "  → Folder '$folder_id' already shared on $peer_name" ;;
        SHARED)         log_info "  → Folder '$folder_id' shared on $peer_name" ;;
        *)              log_info "  → Folder '$folder_id' not yet on $peer_name (will auto-accept)" ;;
      esac
    done

  done <<< "$peers"

  # ── Step 5: Set Syncthing to listen on Tailscale IP ─────────────────
  if command -v tailscale &>/dev/null; then
    local ts_ip
    ts_ip="$(tailscale ip -4 2>/dev/null || echo '')"
    if [[ -n "$ts_ip" ]]; then
      log_info "Configuring Syncthing to listen on Tailscale IP ($ts_ip)..."
      syncthing cli config options set \
        --listen-address "tcp://${ts_ip}:22000" \
        --listen-address "tcp://0.0.0.0:22000" 2>/dev/null || true
    fi
  fi

  # ── Summary ─────────────────────────────────────────────────────────
  echo ""
  log_info "Syncthing setup complete!"
  log_info "  Web GUI: http://localhost:8384"
  log_info "  Device ID: ${my_device_id:0:20}..."
  log_info "  Synced folders:"
  for folder_id in "${!SYNC_FOLDERS[@]}"; do
    log_info "    • $folder_id → ${SYNC_FOLDERS[$folder_id]}"
  done
}
