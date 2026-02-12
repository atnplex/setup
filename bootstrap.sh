#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════╗
# ║  bootstrap.sh — Thin entrypoint for modular system bootstrap     ║
# ║                                                                   ║
# ║  This script performs ONLY:                                       ║
# ║    1. Bash version check                                          ║
# ║    2. CLI flag parsing                                            ║
# ║    3. Repo clone/discovery                                        ║
# ║    4. stdlib sourcing                                             ║
# ║    5. Delegation to stdlib::run::bootstrap_main                   ║
# ║                                                                   ║
# ║  All business logic lives in lib/core/run.sh                      ║
# ╚═══════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Bash 4+ required ─────────────────────────────────────────────────
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "FATAL: Bash 4+ required (found ${BASH_VERSION})" >&2
  exit 1
fi

# ── Constants ─────────────────────────────────────────────────────────
readonly SETUP_REPO="${SETUP_REPO:-https://github.com/atnplex/setup.git}"
readonly SETUP_BRANCH="${SETUP_BRANCH:-modular}"

# ── Resolve script location ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Locate or clone stdlib ───────────────────────────────────────────
find_stdlib() {
  # 1. Relative to script (running from repo checkout)
  if [[ -f "${SCRIPT_DIR}/lib/stdlib.sh" ]]; then
    echo "${SCRIPT_DIR}/lib"
    return 0
  fi

  # 2. Parent directory (script in sub-folder)
  if [[ -f "${SCRIPT_DIR}/../lib/stdlib.sh" ]]; then
    (cd "${SCRIPT_DIR}/../lib" && pwd)
    return 0
  fi

  # 3. Clone into temp directory
  local clone_dir
  clone_dir="$(mktemp -d "${TMPDIR:-/tmp}/setup-XXXXXX")"
  echo "Cloning setup repo into ${clone_dir}..." >&2
  git clone --depth 1 --branch "${SETUP_BRANCH}" "${SETUP_REPO}" "${clone_dir}" 2>&1 | tail -1 >&2
  echo "${clone_dir}/lib"
}

STDLIB_ROOT="$(find_stdlib)"
export STDLIB_ROOT

# ── Validate stdlib exists ───────────────────────────────────────────
if [[ ! -f "${STDLIB_ROOT}/stdlib.sh" ]]; then
  echo "FATAL: stdlib.sh not found at ${STDLIB_ROOT}" >&2
  exit 1
fi

# ── Source stdlib + import orchestrator ────────────────────────────────
# shellcheck source=lib/stdlib.sh
source "${STDLIB_ROOT}/stdlib.sh"
stdlib::import core/run

# ── Delegate to orchestrator ─────────────────────────────────────────
stdlib::run::bootstrap_main "$@"
