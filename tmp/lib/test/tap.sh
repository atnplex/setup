#!/usr/bin/env bash
# Module: test/tap
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::tap::plan, ::ok, ::not_ok, ::is, ::isnt, ::skip, ::bail_out, ::done
# Description: TAP (Test Anything Protocol) output for Bash test scripts.

[[ -n "${_STDLIB_LOADED_TEST_TAP:-}" ]] && return 0
readonly _STDLIB_LOADED_TEST_TAP=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# Internal counters
declare -gi _STDLIB_TAP_COUNT=0
declare -gi _STDLIB_TAP_PASS=0
declare -gi _STDLIB_TAP_FAIL=0
declare -gi _STDLIB_TAP_PLAN=0

# ---------- stdlib::tap::plan ------------------------------------------------
# Declare the number of tests.
# Usage: stdlib::tap::plan 5
stdlib::tap::plan() {
  _STDLIB_TAP_PLAN="${1:?test count required}"
  printf '1..%d\n' "$_STDLIB_TAP_PLAN"
}

# ---------- stdlib::tap::ok --------------------------------------------------
# Record a passing test.
# Usage: stdlib::tap::ok "description"
stdlib::tap::ok() {
  local desc="${1:-}"
  (( _STDLIB_TAP_COUNT++ ))
  (( _STDLIB_TAP_PASS++ ))
  printf 'ok %d %s\n' "$_STDLIB_TAP_COUNT" "$desc"
}

# ---------- stdlib::tap::not_ok ----------------------------------------------
# Record a failing test.
# Usage: stdlib::tap::not_ok "description" ["diagnostic"]
stdlib::tap::not_ok() {
  local desc="${1:-}" diag="${2:-}"
  (( _STDLIB_TAP_COUNT++ ))
  (( _STDLIB_TAP_FAIL++ ))
  printf 'not ok %d %s\n' "$_STDLIB_TAP_COUNT" "$desc"
  [[ -n "$diag" ]] && printf '# %s\n' "$diag"
}

# ---------- stdlib::tap::is --------------------------------------------------
# Assert equality; auto ok/not_ok.
# Usage: stdlib::tap::is "actual" "expected" "description"
stdlib::tap::is() {
  local actual="$1" expected="$2" desc="${3:-}"
  if [[ "$actual" == "$expected" ]]; then
    stdlib::tap::ok "$desc"
  else
    stdlib::tap::not_ok "$desc" "got '$actual', expected '$expected'"
  fi
}

# ---------- stdlib::tap::isnt ------------------------------------------------
stdlib::tap::isnt() {
  local actual="$1" unexpected="$2" desc="${3:-}"
  if [[ "$actual" != "$unexpected" ]]; then
    stdlib::tap::ok "$desc"
  else
    stdlib::tap::not_ok "$desc" "'$actual' should differ from '$unexpected'"
  fi
}

# ---------- stdlib::tap::skip ------------------------------------------------
# Skip a test.
# Usage: stdlib::tap::skip "reason"
stdlib::tap::skip() {
  local reason="${1:-no reason}"
  (( _STDLIB_TAP_COUNT++ ))
  printf 'ok %d # SKIP %s\n' "$_STDLIB_TAP_COUNT" "$reason"
}

# ---------- stdlib::tap::bail_out --------------------------------------------
# Abort the whole test run.
stdlib::tap::bail_out() {
  local reason="${1:-}"
  printf 'Bail out! %s\n' "$reason"
  exit 1
}

# ---------- stdlib::tap::done ------------------------------------------------
# Print summary and exit with appropriate code.
stdlib::tap::done() {
  printf '# Tests: %d, Pass: %d, Fail: %d\n' \
    "$_STDLIB_TAP_COUNT" "$_STDLIB_TAP_PASS" "$_STDLIB_TAP_FAIL"
  (( _STDLIB_TAP_FAIL == 0 ))
}
