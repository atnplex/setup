#!/usr/bin/env bash
# Module: data/string
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::string::trim, ::upper, ::lower, ::split, ::join,
#           ::contains, ::starts_with, ::ends_with, ::replace, ::repeat,
#           ::pad_left, ::pad_right, ::urlencode, ::urldecode
# Description: Pure-bash string manipulation primitives.

[[ -n "${_STDLIB_LOADED_DATA_STRING:-}" ]] && return 0
readonly _STDLIB_LOADED_DATA_STRING=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- trim -------------------------------------------------------------
stdlib::string::trim()  { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}" ; printf '%s' "$s"; }
stdlib::string::ltrim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "$s"; }
stdlib::string::rtrim() { local s="$1"; s="${s%"${s##*[![:space:]]}"}" ; printf '%s' "$s"; }

# ---------- case conversion --------------------------------------------------
stdlib::string::upper()      { printf '%s' "${1^^}"; }
stdlib::string::lower()      { printf '%s' "${1,,}"; }
stdlib::string::capitalize() { local s="$1"; printf '%s%s' "${s:0:1}" "${s:1}"; s="${s^}"; printf '%s' "$s"; }

# ---------- split / join -----------------------------------------------------
# Split string by delimiter into an array via nameref.
# Usage: stdlib::string::split result_array "," "a,b,c"
stdlib::string::split() {
  local -n _arr="$1"
  local delim="$2" str="$3"
  _arr=()
  while [[ "$str" == *"$delim"* ]]; do
    _arr+=("${str%%"$delim"*}")
    str="${str#*"$delim"}"
  done
  _arr+=("$str")
}

# Join array elements with a delimiter.
# Usage: stdlib::string::join "," "${arr[@]}"
stdlib::string::join() {
  local delim="$1"; shift
  local first="$1"; shift
  printf '%s' "$first"
  local item
  for item in "$@"; do
    printf '%s%s' "$delim" "$item"
  done
}

# ---------- predicates -------------------------------------------------------
stdlib::string::contains()    { [[ "$1" == *"$2"* ]]; }
stdlib::string::starts_with() { [[ "$1" == "$2"* ]]; }
stdlib::string::ends_with()   { [[ "$1" == *"$2" ]]; }

# ---------- replace ----------------------------------------------------------
# Replace first occurrence.  Use ::replace_all for global.
stdlib::string::replace()     { printf '%s' "${1/$2/$3}"; }
stdlib::string::replace_all() { printf '%s' "${1//$2/$3}"; }

# ---------- regex match ------------------------------------------------------
# Returns 0 on match; captured groups in BASH_REMATCH.
stdlib::string::regex_match() { [[ "$1" =~ $2 ]]; }

# ---------- repeat / pad -----------------------------------------------------
stdlib::string::repeat() {
  local str="$1" n="$2" out=""
  local i
  for (( i=0; i<n; i++ )); do out+="$str"; done
  printf '%s' "$out"
}

stdlib::string::pad_left() {
  local str="$1" width="$2" ch="${3:- }"
  while (( ${#str} < width )); do str="${ch}${str}"; done
  printf '%s' "$str"
}

stdlib::string::pad_right() {
  local str="$1" width="$2" ch="${3:- }"
  while (( ${#str} < width )); do str+="${ch}"; done
  printf '%s' "$str"
}

# ---------- URL encoding -----------------------------------------------------
stdlib::string::urlencode() {
  local str="$1" encoded="" c
  local i
  for (( i=0; i<${#str}; i++ )); do
    c="${str:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      *) printf -v encoded '%s%%%02X' "$encoded" "'$c" ;;
    esac
  done
  printf '%s' "$encoded"
}

stdlib::string::urldecode() {
  local str="${1//+/ }"
  printf '%b' "${str//%/\\x}"
}

# ---------- length -----------------------------------------------------------
stdlib::string::length() { printf '%d' "${#1}"; }
