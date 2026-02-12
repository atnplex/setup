#!/usr/bin/env bash
# Module: term/prompt
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::prompt::ask, ::confirm, ::select, ::password, ::default
# Description: Interactive terminal prompts for user input.

[[ -n "${_STDLIB_LOADED_TERM_PROMPT:-}" ]] && return 0
readonly _STDLIB_LOADED_TERM_PROMPT=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::prompt::ask ----------------------------------------------
# Prompt for text input. Result stored in nameref.
# Usage: stdlib::prompt::ask result_var "Enter your name:"
stdlib::prompt::ask() {
  local -n _result="$1"
  local prompt="${2:?prompt text required}"
  printf '%s ' "$prompt" >&2
  read -r _result
}

# ---------- stdlib::prompt::confirm ------------------------------------------
# Yes/No prompt. Returns 0 for yes, 1 for no.
# Usage: stdlib::prompt::confirm "Continue?" [default_yes]
stdlib::prompt::confirm() {
  local prompt="${1:?prompt required}" default="${2:-}"
  local yn_hint="[y/n]"
  case "${default,,}" in
    y|yes) yn_hint="[Y/n]" ;;
    n|no)  yn_hint="[y/N]" ;;
  esac

  local answer
  printf '%s %s ' "$prompt" "$yn_hint" >&2
  read -r answer

  case "${answer,,}" in
    y|yes) return 0 ;;
    n|no)  return 1 ;;
    '')
      case "${default,,}" in
        y|yes) return 0 ;;
        n|no)  return 1 ;;
        *)     return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# ---------- stdlib::prompt::select -------------------------------------------
# Numbered menu selection. Returns chosen value in nameref.
# Usage: stdlib::prompt::select result_var "Choose an option:" "opt1" "opt2" "opt3"
stdlib::prompt::select() {
  local -n _result="$1"
  local prompt="$2"; shift 2
  local -a options=("$@")

  printf '%s\n' "$prompt" >&2
  local i
  for (( i=0; i<${#options[@]}; i++ )); do
    printf '  %d) %s\n' "$(( i + 1 ))" "${options[$i]}" >&2
  done

  local choice
  while true; do
    printf 'Selection [1-%d]: ' "${#options[@]}" >&2
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      _result="${options[$(( choice - 1 ))]}"
      return 0
    fi
    printf 'Invalid selection. Try again.\n' >&2
  done
}

# ---------- stdlib::prompt::password -----------------------------------------
# Prompt for hidden input (no echo).
# Usage: stdlib::prompt::password result_var "Enter password:"
stdlib::prompt::password() {
  local -n _result="$1"
  local prompt="${2:-Password:}"
  printf '%s ' "$prompt" >&2
  read -rs _result
  printf '\n' >&2
}

# ---------- stdlib::prompt::default ------------------------------------------
# Prompt with a pre-filled default value.
# Usage: stdlib::prompt::default result_var "Enter port:" "8080"
stdlib::prompt::default() {
  local -n _result="$1"
  local prompt="${2:?prompt required}" default="${3:-}"
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  read -r _result
  [[ -z "$_result" ]] && _result="$default"
}
