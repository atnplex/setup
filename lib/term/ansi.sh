#!/usr/bin/env bash
# Module: term/ansi
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::ansi::fg, ::bg, ::bold, ::dim, ::italic, ::underline,
#           ::reset, ::cursor_to, ::strip, ::supported
# Description: ANSI escape code generation for colors, styles, and cursor.

[[ -n "${_STDLIB_LOADED_TERM_ANSI:-}" ]] && return 0
readonly _STDLIB_LOADED_TERM_ANSI=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# ---------- color support detection ------------------------------------------
stdlib::ansi::supported() {
  # Returns color depth: 0=none, 1=basic(8), 2=256, 3=truecolor
  [[ -t 1 ]] || { printf '0'; return; }
  case "${COLORTERM:-}" in
    truecolor|24bit) printf '3'; return ;;
  esac
  case "${TERM:-}" in
    *-256color|xterm-256color) printf '2'; return ;;
    dumb|'')                   printf '0'; return ;;
  esac
  printf '1'
}

# Internal: emit escape only if color is supported
_stdlib_ansi_esc() {
  local code="$1"
  [[ "$(stdlib::ansi::supported)" == "0" ]] && return
  printf '\033[%sm' "$code"
}

# ---------- text styles ------------------------------------------------------
stdlib::ansi::reset()     { _stdlib_ansi_esc 0; }
stdlib::ansi::bold()      { _stdlib_ansi_esc 1; }
stdlib::ansi::dim()       { _stdlib_ansi_esc 2; }
stdlib::ansi::italic()    { _stdlib_ansi_esc 3; }
stdlib::ansi::underline() { _stdlib_ansi_esc 4; }
stdlib::ansi::blink()     { _stdlib_ansi_esc 5; }
stdlib::ansi::reverse()   { _stdlib_ansi_esc 7; }
stdlib::ansi::hidden()    { _stdlib_ansi_esc 8; }
stdlib::ansi::strike()    { _stdlib_ansi_esc 9; }

# ---------- foreground colors ------------------------------------------------
# Usage: stdlib::ansi::fg color_name  OR  stdlib::ansi::fg 256_code  OR  stdlib::ansi::fg r g b
stdlib::ansi::fg() {
  case "$1" in
    black)   _stdlib_ansi_esc 30 ;;
    red)     _stdlib_ansi_esc 31 ;;
    green)   _stdlib_ansi_esc 32 ;;
    yellow)  _stdlib_ansi_esc 33 ;;
    blue)    _stdlib_ansi_esc 34 ;;
    magenta) _stdlib_ansi_esc 35 ;;
    cyan)    _stdlib_ansi_esc 36 ;;
    white)   _stdlib_ansi_esc 37 ;;
    default) _stdlib_ansi_esc 39 ;;
    *)
      if (( $# == 3 )); then
        # Truecolor: fg r g b
        _stdlib_ansi_esc "38;2;$1;$2;$3"
      elif (( $# == 1 )); then
        # 256-color
        _stdlib_ansi_esc "38;5;$1"
      fi
      ;;
  esac
}

# ---------- background colors ------------------------------------------------
stdlib::ansi::bg() {
  case "$1" in
    black)   _stdlib_ansi_esc 40 ;;
    red)     _stdlib_ansi_esc 41 ;;
    green)   _stdlib_ansi_esc 42 ;;
    yellow)  _stdlib_ansi_esc 43 ;;
    blue)    _stdlib_ansi_esc 44 ;;
    magenta) _stdlib_ansi_esc 45 ;;
    cyan)    _stdlib_ansi_esc 46 ;;
    white)   _stdlib_ansi_esc 47 ;;
    default) _stdlib_ansi_esc 49 ;;
    *)
      if (( $# == 3 )); then
        _stdlib_ansi_esc "48;2;$1;$2;$3"
      elif (( $# == 1 )); then
        _stdlib_ansi_esc "48;5;$1"
      fi
      ;;
  esac
}

# ---------- cursor movement --------------------------------------------------
stdlib::ansi::cursor_to()   { printf '\033[%d;%dH' "${1:-1}" "${2:-1}"; }
stdlib::ansi::cursor_up()   { printf '\033[%dA' "${1:-1}"; }
stdlib::ansi::cursor_down() { printf '\033[%dB' "${1:-1}"; }
stdlib::ansi::cursor_fwd()  { printf '\033[%dC' "${1:-1}"; }
stdlib::ansi::cursor_back() { printf '\033[%dD' "${1:-1}"; }
stdlib::ansi::cursor_save()    { printf '\033[s'; }
stdlib::ansi::cursor_restore() { printf '\033[u'; }
stdlib::ansi::cursor_hide()    { printf '\033[?25l'; }
stdlib::ansi::cursor_show()    { printf '\033[?25h'; }

# ---------- screen control ---------------------------------------------------
stdlib::ansi::clear_screen() { printf '\033[2J\033[H'; }
stdlib::ansi::clear_line()   { printf '\033[2K\r'; }
stdlib::ansi::erase_to_eol() { printf '\033[K'; }

# ---------- strip ANSI codes -------------------------------------------------
# Remove all ANSI escape sequences from a string.
stdlib::ansi::strip() {
  local text="$1"
  # Use sed to remove CSI sequences
  printf '%s' "$text" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}
