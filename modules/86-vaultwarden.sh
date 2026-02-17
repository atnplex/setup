#!/usr/bin/env bash
# Module: Vaultwarden (Self-Hosted Bitwarden)
# Deploys Vaultwarden password manager with automated backups

MODULE_ID="vaultwarden"
MODULE_DESC="Deploy Vaultwarden password manager with SQLite backup"
MODULE_ORDER=86

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
	echo "Deploy Vaultwarden password manager (Docker container on port 8222)?"
}

module_run() {
	local vw_dir="${NAMESPACE:-/atn}/services/vaultwarden"
	local backup_dir="${NAMESPACE:-/atn}/backups/vaultwarden"

	log_info "Setting up Vaultwarden at $vw_dir"

	if ! command -v docker &>/dev/null; then
		log_error "Docker not found. Run module 50-docker first."
		return 1
	fi

	mkdir -p "$vw_dir/data" "$backup_dir"

	# Write docker-compose.yml
	cat >"$vw_dir/docker-compose.yml" <<'COMPOSE'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - "8222:80"
      - "3012:3012"
    volumes:
      - ./data:/data
    env_file:
      - .env
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:80/alive"]
      interval: 30s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.25'

  vaultwarden-backup:
    image: bruceforce/vaultwarden-backup:latest
    container_name: vaultwarden-backup
    restart: unless-stopped
    depends_on:
      - vaultwarden
    volumes:
      - ./data:/data:ro
      - /atn/backups/vaultwarden:/backups
    environment:
      - BACKUP_DIR=/backups
      - CRON_TIME=0 */6 * * *
      - TIMESTAMP=true
      - DELETE_AFTER=30
COMPOSE

	# Write .env template if not exists
	if [[ ! -f "$vw_dir/.env" ]]; then
		cat >"$vw_dir/.env" <<'ENV'
# Vaultwarden Configuration
DOMAIN=https://vault.atnplex.cloud
ADMIN_TOKEN=
SIGNUPS_ALLOWED=false
INVITATIONS_ALLOWED=true
WEBSOCKET_ENABLED=true
LOG_LEVEL=info
SHOW_PASSWORD_HINT=false
ENV
		log_info "Created $vw_dir/.env — set ADMIN_TOKEN and DOMAIN before starting"
	fi

	# Attempt to pull admin token from BWS if available
	local bws_client="${NAMESPACE:-/atn}/services/bws/bws_client.sh"
	if [[ -f "$bws_client" ]]; then
		source "$bws_client"
		local admin_token
		admin_token=$(bws_get "VAULTWARDEN_ADMIN_TOKEN" 2>/dev/null) || true
		if [[ -n "$admin_token" ]]; then
			sed -i "s|^ADMIN_TOKEN=.*|ADMIN_TOKEN=${admin_token}|" "$vw_dir/.env"
			log_info "Injected ADMIN_TOKEN from BWS"
		fi
	fi

	# Start container
	if grep -q "^ADMIN_TOKEN=.\+" "$vw_dir/.env" 2>/dev/null; then
		cd "$vw_dir"
		docker compose up -d
		log_info "Vaultwarden started on port 8222"
		log_info "Backups scheduled every 6h to $backup_dir"
	else
		log_info "Skipping container start — ADMIN_TOKEN not set in .env"
	fi
}
