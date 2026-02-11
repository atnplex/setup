#!/usr/bin/env bash
set -euo pipefail

# ─── VM1 Post-Bootstrap Fix Script ─────────────────────────────────────
# Run this on vm1 to fix what the bootstrap missed

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'
log() { echo -e "  ${BLUE}[FIX]${NC} $*"; }
ok() { echo -e "  ${GREEN}[✓]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[!]${NC} $*"; }
err() { echo -e "  ${RED}[✗]${NC} $*"; }

SOURCE_HOST="${1:-vps2}" # Default source to sync from

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  VM1 Post-Bootstrap Fix${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
echo ""

# ── 1. Fix Tailscale hostname + enable SSH + accept routes ──────────
log "Fixing Tailscale configuration..."
if command -v tailscale &>/dev/null; then
  current_ts_host="$(tailscale status --self --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo '')"
  system_host="$(hostname)"

  if [[ "$current_ts_host" != "$system_host" ]]; then
    log "Tailscale hostname '$current_ts_host' doesn't match system hostname '$system_host'"
    log "Re-running tailscale up with correct hostname, SSH, and routes..."
    sudo tailscale up --hostname="$system_host" --ssh --accept-routes --accept-dns 2>&1
    ok "Tailscale reconfigured: hostname=$system_host, ssh=on, accept-routes=on"
  else
    # Still ensure SSH and routes are enabled
    sudo tailscale set --ssh --accept-routes --accept-dns 2>/dev/null ||
      sudo tailscale up --hostname="$system_host" --ssh --accept-routes --accept-dns 2>&1
    ok "Tailscale already correct: $current_ts_host"
  fi

  echo "  Tailscale IP: $(tailscale ip -4 2>/dev/null)"
else
  err "Tailscale not installed!"
fi
echo ""

# ── 2. Generate SSH key if missing ──────────────────────────────────
log "Checking SSH keys..."
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  log "Generating SSH key..."
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "alex@$(hostname)"
  ok "SSH key generated"
else
  ok "SSH key exists"
fi
echo ""

# ── 3. Test Tailscale SSH to source ─────────────────────────────────
log "Testing Tailscale SSH to $SOURCE_HOST..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "alex@$SOURCE_HOST" 'echo ok' 2>/dev/null; then
  ok "SSH to $SOURCE_HOST works via Tailscale"
else
  warn "SSH to $SOURCE_HOST failed. Trying by IP..."
  SOURCE_IP="$(tailscale status --json 2>/dev/null | jq -r ".Peer[] | select(.HostName==\"$SOURCE_HOST\") | .TailscaleIPs[0]" 2>/dev/null || echo '')"
  if [[ -n "$SOURCE_IP" ]]; then
    SOURCE_HOST="$SOURCE_IP"
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "alex@$SOURCE_IP" 'echo ok' 2>/dev/null; then
      ok "SSH to $SOURCE_HOST works via IP"
    else
      err "Cannot SSH to $SOURCE_HOST. Fix Tailscale SSH on both ends first."
      err "On $SOURCE_HOST run: sudo tailscale set --ssh"
      exit 1
    fi
  else
    err "Cannot find $SOURCE_HOST in Tailscale mesh"
    exit 1
  fi
fi
echo ""

# ── 4. Sync brains/conversations ────────────────────────────────────
log "Syncing brains/conversations from $SOURCE_HOST..."
mkdir -p ~/.gemini/antigravity/brain
rsync -az --timeout=30 \
  "alex@${SOURCE_HOST}:~/.gemini/antigravity/brain/" \
  ~/.gemini/antigravity/brain/ 2>/dev/null &&
  ok "Brains synced: $(ls -1 ~/.gemini/antigravity/brain/ | wc -l) conversations" ||
  warn "Brain sync failed"
echo ""

# ── 5. Sync knowledge items ────────────────────────────────────────
log "Syncing knowledge items from $SOURCE_HOST..."
mkdir -p ~/.gemini/antigravity/knowledge
rsync -az --timeout=30 \
  "alex@${SOURCE_HOST}:~/.gemini/antigravity/knowledge/" \
  ~/.gemini/antigravity/knowledge/ 2>/dev/null &&
  ok "Knowledge synced: $(ls -1 ~/.gemini/antigravity/knowledge/ | wc -l) items" ||
  warn "Knowledge sync failed"
echo ""

# ── 6. Clone/sync repos from source ────────────────────────────────
log "Syncing repos from $SOURCE_HOST..."
mkdir -p /atn/github

# Get list of repos on source
REPOS="$(ssh -o ConnectTimeout=5 "alex@${SOURCE_HOST}" \
  'ls -1d /atn/github/*/  2>/dev/null | xargs -I{} basename {}' 2>/dev/null || echo '')"

if [[ -n "$REPOS" ]]; then
  while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    if [[ -d "/atn/github/$repo/.git" ]]; then
      ok "Repo $repo already exists — pulling updates"
      (cd "/atn/github/$repo" && git pull --quiet 2>/dev/null) || true
    else
      log "Syncing $repo..."
      rsync -az --timeout=60 \
        "alex@${SOURCE_HOST}:/atn/github/$repo/" \
        "/atn/github/$repo/" 2>/dev/null &&
        ok "Synced $repo" || warn "Failed to sync $repo"
    fi
  done <<<"$REPOS"
else
  warn "No repos found on $SOURCE_HOST or SSH failed"
fi
echo ""

# ── 7. Sync AG settings/scratch ────────────────────────────────────
log "Syncing AG settings..."
mkdir -p ~/.gemini/antigravity/scratch
rsync -az --timeout=30 \
  "alex@${SOURCE_HOST}:~/.gemini/antigravity/scratch/" \
  ~/.gemini/antigravity/scratch/ 2>/dev/null &&
  ok "Scratch/settings synced" || warn "Scratch sync failed"
echo ""

# ── 8. Verify Syncthing for ongoing sync ───────────────────────────
log "Checking Syncthing for continuous sync..."
if systemctl --user is-active syncthing &>/dev/null; then
  ok "Syncthing running (user service)"
elif systemctl is-active syncthing@alex &>/dev/null; then
  ok "Syncthing running (system service)"
elif command -v syncthing &>/dev/null; then
  warn "Syncthing installed but not running. Starting..."
  systemctl --user enable syncthing 2>/dev/null || true
  systemctl --user start syncthing 2>/dev/null || true
else
  warn "Syncthing not installed. Brains won't auto-sync."
fi
echo ""

# ── Summary ─────────────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Fix Summary${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
echo ""
echo "  Hostname:       $(hostname)"
echo "  Tailscale:      $(tailscale ip -4 2>/dev/null || echo 'N/A')"
echo "  TS Hostname:    $(tailscale status --self --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo 'N/A')"
echo "  Brains:         $(ls -1 ~/.gemini/antigravity/brain/ 2>/dev/null | wc -l) conversations"
echo "  Knowledge:      $(ls -1 ~/.gemini/antigravity/knowledge/ 2>/dev/null | wc -l) items"
echo "  Repos:          $(ls -1 /atn/github/ 2>/dev/null | wc -l) in /atn/github/"
echo "  Rules:          $(ls -1 /atn/.agent/rules/ 2>/dev/null | wc -l) in /atn/.agent/rules/"
echo ""
