#!/usr/bin/env bash
# Module: term/progress
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::progress::spinner, ::bar, ::status, ::done
# Description: Terminal progress indicators — spinners, bars, status lines.

[[ -n "${_STDLIB_LOADED_TERM_PROGRESS:-}" ]] && return 0
readonly _STDLIB_LOADED_TERM_PROGRESS=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- stdlib::progress::spinner ----------------------------------------
# Start an animated spinner in the background. Returns PID via nameref.
# Usage: stdlib::progress::spinner pid_var "Loading..."
# Stop with: kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
stdlib::progress::spinner() {
  local -n _pid="$1"
  local msg="${2:-Working}"
  local -a frames=('⠋' '⠙' '⠸' '⠰' '⠴' '⠦' '⠇' '⠏')

  (
    local i=0
    while true; do
      printf '\r  %s %s' "${frames[i % ${#frames[@]}]}" "$msg" >&2
      sleep 0.1
      (( i++ ))
    done
  ) &
  _pid=$!
}

# ---------- stdlib::progress::bar --------------------------------------------
# Print a progress bar to stderr.
# Usage: stdlib::progress::bar current total [width] [label]
stdlib::progress::bar() {
  local current="${1:?current required}" total="${2:?total required}"
  local width="${3:-40}" label="${4:-}"

  local pct=0
  (( total > 0 )) && pct=$(( current * 100 / total ))
  local filled=$(( current * width / (total > 0 ? total : 1) ))
  local empty=$(( width - filled ))

  local bar=""
  local i
  for (( i=0; i<filled; i++ )); do bar+="█"; done
  for (( i=0; i<empty; i++ ));  do bar+="░"; done

  printf '\r  %s [%s] %3d%% (%d/%d)' "${label}" "$bar" "$pct" "$current" "$total" >&2
  (( current >= total )) && printf '\n' >&2
}

# ---------- stdlib::progress::status -----------------------------------------
# Print a status line that overwrites itself.
# Usage: stdlib::progress::status "Downloading file..."
stdlib::progress::status() {
  local msg="$1"
  printf '\r\033[K  → %s' "$msg" >&2
}

# ---------- stdlib::progress::done -------------------------------------------
# Clear the progress line and print a completion message.
stdlib::progress::done() {
  local msg="${1:-Done}"
  printf '\r\033[K  ✓ %s\n' "$msg" >&2
}
