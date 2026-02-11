# R81: Tailscale IP-Only SSH Access

> **Version**: 1.0.0
> **Created**: 2026-02-04

---

## Rule

**ALWAYS use Tailscale IPs for SSH, never hostnames.**

| Server | Tailscale IP | Usage |
|--------|-------------|-------|
| VPS1 | `100.67.88.109` | `ssh alex@100.67.88.109` |
| VPS2/condo | `100.102.55.88` | `ssh alex@100.102.55.88` |
| Unraid | `100.76.168.116` | `ssh root@100.76.168.116` |
| WSL | `100.114.18.47` | `ssh alex@100.114.18.47` |

---

## Rationale

Per R74 (Reliability Over Convenience):

- MagicDNS is unreliable in some contexts
- Direct IPs always work
- Eliminates DNS resolution failures

## Examples

```bash
# ✅ Correct
scp file.sh alex@100.67.88.109:/tmp/
ssh alex@100.67.88.109 'command'

# ❌ Wrong
scp file.sh vps1:/tmp/
ssh vps1 'command'
```
