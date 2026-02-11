# R75: Namespace-Based Path Derivation

> **Authority**: OPERATIONAL RULE
> **Severity**: HIGH - MANDATORY for all path references
> **Created**: 2026-02-04

---

## Core Principle

> [!CAUTION]
> **NEVER hardcode paths. ALWAYS derive from NAMESPACE variable.**

---

## Required Variables

```bash
# Primary variable (set once, derive everything else)
NAMESPACE="${NAMESPACE:-atn}"

# Derived paths
NAMESPACE_ROOT="/${NAMESPACE}"
NAMESPACE_CONFIG="${NAMESPACE_ROOT}/.gemini"
NAMESPACE_RULES="${NAMESPACE_CONFIG}/rules"
NAMESPACE_WORKFLOWS="${NAMESPACE_CONFIG}/workflows"
NAMESPACE_SKILLS="${NAMESPACE_CONFIG}/antigravity/skills"

# Infrastructure paths
NAMESPACE_SECRETS="${NAMESPACE_ROOT}/.config/secrets"
NAMESPACE_TMP="${NAMESPACE_ROOT}/tmp"

# Volatile Data Rules
# 1. ALL cache, working directories, and temporary files MUST be under $NAMESPACE_TMP
# 2. $NAMESPACE_TMP MUST be mounted as a **tmpfs** (in-memory) to ensure data is never persisted to disk.
#    - Example mount: `mount -t tmpfs -o size=1G,mode=1777 tmpfs /$NAMESPACE/tmp`
# 3. NO nested caches or temp files are allowed within $NAMESPACE_SECRETS
# 4. Secrets directory MUST only contain persistent secret metadata (encrypted files, keys)

# Homelab paths (derive from namespace)
HOMELAB_ROOT="${HOMELAB_ROOT:-${NAMESPACE_ROOT}/homelab}"
HOMELAB_CONFIG="${HOMELAB_ROOT}/config"
HOMELAB_DATA="${HOMELAB_ROOT}/data"
HOMELAB_SECRETS="${NAMESPACE_SECRETS}"
```

---

## Usage Examples

### ✅ Correct

```bash
# Derive from variable
source "${NAMESPACE_ROOT}/bootstrap/common.sh"
docker compose -f "${HOMELAB_ROOT}/docker-compose/core.yml" up -d
```

### ❌ Incorrect

```bash
# Hardcoded paths - NEVER DO THIS
source /atn/bootstrap/common.sh
docker compose -f /opt/homelab/docker-compose/core.yml up -d
```

---

## Script Header Template

Every script MUST start with:

```bash
#!/bin/bash
set -euo pipefail

# Namespace derivation
NAMESPACE="${NAMESPACE:-atn}"
NAMESPACE_ROOT="/${NAMESPACE}"

# Derive all other paths from NAMESPACE_ROOT
# ...
```

---

## Environment File

Create `${NAMESPACE_ROOT}/.env` as single source:

```bash
# /atn/.env - Namespace configuration
NAMESPACE=atn
NAMESPACE_ROOT=/atn
HOMELAB_ROOT=/atn/homelab
```

Scripts source this file:

```bash
source "/${NAMESPACE:-.}/.env" 2>/dev/null || true
```

---

## Rationale

1. **Portability**: Change namespace once, all paths update
2. **Testing**: Can run with different namespace for staging
3. **Multi-tenant**: Support multiple namespaces on same host
4. **No Magic**: Every path is traceable to a variable
