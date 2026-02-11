---
name: ai-reviewer-workflow
description: Optimized AI code review strategy to save Copilot Pro limits
keywords: [review, copilot, coderabbit, gemini, jules, optimization]
argument-hint: <PR number or repo>
disable-model-invocation: true
---

# AI Reviewer Workflow Skill

> **Purpose**: Optimize AI code review to save Copilot Pro limits (300/mo)

## Tiered Review Strategy

```
┌────────────────────────────────────────────────────────┐
│           AI CODE REVIEW PIPELINE                      │
├────────────────────────────────────────────────────────┤
│ TIER 1 (FREE - Always Run):                            │
│ • Gemini Code Assist (unlimited, auto on all PRs)      │
│ • CodeRabbit Free (2 reviews/hr, OSS repos)            │
│ • Jules.google (per-account, use multi-account)        │
├────────────────────────────────────────────────────────┤
│ TIER 2 (PAID - Explicit Only):                         │
│ • Copilot PR Review (300/mo, `copilot-review` label)   │
├────────────────────────────────────────────────────────┤
│ TIER 3 (ESCALATION):                                   │
│ • Human review for critical/sensitive changes          │
└────────────────────────────────────────────────────────┘
```

## Free Tool Rate Limits

| Tool | Rate Limit | Trigger |
| ---- | ---------- | ------- |
| Gemini Code Assist | Unlimited | Auto (GitHub App installed) |
| CodeRabbit Free | 2 reviews/hr | Auto (GitHub App installed) |
| Jules Google | Per-account | Label `jules` on issue |
| Copilot Pro | 300/month | Label `copilot-review` (PROTECTED) |

## Jules API Integration (Confirmed!)

```bash
# Base URL
https://jules.googleapis.com/v1alpha

# Create session with auto-PR
curl -X POST "$BASE_URL/sessions" \
  -H "X-Goog-Api-Key: YOUR_KEY" \
-d '{
  "prompt": "Fix these review comments",
    "sourceContext": {
    "source": "sources/github/owner/repo",
      "githubRepoContext": { "startingBranch": "main" }
    },
    "automationMode": "AUTO_CREATE_PR"
  }'
```

## Bitwarden Secrets Manager Integration

```yaml
# In GitHub Actions workflow
- uses: bitwarden/sm-action@v2
  with:
    access_token: ${{ secrets.BW_ACCESS_TOKEN }}
    secrets: |
      UUID_1 > JULES_API_KEY_01
      UUID_2 > JULES_API_KEY_02
      UUID_3 > JULES_API_KEY_03
```

### Bitwarden Free Tier Limits

| Resource | Limit |
| -------- | ----- |
| Secrets | **Unlimited** |
| Projects | 3 |
| Machine Accounts | 3 |

### Trust-Boundary Project Structure (Recommended for Homelabs)

```
internet-facing/     # Cloudflare, OAuth, webhooks, Jules, public APIs
internal-services/   # Plex, *arrs, DBs, internal APIs
admin-breakglass/    # Root creds, recovery codes, backup keys (NO machine account!)
```

### Sync Behavior

```
Bitwarden (SSOT) ─────► GitHub Actions (read-only at runtime)
                 ONE-WAY PULL

✅ Bitwarden: View, edit, manage secrets
✅ GitHub: Pulls secrets when workflow runs (never stored)
❌ No sync FROM GitHub TO Bitwarden
```

```

## Protect Copilot Budget

**NEVER auto-assign Copilot as reviewer.**

Copilot is triggered ONLY when:

1. Label `copilot-review` is explicitly added
2. Security-critical changes detected
3. User explicitly requests `/copilot review`

### Monthly Budget (300 premium requests)

```yaml
security_reviews: 50      # Worth the cost
architecture: 30          # Complex decisions
final_approval: 100       # Merge-blocking
complex_refactors: 70     # Multi-file changes
buffer: 50                # Unexpected
```

## Cascade Pattern

For complex changes, cascade through reviewers:

```
1. Gemini Code Assist → Fast initial review (auto)
2. CodeRabbit → Deep analysis + suggestions (auto)
3. Jules → Implement suggestions (if tagged)
4. Copilot → Final security check (explicit only)
```

## Auto-Implement Suggestions

**Jules CAN implement suggestions**, not just review:

```
1. Reviewer (Gemini/CodeRabbit) suggests change
2. Add label `jules` to issue/PR
3. Jules implements the suggestion
4. Jules creates new commit or PR
5. Original reviewer re-reviews
```

## Perplexity in Review Process

Use Perplexity for research during review:

```yaml
# Via MCP or API
- Research best practices for suggested pattern
- Verify external documentation references
- Check for security advisories on dependencies
```

## GitHub Actions Implemented

| Action | Purpose | Status |
| ------ | ------- | ------ |
| `stale.yml` | Auto-close inactive | ✅ Added |
| `auto-assign-reviewers.yml` | Round-robin assignment | ✅ Added |
| `label-sync.yml` | Consistent labels | ✅ Added |
| `CODEOWNERS` | Path-based assignment | ✅ Added |

## Branch Protection Recommendations

### For Solo Dev + AI Bots

```yaml
# Repository Settings → Rules → Branch protection for main

require_merge_queue: false     # Not needed for solo
require_pr_before_merge: true
require_approvals: 1-2         # From AI reviewers
require_conversations_resolved: true  # Enforce AI feedback
required_status_checks:
  - "Gemini Code Assist"       # Free, required
  # NOT Copilot (uses quota)
```

## Setup Checklist

- [ ] Install Gemini Code Assist GitHub App
- [ ] Install CodeRabbit from GitHub Marketplace
- [ ] Install Jules from each Google Pro account
- [ ] Set Gemini as required status check
- [ ] Add `.coderabbit.yaml` configuration
- [ ] Add `CODEOWNERS` file
- [ ] Create `ai-reviewers` team with bot accounts
- [ ] Remove merge queue (optional for solo)
- [ ] Keep conversations resolved requirement
