# R79: VPS-First Deployment Strategy

> **Authority**: OPERATIONAL RULE
> **Severity**: HIGH - MANDATORY for all deployments
> **Created**: 2026-02-04

---

## Core Principle

> [!CAUTION]
> **ALWAYS deploy to VPS first. Unraid is the LAST server to update.**

---

## Deployment Order

```text
1. VPS1 (staging/test)    ← First deployment, catch issues here
2. VPS2 (secondary)       ← Confirm on second VPS
3. WSL (dev)              ← Optional dev testing
4. Unraid (production)    ← LAST, only after VPS validation
```

---

## Rationale

- **Unraid is most critical**: Stores all media, runs most services
- **VPS are expendable**: Easy to recreate, minimal data at risk
- **Catch issues early**: VPS deployment validates before Unraid
- **Rollback is easier**: VPS issues don't affect home services

---

## Enforcement

### Before ANY Unraid Deployment

1. Verify successful deployment on at least one VPS
2. Run health checks on VPS deployment
3. Confirm no regressions in VPS logs
4. Wait minimum 5 minutes after VPS deployment

### CI/CD Pipeline Example

```yaml
jobs:
  deploy-vps1:
    runs-on: vps1
    steps: [deploy, health-check]

  deploy-vps2:
    needs: deploy-vps1
    runs-on: vps2
    steps: [deploy, health-check]

  deploy-unraid:
    needs: [deploy-vps1, deploy-vps2]
    runs-on: unraid
    # Manual approval gate
    environment: production
```

---

## Exceptions

Manual Unraid-first only allowed for:

- Unraid-specific bug fixes
- Hardware-related changes
- Emergency recovery (documented justification required)
