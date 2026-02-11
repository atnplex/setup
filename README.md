# ATN Server Setup

Universal bootstrap for ATN infrastructure servers. One repo to set up any Debian server with everything needed: Docker, Tailscale, Cloudflared, GitHub CLI, MCP servers, and the full Antigravity agent configuration.

## Quick Start

```bash
# Clone and run all modules
git clone https://github.com/atnplex/setup.git /atn/github/setup
cd /atn/github/setup

# Option 1: Run the all-in-one bootstrap (installs everything)
./bootstrap.sh

# Option 2: Run the modular system (ordered modules)
source lib/core.sh
source lib/registry.sh
detect_os
parse_args "$@"
registry_init modules
# Then run individual or all modules
```

## Modules (execution order)

| Order | Module | Description |
|-------|--------|-------------|
| 10 | `ssh` | Configure SSH server and client |
| 20 | `users-groups` | Create users and set permissions |
| 30 | `tailscale` | Install Tailscale mesh VPN |
| 40 | `cloudflared` | Install Cloudflare Tunnel |
| 50 | `docker` | Install Docker Engine + Compose |
| 60 | `github-cli` | Install `gh` CLI + authenticate |
| 70 | `agent-config` | **Deploy AG rules, skills, workflows, settings** |
| 80 | `mcp-servers` | Pull MCP Docker images |

## Config Directory

The `config/` directory contains the portable, version-controlled agent configuration:

```
config/
├── agent/
│   ├── rules/          # 60+ operational, format, and security rules
│   └── learning/       # Learning patterns and reflections
├── gemini/
│   ├── GEMINI.md       # Global rules entry point
│   ├── mcp_config.json # MCP server configuration
│   ├── skills/         # 22 skills with SKILL.md + scripts
│   ├── global_workflows/  # 19 workflows (/triage, /resume, etc.)
│   └── personas/       # 13 persona definitions
├── baseline/           # Baseline rules (format, execution, governance)
└── vscode/
    └── machine-settings.json  # Auto-approve and editor settings
```

### What's NOT in this repo (sync separately)

| Data | Size | Sync method |
|------|------|-------------|
| Brain/conversations | ~180MB | Syncthing or cloud drive |
| Scratch state (session_log, todo) | ~30MB | Syncthing |
| VS Code server binaries | ~2.5GB | Auto-downloaded on first connect |
| Appdata (service volumes) | varies | Per-service backup |

## Servers

| Server | Tailscale IP | Role |
|--------|-------------|------|
| VPS1 (vps) | 100.67.88.109 | HA secondary |
| VPS2 (condo) | 100.102.55.88 | HA primary |
| Unraid | 100.76.168.116 | Media services |
| Debian VM | 100.74.111.60 | Development/testing |

## Environment Variables

Set these before running for non-interactive setup:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
export CLOUDFLARED_TOKEN="eyJ..."       # Cloudflare tunnel token
export NAMESPACE="/atn"             # Default: /atn
```
