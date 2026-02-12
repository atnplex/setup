#!/usr/bin/env bash
# Module: core/run
# Version: 0.1.0
# Provides: Dry-run aware command execution with logging
# Requires: core/log
[[ -n "${_STDLIB_RUN:-}" ]] && return 0
declare -g _STDLIB_RUN=1

# ── Internal State ─────────────────────────────────────────────────────
declare -g _RUN_DRY_RUN="${DRY_RUN:-false}"
declare -g _RUN_LOG_FILE=""

# ── stdlib::run ───────────────────────────────────────────────────────
# Execute command with logging. Respects dry-run mode.
# Usage: stdlib::run cmd [args...]
stdlib::run() {
  if [[ "$_RUN_DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $*" >&2
    return 0
  fi

  echo "[RUN] $*" >&2
  "$@"
}

# ── stdlib::run::set_dry_run ──────────────────────────────────────────
# Enable or disable dry-run mode.
stdlib::run::set_dry_run() {
  _RUN_DRY_RUN="${1:-true}"
}

# ── stdlib::run::is_dry_run ───────────────────────────────────────────
stdlib::run::is_dry_run() {
  [[ "$_RUN_DRY_RUN" == "true" ]]
}

# ── stdlib::run::capture ──────────────────────────────────────────────
# Execute and capture stdout into a nameref variable.
# Usage: stdlib::run::capture result_var cmd [args...]
stdlib::run::capture() {
  local -n _result="$1"; shift

  if [[ "$_RUN_DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $*" >&2
    _result=""
    return 0
  fi

  _result=$("$@")
}

# ── stdlib::run::tee ─────────────────────────────────────────────────
# Execute with stdout+stderr tee to log file.
# Usage: stdlib::run::tee cmd [args...]
stdlib::run::tee() {
  if [[ -n "$_RUN_LOG_FILE" ]]; then
    "$@" 2>&1 | tee -a "$_RUN_LOG_FILE"
    return "${PIPESTATUS[0]}"
  else
    "$@"
  fi
}

# ── stdlib::run::set_log_file ─────────────────────────────────────────
# Set log file for tee output.
stdlib::run::set_log_file() {
  _RUN_LOG_FILE="$1"
  [[ -n "$_RUN_LOG_FILE" ]] && touch "$_RUN_LOG_FILE"
}
