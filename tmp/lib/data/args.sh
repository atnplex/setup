#!/usr/bin/env bash
# Module: data/args
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::args::define, ::parse, ::usage, ::require, ::get
# Description: Declarative argument parsing with auto-generated usage.

[[ -n "${_STDLIB_LOADED_DATA_ARGS:-}" ]] && return 0
readonly _STDLIB_LOADED_DATA_ARGS=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# Internal registries
declare -gA _STDLIB_ARGS_DEFS=()      # [name]=type:default:required:help
declare -gA _STDLIB_ARGS_VALUES=()    # [name]=parsed_value
declare -g  _STDLIB_ARGS_PROG=""      # program name for usage
declare -ga _STDLIB_ARGS_POSITIONAL=() # remaining positional args

# ---------- stdlib::args::define ---------------------------------------------
# Declare an expected argument.
# Usage: stdlib::args::define --name=output --short=o --type=string \
#          --default="/dev/stdout" --required --help="Output file path"
stdlib::args::define() {
  local name="" short="" type="string" default="" required=0 help=""
  local arg
  for arg in "$@"; do
    case "$arg" in
      --name=*)     name="${arg#*=}" ;;
      --short=*)    short="${arg#*=}" ;;
      --type=*)     type="${arg#*=}" ;;
      --default=*)  default="${arg#*=}" ;;
      --required)   required=1 ;;
      --help=*)     help="${arg#*=}" ;;
    esac
  done
  [[ -z "$name" ]] && { printf 'stdlib::args::define: --name is required\n' >&2; return 1; }
  _STDLIB_ARGS_DEFS["$name"]="${type}:${default}:${required}:${short}:${help}"
  _STDLIB_ARGS_VALUES["$name"]="$default"
}

# ---------- stdlib::args::parse ----------------------------------------------
# Parse command-line arguments against definitions.
# Usage: stdlib::args::parse "$@"
stdlib::args::parse() {
  _STDLIB_ARGS_PROG="${0##*/}"
  _STDLIB_ARGS_POSITIONAL=()

  while (( $# > 0 )); do
    case "$1" in
      --help|-h)
        stdlib::args::usage
        exit 0
        ;;
      --*=*)
        local key="${1%%=*}" value="${1#*=}"
        key="${key#--}"
        if [[ -n "${_STDLIB_ARGS_DEFS[$key]:-}" ]]; then
          _STDLIB_ARGS_VALUES["$key"]="$value"
        else
          printf 'Unknown option: --%s\n' "$key" >&2
          return 1
        fi
        ;;
      --no-*)
        local key="${1#--no-}"
        if [[ -n "${_STDLIB_ARGS_DEFS[$key]:-}" ]]; then
          _STDLIB_ARGS_VALUES["$key"]="false"
        fi
        ;;
      --*)
        local key="${1#--}"
        if [[ -n "${_STDLIB_ARGS_DEFS[$key]:-}" ]]; then
          local def="${_STDLIB_ARGS_DEFS[$key]}"
          local type="${def%%:*}"
          if [[ "$type" == "bool" ]]; then
            _STDLIB_ARGS_VALUES["$key"]="true"
          elif (( $# > 1 )); then
            shift
            _STDLIB_ARGS_VALUES["$key"]="$1"
          fi
        fi
        ;;
      -?)
        local s="${1#-}" found=0
        local name def
        for name in "${!_STDLIB_ARGS_DEFS[@]}"; do
          def="${_STDLIB_ARGS_DEFS[$name]}"
          local short
          IFS=: read -r _ _ _ short _ <<< "$def"
          if [[ "$short" == "$s" ]]; then
            local type
            IFS=: read -r type _ <<< "$def"
            if [[ "$type" == "bool" ]]; then
              _STDLIB_ARGS_VALUES["$name"]="true"
            elif (( $# > 1 )); then
              shift
              _STDLIB_ARGS_VALUES["$name"]="$1"
            fi
            found=1
            break
          fi
        done
        (( found )) || { printf 'Unknown option: -%s\n' "$s" >&2; return 1; }
        ;;
      --)
        shift
        _STDLIB_ARGS_POSITIONAL+=("$@")
        break
        ;;
      *)
        _STDLIB_ARGS_POSITIONAL+=("$1")
        ;;
    esac
    shift
  done
}

# ---------- stdlib::args::require --------------------------------------------
# Fail if any required argument is missing.
stdlib::args::require() {
  local name def
  for name in "${!_STDLIB_ARGS_DEFS[@]}"; do
    def="${_STDLIB_ARGS_DEFS[$name]}"
    local required
    IFS=: read -r _ _ required _ <<< "$def"
    if (( required )) && [[ -z "${_STDLIB_ARGS_VALUES[$name]:-}" ]]; then
      printf 'Error: required argument --%s is missing\n' "$name" >&2
      stdlib::args::usage >&2
      return 1
    fi
  done
}

# ---------- stdlib::args::get ------------------------------------------------
# Retrieve a parsed value by name.
stdlib::args::get() {
  local name="${1:?argument name required}"
  printf '%s' "${_STDLIB_ARGS_VALUES[$name]:-}"
}

# ---------- stdlib::args::usage ----------------------------------------------
# Auto-generate usage text from definitions.
stdlib::args::usage() {
  printf 'Usage: %s [OPTIONS]\n\nOptions:\n' "$_STDLIB_ARGS_PROG"
  local name def
  for name in $(printf '%s\n' "${!_STDLIB_ARGS_DEFS[@]}" | sort); do
    def="${_STDLIB_ARGS_DEFS[$name]}"
    local type default required short help
    IFS=: read -r type default required short help <<< "$def"
    local flag="--${name}"
    [[ -n "$short" ]] && flag="-${short}, ${flag}"
    local meta=""
    [[ "$type" != "bool" ]] && meta=" <${type}>"
    local req_label=""
    (( required )) && req_label=" (required)"
    local def_label=""
    [[ -n "$default" ]] && def_label=" [default: ${default}]"
    printf '  %-28s %s%s%s\n' "${flag}${meta}" "${help}" "${req_label}" "${def_label}"
  done
}
