# R78: Derive Don't Hardcode

> **Authority**: OPERATIONAL RULE
> **Severity**: HIGH - MANDATORY for all configurations
> **Created**: 2026-02-04

---

## Core Principle

> [!CAUTION]
> **If a value can be derived, it MUST be derived. Never hardcode derivable values.**

---

## Derivation Hierarchy

```
Environment Variable
    ↓ (default if not set)
Configuration File
    ↓ (default if not found)
Computed/Detected Value
    ↓ (fallback)
Sensible Default
```

---

## Examples

### Paths

```bash
# ❌ Hardcoded
CONFIG_PATH="/atn/.gemini/config"

# ✅ Derived
NAMESPACE="${NAMESPACE:-atn}"
CONFIG_PATH="/${NAMESPACE}/.gemini/config"
```

### IPs

```bash
# ❌ Hardcoded
VPS1_IP="100.67.88.109"

# ✅ Derived from config or inventory
VPS1_IP="${VPS1_TAILSCALE_IP:-$(tailscale ip -4 vps1 2>/dev/null)}"
```

### Ports

```bash
# ❌ Hardcoded
TRAEFIK_PORT="443"

# ✅ Derived from service config
TRAEFIK_PORT="${TRAEFIK_HTTPS_PORT:-443}"
```

### URLs

```bash
# ❌ Hardcoded
API_URL="https://api.atnplex.com"

# ✅ Derived from domain
DOMAIN="${DOMAIN:-atnplex.com}"
API_URL="https://api.${DOMAIN}"
```

---

## Configuration Template

```bash
# config.sh - Central configuration with derivation

# Primary variables (can be overridden)
NAMESPACE="${NAMESPACE:-atn}"
DOMAIN="${DOMAIN:-atnplex.com}"

# Derived paths
NAMESPACE_ROOT="/${NAMESPACE}"
HOMELAB_ROOT="${HOMELAB_ROOT:-${NAMESPACE_ROOT}/homelab}"

# Derived URLs
API_URL="https://api.${DOMAIN}"
AG_URL="https://ag.${DOMAIN}"

# Platform detection for UID/GID
if [[ -f /etc/unraid-version ]]; then
    PUID="${PUID:-99}"
    PGID="${PGID:-100}"
else
    PUID="${PUID:-1000}"
    PGID="${PGID:-1000}"
fi
```

---

## Forbidden Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Inline IP addresses | Breaks when IP changes | Use variable or DNS |
| Inline ports | Inflexible | Use variable with default |
| Inline paths | Not portable | Derive from NAMESPACE |
| Inline domains | Can't change environments | Use DOMAIN variable |
| Inline usernames | Varies by platform | Detect or configure |

---

## Validation

Scripts should validate derived values:

```bash
validate_config() {
    [[ -z "$NAMESPACE" ]] && { echo "ERROR: NAMESPACE not set"; exit 1; }
    [[ -d "/${NAMESPACE}" ]] || { echo "ERROR: /${NAMESPACE} not found"; exit 1; }
}
```

---

## Rationale

1. **Environment Portability**: Same config works dev/staging/prod
2. **Single Source of Truth**: Change once, applies everywhere
3. **Debuggability**: Clear chain from variable to value
4. **Testability**: Override variables for testing
