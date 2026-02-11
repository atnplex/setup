---
description: Delegate Pull Request work to Jules (Google AI) for external review and fixes. | Creates sessions on Jules.Google to automatically review PRs, implement fixes, and push updates. Uses API key rotation for rate limit management. Best for offloading repetitive reviews to external AI.
---

# Delegate Pull Request (Jules Google)

> **Scope**: External AI delegation
> **Primary Use**: Offload PR review/fixing to Jules.Google when you want hands-off automation

## What This Workflow Does

This workflow delegates PR work to **Jules (Google's AI coding assistant)**:

1. Creates a Jules session for a specific PR or branch.
2. Jules reviews code, identifies issues, implements fixes.
3. Jules pushes updates directly to the PR.
4. Supports account rotation for rate limit management.

## Key Differences from Other Pull Request Workflows

| Workflow | Purpose | When to Use |
| -------- | ------- | ----------- |
| **manage-pull-requests** | Batch process PRs locally | General cleanup, unblocking |
| **pipeline-04-pr-lifecycle** | Single PR creation→merge | After local code changes |
| **delegate-pull-request** (this) | External AI review | Offload to Jules for fixes |

---

> Trigger Jules to review, fix, and complete PRs automatically.

1. Jules GitHub App installed on repos: <https://jules.google/docs>
2. API key from: <https://jules.google.com/settings>
3. Connected repos visible via `/v1alpha/sources` endpoint

## Quick Reference

```bash
# Environment setup
export JULES_API_KEY="your-api-key"
export JULES_BASE="https://jules.googleapis.com/v1alpha"
```

---

## Workflow Steps

### 1. List Available Sources

```bash
curl "$JULES_BASE/sources" \
  -H "X-Goog-Api-Key: $JULES_API_KEY"
```

### 2. Create PR Review Session

For reviewing an existing PR:

```bash
curl "$JULES_BASE/sessions" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Goog-Api-Key: $JULES_API_KEY" \
  -d '{
    "prompt": "Review PR #42. Check for: security issues, code quality, test coverage. Implement necessary fixes and update the PR.",
    "sourceContext": {
      "source": "sources/github/atnplex/REPO_NAME",
      "githubRepoContext": { "startingBranch": "PR_BRANCH_NAME" }
    },
    "automationMode": "AUTO_CREATE_PR",
    "title": "Jules Review: PR #42"
  }'
```

### 3. Monitor Session Progress

```bash
# List sessions
curl "$JULES_BASE/sessions?pageSize=10" \
  -H "X-Goog-Api-Key: $JULES_API_KEY"

# Get specific session
curl "$JULES_BASE/sessions/SESSION_ID" \
  -H "X-Goog-Api-Key: $JULES_API_KEY"
```

### 4. Review Created PR

When session completes, check `outputs.pullRequest.url` for the resulting PR.

---

## CLI Alternative

```bash
# Login (one-time)
jules login

# Create review session
jules remote new \
  --repo atnplex/organizr \
  --session "Review and fix any issues in the latest PR"

# List active sessions
jules remote list --session

# Pull results
jules remote pull --session SESSION_ID
```

---

## Account Rotation Pattern

When hitting rate limits or to maximize quota usage:

1. Maintain list of Google accounts with Jules access
2. Each account has its own API key
3. Rotate through accounts round-robin style

```python
# Example rotation (implement in automation script)
api_keys = [
    os.getenv("JULES_KEY_1"),
    os.getenv("JULES_KEY_2"),
    # ... more accounts
]

def get_api_key():
    global current_index
    key = api_keys[current_index % len(api_keys)]
    current_index += 1
    return key
```

---

## GitHub Actions Integration

Create `.github/workflows/jules-review.yml`:

```yaml
name: Jules PR Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  jules-review:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Jules Review
        run: |
          curl 'https://jules.googleapis.com/v1alpha/sessions' \
            -X POST \
            -H "Content-Type: application/json" \
            -H "X-Goog-Api-Key: ${{ secrets.JULES_API_KEY }}" \
            -d '{
              "prompt": "Review PR #${{ github.event.pull_request.number }}. Check for bugs, security issues, and code quality. Suggest improvements.",
              "sourceContext": {
                "source": "sources/github/${{ github.repository }}",
                "githubRepoContext": {
                  "startingBranch": "${{ github.head_ref }}"
                }
              },
              "title": "Auto-Review PR #${{ github.event.pull_request.number }}"
            }'
```

---

## Prompts for Common Tasks

### Security Review

```
Review this code for security vulnerabilities including:
- XSS, CSRF, SQLi, path traversal
- Authentication/authorization flaws
- Sensitive data exposure
- Insecure dependencies
Provide detailed findings and implement fixes.
```

### Code Quality

```
Review for code quality:
- Code duplication and DRY violations
- Missing error handling
- Poor naming conventions
- Complexity issues
Refactor and improve where appropriate.
```

### Documentation

```
Review and enhance documentation:
- Add missing docstrings
- Update README if functionality changed
- Add inline comments for complex logic
```

---

## Reference

- Snippet: `/atn/.gemini/scratch/snippets/003-jules-api-integration.md`
- API Docs: <https://developers.google.com/jules/api>
- Jules Settings: <https://jules.google.com/settings>
