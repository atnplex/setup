#!/usr/bin/env bash

menu_select_modules() {
  echo "Select modules to run (space-separated indices, empty = all):"
  local i=1
  for id in "${MODULE_IDS[@]}"; do
    echo "  [$i] $id"
    i=$((i+1))
  done
  printf 'Selection: '
  read -r selection

  if [[ -z "$selection" ]]; then
    printf '%s\n' "${MODULE_IDS[@]}"
    return
  fi

  local selected_ids=()
  for idx in $selection; do
    local pos=$((idx-1))
    selected_ids+=("${MODULE_IDS[$pos]}")
  done

  printf '%s\n' "${selected_ids[@]}"
}
