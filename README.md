# ATN Bootstrap

Universal bootstrap script for ATN infrastructure - sets up Docker, MCP servers, gh CLI, Tailscale, Cloudflared on any server.

## One-Liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/atnplex/atn-bootstrap/main/bootstrap.sh | bash
```

## What It Does

- ✅ Detects OS and architecture (Linux/macOS, x86_64/arm64)
- ✅ Installs base dependencies (curl, wget, git, jq)
- ✅ Installs Docker with compose plugin
- ✅ Installs and authenticates GitHub CLI (`gh`)
- ✅ Pulls MCP Docker images
- ✅ Creates MCP docker-compose with systemd service
- ✅ Installs Tailscale for mesh networking
- ✅ Installs Cloudflared for tunnel access
- ✅ Creates convenient shell aliases

## Options

```bash
./bootstrap.sh [OPTIONS]

Options:
  --dry-run          Show what would be done without making changes
  --skip-docker      Skip Docker installation
  --skip-mcp         Skip MCP server setup
  --non-interactive  Run without prompts (use defaults or env vars)
  -h, --help         Show help message
```

## After Bootstrap

Reload your shell and use these commands:

```bash
source ~/.bashrc

# MCP Management
mcp-start      # Start MCP server stack
mcp-stop       # Stop MCP servers
mcp-logs       # View MCP logs
mcp-status     # Show running MCP containers

# Antigravity Manager
ag-logs        # View Antigravity Manager logs
ag-restart     # Restart Antigravity Manager

# Quick access
ts-status      # Tailscale status
cf-status      # Cloudflared status

# GitHub shortcuts
pr-list        # List PRs
pr-view        # View current PR
pr-merge       # Merge PR
```

## Environment Variables

The script looks for tokens in:
1. `GITHUB_PERSONAL_ACCESS_TOKEN` environment variable
2. `~/.antigravity-server/.env` file

Set these before running for automatic authentication.

## Supported Systems

| OS | Architecture | Package Manager |
|----|--------------|----------------|
| Debian/Ubuntu | x86_64, arm64 | apt |
| RHEL/CentOS | x86_64, arm64 | yum |
| macOS | x86_64, arm64 | brew |
| Unraid | x86_64 | (custom detection) |

## License

MIT
