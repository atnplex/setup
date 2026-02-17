#!/usr/bin/env bash
# Module: BWS (Bitwarden Secrets Manager) Server
# Deploys BWS HTTP server for multi-tier secret access

MODULE_ID="bws"
MODULE_DESC="Deploy BWS HTTP server for secret resolution"
MODULE_ORDER=85

module_supports_os() {
	case "$OS_ID" in
	ubuntu | debian) return 0 ;;
	*) return 1 ;;
	esac
}

module_requires_root() {
	return 0
}

module_interactive_prompt() {
	echo "Deploy BWS secrets server (Docker container on port 5000)?"
}

module_run() {
	local bws_dir="${NAMESPACE:-/atn}/services/bws"

	log_info "Setting up BWS server at $bws_dir"

	# Ensure Docker is available
	if ! command -v docker &>/dev/null; then
		log_error "Docker not found. Run module 50-docker first."
		return 1
	fi

	# Create directory structure
	mkdir -p "$bws_dir"

	# Check for BWS_ACCESS_TOKEN
	if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
		log_warn "BWS_ACCESS_TOKEN not set. Container will not start without it."
		log_info "Set BWS_ACCESS_TOKEN in $bws_dir/.env before starting."
	fi

	# Write docker-compose.yml
	cat >"$bws_dir/docker-compose.yml" <<'COMPOSE'
services:
  bws-server:
    image: bitwarden/bws:latest
    container_name: bws-server
    restart: unless-stopped
    ports:
      - "5000:5000"
    env_file:
      - .env
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:5000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 128M
          cpus: '0.25'
COMPOSE

	# Write .env template if not exists
	if [[ ! -f "$bws_dir/.env" ]]; then
		cat >"$bws_dir/.env" <<'ENV'
# BWS Server Configuration
# Populate BWS_ACCESS_TOKEN before starting
BWS_ACCESS_TOKEN=
BWS_PORT=5000
ENV
		log_info "Created $bws_dir/.env — populate BWS_ACCESS_TOKEN before starting"
	fi

	# Copy unified bws_client.sh
	local client_src="${NAMESPACE:-/atn}/github/atnplex/ssot-secrets/bws_client.sh"
	if [[ -f "$client_src" ]]; then
		cp "$client_src" "$bws_dir/bws_client.sh"
		chmod +x "$bws_dir/bws_client.sh"
		log_info "Installed bws_client.sh"
	fi

	# Start if token is available
	if [[ -n "${BWS_ACCESS_TOKEN:-}" ]]; then
		echo "BWS_ACCESS_TOKEN=${BWS_ACCESS_TOKEN}" >"$bws_dir/.env"
		cd "$bws_dir"
		docker compose up -d
		log_info "BWS server started on port 5000"
	else
		log_info "Skipping container start — BWS_ACCESS_TOKEN not set"
	fi
}
