---
trigger: always_on
---

# Secrets Management

> **Authority**: GLOBAL SECURITY RULE — HIGHEST PRECEDENCE
> **Severity**: CRITICAL — violations are unacceptable
> **Scope**: All agents, all operations, all environments

---

## Core Principle

> [!CAUTION]
> **NEVER** read, output, log, or expose secrets. Always use variables and pipe directly.
> **ALWAYS** use existing BWS libraries. The implementation is COMPLETE.

---

## SSOT Hierarchy

```
1. BWS (Bitwarden Secrets Manager) — Primary SSOT for all secrets
2. Local encrypted cache (age)      — Offline/performance reads
3. Environment variables            — In-memory only, never logged
```

---

## Absolute Prohibitions

| Action | Alternative |
|--------|-------------|
| Outputting secrets to logs | Mask: `${secret:0:4}...${secret: -4}` |
| Hardcoding in source code | Fetch from BWS at runtime |
| CLI arguments with secrets | Pipe via stdin |
| Secrets in docker-compose.yml | Entrypoint fetches at start |
| Secrets in git commits | BWS + gitleaks pre-commit |
| Reading/displaying API keys | Direct piping only |
| Plain text `.env` files | Use `.age` encrypted or BWS |

---

## Existing Libraries (USE THESE — DON'T RECREATE)

| Platform | Library | Usage |
|----------|---------|-------|
| **Python** | `/atn/github/atn/lib/bootstrap/secrets.py` | `SecretManager.get_secret()` |
| **Bash** | `/atn/github/atn/lib/ops/secrets_bws.sh` | `bws_get_secret()` |
| **PowerShell** | `atnplex/atn-secrets-manager/atn-bws.ps1` | `Get-BwsSecret` |
| **GitHub Actions** | `bitwarden/sm-action@v2` | Inject at workflow runtime |

### Python

```python
from pathlib import Path
from lib.bootstrap.secrets import SecretManager

secrets = SecretManager(Path("/atn/github/atn"))
token = secrets.get_secret("GITHUB_PAT")
# NEVER: print(token), logger.info(f"Token: {token}")
```

### Bash

```bash
source /atn/github/atn/lib/ops/secrets_bws.sh
TOKEN=$(bws_get_secret "GITHUB_PAT")
echo "$TOKEN" | gh auth login --with-token  # ✅ Pipe directly
# NEVER: echo "Token is: $TOKEN"
```

### GitHub Actions

```yaml
- uses: bitwarden/sm-action@v2
  with:
    access_token: ${{ secrets.BWS_ACCESS_TOKEN }}
    secrets: |
      GITHUB_PAT=<uuid>
      CLOUDFLARE_TOKEN=<uuid>
```

---

## Token Strategy

| Token Type | Permissions | Storage | Used By |
|------------|-------------|---------|---------|
| **Read-Only** | Read secrets | `~/.config/atn/secrets/bws_token.age` | MCP servers, apps, CI/CD |
| **Read-Write** | Read + Create/Edit | NOT stored — interactive only | Admin tasks, rotation |

---

## Encryption at Rest

**ALL secrets MUST be encrypted at rest. NO EXCEPTIONS.**

| Layer | Tool | Purpose |
|-------|------|---------|
| Master SSOT | BWS | Cloud-managed, audited |
| Local cache | age-encrypted (`.age`) | Offline access, fast reads |
| Runtime | keyctl (kernel keyring) | In-memory only, auto-expires |
| Process | Environment variables | Passed to child processes |

### Bootstrap Secret (BWS Access Token)

```bash
# Encrypt BWS token with age
echo -n "$BWS_ACCESS_TOKEN" | age -e -R ~/.atn/secrets/recipients.txt \
    > ~/.config/atn/secrets/bws_token.age

# Decrypt at runtime
BWS_ACCESS_TOKEN=$(age -d -i ~/.atn/secrets/age.key < ~/.config/atn/secrets/bws_token.age)
```

---

## Secret Naming Convention

Format: `<SERVICE>_<TYPE>_<SCOPE>_<PURPOSE>`

| Key Name | Purpose |
|----------|---------|
| `CLOUDFLARE_API_TOKEN_READ_ALL_RESOURCES` | Cloudflare token (read-all scope) |
| `GITHUB_PAT` | GitHub Personal Access Token |
| `PERPLEXITY_API_TOKEN` | Perplexity API key |
| `JULES_API_KEY_01` | Jules API key (account 1) |

---

## Emergency: Secret Exposure

1. **Rotate immediately** in BWS
2. **Revoke old credential** at source
3. **Clear local cache**: `rm -rf ~/.cache/atn/secrets.json`
4. **Audit all usage** via BWS logs
5. **Document incident** in `/atn/.gemini/antigravity/scratch/security_incidents.md`

---

## Compliance Checklist

Before ANY operation involving credentials:

- [ ] Using existing BWS library (not recreating)?
- [ ] Secret fetched at runtime (not hardcoded)?
- [ ] Secret in variable (not CLI argument)?
- [ ] No echo/print/log of secret value?
- [ ] Pipe to consumer (not stored unencrypted)?
- [ ] gitleaks pre-commit enabled?

**If ANY is "no" → STOP and FIX before proceeding.**
