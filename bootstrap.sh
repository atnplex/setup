#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# bootstrap.sh — Thin entrypoint for modular system bootstrap
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/atnplex/setup/modular/bootstrap.sh | sudo bash
#
# This script performs ONLY:
#   1. Bash 4+ / root check
#   2. Create minimal temp workspace
#   3. Clone or discover the setup repo
#   4. Source stdlib.sh
#   5. Delegate to stdlib::run::bootstrap_main
#
# All business logic lives in lib/core/run.sh
# ═══════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Bash 4+ required ────────────────────────────────────────────────
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  printf 'FATAL: Bash 4+ required (found %s)\n' "${BASH_VERSION}" >&2
  exit 1
fi

# ── Root required ────────────────────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
  printf 'FATAL: Must run as root\n' >&2
  exit 1
fi

# ── Configuration ────────────────────────────────────────────────────
readonly _BOOT_REPO_URL="https://github.com/${GH_ORG:-atnplex}/setup.git"
readonly _BOOT_REPO_BRANCH="${REPO_BRANCH:-modular}"

# ── Minimal temp workspace ───────────────────────────────────────────
_BOOT_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-XXXXXX")"
readonly _BOOT_TMPDIR
trap 'rm -rf "${_BOOT_TMPDIR}"' EXIT

# ── Locate or clone the setup repo ───────────────────────────────────
_BOOT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${SETUP_REPO_DIR:-}" && -f "${SETUP_REPO_DIR}/lib/stdlib.sh" ]]; then
  REPO_DIR="${SETUP_REPO_DIR}"
elif [[ -f "${_BOOT_SCRIPT_DIR}/lib/stdlib.sh" ]]; then
  REPO_DIR="${_BOOT_SCRIPT_DIR}"
else
  REPO_DIR="${_BOOT_TMPDIR}/setup"
  printf 'Cloning %s (branch: %s)...\n' "${_BOOT_REPO_URL}" "${_BOOT_REPO_BRANCH}" >&2
  git clone --depth 1 --branch "${_BOOT_REPO_BRANCH}" \
    "${_BOOT_REPO_URL}" "${REPO_DIR}" >/dev/null 2>&1
fi
export REPO_DIR

# ── Validate + source stdlib ────────────────────────────────────────
if [[ ! -f "${REPO_DIR}/lib/stdlib.sh" ]]; then
  printf 'FATAL: stdlib.sh not found at %s/lib\n' "${REPO_DIR}" >&2
  exit 1
fi

export STDLIB_ROOT="${REPO_DIR}/lib"
# shellcheck source=lib/stdlib.sh
source "${STDLIB_ROOT}/stdlib.sh"
stdlib::import core/run

# ── Delegate to orchestrator ─────────────────────────────────────────
stdlib::run::bootstrap_main "$@"
