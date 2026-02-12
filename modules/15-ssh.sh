#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# Module: 15-ssh
# Purpose: SSH hardening — key management, sshd configuration, agent
# Order:   After 01-core-policy (identity/layout/tmpfs must exist first)
#          Before networking modules (e.g. tailscale)
# Note:    Renamed from 10-ssh.sh to enforce correct execution order
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/lib/stdlib.sh" ]]; then
  echo "FATAL: stdlib.sh not found at ${REPO_ROOT}/lib/stdlib.sh" >&2
  exit 1
fi

# shellcheck source=../lib/stdlib.sh
source "${REPO_ROOT}/lib/stdlib.sh"

echo "[15-ssh] SSH hardening module (stub — populate with SSH logic)"

# TODO: Implement SSH hardening:
#   - Generate/deploy SSH host keys
#   - Harden sshd_config (disable password auth, root login, etc.)
#   - Configure SSH agent forwarding
#   - Deploy authorized_keys from secrets

echo "[15-ssh] ✓ SSH module complete"
