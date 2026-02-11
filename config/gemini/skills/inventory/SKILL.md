---
name: inventory
description: Collect system inventory from local or remote servers
argument-hint: [all|<hostname>]
disable-model-invocation: true
context: fork
---

# System Inventory

Discover services on `$ARGUMENTS` (default: current server).

> **Run this FIRST before any infrastructure work.**

## Usage

- `/inventory` — Current server only
- `/inventory all` — All Tailscale-connected devices
- `/inventory <hostname>` — Specific server

## Compute Priority

1. **VPS1/VPS2** (Always On) — max out these first
2. **Windows Desktop** (Transient) — temp/GPU tasks
3. **Unraid** (Media Server) — only if specifically needed

## Known Hosts

| Alias | Hostname | Tailscale IP | Role | SSH User |
|-------|----------|--------------|------|----------|
| `vps1` | vps | `100.67.88.109` | Primary compute | alex |
| `vps2` | condo | `100.102.55.88` | Secondary compute (ARM) | alex |
| `amd` | amd | `100.118.253.91` | Windows (RTX 3080) | alex |
| `unraid` | unraid | `100.76.168.116` | Media/Storage | root |

## Per-Host Discovery

```bash
# Tailscale devices
tailscale status | grep -v "^#" | awk '{print $1, $2, $5}'

# ALL containers (running AND stopped)
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Docker images
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'

# Docker volumes
docker volume ls

# Compose files
find /srv /home -name "docker-compose*.yml" -o -name "compose*.yml" 2>/dev/null

# Systemd services
systemctl list-units --type=service --all | grep -E "docker|caddy|nginx|tailscale"

# Resources
echo "CPU: $(nproc) cores"
echo "RAM: $(free -h | awk '/Mem:/{print $2" total, "$7" available"}')"
echo "Disk: $(df -h / | awk 'NR==2{print $4" free of "$2}')"
```

## Quick One-Liner (All Hosts)

```bash
for ip in $(tailscale status | awk 'NR>1 && !/offline/ {print $1}'); do
  echo "=== $ip ==="
  timeout 10 ssh -o StrictHostKeyChecking=no $ip \
    "hostname; docker ps -a --format '{{.Names}} {{.Status}}'; free -h | grep Mem" 2>/dev/null
done
```

## Output

Write results to `/atn/.gemini/scratch/inventory.md`
