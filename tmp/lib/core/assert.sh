#!/usr/bin/env bash
# Module: core/assert
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::assert::eq, ::ne, ::gt, ::lt, ::file_exists, ::dir_exists,
#           ::executable, ::not_empty, ::matches, ::cmd_exists
# Description: Guard assertions — fail fast with clear messages.

[[ -n "${_STDLIB_LOADED_CORE_ASSERT:-}" ]] && return 0
readonly _STDLIB_LOADED_CORE_ASSERT=1
readonly _STDLIB_MOD_VERSION="0.1.0"

_stdlib_assert_fail() {
  local assertion="$1" detail="$2"
  printf 'ASSERTION FAILED: %s — %s\n' "$assertion" "$detail" >&2
  printf '  at %s:%s in %s()\n' "${BASH_SOURCE[2]:-unknown}" "${BASH_LINENO[1]:-?}" "${FUNCNAME[2]:-main}" >&2
  return 1
}

# ---------- value comparisons ------------------------------------------------
stdlib::assert::eq() {
  local actual="$1" expected="$2" label="${3:-}"
  [[ "$actual" == "$expected" ]] || \
    _stdlib_assert_fail "eq${label:+ ($label)}" "expected '$expected', got '$actual'"
}

stdlib::assert::ne() {
  local actual="$1" unexpected="$2" label="${3:-}"
  [[ "$actual" != "$unexpected" ]] || \
    _stdlib_assert_fail "ne${label:+ ($label)}" "'$actual' should differ from '$unexpected'"
}

stdlib::assert::gt() {
  local actual="$1" threshold="$2" label="${3:-}"
  (( actual > threshold )) 2>/dev/null || \
    _stdlib_assert_fail "gt${label:+ ($label)}" "$actual is not > $threshold"
}

stdlib::assert::lt() {
  local actual="$1" threshold="$2" label="${3:-}"
  (( actual < threshold )) 2>/dev/null || \
    _stdlib_assert_fail "lt${label:+ ($label)}" "$actual is not < $threshold"
}

# ---------- filesystem assertions --------------------------------------------
stdlib::assert::file_exists() {
  local path="${1:?path required}"
  [[ -f "$path" ]] || _stdlib_assert_fail "file_exists" "'$path' is not a file"
}

stdlib::assert::dir_exists() {
  local path="${1:?path required}"
  [[ -d "$path" ]] || _stdlib_assert_fail "dir_exists" "'$path' is not a directory"
}

stdlib::assert::executable() {
  local path="${1:?path required}"
  [[ -x "$path" ]] || _stdlib_assert_fail "executable" "'$path' is not executable"
}

# ---------- string assertions ------------------------------------------------
stdlib::assert::not_empty() {
  local value="$1" label="${2:-value}"
  [[ -n "$value" ]] || _stdlib_assert_fail "not_empty" "$label is empty"
}

stdlib::assert::matches() {
  local value="$1" pattern="$2" label="${3:-}"
  [[ "$value" =~ $pattern ]] || \
    _stdlib_assert_fail "matches${label:+ ($label)}" "'$value' does not match /$pattern/"
}

# ---------- command assertions -----------------------------------------------
stdlib::assert::cmd_exists() {
  local cmd="${1:?command name required}"
  command -v "$cmd" &>/dev/null || \
    _stdlib_assert_fail "cmd_exists" "command '$cmd' not found in PATH"
}
