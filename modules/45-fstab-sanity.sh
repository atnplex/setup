#!/usr/bin/env bash
# Module: 45-fstab-sanity
# Description: Validate /etc/fstab entries — log warnings only, never modify.
# Requires: stdlib (core/log)
# Idempotent: YES
set -euo pipefail

# ── Source stdlib ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/stdlib.sh
source "${SCRIPT_DIR}/lib/stdlib.sh"
stdlib::import core/log

stdlib::log::info "45-fstab-sanity: Validating /etc/fstab"

readonly FSTAB="/etc/fstab"
issues=0

if [[ ! -f "$FSTAB" ]]; then
  stdlib::log::warn "45-fstab-sanity: /etc/fstab not found — skipping"
  exit 0
fi

# ── Check for duplicate mountpoints ───────────────────────────────────
declare -A seen_mountpoints=()
while IFS= read -r line; do
  # Skip comments and blank lines
  [[ -z "$line" || "$line" == \#* ]] && continue

  mountpoint="$(echo "$line" | awk '{print $2}')"
  [[ -z "$mountpoint" ]] && continue

  if [[ -n "${seen_mountpoints[$mountpoint]:-}" ]]; then
    stdlib::log::warn "45-fstab-sanity: Duplicate mountpoint: ${mountpoint}"
    ((issues++)) || true
  else
    seen_mountpoints["$mountpoint"]=1
  fi
done <"$FSTAB"

# ── Check for tmpfs entries with valid options ────────────────────────
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue

  fstype="$(echo "$line" | awk '{print $3}')"
  mountpoint="$(echo "$line" | awk '{print $2}')"
  options="$(echo "$line" | awk '{print $4}')"

  if [[ "$fstype" == "tmpfs" ]]; then
    # Validate size option exists
    if ! echo "$options" | grep -q "size="; then
      stdlib::log::warn "45-fstab-sanity: tmpfs at ${mountpoint} has no size option"
      ((issues++)) || true
    fi
    # Validate mode option is valid
    if echo "$options" | grep -qE "mode=[0-9]+" 2>/dev/null; then
      mode_val="$(echo "$options" | grep -oE 'mode=[0-9]+' | cut -d= -f2)"
      if [[ ${#mode_val} -ne 3 && ${#mode_val} -ne 4 ]]; then
        stdlib::log::warn "45-fstab-sanity: tmpfs at ${mountpoint} has invalid mode: ${mode_val}"
        ((issues++)) || true
      fi
    fi
  fi

  # Validate field count (should have 6 fields)
  field_count="$(echo "$line" | awk '{print NF}')"
  if [[ "$field_count" -lt 4 ]]; then
    stdlib::log::warn "45-fstab-sanity: Malformed line (${field_count} fields): ${line}"
    ((issues++)) || true
  fi
done <"$FSTAB"

# ── Summary ───────────────────────────────────────────────────────────
if [[ "$issues" -eq 0 ]]; then
  stdlib::log::ok "45-fstab-sanity: All fstab entries valid"
else
  stdlib::log::warn "45-fstab-sanity: Found ${issues} issue(s) — review manually (no changes made)"
fi

stdlib::log::ok "45-fstab-sanity: Complete"
