# PAT Requirements for Container Registries

> **Last Updated**: 2026-02-05
> **Authority**: R80 Container Registry Authentication

---

## GHCR (GitHub Container Registry)

### Required: Classic PAT

Fine-grained PATs do NOT support `write:packages`. You must use a **Classic PAT**.

### Creation URL

<https://github.com/settings/tokens/new>

### Required Scopes

| Scope | Purpose |
|-------|---------|
| `write:packages` | Push images to GHCR |
| `read:packages` | Pull images from GHCR |
| `delete:packages` | Delete images (optional) |
| `repo` | Access private repos (if pushing from private repo) |

### Storage in BWS

- **Key**: `GITHUB_PAT_PACKAGES`
- **Project**: `secrets`

### Expiration

- Set to **No expiration** for automation tokens
- Or set calendar reminder for renewal

---

## Docker Hub

### Required: Access Token

Create at: <https://hub.docker.com/settings/security>

### Permissions

- **Read & Write** for push operations
- **Read-only** for pull-only scenarios

### Storage in BWS

- **Key**: `DOCKER_HUB_TOKEN`
- **Project**: `secrets`

---

## Token Rotation Policy

| Token Type | Rotation Frequency | Alert Before |
|------------|-------------------|--------------|
| GHCR Classic PAT | Annually | 30 days |
| Docker Hub Token | Annually | 30 days |

---

## Verification Commands

```bash
# Verify GHCR token has correct scopes
curl -H "Authorization: Bearer $(bws_get_secret GITHUB_PAT_PACKAGES)" \
  https://api.github.com/user | jq '.login'

# Verify Docker Hub token
curl -H "Authorization: Bearer $(bws_get_secret DOCKER_HUB_TOKEN)" \
  https://hub.docker.com/v2/users/atnplex
```

---

## Quick Setup Checklist

1. [ ] Create Classic PAT at <https://github.com/settings/tokens/new>
2. [ ] Select scopes: `write:packages`, `read:packages`, `repo`
3. [ ] Set expiration to "No expiration" (for automation)
4. [ ] Copy token value
5. [ ] Store in BWS as `GITHUB_PAT_PACKAGES`
6. [ ] Test: `source /atn/github/atn/lib/ops/secrets_bws.sh && bws_docker_login_ghcr`
