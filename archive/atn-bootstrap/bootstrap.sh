#!/usr/bin/env bash
#
# ATN Infrastructure Bootstrap Script
# One command to set up any server with persistent MCP servers, tools, and configurations
#
# Usage: curl -fsSL https://raw.githubusercontent.com/atnplex/atn-bootstrap/main/bootstrap.sh | bash
#    OR: ./bootstrap.sh [--dry-run] [--skip-docker] [--skip-mcp]
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ATN_HOME="${ATN_HOME:-$HOME/.atn}"
ATN_DATA="${ATN_DATA:-$HOME/.antigravity-server/data}"
NAMESPACE="${NAMESPACE:-atn}"
LOG_FILE="/tmp/atn-bootstrap-$(date +%Y%m%d-%H%M%S).log"

# Flags
DRY_RUN=false
SKIP_DOCKER=false
SKIP_MCP=false
INTERACTIVE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --skip-docker) SKIP_DOCKER=true; shift ;;
        --skip-mcp) SKIP_MCP=true; shift ;;
        --non-interactive) INTERACTIVE=false; shift ;;
        -h|--help) 
            echo "ATN Bootstrap Script"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run          Show what would be done without making changes"
            echo "  --skip-docker      Skip Docker installation"
            echo "  --skip-mcp         Skip MCP server setup"
            echo "  --non-interactive  Run without prompts (use defaults or env vars)"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log() { echo -e "${BLUE}[ATN]${NC} $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

run() {
    if $DRY_RUN; then
        log "[DRY-RUN] Would execute: $*"
    else
        log "Executing: $*"
        eval "$@" 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Detect OS and architecture
detect_system() {
    log "Detecting system..."
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    case "$OS" in
        Linux) OS_TYPE="linux" ;;
        Darwin) OS_TYPE="darwin" ;;
        *) error "Unsupported OS: $OS" ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64) ARCH_TYPE="amd64" ;;
        aarch64|arm64) ARCH_TYPE="arm64" ;;
        *) error "Unsupported architecture: $ARCH" ;;
    esac
    
    # Detect package manager
    if command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    elif command -v yum &>/dev/null; then
        PKG_MGR="yum"
    elif command -v brew &>/dev/null; then
        PKG_MGR="brew"
    else
        PKG_MGR="unknown"
    fi
    
    # Detect if we're on specific host types
    HOSTNAME="$(hostname -s)"
    if [[ -f /etc/unraid-version ]]; then
        HOST_TYPE="unraid"
    elif tailscale status 2>/dev/null | grep -q "100\."; then
        HOST_TYPE="tailscale-connected"
    else
        HOST_TYPE="standalone"
    fi
    
    success "System: $OS_TYPE/$ARCH_TYPE, Package Manager: $PKG_MGR, Host Type: $HOST_TYPE"
}

# Install base dependencies
install_dependencies() {
    log "Installing base dependencies..."
    
    case "$PKG_MGR" in
        apt)
            run "sudo apt-get update -qq"
            run "sudo apt-get install -y -qq curl wget git jq unzip ca-certificates gnupg lsb-release"
            ;;
        yum)
            run "sudo yum install -y curl wget git jq unzip ca-certificates"
            ;;
        brew)
            run "brew install curl wget git jq"
            ;;
        *)
            warn "Unknown package manager, assuming dependencies exist"
            ;;
    esac
    
    success "Base dependencies installed"
}

# Install Docker
install_docker() {
    if $SKIP_DOCKER; then
        log "Skipping Docker installation (--skip-docker)"
        return
    fi
    
    if command -v docker &>/dev/null; then
        success "Docker already installed: $(docker --version)"
        return
    fi
    
    log "Installing Docker..."
    
    case "$PKG_MGR" in
        apt)
            # Add Docker's official GPG key
            run "sudo install -m 0755 -d /etc/apt/keyrings"
            run "curl -fsSL https://download.docker.com/linux/$( . /etc/os-release && echo \$ID)/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
            run "sudo chmod a+r /etc/apt/keyrings/docker.gpg"
            
            # Add the repository
            echo "deb [arch=$ARCH_TYPE signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$( . /etc/os-release && echo \$ID) $( . /etc/os-release && echo \$VERSION_CODENAME) stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            run "sudo apt-get update -qq"
            run "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
            ;;
        brew)
            run "brew install --cask docker"
            ;;
        *)
            warn "Please install Docker manually for your system"
            return
            ;;
    esac
    
    # Add user to docker group
    if [[ "$OS_TYPE" == "linux" ]]; then
        run "sudo usermod -aG docker $USER"
        warn "You may need to log out and back in for Docker group membership to take effect"
    fi
    
    success "Docker installed"
}

# Install GitHub CLI
install_gh_cli() {
    if command -v gh &>/dev/null; then
        success "GitHub CLI already installed: $(gh --version | head -1)"
    else
        log "Installing GitHub CLI..."
        
        case "$PKG_MGR" in
            apt)
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$ARCH_TYPE signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
                    sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                run "sudo apt-get update -qq && sudo apt-get install -y gh"
                ;;
            brew)
                run "brew install gh"
                ;;
            *)
                warn "Please install GitHub CLI manually"
                ;;
        esac
    fi
    
    # Authenticate if token available
    if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
        log "Authenticating GitHub CLI with token..."
        echo "$GITHUB_PERSONAL_ACCESS_TOKEN" | gh auth login --with-token 2>/dev/null && \
            success "GitHub CLI authenticated" || warn "GitHub CLI auth failed"
    elif [[ -f "$HOME/.antigravity-server/.env" ]]; then
        TOKEN=$(grep GITHUB_PERSONAL_ACCESS_TOKEN "$HOME/.antigravity-server/.env" 2>/dev/null | cut -d= -f2)
        if [[ -n "$TOKEN" ]]; then
            log "Authenticating GitHub CLI from .env file..."
            echo "$TOKEN" | gh auth login --with-token 2>/dev/null && \
                success "GitHub CLI authenticated" || warn "GitHub CLI auth failed"
        fi
    else
        warn "No GitHub token found. Run 'gh auth login' to authenticate."
    fi
}

# Pull MCP Docker images
pull_mcp_images() {
    if $SKIP_MCP; then
        log "Skipping MCP image pull (--skip-mcp)"
        return
    fi
    
    log "Pulling MCP Docker images..."
    
    MCP_IMAGES=(
        "mcp/filesystem"
        "mcp/git"
        "mcp/fetch"
        "mcp/memory"
        "mcp/sequentialthinking"
        "mcp/time"
        "mcp/playwright"
        "ghcr.io/github/github-mcp-server"
    )
    
    for img in "${MCP_IMAGES[@]}"; do
        log "Pulling $img..."
        docker pull "$img" 2>&1 | tail -1 || warn "Failed to pull $img"
    done
    
    success "MCP images pulled"
}

# Create MCP docker-compose
create_mcp_compose() {
    if $SKIP_MCP; then
        log "Skipping MCP compose creation (--skip-mcp)"
        return
    fi
    
    log "Creating MCP docker-compose..."
    
    mkdir -p "$ATN_HOME/mcp"
    
    cat > "$ATN_HOME/mcp/docker-compose.yml" << 'COMPOSE_EOF'
# ATN MCP Server Stack
# Auto-generated by atn-bootstrap
version: '3.8'

services:
  mcp-memory:
    image: mcp/memory
    container_name: atn-mcp-memory
    restart: unless-stopped
    volumes:
      - ${ATN_HOME:-~/.atn}/mcp/memory:/data
    stdin_open: true
    tty: true

  github-mcp:
    image: ghcr.io/github/github-mcp-server
    container_name: atn-github-mcp
    restart: unless-stopped
    environment:
      - GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_PERSONAL_ACCESS_TOKEN}
    stdin_open: true
    tty: true

networks:
  default:
    name: atn_bridge
    external: true
COMPOSE_EOF

    # Create .env for compose
    if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
        echo "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN" > "$ATN_HOME/mcp/.env"
        chmod 600 "$ATN_HOME/mcp/.env"
    fi
    
    success "MCP docker-compose created at $ATN_HOME/mcp/docker-compose.yml"
}

# Create systemd service for MCP stack
create_mcp_service() {
    if $SKIP_MCP || [[ "$OS_TYPE" != "linux" ]]; then
        return
    fi
    
    log "Creating systemd service for MCP stack..."
    
    sudo tee /etc/systemd/system/atn-mcp.service > /dev/null << EOF
[Unit]
Description=ATN MCP Server Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$ATN_HOME/mcp
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=$USER
Group=docker

[Install]
WantedBy=multi-user.target
EOF

    run "sudo systemctl daemon-reload"
    run "sudo systemctl enable atn-mcp.service"
    
    success "Systemd service created: atn-mcp.service"
}

# Create ATN network if not exists
create_docker_network() {
    if docker network inspect atn_bridge &>/dev/null; then
        success "Docker network atn_bridge already exists"
    else
        log "Creating Docker network atn_bridge..."
        run "docker network create atn_bridge"
        success "Docker network created"
    fi
}

# Setup Tailscale
setup_tailscale() {
    if command -v tailscale &>/dev/null; then
        if tailscale status &>/dev/null; then
            success "Tailscale already connected: $(tailscale ip -4 2>/dev/null || echo 'connected')"
            return
        fi
    fi
    
    log "Installing Tailscale..."
    
    case "$PKG_MGR" in
        apt)
            curl -fsSL https://tailscale.com/install.sh | sh
            ;;
        brew)
            run "brew install tailscale"
            ;;
        *)
            warn "Please install Tailscale manually: https://tailscale.com/download"
            return
            ;;
    esac
    
    if $INTERACTIVE; then
        log "Starting Tailscale authentication..."
        sudo tailscale up
    else
        warn "Run 'sudo tailscale up' to authenticate with Tailscale"
    fi
}

# Setup Cloudflared
setup_cloudflared() {
    if command -v cloudflared &>/dev/null; then
        success "Cloudflared already installed: $(cloudflared --version)"
        return
    fi
    
    log "Installing Cloudflared..."
    
    case "$PKG_MGR" in
        apt)
            curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
            echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared any main" | \
                sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
            run "sudo apt-get update -qq && sudo apt-get install -y cloudflared"
            ;;
        brew)
            run "brew install cloudflared"
            ;;
        *)
            warn "Please install cloudflared manually"
            ;;
    esac
    
    success "Cloudflared installed"
}

# Create convenient shell aliases
create_aliases() {
    log "Creating shell aliases..."
    
    ALIAS_FILE="$ATN_HOME/aliases.sh"
    
    cat > "$ALIAS_FILE" << 'ALIASES_EOF'
# ATN Infrastructure Aliases
# Source this file in your .bashrc/.zshrc

# MCP Management
alias mcp-start='cd ~/.atn/mcp && docker compose up -d'
alias mcp-stop='cd ~/.atn/mcp && docker compose down'
alias mcp-logs='cd ~/.atn/mcp && docker compose logs -f'
alias mcp-status='docker ps --filter "name=atn-" --format "table {{.Names}}\t{{.Status}}"'

# Antigravity Manager
alias ag-logs='docker logs -f antigravity-manager 2>/dev/null || journalctl -fu antigravity-manager'
alias ag-restart='docker restart antigravity-manager 2>/dev/null || systemctl restart antigravity-manager'

# Quick access
alias ts-status='tailscale status'
alias cf-status='systemctl status cloudflared'

# GitHub shortcuts
alias pr-list='gh pr list'
alias pr-view='gh pr view'
alias pr-merge='gh pr merge'
ALIASES_EOF

    # Add to bashrc if not already present
    if ! grep -q "source.*atn/aliases.sh" "$HOME/.bashrc" 2>/dev/null; then
        echo "source $ALIAS_FILE" >> "$HOME/.bashrc"
    fi
    
    success "Aliases created at $ALIAS_FILE"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ATN Bootstrap Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Configuration directory: $ATN_HOME"
    echo "  Log file: $LOG_FILE"
    echo ""
    echo "  Quick commands:"
    echo "    mcp-start      Start MCP server stack"
    echo "    mcp-status     Show running MCP containers"
    echo "    ag-logs        View Antigravity Manager logs"
    echo ""
    echo "  Next steps:"
    echo "    1. Reload shell: source ~/.bashrc"
    echo "    2. Start MCP stack: mcp-start"
    echo "    3. If needed, run: gh auth login"
    echo ""
    if [[ "$HOST_TYPE" == "tailscale-connected" ]]; then
        echo "  ✓ Tailscale connected: $(tailscale ip -4 2>/dev/null)"
    fi
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           ATN Infrastructure Bootstrap Script                 ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if $DRY_RUN; then
        warn "DRY RUN MODE - No changes will be made"
    fi
    
    detect_system
    install_dependencies
    install_docker
    create_docker_network
    install_gh_cli
    pull_mcp_images
    create_mcp_compose
    create_mcp_service
    setup_tailscale
    setup_cloudflared
    create_aliases
    print_summary
}

main "$@"
