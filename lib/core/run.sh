#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# core/run.sh — Bootstrap orchestrator
#
# Imports all stdlib modules and executes them in the correct
# secrets-first order. Contains NO business logic — only sequencing.
# ═══════════════════════════════════════════════════════════════════════════════
[[ -n "${_STDLIB_MOD_RUN:-}" ]] && return 0
readonly _STDLIB_MOD_RUN=1
_STDLIB_MOD_VERSION="1.0.0"

# ── Import all required modules ───────────────────────────────────────────────
stdlib::import core/log
stdlib::import data/config
stdlib::import sys/tmpfs
stdlib::import sys/secrets
stdlib::import sys/probe
stdlib::import sys/user
stdlib::import sys/service
stdlib::import fs/layout
stdlib::import fs/symlink

# ── Section banner ────────────────────────────────────────────────────────────
stdlib::run::_section() {
  printf '\n━━━ %s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$1"
}

# ══════════════════════════════════════════════════════════════════════════════
# Main entry point — called by bootstrap.sh
# ══════════════════════════════════════════════════════════════════════════════
stdlib::run::bootstrap_main() {
  stdlib::log::info "Starting bootstrap (stdlib ${STDLIB_VERSION})"

  # ── 1. TMP_DIR selection + trap-managed workspace ────────────────────────
  #    Detect tmpfs candidates → select best → create TMP_DIR → register trap
  stdlib::run::_section "Phase 1: Tmpfs Workspace"
  stdlib::tmpfs::detect_candidates
  stdlib::tmpfs::select_best
  stdlib::tmpfs::create_workspace

  # ── 2. Secrets-first flow ───────────────────────────────────────────────
  #    Install BWS → prompt token → fetch vars+secrets → write variables.env
  #    → write secrets.age → decrypt into keyctl → source variables.env
  stdlib::run::_section "Phase 2: Secrets"
  stdlib::secrets::install_bws
  stdlib::secrets::prompt_token
  stdlib::secrets::fetch
  stdlib::secrets::decrypt_to_keyctl
  stdlib::secrets::source_variables

  # ── 3. Configuration + identity derivation ──────────────────────────────
  stdlib::run::_section "Phase 3: Configuration"
  stdlib::config::load_chain
  stdlib::config::derive_identity

  # ── 4. Environment probe ────────────────────────────────────────────────
  stdlib::run::_section "Phase 4: Environment Probe"
  stdlib::run::probe_environment

  # ── 5. Identity enforcement ─────────────────────────────────────────────
  stdlib::run::_section "Phase 5: Identity"
  stdlib::user::ensure_identity

  # ── 6. Directory layout ─────────────────────────────────────────────────
  stdlib::run::_section "Phase 6: Directory Layout"
  stdlib::layout::ensure_directories

  # ── 7. Symlink enforcement ──────────────────────────────────────────────
  stdlib::run::_section "Phase 7: Symlinks"
  stdlib::layout::ensure_symlinks

  # ── 8. Permanent tmpfs mounts ───────────────────────────────────────────
  stdlib::run::_section "Phase 8: Tmpfs Mounts"
  stdlib::tmpfs::ensure_mounts

  # ── 9. Service setup ────────────────────────────────────────────────────
  stdlib::run::_section "Phase 9: Services"
  stdlib::service::ensure_services

  # ── 10. Hardening modules ───────────────────────────────────────────────
  stdlib::run::_section "Phase 10: Hardening Modules"
  stdlib::run::_exec_modules

  # ── 11. Summary ─────────────────────────────────────────────────────────
  stdlib::run::summary
}

# ══════════════════════════════════════════════════════════════════════════════
# Wrapper: probe environment (OS, arch, virt, deps)
# ══════════════════════════════════════════════════════════════════════════════
stdlib::run::probe_environment() {
  stdlib::probe::detect_os
  stdlib::probe::detect_arch
  stdlib::probe::detect_virt
  stdlib::probe::check_deps
}

# ══════════════════════════════════════════════════════════════════════════════
# Execute numbered modules from modules/ directory
# ══════════════════════════════════════════════════════════════════════════════
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

# ══════════════════════════════════════════════════════════════════════════════
# Print final summary
# ══════════════════════════════════════════════════════════════════════════════
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
