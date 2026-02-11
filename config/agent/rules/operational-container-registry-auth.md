## Scoping & Security Recommendation

**Always follow the Principle of Least Privilege (PoLP).**

- **DO NOT** use a single "Everything PAT" for all tasks.
- **DO** scope your tokens to the minimum required permissions.
- **DO** use dedicated tokens for different registries (e.g., `GITHUB_PAT_PACKAGES` only for GHCR).

Storing scoped tokens in BWS makes them easy to manage without compromising your entire account if one is leaked.

---

## Required Secrets in BWS

The script will try these keys in order:

1. `GITHUB_PAT_PACKAGES` (Fine-grained or Classic with `write:packages`)
2. `GITHUB_PERSONAL_ACCESS_TOKEN`
3. `GITHUB_PAT`

| Secret Key | Registry | Required Scopes |
|------------|----------|-----------------|
| `GITHUB_PAT_PACKAGES` | ghcr.io | `write:packages`, `read:packages`, `delete:packages` |
| `DOCKER_HUB_TOKEN` | docker.io | Read/Write access |

---

## Authentication Flow

### 1. Preferred: Use BWS Helper Functions

```bash
# Derivative path relative to repo or script
source lib/ops/secrets_bws.sh

# GHCR (GitHub Container Registry)
bws_docker_login_ghcr "USERNAME"

# Docker Hub
bws_docker_login_hub "USERNAME"
```

### 2. Fallback: Manual with BWS

```bash
source lib/ops/secrets_bws.sh

# Get token and login
TOKEN=$(bws_get_secret "GITHUB_PAT_PACKAGES")
echo "$TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
```

### 3. CI/CD (GitHub Actions)

```yaml
- name: Login to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}

# Or with BWS:
- uses: bitwarden/sm-action@v2
  with:
    access_token: ${{ secrets.BWS_ACCESS_TOKEN }}
    secrets: |
      GITHUB_PAT_PACKAGES > GHCR_TOKEN
- run: echo "$GHCR_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
```

---

## Pre-Push Checklist

Before pushing container images:

1. ✅ `BWS_ACCESS_TOKEN` is set in environment
2. ✅ Target secret exists in BWS (`GITHUB_PAT_PACKAGES` or `DOCKER_HUB_TOKEN`)
3. ✅ Token has required scopes (see table above)
4. ✅ Using BWS helper function or explicit BWS fetch

---

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| `unauthenticated` | No login or expired token | Run `bws_docker_login_ghcr` |
| `permission_denied: scopes` | PAT missing `write:packages` | Create new PAT with correct scopes, store in BWS |
| `Missing access token` | `BWS_ACCESS_TOKEN` not set | Export token or source from file |

---

## Never Do This

```bash
# ❌ Hardcoded credentials
echo "ghp_secret123" | docker login ghcr.io -u user --password-stdin

# ❌ Relying on cached docker login
docker push ghcr.io/org/image  # May fail if session expired

# ❌ Using gh CLI token (wrong scopes)
gh auth token | docker login ghcr.io -u user --password-stdin
```

---

## Reference

- [R40: Secret Management](/atn/.gemini/rules/security/secrets.md)
- [R43: Runtime Fetching](/atn/.gemini/rules/operational/secrets_runtime.md)
- [R70: BWS Master Reference](/atn/.gemini/rules/security/bws_master.md)
