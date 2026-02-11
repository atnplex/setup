---
name: Pull Request Lifecycle
description: Single Pull Request from creation to merge (pipeline step). | Handles the complete lifecycle of ONE Pull Request after code work is done. Includes security pre-check, PR creation, CI monitoring, comment resolution, and merge with cleanup. Part of the standard pipeline.
model: claude-opus-4.5
---

# Create and Merge Pull Request (Pipeline Step)

> **Scope**: Single Pull Request lifecycle
> **Primary Use**: After completing code changes in a worktree, create PR and shepherd to merge

## What This Workflow Does

This is the **pipeline step for completing a single Pull Request**:

1. Security pre-check (no secrets exposed).
2. Create PR with proper template.
3. Enable auto-merge immediately.
4. Update branch from main.
5. Wait for CI checks.
6. Resolve ALL review comments.
7. Merge when all gates pass.
8. Cleanup (branch delete, worktree remove).

## Key Differences from Other Pull Request Workflows

| Workflow | Purpose | When to Use |
| -------- | ------- | ----------- |
| **manage-pull-requests** | Batch process many PRs | Org/repo cleanup |
| **create-merge-pull-request** (this) | Single PR lifecycle | After code work, in pipeline |
| **delegate-pull-request** | External AI delegation | Offload to Jules |

---

## Mandatory Actions (Rule Enforcement)

> [!CAUTION]
> These steps are NON-NEGOTIABLE per our rules.

1. **Enable Auto-Merge** (R46): Immediately after PR creation.
2. **Update Branch** (R45): Sync with main before requesting review.
3. **Resolve All Conversations** (R491): Every comment must be addressed.
4. **Never Dismiss Reviews** (R47): Address all feedback, never bypass.

---

## Guardrails (NEVER BYPASS)

---

## Phase 4.1: Security Pre-Check

**BEFORE creating PR**:

```bash
# Check for sensitive files
git diff main --name-only | grep -E '\.(env|key|pem|crt|p12)$'

# Check for exposed secrets
git diff main | grep -iE '(password|secret|token|api[_-]?key|private[_-]?key)\s*[=:]'

# Check for weak file permissions
find . -name "*.sh" -perm /o+w 2>/dev/null
```

**If ANY found → STOP and fix first**

---

## Phase 4.2: Create PR

```bash
gh pr create \
  --base main \
  --head feat/task-001 \
  --title "feat: <description>" \
  --body "## Summary
<description of changes>

## Testing
<how it was tested>

## Checklist
- [ ] Tests pass
- [ ] Linting passes
- [ ] No secrets exposed
- [ ] Documentation updated
"
```

---

## Phase 4.3: Wait for CI

```bash
# Watch checks (blocks until complete or timeout)
gh pr checks <number> --watch

# Timeout: 10 minutes for standard checks
# If timeout → investigate, don't force-merge
```

### CI Check Categories

| Check | Required | Action on Fail |
|-------|----------|---------------|
| Lint | Yes | Fix and push |
| Tests | Yes | Fix and push |
| Build | Yes | Fix and push |
| Security | Yes | STOP, review |
| Coverage | Warning | Consider improving |

---

## Phase 4.4: Review Processing

### Get All Comments

```bash
# Get reviews
gh pr view <number> --json reviews

# Get comments
gh pr view <number> --json comments

# Get review threads (unresolved)
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          isResolved
          comments(first:10) {
            nodes { body author { login } }
          }
        }
      }
    }
  }
}' -f owner=atnplex -f repo=<repo> -F number=<number>
```

### Process Each Comment

For EACH comment:

1. **Read** the comment fully
2. **Understand** the concern
3. **Respond** with one of:
   - Fix implemented (with commit SHA)
   - Explanation of design decision
   - Question for clarification
4. **Never dismiss** without addressing

---

## Phase 4.5: Push Fixes

```bash
# Make fixes in worktree
cd "$ROOT/worktrees/feat/task-001"

# Edit files
# ...

# Commit with reference to review
git add .
git commit -m "fix: address review - <summary>"
git push origin feat/task-001
```

### Re-trigger CI

After push:

1. Wait for new CI run
2. Ensure all checks pass
3. Respond to reviewer confirming fix

---

## Phase 4.6: Merge

**ONLY when**:

- All CI checks pass ✓
- All review comments addressed ✓
- Approvals received (if required) ✓

```bash
# Merge with squash
gh pr merge <number> --squash --delete-branch

# Verify
gh pr view <number> --json state,mergedAt
```

---

## Phase 4.7: Cleanup

```bash
# Branch auto-deleted via --delete-branch or GitHub setting

# Remove worktree
git worktree remove "$ROOT/worktrees/feat/task-001"

# Prune references
git fetch --prune

# Verify cleanup
git worktree list
git branch -a | grep task-001
```

---

## Retry Logic

```yaml
max_retries: 5
review_wait_timeout: 300s  # 5 min between checks
ci_check_interval: 30s
on_failure: escalate_to_user
```

---

## Output

```yaml
pr_lifecycle_result:
  pr_number: 123
  pr_url: "https://github.com/..."

  phases:
    security_precheck: pass|fail
    pr_created: true
    ci_passed: true|false
    reviews_addressed: true|false
    merged: true|false
    branch_deleted: true|false

  retry_count: 0
  final_status: complete|failed|escalated
```

---

## Task Complete Condition

Task is **NOT complete** until:

- ✅ PR merged
- ✅ Branch deleted
- ✅ Worktree removed
- ✅ All cleanup verified
