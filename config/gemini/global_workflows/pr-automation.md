---
description: Automated PR lifecycle following baseline process-pull-requests.md
---

# PR Automation Workflow

## Purpose

Full PR lifecycle automation following `/atn/baseline/workflows/process-pull-requests.md` v1.2.0.

## Security-First Processing (Phase 1)

Before any other action:

```bash
# Check for sensitive files
gh pr view <number> --json files | jq -r '.files[].path' | grep -E '\.(env|key|pem|crt|p12)$'

# Check for exposed secrets
gh pr diff <number> | grep -iE '(password|secret|token|api[_-]?key)'
```

**If sensitive content found**: STOP and escalate to user.

## PR Lifecycle Phases

### Phase 2: Initial Triage

```bash
# Get PR details
gh pr view <number> --json title,body,files,additions,deletions,author

# Classify: small (<50 lines), medium (<200), large (>200)
```

### Phase 3: Wait for CI

```bash
# Check status (repeat every 30s until complete)
gh pr checks <number> --watch

# Timeout: 10 minutes for standard checks
```

### Phase 4: Review Comments

```bash
# Get all review comments
gh pr view <number> --json reviews,comments

# List unresolved threads
gh api graphql -f query='...'
```

### Phase 5: Address Feedback

1. Read ALL comments - no skipping
2. Address EVERY comment - explain if disagreeing
3. Push fixes
4. Re-trigger CI

### Phase 6: Merge

```bash
# Only when: approved + all checks pass
gh pr merge <number> --squash --delete-branch

# Verify branch deletion
git fetch --prune
```

### Phase 7: Cleanup

```bash
# Remove worktree
git worktree remove "$ROOT/worktrees/<type>/<slug>"

# Verify
git worktree list
```

## Retry Logic

```yaml
max_retries: 5
review_wait_timeout: 300s
ci_check_interval: 30s
on_failure: escalate_to_user
```

## Guardrails (NEVER BYPASS)

1. PRs created via `gh pr create` only
2. Wait for ALL CI checks before proceeding
3. Read ALL review comments - no skipping
4. Address EVERY comment
5. Never force-merge with failing checks
6. Never manually merge - only via `gh pr merge`
7. Branch deletion automatic on merge
8. Task NOT complete until branch deleted

## Integration with Baseline

This workflow implements the 7-phase process from `/atn/baseline/workflows/process-pull-requests.md`.
