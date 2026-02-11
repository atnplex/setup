# R76: Standard UID/GID for Stability

> **Authority**: OPERATIONAL RULE
> **Severity**: HIGH - MANDATORY for all container configurations
> **Created**: 2026-02-04

---

## Core Principle

> [!CAUTION]
> **Use platform-standard UID:GID values. Do NOT create custom UIDs that may conflict.**

---

## Platform Standards

| Platform | Standard UID:GID | User | Notes |
|----------|------------------|------|-------|
| Unraid | 99:100 | nobody:users | Default for all containers |
| Debian/Ubuntu | 1000:1000 | First user | Standard user account |
| Alpine | 1000:1000 | appuser | Common convention |

---

## Selection Logic

```bash
# Detect platform and set appropriate UID:GID
detect_uid_gid() {
    if [[ -f /etc/unraid-version ]] || grep -qi unraid /etc/os-release 2>/dev/null; then
        # Unraid: Use standard nobody:users
        export PUID=99
        export PGID=100
    else
        # Debian/Ubuntu/Other: Use standard first user
        export PUID=1000
        export PGID=1000
    fi
}
```

---

## Docker Compose Usage

```yaml
services:
  app:
    image: example/app
    environment:
      - PUID=${PUID:-99}
      - PGID=${PGID:-100}
    user: "${PUID:-99}:${PGID:-100}"
```

---

## Forbidden Practices

❌ **DO NOT** create random high UIDs (e.g., 65534, 33333)
❌ **DO NOT** use UID 0 (root) unless absolutely required
❌ **DO NOT** assume UID without detection
❌ **DO NOT** mix UID standards on same host

---

## Rationale

1. **File Permissions**: Consistent ownership across containers
2. **No Conflicts**: Standard UIDs don't clash with system accounts
3. **Unraid Compatibility**: 99:100 is expected and works everywhere
4. **Stability**: Platform-native values are tested and reliable
