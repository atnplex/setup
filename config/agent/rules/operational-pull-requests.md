# Pull Request Lifecycle Rules

> Consolidated from R50, R51, R52, R80. Covers the full PR lifecycle from creation to merge.

## Golden Rule

**A PR is NOT complete until it is MERGED, not just created.**

## Required Steps (In Order)

1. **Create PR**: `gh pr create --title "..." --body "..."`
2. **Wait for CI**: `gh pr checks <PR> --watch`
3. **Address ALL review comments** (see Comment Resolution below)
4. **Verify no blocking reviews**: `gh pr view <PR> --json reviews -q '.reviews[] | select(.state == "CHANGES_REQUESTED")'`
5. **Merge**: `gh pr merge <PR> --squash --delete-branch`
6. **Verify**: `gh pr view <PR> --json state -q '.state'` → must return `MERGED`

## Comment Resolution

| Type | Action Required |
| ---- | --------------- |
| Bug / Security | Fix immediately |
| Suggestion | Fix or explain why not |
| Question | Answer and resolve |
| Nitpick | Fix if quick, else explain |
| Praise | Thank and resolve |

### Batch Resolution via API

```bash
# List unresolved threads
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUM) {
      reviewThreads(first: 50) {
        nodes { id isResolved }
      }
    }
  }
}' | jq -r '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id'

# Resolve a thread
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "THREAD_ID"}) {
    thread { isResolved }
  }
}'
```

## Auto-Resolution Rules (Batch Processing)

| Comment Type | Condition | Action |
| ------------ | --------- | ------ |
| Outdated | `isOutdated: true` | Auto-resolve after logging |
| Style/Lint | Formatting only | Auto-resolve |
| Bot (non-security) | gemini-code-assist, coderabbitai | Evaluate → log → resolve |
| Security Flag | Contains `![security]` or `![high]` | **DO NOT auto-resolve** |
| Suggestion Block | Has `` ```suggestion `` | Log to deferred → resolve |

Deferred suggestions logged to `.pull_request_work/deferred_improvements.md`.

## Security Alerts

> [!CAUTION]
> **NEVER dismiss security alerts. NEVER adjust rulesets to bypass.**

| Severity | Action | Timeline |
| -------- | ------ | -------- |
| Critical | Block everything, fix immediately | Same day |
| High/Error | Must fix before merge | Before PR merge |
| Medium/Warning | Should fix, can be batched | Within sprint |
| Low/Note | Fix opportunistically | When touching file |

## Common Security Fix Patterns

| Alert | Fix |
| ----- | --- |
| path-injection | Validate/sanitize paths, use allowlists |
| command-injection | Use parameterized execution, temp files |
| clear-text-storage | Use secure storage |
| sql-injection | Use prepared statements |
| xss | Escape/sanitize output |

## Common Blockers

| Blocker | Solution |
| ------- | -------- |
| Unresolved comments | Address each, push fix |
| CHANGES_REQUESTED | Fix issues, push, wait for re-review |
| Duplicate CodeQL | Delete custom `codeql.yml` if Default Setup is enabled |
| Required check missing | Wait or fix workflow |

## Pre-Merge Checklist

- [ ] All review threads resolved
- [ ] All CI checks passed
- [ ] No CHANGES_REQUESTED reviews remain
- [ ] Branch up to date with base
- [ ] `gh pr view <PR> --json state` shows `MERGED`
