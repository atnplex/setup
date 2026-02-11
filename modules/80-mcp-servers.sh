MODULE_ID="mcp_servers"
MODULE_DESC="Pull MCP Docker images for Antigravity agent"
MODULE_ORDER=80

module_supports_os() {
  case "$OS_ID" in
  ubuntu | debian) return 0 ;;
  *) return 1 ;;
  esac
}

module_requires_root() { return 1; } # Docker group, not root

module_run() {
  if ! command -v docker &>/dev/null; then
    log_warn "Docker not found. Skipping MCP image pull."
    return 1
  fi

  log_info "Checking MCP Docker images..."

  local images=(
    "mcp/filesystem"
    "mcp/git"
    "mcp/fetch"
    "mcp/memory"
    "mcp/sequentialthinking"
    "mcp/time"
    "mcp/playwright"
  )

  local pulled=0 skipped=0 failed=0
  for img in "${images[@]}"; do
    # Check if image already exists locally
    if docker image inspect "$img" &>/dev/null; then
      log_info "Image $img already present — skipping"
      ((skipped++))
    else
      log_info "Pulling $img..."
      if docker pull "$img" 2>&1 | tail -1; then
        ((pulled++))
      else
        log_warn "Failed to pull $img"
        ((failed++))
      fi
    fi
  done

  log_info "MCP images: $pulled pulled, $skipped already present, $failed failed"
}
