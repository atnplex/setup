#!/usr/bin/env bash
# Module: term/prompt
# Version: 0.2.0
# Provides: Interactive prompts — confirm, ask, select, password, multi-select, timed
# Requires: none
[[ -n "${_STDLIB_PROMPT:-}" ]] && return 0
declare -g _STDLIB_PROMPT=1

declare -g _PROMPT_NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

# ── stdlib::prompt::confirm ───────────────────────────────────
# Yes/no confirmation. Returns 0 for yes, 1 for no.
# Usage: stdlib::prompt::confirm "Are you sure?" [default_yes]
stdlib::prompt::confirm() {
  local msg="$1"
  local default="${2:-n}"

  if [[ "$_PROMPT_NON_INTERACTIVE" == "true" ]]; then
    [[ "$default" == "y" || "$default" == "Y" ]]
    return $?
  fi

  local prompt
  if [[ "$default" =~ ^[yY] ]]; then
    prompt="$msg [Y/n]: "
  else
    prompt="$msg [y/N]: "
  fi

  local answer
  read -rp "$prompt" answer
  answer="${answer:-$default}"

  [[ "$answer" =~ ^[yY] ]]
}

# ── stdlib::prompt::ask ───────────────────────────────────────
# Ask for text input with optional default.
# Usage: stdlib::prompt::ask result_var "prompt" [default]
stdlib::prompt::ask() {
  local -n _result="$1"
  local msg="$2"
  local default="${3:-}"

  if [[ "$_PROMPT_NON_INTERACTIVE" == "true" ]]; then
    _result="$default"
    return 0
  fi

  local prompt="$msg"
  [[ -n "$default" ]] && prompt+=" [$default]"
  prompt+=": "

  local answer
  read -rp "$prompt" answer
  _result="${answer:-$default}"
}

# ── stdlib::prompt::password ──────────────────────────────────
# Ask for a password (hidden input).
stdlib::prompt::password() {
  local -n _result="$1"
  local msg="${2:-Password}"

  if [[ "$_PROMPT_NON_INTERACTIVE" == "true" ]]; then
    _result=""
    return 1
  fi

  read -rsp "${msg}: " _result
  echo >&2
}

# ── stdlib::prompt::select ────────────────────────────────────
# Single-select from a list.
# Usage: stdlib::prompt::select result_var "prompt" item1 item2 item3...
stdlib::prompt::select() {
  local -n _result="$1"; shift
  local msg="$1"; shift
  local -a items=("$@")

  if [[ "$_PROMPT_NON_INTERACTIVE" == "true" ]]; then
    _result="${items[0]}"
    return 0
  fi

  echo "$msg" >&2
  local i
  for i in "${!items[@]}"; do
    printf '  %2d) %s\n' "$(( i + 1 ))" "${items[$i]}" >&2
  done

  local choice
  while true; do
    read -rp "  Select [1-${#items[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#items[@]} )); then
      _result="${items[$((choice - 1))]}"
      return 0
    fi
    echo "  Invalid selection" >&2
  done
}

# ══════════════════════════════════════════════════════════════
# NEW FUNCTIONS (v0.2.0)
# ══════════════════════════════════════════════════════════════

# ── stdlib::prompt::multi_select ──────────────────────────────
# Multi-select from a list with toggle-style checkboxes.
# Usage: stdlib::prompt::multi_select result_var "prompt" item1 item2...
stdlib::prompt::multi_select() {
  local -n _result="$1"; shift
  local msg="$1"; shift
  local -a items=("$@")
  local -a selected=()

  if [[ "$_PROMPT_NON_INTERACTIVE" == "true" ]]; then
    _result=("${items[@]}")
    return 0
  fi

  # Initialize all as unselected
  local -a checked=()
  for (( i=0; i<${#items[@]}; i++ )); do
    checked+=("false")
  done

  while true; do
    echo "" >&2
    echo "$msg (toggle by number, 'a' for all, 'd' for done):" >&2
    for i in "${!items[@]}"; do
      local mark=" "
      [[ "${checked[$i]}" == "true" ]] && mark="✓"
      printf '  [%s] %2d) %s\n' "$mark" "$(( i + 1 ))" "${items[$i]}" >&2
    done
    echo "" >&2

    local input
    read -rp "  Toggle/done: " input

    case "$input" in
      d|D|done)
        # Collect selected items
        _result=()
        for i in "${!items[@]}"; do
          [[ "${checked[$i]}" == "true" ]] && _result+=("${items[$i]}")
        done
        return 0
        ;;
      a|A|all)
        for i in "${!checked[@]}"; do checked[$i]="true"; done
        ;;
      *)
        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#items[@]} )); then
          local idx=$(( input - 1 ))
          if [[ "${checked[$idx]}" == "true" ]]; then
            checked[$idx]="false"
          else
            checked[$idx]="true"
          fi
        else
          echo "  Invalid input" >&2
        fi
        ;;
    esac
  done
}

# ── stdlib::prompt::timed ─────────────────────────────────────
# Prompt with timeout — uses default if user doesn't respond.
# Usage: stdlib::prompt::timed result_var "prompt" timeout_seconds default
stdlib::prompt::timed() {
  local -n _result="$1"
  local msg="$2"
  local timeout="$3"
  local default="$4"

  if [[ "$_PROMPT_NON_INTERACTIVE" == "true" ]]; then
    _result="$default"
    return 0
  fi

  local answer
  if read -rp "${msg} [${default}] (${timeout}s): " -t "$timeout" answer; then
    _result="${answer:-$default}"
  else
    echo "" >&2
    echo "  Timed out, using default: $default" >&2
    _result="$default"
  fi
}
