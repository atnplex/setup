#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# Module: 01-core-policy
# Purpose: First-run policy enforcement — identity, layout, tmpfs, symlinks
# Order:   MUST execute before all other modules
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
stdlib::import sys/user
stdlib::import fs/layout
stdlib::import sys/tmpfs
stdlib::import sys/fstab

# ── 1. Identity Enforcement ──────────────────────────────────────────
echo "[01-core-policy] Enforcing identity: ${SYSTEM_USERNAME}:${SYSTEM_GROUPNAME} (${SYSTEM_USER_UID}:${SYSTEM_GROUP_GID})"

stdlib::user::ensure_identity \
    "$SYSTEM_USERNAME" \
    "$SYSTEM_GROUPNAME" \
    "$SYSTEM_USER_UID" \
    "$SYSTEM_GROUP_GID" \
    "docker" "sudo"

# ── 2. Layout Enforcement ────────────────────────────────────────────
echo "[01-core-policy] Enforcing namespace layout: ${NAMESPACE_ROOT_DIR}"

stdlib::layout::ensure_all \
    "$NAMESPACE_ROOT_DIR" \
    "$NAMESPACE" \
    "$SYSTEM_USERNAME" \
    "$SYSTEM_GROUPNAME"

# ── 3. Tmpfs Mount ───────────────────────────────────────────────────
echo "[01-core-policy] Ensuring tmpfs at ${NAMESPACE_ROOT_DIR}/tmp"

stdlib::tmpfs::ensure_mount \
    "$NAMESPACE_ROOT_DIR/tmp" \
    "50%" \
    "1777" \
    "$SYSTEM_USER_UID" \
    "$SYSTEM_GROUP_GID"

export TMPDIR="$NAMESPACE_ROOT_DIR/tmp"
echo "[01-core-policy] TMPDIR=${TMPDIR}"

# Create volatile subdirs
mkdir -p "$NAMESPACE_ROOT_DIR/tmp/.cache" \
         "$NAMESPACE_ROOT_DIR/tmp/.lock"
chown "$SYSTEM_USERNAME:$SYSTEM_GROUPNAME" \
      "$NAMESPACE_ROOT_DIR/tmp/.cache" \
      "$NAMESPACE_ROOT_DIR/tmp/.lock"

# ── 4. Symlinks ──────────────────────────────────────────────────────
# KEEP: ~/atn → /atn
local_home="$(eval echo ~"${SYSTEM_USERNAME}")"
if [[ ! -L "${local_home}/atn" ]]; then
  ln -sfn "${NAMESPACE_ROOT_DIR}" "${local_home}/atn"
  echo "[01-core-policy] Symlink: ${local_home}/atn → ${NAMESPACE_ROOT_DIR}"
fi

# REMOVE: ~/configs symlink (declutter)
if [[ -L "${local_home}/configs" ]]; then
  rm -f "${local_home}/configs"
  echo "[01-core-policy] Removed symlink: ${local_home}/configs"
fi

echo "[01-core-policy] ✓ Core policy enforced"
