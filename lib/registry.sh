#!/usr/bin/env bash

declare -a MODULE_IDS=()
declare -A MODULE_ORDER_MAP=()

registry_init() {
  local modules_dir="$1"
  for f in "$modules_dir"/*.sh; do
    # shellcheck disable=SC1090
    source "$f"
    MODULE_IDS+=("$MODULE_ID")
    MODULE_ORDER_MAP["$MODULE_ID"]="$MODULE_ORDER"
  done

  # sort MODULE_IDS by MODULE_ORDER
  IFS=$'\n' MODULE_IDS=($(for id in "${MODULE_IDS[@]}"; do
    echo "${MODULE_ORDER_MAP[$id]}:$id"
  done | sort -n | cut -d: -f2))
  unset IFS
}

run_module() {
  local module_id="$1"
  local run_dir="$2"

  if ! module_supports_os 2>/dev/null; then
    log_info "Skipping $module_id (unsupported on $OS_ID)"
    return
  fi

  if module_requires_root 2>/dev/null; then
    if [[ $EUID -ne 0 ]]; then
      log_warn "Module $module_id requires root; skipping (not root)."
      return
    fi
  fi

  log_info "Running module: $module_id"
  local log_file="$run_dir/${module_id}.log"
  if module_run >"$log_file" 2>&1; then
    log_info "Module $module_id completed successfully."
  else
    log_error "Module $module_id failed. See $log_file"
  fi
}

resolve_modules_from_flags_or_config() {
  if [[ ${#MODULE_FLAGS[@]} -gt 0 ]]; then
    printf '%s\n' "${MODULE_FLAGS[@]}"
  else
    # default: run all modules
    printf '%s\n' "${MODULE_IDS[@]}"
  fi
}

emit_run_manifest() {
  local path="$1"; shift
  local modules=("$@")
  {
    echo '{'
    echo '  "timestamp": "'"$(date --iso-8601=seconds)"'",'
    echo '  "os_id": "'"$OS_ID"'",'
    echo '  "os_version": "'"$OS_VERSION_ID"'",'
    echo '  "modules": ['
    local first=1
    for m in "${modules[@]}"; do
      if [[ $first -eq 0 ]]; then echo ','; fi
      printf '    "%s"' "$m"
      first=0
    done
    echo
    echo '  ]'
    echo '}'
  } > "$path"
}
