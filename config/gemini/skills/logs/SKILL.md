---
name: logs
description: View Docker container logs locally or remotely
argument-hint: <container> [server] [--tail N]
disable-model-invocation: true
---

# Docker Logs

View logs for container `$ARGUMENTS[0]` on server `$ARGUMENTS[1]`.

## Server Map

| Alias | Name | Tailscale IP | SSH User |
|-------|------|-------------|----------|
| `vps1` | vps | `100.67.88.109` | alex |
| `vps2` | condo | `100.102.55.88` | alex |
| `unraid` | unraid | `100.76.168.116` | root |

## Steps

1. Resolve server (default: local if no server specified)
2. Run: `docker logs <container> --tail 50`
3. If on remote: `ssh <user>@<ip> 'docker logs <container> --tail 50'`

## Filters

```bash
# Errors only
docker logs <container> 2>&1 | grep -i error

# Warnings
docker logs <container> 2>&1 | grep -i warn

# Follow live
docker logs <container> -f

# With timestamps
docker logs <container> --tail 50 -t
```
