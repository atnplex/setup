#!/bin/bash
# Connect to MCP servers via docker exec

# Get first running MCP container and connect to it
CONTAINER=$(docker ps --filter "name=mcp-" --format "{{.Names}}" | head -1)

if [ -z "$CONTAINER" ]; then
  echo "Error: No MCP containers running" >&2
  exit 1
fi

# Use docker exec to connect to the container's stdio
docker exec -i $CONTAINER sh
