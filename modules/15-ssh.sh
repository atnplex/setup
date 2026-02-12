#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# Module: 15-ssh
# Purpose: SSH hardening — package installation, directory setup,
#          sshd configuration, and agent management
# Order:   After 01-core-policy (identity/layout/tmpfs must exist first)
#          Before networking modules (e.g. tailscale)
# Note:    Ported from main:modules/10-ssh.sh, modernized for
#          SYSTEM_*/NAMESPACE_* variable governance
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
stdlib::import sys/os
stdlib::import sys/pkg
stdlib::import sys/service

echo "[15-ssh] Configuring SSH..."

# ── 1. Ensure OpenSSH packages ───────────────────────────────────────
echo "[15-ssh] Ensuring OpenSSH packages..."

if declare -F stdlib::pkg::install &>/dev/null; then
  stdlib::pkg::install openssh-client
else
  sudo apt-get install -y -qq openssh-client 2>/dev/null || true
fi

# Install server on Debian/Ubuntu only
local_distro="$(stdlib::os::distro 2>/dev/null || echo unknown)"
case "$local_distro" in
  ubuntu|debian)
    if declare -F stdlib::pkg::install &>/dev/null; then
      stdlib::pkg::install openssh-server
    else
      sudo apt-get install -y -qq openssh-server 2>/dev/null || true
    fi

    # Enable and start sshd (idempotent)
    if declare -F stdlib::service::enable &>/dev/null; then
      stdlib::service::enable ssh
      stdlib::service::start ssh
    else
      sudo systemctl enable ssh 2>/dev/null || true
      sudo systemctl start ssh 2>/dev/null || true
    fi
    echo "[15-ssh] ✓ openssh-server installed and running"
    ;;
  *)
    echo "[15-ssh] Skipping openssh-server (non-Debian distro: ${local_distro})"
    ;;
esac

# ── 2. Configure SSH directory for system user ───────────────────────
echo "[15-ssh] Configuring SSH directory for ${SYSTEM_USERNAME}..."

local_home="$(eval echo ~"${SYSTEM_USERNAME}")"
ssh_dir="${local_home}/.ssh"

# Create .ssh with correct permissions (idempotent)
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
chown "${SYSTEM_USERNAME}:${SYSTEM_GROUPNAME}" "$ssh_dir"

# Ensure authorized_keys exists with correct perms
if [[ ! -f "${ssh_dir}/authorized_keys" ]]; then
  touch "${ssh_dir}/authorized_keys"
fi
chmod 600 "${ssh_dir}/authorized_keys"
chown "${SYSTEM_USERNAME}:${SYSTEM_GROUPNAME}" "${ssh_dir}/authorized_keys"

# If namespace has SSH configs, link them (graceful skip if missing)
ssh_config_dir="${NAMESPACE_ROOT_DIR}/configs/ssh"
if [[ -d "$ssh_config_dir" ]]; then
  _linked=0
  for cfg_file in "${ssh_config_dir}/"*; do
    [[ -f "$cfg_file" ]] || continue
    local_name="$(basename "$cfg_file")"
    target="${ssh_dir}/${local_name}"
    # Only link if not already linked or if stale
    if [[ ! -e "$target" ]] || [[ -L "$target" ]]; then
      ln -sfn "$cfg_file" "$target"
      chown -h "${SYSTEM_USERNAME}:${SYSTEM_GROUPNAME}" "$target"
      ((_linked++)) || true
    fi
  done
  if (( _linked > 0 )); then
    echo "[15-ssh] ✓ Linked ${_linked} SSH config(s) from ${ssh_config_dir}/"
  else
    echo "[15-ssh] ℹ SSH config dir exists but contains no files"
  fi
  unset _linked
else
  echo "[15-ssh] ℹ No SSH configs at ${ssh_config_dir} — skipping symlinks"
fi

# ── 3. Harden sshd_config (idempotent) ───────────────────────────────
SSHD_CONFIG="/etc/ssh/sshd_config"

_ssh_set_config() {
  local key="$1" value="$2"
  if grep -qE "^\s*${key}\s" "$SSHD_CONFIG" 2>/dev/null; then
    # Update existing line
    sudo sed -i "s|^\s*${key}\s.*|${key} ${value}|" "$SSHD_CONFIG"
  elif grep -qE "^#\s*${key}\s" "$SSHD_CONFIG" 2>/dev/null; then
    # Uncomment and set
    sudo sed -i "s|^#\s*${key}\s.*|${key} ${value}|" "$SSHD_CONFIG"
  else
    # Append
    echo "${key} ${value}" | sudo tee -a "$SSHD_CONFIG" >/dev/null
  fi
}

if [[ -f "$SSHD_CONFIG" ]]; then
  echo "[15-ssh] Hardening sshd_config..."
  _ssh_set_config "PermitRootLogin" "no"
  _ssh_set_config "PasswordAuthentication" "no"
  _ssh_set_config "ChallengeResponseAuthentication" "no"
  _ssh_set_config "UsePAM" "yes"
  _ssh_set_config "X11Forwarding" "no"
  _ssh_set_config "PrintMotd" "no"
  _ssh_set_config "AcceptEnv" "LANG LC_*"
  _ssh_set_config "MaxAuthTries" "3"
  _ssh_set_config "ClientAliveInterval" "300"
  _ssh_set_config "ClientAliveCountMax" "2"

  # Validate config before reloading
  if sudo sshd -t 2>/dev/null; then
    # Use systemctl reload directly — stdlib::service has no per-service reload
    sudo systemctl reload ssh 2>/dev/null \
      || sudo systemctl reload sshd 2>/dev/null \
      || sudo systemctl restart ssh 2>/dev/null \
      || sudo systemctl restart sshd 2>/dev/null \
      || true
    echo "[15-ssh] ✓ sshd_config hardened and reloaded"
  else
    echo "[15-ssh] ⚠ sshd_config validation failed — not reloading" >&2
  fi
fi

echo "[15-ssh] ✓ SSH module complete"
