#!/usr/bin/env bash
# Module: sys/docker
# Version: 0.1.0
# Provides: Docker primitives — daemon check, network, image, container, compose
# Requires: docker
[[ -n "${_STDLIB_DOCKER:-}" ]] && return 0
declare -g _STDLIB_DOCKER=1

# ── stdlib::docker::available ─────────────────────────────────
# Check if Docker is installed and the daemon is running.
stdlib::docker::available() {
  command -v docker &>/dev/null || return 1
  docker info &>/dev/null 2>&1
}

# ── stdlib::docker::network_ensure ────────────────────────────
# Create a Docker network if it doesn't already exist.
# Usage: stdlib::docker::network_ensure name [driver]
stdlib::docker::network_ensure() {
  local name="$1"
  local driver="${2:-bridge}"

  if docker network inspect "$name" &>/dev/null 2>&1; then
    return 0
  fi

  docker network create --driver "$driver" "$name"
}

# ── stdlib::docker::image_exists ──────────────────────────────
# Check if a Docker image is available locally.
stdlib::docker::image_exists() {
  docker image inspect "$1" &>/dev/null 2>&1
}

# ── stdlib::docker::pull ──────────────────────────────────────
# Pull a Docker image. Returns 0 on success, 1 on failure.
stdlib::docker::pull() {
  docker pull "$1" 2>&1
}

# ── stdlib::docker::container_running ─────────────────────────
# Check if a container is currently running.
stdlib::docker::container_running() {
  local name="$1"
  [[ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" == "true" ]]
}

# ── stdlib::docker::container_exists ──────────────────────────
# Check if a container exists (running or stopped).
stdlib::docker::container_exists() {
  docker inspect "$1" &>/dev/null 2>&1
}

# ── stdlib::docker::compose_up ────────────────────────────────
# Run docker compose up -d in the given directory.
# Usage: stdlib::docker::compose_up [compose_dir]
stdlib::docker::compose_up() {
  local dir="${1:-.}"
  docker compose -f "${dir}/docker-compose.yml" up -d
}

# ── stdlib::docker::compose_down ──────────────────────────────
# Run docker compose down in the given directory.
stdlib::docker::compose_down() {
  local dir="${1:-.}"
  docker compose -f "${dir}/docker-compose.yml" down
}

# ── stdlib::docker::compose_status ────────────────────────────
# List services and their status for a compose project.
stdlib::docker::compose_status() {
  local dir="${1:-.}"
  docker compose -f "${dir}/docker-compose.yml" ps --format "table {{.Name}}\t{{.Status}}"
}
