# R77: Public Repository Safeguards

> **Authority**: SECURITY RULE
> **Severity**: CRITICAL - MANDATORY for all public repos
> **Created**: 2026-02-04

---

## Core Principle

> [!CAUTION]
> **Public repos MUST have multiple safeguards to prevent secret/PII exposure.**

---

## Required Safeguards

### Layer 1: .gitignore

Every public repo MUST include:

```gitignore
# Secrets - NEVER commit
secrets/
*.age
*.gpg
*.pem
*.key
*.env
.env.*
!.env.example

# Personal info
*.log
*.bak
.DS_Store
Thumbs.db

# BWS cache
.bws-cache/
```

---

### Layer 2: Pre-commit Hook

Install git hook to scan for secrets:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check for common secret patterns
if git diff --cached --name-only | xargs grep -lE \
    '(password|secret|token|api_key|private_key)=.+' 2>/dev/null; then
    echo "ERROR: Potential secret detected in staged files"
    exit 1
fi

# Check for age-encrypted files being committed unencrypted
if git diff --cached --name-only | grep -E '\.(age|gpg)$' >/dev/null; then
    echo "WARNING: Encrypted file staged - verify it's actually encrypted"
fi
```

---

### Layer 3: Variable Substitution

All sensitive values MUST use variables:

```yaml
# ✅ Correct - variable substitution
environment:
  - API_TOKEN=${API_TOKEN}
  - CF_ACCOUNT_ID=${CF_ACCOUNT_ID}

# ❌ Incorrect - hardcoded value
environment:
  - API_TOKEN=sk-abc123xyz
```

---

### Layer 4: Example Files

Provide `.example` files showing structure without values:

```bash
# .env.example (commit this)
API_TOKEN=
CF_ACCOUNT_ID=
TAILSCALE_IP=

# .env (gitignored, never commit)
API_TOKEN=sk-abc123xyz
CF_ACCOUNT_ID=abc123
TAILSCALE_IP=100.x.x.x
```

---

### Layer 5: CI/CD Scanning

Add secret scanning to workflows:

```yaml
# .github/workflows/security.yml
jobs:
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          fail: true
```

---

### Layer 6: Branch Protection

Require PR reviews for main branch:

- No direct pushes
- At least 1 approval
- All checks must pass

---

## Verification Checklist

Before making any repo public:

- [ ] .gitignore covers all secret patterns
- [ ] Pre-commit hook installed
- [ ] No hardcoded values in any file
- [ ] All sensitive configs use variables
- [ ] .example files provided
- [ ] CI secret scanning enabled
- [ ] Branch protection configured
- [ ] Manual review of git history for past leaks

---

## Emergency Response

If secrets are exposed:

1. **Rotate immediately** - generate new credentials
2. **Revoke old** - disable leaked tokens
3. **Clean history** - use BFG Repo-Cleaner
4. **Audit access** - check for unauthorized use
