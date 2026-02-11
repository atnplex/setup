MODULE_ID="sync_state"
MODULE_DESC="Sync private state (todo, preferences, recent brain) from another server via Tailscale"
MODULE_ORDER=90

module_supports_os() { return 0; }
module_requires_root() { return 1; } # No root needed

module_interactive_prompt() {
  echo "Sync private state (todo, preferences, recent brain data) from another server?"
}

module_run() {
  local atn_root="${NAMESPACE:-/atn}"
  local scratch_dir="$atn_root/.gemini/antigravity/scratch"
  local brain_dir="$atn_root/.gemini/antigravity/brain"

  # Derive source server from Tailscale mesh
  if ! command -v tailscale &>/dev/null; then
    log_warn "Tailscale not installed. Cannot sync state."
    return 1
  fi

  log_info "Discovering servers on Tailscale mesh..."
  local machines
  machines=$(tailscale status --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
peers = data.get('Peer', {})
for peer_id, peer in peers.items():
    if peer.get('Online', False):
        name = peer.get('HostName', 'unknown')
        ip = peer.get('TailscaleIPs', [''])[0]
        os_val = peer.get('OS', '')
        if os_val == 'linux' and name != '$(hostname -s)':
            print(f'{name}={ip}')
" 2>/dev/null)

  if [[ -z "$machines" ]]; then
    log_warn "No online Linux servers found on Tailscale mesh."
    return 0
  fi

  log_info "Available source servers:"
  local i=0
  declare -a names=() ips=()
  while IFS='=' read -r name ip; do
    ((i++)) || true
    names+=("$name")
    ips+=("$ip")
    log_info "  [$i] $name ($ip)"
  done <<<"$machines"

  local source_ip=""
  local source_name=""
  if [[ "$MODE" == "noninteractive" ]]; then
    # Non-interactive: use SYNC_SOURCE env var or first available
    if [[ -n "${SYNC_SOURCE:-}" ]]; then
      # Find by name or IP
      for idx in "${!names[@]}"; do
        if [[ "${names[$idx]}" == "$SYNC_SOURCE" || "${ips[$idx]}" == "$SYNC_SOURCE" ]]; then
          source_name="${names[$idx]}"
          source_ip="${ips[$idx]}"
          break
        fi
      done
    fi
    if [[ -z "$source_ip" ]]; then
      source_name="${names[0]}"
      source_ip="${ips[0]}"
    fi
  else
    echo -n "Select source server [1-$i] (or 'skip' to skip): "
    read -r choice
    if [[ "$choice" == "skip" ]]; then
      log_info "Skipping state sync"
      return 0
    fi
    local idx=$((choice - 1))
    source_name="${names[$idx]}"
    source_ip="${ips[$idx]}"
  fi

  log_info "Syncing from $source_name ($source_ip)..."

  # 1. Sync scratch state (todo, preferences, session_log)
  log_info "Syncing scratch state (todo, preferences, session_log)..."
  mkdir -p "$scratch_dir"
  rsync -az --timeout=30 \
    "${USER}@${source_ip}:${atn_root}/.gemini/antigravity/scratch/" \
    "$scratch_dir/" 2>/dev/null &&
    log_info "Scratch state synced" ||
    log_warn "Failed to sync scratch state"

  # 2. Sync recent brain/conversations (last 7 days)
  if [[ "${SYNC_BRAIN:-true}" == "true" ]]; then
    log_info "Syncing recent brain/conversations (last 7 days)..."
    mkdir -p "$brain_dir"

    # Get list of recent conversation dirs from source
    local recent_dirs
    recent_dirs=$(ssh -o ConnectTimeout=10 "${USER}@${source_ip}" \
      "find ${atn_root}/.gemini/antigravity/brain -maxdepth 1 -type d -mtime -7 2>/dev/null" \
      2>/dev/null | grep -v '^$')

    if [[ -n "$recent_dirs" ]]; then
      local count=0
      while IFS= read -r dir; do
        local basename
        basename=$(basename "$dir")
        if [[ "$basename" != "brain" ]]; then
          rsync -az --timeout=60 \
            "${USER}@${source_ip}:${dir}/" \
            "${brain_dir}/${basename}/" 2>/dev/null &&
            ((count++)) || true
        fi
      done <<<"$recent_dirs"
      log_info "Synced $count recent conversations"
    else
      log_info "No recent conversations found on source"
    fi
  fi

  # 3. Sync knowledge items
  local knowledge_dir="$HOME/.gemini/antigravity/knowledge"
  if ssh -o ConnectTimeout=10 "${USER}@${source_ip}" \
    "test -d ${HOME}/.gemini/antigravity/knowledge" 2>/dev/null; then
    log_info "Syncing knowledge items..."
    mkdir -p "$knowledge_dir"
    rsync -az --timeout=60 \
      "${USER}@${source_ip}:${knowledge_dir}/" \
      "$knowledge_dir/" 2>/dev/null &&
      log_info "Knowledge items synced" ||
      log_warn "Failed to sync knowledge items"
  fi

  log_info "State sync complete from $source_name"
}
