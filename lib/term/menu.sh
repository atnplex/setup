#!/usr/bin/env bash
# Module: term/menu
# Version: 0.1.0
# Provides: Interactive action menus with dynamic items
# Requires: term/ansi
[[ -n "${_STDLIB_MENU:-}" ]] && return 0
declare -g _STDLIB_MENU=1

# ── Internal State ─────────────────────────────────────────────────────
declare -gA _MENU_ITEMS=()      # menu:idx → "label\0func"
declare -gA _MENU_COUNTS=()    # menu → item_count

# ── stdlib::menu::create ──────────────────────────────────────────────
# Initialize a new menu.
# Usage: stdlib::menu::create menu_name
stdlib::menu::create() {
  local name="$1"
  _MENU_COUNTS["$name"]=0
}

# ── stdlib::menu::add_item ────────────────────────────────────────────
# Add an item to a menu.
# Usage: stdlib::menu::add_item menu_name label function_name
stdlib::menu::add_item() {
  local name="$1" label="$2" func="$3"
  local idx=${_MENU_COUNTS["$name"]}

  _MENU_ITEMS["${name}:${idx}"]="${label}|${func}"
  _MENU_COUNTS["$name"]=$(( idx + 1 ))
}

# ── stdlib::menu::add_separator ───────────────────────────────────────
# Add a visual separator to the menu.
stdlib::menu::add_separator() {
  local name="$1"
  local idx=${_MENU_COUNTS["$name"]}

  _MENU_ITEMS["${name}:${idx}"]="---|"
  _MENU_COUNTS["$name"]=$(( idx + 1 ))
}

# ── stdlib::menu::show ────────────────────────────────────────────────
# Display a menu and execute the selected action.
# Loops until user selects quit/exit option.
# Usage: stdlib::menu::show menu_name
stdlib::menu::show() {
  local name="$1"
  local count=${_MENU_COUNTS["$name"]:-0}

  [[ $count -eq 0 ]] && { echo "Menu '$name' is empty" >&2; return 1; }

  while true; do
    echo ""
    local visible_idx=0
    local -a action_map=()

    for (( i=0; i<count; i++ )); do
      local entry="${_MENU_ITEMS["${name}:${i}"]}"
      local label="${entry%%|*}"

      if [[ "$label" == "---" ]]; then
        echo "  ────────────────────────"
      else
        (( visible_idx++ ))
        action_map+=("$i")
        printf '  %2d) %s\n' "$visible_idx" "$label"
      fi
    done

    echo ""
    printf '  %2d) Quit\n' 0
    echo ""

    local choice
    read -rp "  Select [0-${visible_idx}]: " choice

    # Validate
    if [[ "$choice" == "0" || "$choice" == "q" || "$choice" == "Q" ]]; then
      return 0
    fi

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > visible_idx )); then
      echo "  Invalid selection" >&2
      continue
    fi

    # Execute the action
    local entry_idx=${action_map[$((choice - 1))]}
    local entry="${_MENU_ITEMS["${name}:${entry_idx}"]}"
    local func="${entry##*|}"

    if [[ -n "$func" ]] && declare -F "$func" &>/dev/null; then
      echo ""
      "$func"
    else
      echo "  Action not available: $func" >&2
    fi
  done
}

# ── stdlib::menu::dynamic ─────────────────────────────────────────────
# Show a dynamic menu that re-evaluates items each loop.
# check_fn returns item count, label_fn N returns label, action_fn N runs action.
# Usage: stdlib::menu::dynamic menu_name check_fn label_fn action_fn
stdlib::menu::dynamic() {
  local name="$1" check_fn="$2" label_fn="$3" action_fn="$4"

  while true; do
    local count
    count=$($check_fn)
    [[ $count -eq 0 ]] && { echo "No items available" >&2; return 0; }

    echo ""
    for (( i=1; i<=count; i++ )); do
      printf '  %2d) %s\n' "$i" "$($label_fn $i)"
    done
    echo ""
    printf '  %2d) Quit\n' 0
    echo ""

    local choice
    read -rp "  Select [0-${count}]: " choice

    [[ "$choice" == "0" || "$choice" == "q" ]] && return 0

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      echo ""
      $action_fn "$choice"
    else
      echo "  Invalid selection" >&2
    fi
  done
}
