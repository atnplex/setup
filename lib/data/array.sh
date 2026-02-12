#!/usr/bin/env bash
# Module: data/array
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::array::contains, ::index_of, ::unique, ::sort, ::reverse,
#           ::join, ::push, ::pop, ::shift, ::map, ::filter, ::reduce,
#           ::length, ::is_empty
# Description: Array manipulation primitives using namerefs.

[[ -n "${_STDLIB_LOADED_DATA_ARRAY:-}" ]] && return 0
readonly _STDLIB_LOADED_DATA_ARRAY=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- predicates -------------------------------------------------------
stdlib::array::contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

stdlib::array::index_of() {
  local needle="$1"; shift
  local i=0 item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && { printf '%d' "$i"; return 0; }
    (( i++ ))
  done
  return 1
}

stdlib::array::length() {
  printf '%d' "$#"
}

stdlib::array::is_empty() {
  (( $# == 0 ))
}

# ---------- transformations via nameref --------------------------------------
# Usage: stdlib::array::unique dest_array "${source[@]}"
stdlib::array::unique() {
  local -n _out="$1"; shift
  local -A _seen=()
  _out=()
  local item
  for item in "$@"; do
    if [[ -z "${_seen[$item]:-}" ]]; then
      _seen["$item"]=1
      _out+=("$item")
    fi
  done
}

stdlib::array::sort() {
  local -n _out="$1"; shift
  local IFS=$'\n'
  mapfile -t _out < <(printf '%s\n' "$@" | sort)
}

stdlib::array::reverse() {
  local -n _out="$1"; shift
  _out=()
  local i
  for (( i=$#; i>0; i-- )); do
    _out+=("${!i}")
  done
}

# ---------- stack operations -------------------------------------------------
stdlib::array::push() {
  local -n _arr="$1"; shift
  _arr+=("$@")
}

stdlib::array::pop() {
  local -n _arr="$1"
  local -n _val="$2"
  local len="${#_arr[@]}"
  (( len == 0 )) && return 1
  _val="${_arr[-1]}"
  unset '_arr[-1]'
}

stdlib::array::shift() {
  local -n _arr="$1"
  local -n _val="$2"
  local len="${#_arr[@]}"
  (( len == 0 )) && return 1
  _val="${_arr[0]}"
  _arr=("${_arr[@]:1}")
}

# ---------- join -------------------------------------------------------------
stdlib::array::join() {
  local delim="$1"; shift
  local first="$1"; shift
  printf '%s' "$first"
  local item
  for item in "$@"; do
    printf '%s%s' "$delim" "$item"
  done
}

# ---------- functional -------------------------------------------------------
# Usage: stdlib::array::map dest_array func_name "${source[@]}"
stdlib::array::map() {
  local -n _out="$1"; shift
  local func="$1"; shift
  _out=()
  local item
  for item in "$@"; do
    _out+=("$( "$func" "$item" )")
  done
}

# Usage: stdlib::array::filter dest_array predicate_func "${source[@]}"
stdlib::array::filter() {
  local -n _out="$1"; shift
  local func="$1"; shift
  _out=()
  local item
  for item in "$@"; do
    "$func" "$item" && _out+=("$item")
  done
  return 0
}

# Usage: stdlib::array::reduce accumulator_var func_name initial "${source[@]}"
stdlib::array::reduce() {
  local -n _acc="$1"; shift
  local func="$1"; shift
  _acc="$1"; shift
  local item
  for item in "$@"; do
    _acc="$( "$func" "$_acc" "$item" )"
  done
}
