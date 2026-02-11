---
name: deploy
description: Deploy or restart Docker services on VPS1, VPS2, or Unraid
argument-hint: <service> <server>
disable-model-invocation: true
---

# Deploy Service

Deploy `$ARGUMENTS[0]` to `$ARGUMENTS[1]`.

## Server Map

| Alias | Name | Tailscale IP | SSH User |
|-------|------|-------------|----------|
| `vps1` | vps | `100.67.88.109` | alex |
| `vps2` | condo | `100.102.55.88` | alex |
| `unraid` | unraid | `100.76.168.116` | root |

## Steps

1. Resolve server name to Tailscale IP from the map above
2. SSH to the target server
3. Navigate to service directory: `cd ~/<service>/docker` or find compose file
4. Pull latest images: `docker compose pull`
5. Start/restart: `docker compose up -d`
6. Verify health: `curl -s http://localhost:<PORT>/health`
7. Check logs: `docker logs <service> --tail 10`

## Example

```bash
# Deploy antigravity-manager on condo
ssh alex@100.67.88.109 'cd ~/antigravity-manager/docker && docker compose up -d'
```

## Notes

- If no server specified, ask the user
- If no service specified, ask the user
- Always verify health after deploy
