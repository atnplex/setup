#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# sys/user.sh — Identity enforcement (user, group, UID, GID)
# ═══════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_USER:-}" ]] && return 0
readonly _STDLIB_MOD_USER=1
_STDLIB_MOD_VERSION="1.0.0"

stdlib::import core/log

# ── Enforce user and group with correct UID/GID ──────────────────────
stdlib::user::enforce() {
  local user="${BOOTSTRAP_USER:?BOOTSTRAP_USER not set}"
  local group="${BOOTSTRAP_GROUP:?BOOTSTRAP_GROUP not set}"
  local uid="${BOOTSTRAP_UID:?BOOTSTRAP_UID not set}"
  local gid="${BOOTSTRAP_GID:?BOOTSTRAP_GID not set}"

  # Ensure group
  if ! getent group "${group}" >/dev/null 2>&1; then
    groupadd --gid "${gid}" "${group}"
    stdlib::log::info "Created group: ${group} (${gid})"
  else
    local current_gid
    current_gid="$(getent group "${group}" | cut -d: -f3)"
    if [[ "${current_gid}" != "${gid}" ]]; then
      groupmod --gid "${gid}" "${group}"
      stdlib::log::warn "Fixed group GID: ${group} ${current_gid} -> ${gid}"
    fi
  fi

  # Ensure user
  if ! id "${user}" >/dev/null 2>&1; then
    useradd \
      --uid "${uid}" \
      --gid "${gid}" \
      --create-home \
      --shell /bin/bash \
      "${user}"
    stdlib::log::info "Created user: ${user} (${uid}:${gid})"
  else
    local current_uid current_gid
    current_uid="$(id -u "${user}")"
    current_gid="$(id -g "${user}")"
    if [[ "${current_uid}" != "${uid}" ]]; then
      usermod --uid "${uid}" "${user}"
      stdlib::log::warn "Fixed UID: ${user} ${current_uid} -> ${uid}"
    fi
    if [[ "${current_gid}" != "${gid}" ]]; then
      usermod --gid "${gid}" "${user}"
      stdlib::log::warn "Fixed GID: ${user} ${current_gid} -> ${gid}"
    fi
  fi

  # Add to docker group if available
  if getent group docker >/dev/null 2>&1; then
    usermod -aG docker "${user}" 2>/dev/null || true
  fi

  stdlib::user::verify
}

# ── Verify identity matches expected values ──────────────────────────
stdlib::user::verify() {
  local user="${BOOTSTRAP_USER:?BOOTSTRAP_USER not set}"
  local uid="${BOOTSTRAP_UID:?BOOTSTRAP_UID not set}"
  local gid="${BOOTSTRAP_GID:?BOOTSTRAP_GID not set}"

  local actual_uid actual_gid
  actual_uid="$(id -u "${user}" 2>/dev/null)" || {
    stdlib::log::error "User ${user} does not exist"
    return 1
  }
  actual_gid="$(id -g "${user}" 2>/dev/null)"

  if [[ "${actual_uid}" != "${uid}" || "${actual_gid}" != "${gid}" ]]; then
    stdlib::log::error "Identity mismatch: expected ${uid}:${gid}, got ${actual_uid}:${actual_gid}"
    return 1
  fi

  stdlib::log::info "Identity verified: ${user} (${uid}:${gid})"
}
