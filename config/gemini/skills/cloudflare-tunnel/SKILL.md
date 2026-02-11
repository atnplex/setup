---
name: cloudflare-tunnel
description: Manage Cloudflare Tunnels (cloudflared) across servers — system service on VPS, plugin on Unraid
argument-hint: [status|configure|restart] [server]
disable-model-invocation: true
---

# Cloudflare Tunnel (cloudflared) Management

> **Architecture decision**: cloudflared runs as a **systemd service** on VPS1/VPS2, and as a **plugin** on Unraid. This avoids Docker dependency for critical networking infrastructure.

## Why NOT Docker for cloudflared

On VPS1/VPS2, running cloudflared as a Docker container creates a circular dependency:
- If Docker crashes/hangs → cloudflared goes down → remote access via CF tunnel lost
- System service has no such dependency — it runs independently of Docker

On Unraid, Docker depends on the array being started. A plugin runs from RAM at boot, before the array:
- Array down → Docker down → tunnel down (if Docker)
- Plugin → tunnel available even without array

## Server Architecture

| Server | cloudflared Type | Config Location | Managed By |
|--------|-----------------|-----------------|------------|
| **VPS1** | systemd service | `/etc/cloudflared/` | `systemctl` |
| **VPS2** | systemd service | `/etc/cloudflared/` | `systemctl` |
| **Unraid** | Plugin (static binary) | `/boot/config/plugins/cloudflared/` | Plugin system |

## VPS1/VPS2: systemd Service

### Install (Debian 12)

```bash
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install -y cloudflared
```

### Configure

```bash
# Login (one-time, creates cert.pem)
cloudflared tunnel login

# Create tunnel (or use existing)
cloudflared tunnel create <tunnel-name>

# Config: /etc/cloudflared/config.yml
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml <<'EOF'
tunnel: <TUNNEL_ID>
credentials-file: /etc/cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: example.atnplex.com
    service: http://localhost:PORT
  - service: http_status:404
EOF
```

### Enable & Start

```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

### Management

```bash
sudo systemctl status cloudflared       # Status
sudo systemctl restart cloudflared      # Restart
sudo journalctl -u cloudflared -f --no-pager -n 50  # Logs
sudo apt update && sudo apt upgrade cloudflared      # Update
```

## Unraid: Plugin

### Install

Via Community Applications or manually:
1. Dashboard → Plugins → Install Plugin
2. URL: community plugin URL or custom `.plg` file

### Config

Plugin config persists on USB (`/boot/config/plugins/cloudflared/`):
- Token-based auth (no cert.pem needed)
- Configure routes via Cloudflare dashboard or API

### Management

```bash
/etc/rc.d/rc.cloudflared status    # Status
/etc/rc.d/rc.cloudflared restart   # Restart
cat /var/log/cloudflared.log       # Logs
```

## Verify Tunnel Status

```bash
# Via Cloudflare API (any machine with CF_API_TOKEN)
curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel" \
  | jq '.result[] | {name, id, status}'

# Local
cloudflared tunnel info <TUNNEL_NAME>
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| 502 on CF domain | Is cloudflared running? `systemctl status cloudflared` |
| Tunnel "inactive" | Credentials file missing or expired |
| DNS not resolving | CNAME → `<TUNNEL_ID>.cfargotunnel.com` |
| Connection refused | Local service not listening on configured port |

## Access Hierarchy

```
1. Tailscale SSH          — always works if Tailscale is up
2. Cloudflare Tunnel      — system service (VPS) / plugin (Unraid), no Docker dep
3. Caddy reverse proxy    — Docker-dependent, for HTTPS on Tailscale IPs
4. Direct port access     — Tailscale IP + port
```
