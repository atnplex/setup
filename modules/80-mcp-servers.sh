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

  log_info "Pulling MCP Docker images..."

  local images=(
    "mcp/filesystem"
    "mcp/git"
    "mcp/fetch"
    "mcp/memory"
    "mcp/sequentialthinking"
    "mcp/time"
    "mcp/playwright"
  )

  local failed=0
  for img in "${images[@]}"; do
    log_info "Pulling $img..."
    if docker pull "$img" 2>&1 | tail -1; then
      log_info "Pulled $img"
    else
      log_warn "Failed to pull $img"
      ((failed++)) || true
    fi
  done

  if [[ $failed -gt 0 ]]; then
    log_warn "$failed MCP images failed to pull"
  else
    log_info "All MCP images pulled successfully"
  fi
}
