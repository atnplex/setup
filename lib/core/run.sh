#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# core/run.sh — Bootstrap orchestrator
#
# Imports all stdlib modules and executes them in the correct
# secrets-first order. Contains NO business logic — only sequencing.
# ═══════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_RUN:-}" ]] && return 0
readonly _STDLIB_MOD_RUN=1
_STDLIB_MOD_VERSION="1.0.0"

# ── Import all required modules ─────────────────────────────────────
stdlib::import core/log
stdlib::import data/config
stdlib::import sys/tmpfs
stdlib::import sys/secrets
stdlib::import sys/probe
stdlib::import sys/user
stdlib::import sys/service
stdlib::import fs/layout
stdlib::import fs/symlink

# ── Section banner helper ───────────────────────────────────────────
stdlib::run::_section() {
  printf '\n━━━ %s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$1"
}

# ── Main entry point ────────────────────────────────────────────────
stdlib::run::bootstrap_main() {
  stdlib::log::info "Starting bootstrap (stdlib ${STDLIB_VERSION})"

  # Phase 1: TMP_DIR selection + trap-managed workspace
  stdlib::run::_section "Phase 1: Workspace"
  stdlib::tmpfs::create_workspace

  # Phase 2: Secrets-first flow
  stdlib::run::_section "Phase 2: Secrets"
  stdlib::secrets::bootstrap

  # Phase 3: Load config chain (defaults → variables → overrides)
  stdlib::run::_section "Phase 3: Configuration"
  stdlib::config::load_chain
  stdlib::config::derive_identity

  # Phase 4: Environment probe
  stdlib::run::_section "Phase 4: Environment Probe"
  stdlib::probe::run

  # Phase 5: Identity enforcement
  stdlib::run::_section "Phase 5: Identity"
  stdlib::user::enforce

  # Phase 6: Directory layout
  stdlib::run::_section "Phase 6: Directory Layout"
  stdlib::layout::enforce

  # Phase 7: Permanent tmpfs mounts
  stdlib::run::_section "Phase 7: Tmpfs Mounts"
  stdlib::tmpfs::ensure_mounts

  # Phase 8: Symlink enforcement
  stdlib::run::_section "Phase 8: Symlinks"
  stdlib::symlink::enforce

  # Phase 9: System dependencies
  stdlib::run::_section "Phase 9: Dependencies"
  stdlib::probe::deps

  # Phase 10: Service setup
  stdlib::run::_section "Phase 10: Services"
  stdlib::service::setup

  # Phase 11: Hardening modules
  stdlib::run::_section "Phase 11: Hardening Modules"
  stdlib::run::_exec_modules

  # Phase 12: Summary
  stdlib::run::summary
}

# ── Execute numbered modules from modules/ directory ─────────────────
stdlib::run::_exec_modules() {
  local modules_dir="${REPO_DIR:-.}/modules"

  if [[ ! -d "${modules_dir}" ]]; then
    stdlib::log::warn "modules/ directory not found — skipping"
    return 0
  fi

  local count=0
  local module
  while IFS= read -r -d '' module; do
    local name
    name="$(basename "${module}")"
    stdlib::log::info "Running: ${name}"
    # shellcheck source=/dev/null
    source "${module}"
    ((count++)) || true
  done < <(find "${modules_dir}" -maxdepth 1 -name '*.sh' -type f -print0 | sort -zV)

  stdlib::log::info "Executed ${count} hardening modules"
}

# ── Print final summary ──────────────────────────────────────────────
stdlib::run::summary() {
  printf '\n'
  printf '╔═══════════════════════════════════════════════════════════════╗\n'
  printf '║  Bootstrap Complete                                          ║\n'
  printf '╠═══════════════════════════════════════════════════════════════╣\n'
  printf '║  NAMESPACE:  %-46s ║\n' "${NAMESPACE:-unknown}"
  printf '║  ROOT:       %-46s ║\n' "${NAMESPACE_ROOT:-unknown}"
  printf '║  USER:       %-46s ║\n' "${BOOTSTRAP_USER:-unknown} (${BOOTSTRAP_UID:-?}:${BOOTSTRAP_GID:-?})"
  printf '║  TMP_DIR:    %-46s ║\n' "${TMP_DIR:-none}"
  printf '║  OS:         %-46s ║\n' "${PROBE_OS:-unknown} ${PROBE_DISTRO:-} ${PROBE_DISTRO_VERSION:-}"
  printf '╚═══════════════════════════════════════════════════════════════╝\n'
  printf '\n'
  stdlib::log::info "Bootstrap completed successfully"
}
