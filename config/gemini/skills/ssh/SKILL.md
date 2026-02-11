---
name: ssh
description: SSH connection shortcuts for all servers
argument-hint: <server> [command]
disable-model-invocation: true
---

# SSH Remote

Connect to `$ARGUMENTS[0]` and run `$ARGUMENTS[1]` if provided.

## Rules

- **Always use Tailscale IP** — never MagicDNS hostnames
- **No passwords or SSH keys** — Tailscale ACL handles authentication
- **Use SSH aliases** from `~/.ssh/config` (e.g., `ssh vps1`)
- **Always use timeouts** — `timeout 10 ssh -o ConnectTimeout=5 ...`
- **Discover machines dynamically**: `tailscale status` shows all connected nodes

## Server Inventory

| Alias | Name | Role | Tailscale IP | User | OS |
|-------|------|------|-------------|------|-----|
| `vps1` | vps | Primary compute | `100.67.88.109` | alex | Linux |
| `vps2` | condo | Secondary compute (ARM) | `100.102.55.88` | alex | Linux |
| `unraid` | unraid | Storage/Media | `100.76.168.116` | root | Linux |
| `amd` | amd | Windows desktop | `100.118.253.91` | alex | Windows |
| `windows` | windows | Windows desktop (WSL) | `100.114.18.47` | alex | Windows/WSL |

> [!NOTE]
> VPS2 (condo) is typically the local machine running the agent. Use `localhost` for local services.
> The `windows` entry is the same physical machine as `amd` — `amd` is the Windows IP, `windows` may be the WSL IP.

## Steps

1. Resolve server name to SSH alias from inventory
2. If command provided: `timeout 10 ssh -o ConnectTimeout=5 <alias> '<command>'`
3. If no command: `ssh <alias>` (interactive)

## Dynamic Discovery

```bash
# Check if Tailscale is available on current machine
tailscale status 2>/dev/null && echo "Tailscale active" || echo "No Tailscale"

# Find all Tailscale machines and their IPs (human readable)
tailscale status

# JSON format — filter online machines
tailscale status --json | jq -r '.Peer[] | select(.Online==true) | "\(.HostName)\t\(.TailscaleIPs[0])\t\(.OS)"'

# Check if a specific machine is reachable
timeout 5 tailscale ping <tailscale-ip> --c 1
```

## Windows Desktop Access (WSL)

Windows machines running WSL can be accessed via SSH to run both Windows and Linux commands.

```bash
# Access WSL on Windows (Linux commands via WSL)
timeout 10 ssh -o ConnectTimeout=5 alex@100.114.18.47 'cat /etc/os-release'

# Access Windows files via WSL mount
timeout 10 ssh -o ConnectTimeout=5 alex@100.114.18.47 'cat "/mnt/c/Users/Alex/AppData/Roaming/Antigravity/User/settings.json"'

# Run PowerShell commands from WSL
timeout 10 ssh -o ConnectTimeout=5 alex@100.114.18.47 'powershell.exe -Command "Get-Process"'

# Access native Windows SSH (if OpenSSH enabled)
timeout 10 ssh -o ConnectTimeout=5 alex@100.118.253.91 'dir C:\Users\Alex'
```

> [!IMPORTANT]
> Windows desktop may not always be online (Docker Desktop / WSL must be running for WSL SSH).
> Always use `timeout` + `ConnectTimeout` to avoid hanging.
> If WSL SSH fails, try the native Windows SSH IP (`amd` / `100.118.253.91`).

## Cross-Machine Settings Access

Use SSH to read/write settings on remote machines:

```bash
# Read Antigravity client settings from Windows
timeout 10 ssh -o ConnectTimeout=5 alex@100.114.18.47 \
  'cat "/mnt/c/Users/Alex/AppData/Roaming/Antigravity/User/settings.json"'

# Write settings to Windows client via WSL
timeout 10 ssh -o ConnectTimeout=5 alex@100.114.18.47 \
  'echo '"'"'{"chat.tools.global.autoApprove": true}'"'"' > "/mnt/c/Users/Alex/AppData/Roaming/Antigravity/User/settings.json"'
```

## Fallback Strategy

1. Try SSH alias first: `ssh vps1 'command'`
2. If alias fails, try direct IP: `ssh alex@100.67.88.109 'command'`
3. If SSH fails, check connectivity: `tailscale ping <ip> --c 1`
4. If machine offline, report to user and suggest alternatives

## Examples

```bash
# Run command on VPS1 via alias
timeout 10 ssh vps1 'docker ps'

# Check disk on Unraid
timeout 10 ssh unraid 'df -h'

# Direct IP syntax (if alias not available)
timeout 10 ssh alex@100.67.88.109 'hostname'

# Multi-command on remote
timeout 30 ssh vps1 'docker ps && docker stats --no-stream'
```
