#!/bin/bash
# save as ~/start-mcp-servers.sh

# Function to start a container if it doesn't exist
start_mcp_container() {
  local name=$1
  local image=$2
  local env_vars=$3
  
  if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
    # Container exists, make sure it's running
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
      echo "Starting existing container: $name"
      docker start $name
    else
      echo "Container already running: $name"
    fi
  else
    # Container doesn't exist, create it
    echo "Creating new container: $name"
    docker run -d \
      --name $name \
      --restart unless-stopped \
      $env_vars \
      $image
  fi
}

# Start MCP servers
start_mcp_container "mcp-git" "mcp/git" ""
start_mcp_container "mcp-filesystem" "mcp/filesystem" "--network none"
start_mcp_container "mcp-fetch" "mcp/fetch" ""
start_mcp_container "mcp-playwright" "mcp/playwright" ""
start_mcp_container "mcp-github" "ghcr.io/github/github-mcp-server" "-e GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_PAT}"

echo "All MCP servers started/verified"
