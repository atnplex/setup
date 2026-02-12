#!/usr/bin/env bash
# Module: data/semver
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::semver::parse, ::compare, ::valid,
#           ::bump_major, ::bump_minor, ::bump_patch
# Description: Semantic versioning parser and comparator.

[[ -n "${_STDLIB_LOADED_DATA_SEMVER:-}" ]] && return 0
readonly _STDLIB_LOADED_DATA_SEMVER=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::semver::valid --------------------------------------------
# Returns 0 if the string is a valid semver (with optional v prefix).
stdlib::semver::valid() {
  local ver="${1#v}"
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.+)?(\+.+)?$ ]]
}

# ---------- stdlib::semver::parse --------------------------------------------
# Parse version into components via namerefs.
# Usage: stdlib::semver::parse "1.2.3-rc1+build" major minor patch pre build
stdlib::semver::parse() {
  local ver="${1#v}"
  local -n _major="$2" _minor="$3" _patch="$4"
  local -n _pre="${5:-_stdlib_semver_discard}" _build="${6:-_stdlib_semver_discard}"
  local _stdlib_semver_discard=""

  local base="${ver%%[-+]*}"
  _major="${base%%.*}"
  local rest="${base#*.}"
  _minor="${rest%%.*}"
  _patch="${rest#*.}"

  _pre=""
  _build=""
  if [[ "$ver" == *-* ]]; then
    local after_base="${ver#*-}"
    _pre="${after_base%%+*}"
  fi
  if [[ "$ver" == *+* ]]; then
    _build="${ver#*+}"
  fi
}

# ---------- stdlib::semver::compare ------------------------------------------
# Compare two semver strings. Prints -1, 0, or 1 to stdout.
stdlib::semver::compare() {
  local a="${1#v}" b="${2#v}"
  local a_major a_minor a_patch a_pre a_build
  local b_major b_minor b_patch b_pre b_build

  stdlib::semver::parse "$a" a_major a_minor a_patch a_pre a_build
  stdlib::semver::parse "$b" b_major b_minor b_patch b_pre b_build

  local i
  for i in major minor patch; do
    local av="a_$i" bv="b_$i"
    if (( ${!av} > ${!bv} )); then printf '1'; return 0; fi
    if (( ${!av} < ${!bv} )); then printf -- '-1'; return 0; fi
  done

  # Pre-release: presence means lower precedence
  if [[ -n "$a_pre" && -z "$b_pre" ]]; then printf -- '-1'; return 0; fi
  if [[ -z "$a_pre" && -n "$b_pre" ]]; then printf '1'; return 0; fi
  if [[ "$a_pre" < "$b_pre" ]]; then printf -- '-1'; return 0; fi
  if [[ "$a_pre" > "$b_pre" ]]; then printf '1'; return 0; fi

  printf '0'
}

# ---------- bump helpers -----------------------------------------------------
stdlib::semver::bump_major() {
  local ver="${1#v}"
  local major minor patch
  stdlib::semver::parse "$ver" major minor patch
  printf '%d.0.0' "$(( major + 1 ))"
}

stdlib::semver::bump_minor() {
  local ver="${1#v}"
  local major minor patch
  stdlib::semver::parse "$ver" major minor patch
  printf '%d.%d.0' "$major" "$(( minor + 1 ))"
}

stdlib::semver::bump_patch() {
  local ver="${1#v}"
  local major minor patch
  stdlib::semver::parse "$ver" major minor patch
  printf '%d.%d.%d' "$major" "$minor" "$(( patch + 1 ))"
}
