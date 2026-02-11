# R66: Docker Networking Standards

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: HIGH - prevents network conflicts
> **Updated**: 2026-02-03

---

## Network CIDR Allocation

Each server MUST use a unique Docker network CIDR to prevent conflicts with Tailscale subnet routing.

### Current Allocations

| Server | Network Name | CIDR | Status |
| ------ | ------------ | ---- | ------ |
| VPS2 (condo) | `atn_bridge` | `172.20.0.0/16` | ✅ Active |
| VPS1 (vps) | `atn_bridge` | `172.18.0.0/16` | ✅ Active |
| Unraid | `atn_bridge` | `172.22.0.0/16` | 🔵 Proposed |
| WSL | `atn_bridge` | `172.24.0.0/16` | 🔵 Proposed (if Docker needed) |

### Reserved Ranges (DO NOT USE)

| Range | Reason |
| ----- | ------ |
| `172.17.0.0/16` | Docker default (avoid for custom networks) |
| `10.0.0.0/8` | Home LAN overlap risk |
| `100.64.0.0/10` | Tailscale CGNAT range |
| `192.168.0.0/16` | Common home LAN |

---

## Bridge User Standard

### Requirement

Each server MUST have a dedicated bridge user for Docker operations:

```bash
# User: atn_bridge
# Purpose: Docker container process ownership
# UID: 1001 (consistent across servers)
# GID: 1001

sudo useradd -u 1001 -g 1001 -M -s /sbin/nologin atn_bridge
```

### Current Status

| Server | atn_bridge User | Status |
| ------ | --------------- | ------ |
| VPS2 (condo) | TBD | 🔵 To Create |
| VPS1 (vps) | TBD | 🔵 To Create |
| Unraid | Does not exist | 🔵 To Create |
| WSL | N/A | Not needed (dev environment) |

---

## LAN IP Clash Detection

### Warning Triggers

Alert user if:

1. Server LAN IP overlaps with Tailscale subnet routing range
2. Docker CIDR overlaps with home LAN
3. Two servers use the same Docker CIDR

### Current LAN Status

| Server | LAN IP | Potential Clash |
| ------ | ------ | --------------- |
| VPS1 | Cloud (no local LAN) | ✅ No clash |
| VPS2 | Cloud (no local LAN) | ✅ No clash |
| Unraid | 10.0.0.x expected | ⚠️ Check against Docker |
| Windows | 10.0.0.198 | ⚠️ Verify no overlap |

---

## Network Creation Template

```bash
#!/bin/bash
set -euo pipefail

: "${NAMESPACE:=atn}"
: "${NETWORK_NAME:=${NAMESPACE}_bridge}"
: "${NETWORK_CIDR:=172.20.0.0/16}"

# Check if network exists
if docker network ls | grep -q "${NETWORK_NAME}"; then
    echo "Network ${NETWORK_NAME} already exists"
else
    docker network create \
        --driver bridge \
        --subnet "${NETWORK_CIDR}" \
        "${NETWORK_NAME}"
    echo "Created network ${NETWORK_NAME} with CIDR ${NETWORK_CIDR}"
fi
```

---

## Cross-References

- [R61: Infrastructure Standards](/atn/.gemini/rules/operational/infrastructure_standards.md)
- [Tailscale Network](/atn/.gemini/scratch/tailscale_network.md)
