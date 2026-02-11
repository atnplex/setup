# R74: Reliability Over Convenience

> **Authority**: OPERATIONAL RULE
> **Severity**: HIGH - MANDATORY for all automation
> **Created**: 2026-02-04

---

## Core Principle

> [!CAUTION]
> **ALWAYS use the standard, reliable option. NEVER take the lazy path.**

When multiple implementation options exist, prioritize:

1. **Reliability** over convenience
2. **Stability** over simplicity
3. **Explicit** over implicit
4. **Tested** over theoretical

---

## Specific Requirements

### Networking

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| Tailscale MagicDNS | Direct Tailscale IPs | MagicDNS requires specific conditions (Override DNS) |
| Dynamic hostnames | Static IPs or direct resolution | Reduces dependencies |
| Assumed DNS propagation | Explicit health checks | DNS can be stale |

**Example:**

```bash
# ❌ WRONG: Relies on MagicDNS
curl https://vps1.tailnet.ts.net/health

# ✅ CORRECT: Direct Tailscale IP
curl https://100.67.88.109/health
```

### Configuration

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| Auto-detection | Explicit configuration | Auto-detection can fail |
| Default values | Explicit values | Defaults can change |
| Environment inference | Environment variables | Clear contract |

### Scripting/Automation

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `set -e` alone | `set -euo pipefail` | Catches more errors |
| Implicit paths | Absolute paths | No ambiguity |
| Silent failures | Explicit error handling | Debuggable |

**Example:**

```bash
# ❌ WRONG: Silent failure
docker compose up -d 2>/dev/null

# ✅ CORRECT: Explicit error handling
if ! docker compose up -d; then
    echo "ERROR: Failed to start stack" >&2
    exit 1
fi
```

### Model/API Calls

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| Assumed availability | Health check first | Rate limits exist |
| Single provider | Failover chain | Providers go down |
| Blind retries | Exponential backoff | Respects limits |

---

## Enforcement

This rule applies to:

1. All bootstrap scripts
2. All Docker Compose files
3. All GitHub Actions workflows
4. All automation and CI/CD
5. All Traefik/proxy configurations

---

## Rationale

> "If it's scripted or automated, take the reliable path, always."

Automation runs unattended. Lazy shortcuts that work manually often fail in automated contexts due to:

- Missing interactive context
- Network timing issues
- Service dependency ordering
- Environment variable availability
