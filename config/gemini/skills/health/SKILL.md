---
name: health
description: Check health endpoints for running services
argument-hint: [service|all]
disable-model-invocation: true
---

# Health Check

Check health of `$ARGUMENTS` services.

## Server Map

| Name | Tailscale IP |
|------|-------------|
| vps | 100.102.55.88 |
| condo | 100.67.88.109 |
| unraid | 100.76.168.116 |

## Steps

1. If `$ARGUMENTS` is "all" or empty, check all known services on all servers
2. If a specific service is named, find it and check its health endpoint
3. Report status with a pass/fail per service

## Quick Checks

```bash
# Antigravity Manager (condo)
curl -s http://100.67.88.109:9045/health

# Antigravity Manager (vps)
curl -s http://100.102.55.88:9045/health

# Via SSH for internal-only services
ssh alex@100.67.88.109 'curl -s http://localhost:9045/health'
```

## Troubleshooting

If health check fails:

1. Check container status: `docker ps`
2. View logs: `docker logs <container> --tail 50`
3. Check port binding: `ss -tlnp | grep <port>`
