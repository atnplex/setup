#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load core libs
source "$ROOT_DIR/lib/core.sh"
source "$ROOT_DIR/lib/registry.sh"
source "$ROOT_DIR/lib/menu.sh"

main() {
  detect_os
  parse_args "$@"
  load_config_if_any

  registry_init "$ROOT_DIR/modules"

  if [[ "$MODE" == "interactive" ]]; then
    selected_modules=($(menu_select_modules))
  else
    selected_modules=($(resolve_modules_from_flags_or_config))
  fi

  run_id="$(date +%Y%m%d-%H%M%S)"
  run_dir="$ROOT_DIR/state/runs/$run_id"
  mkdir -p "$run_dir"

  emit_run_manifest "$run_dir/run-manifest.json" "${selected_modules[@]}"

  for module_id in "${selected_modules[@]}"; do
    run_module "$module_id" "$run_dir"
  done

  log_info "Bootstrap complete. Run artifacts: $run_dir"
}

main "$@"
