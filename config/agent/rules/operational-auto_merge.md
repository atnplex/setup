# R46: Enable Auto-Merge

> **Rule ID**: R46
> **Category**: operational
> **Severity**: MUST

## Rule

When creating or updating a PR, **ALWAYS enable auto-merge** if:

1. The repository has auto-merge enabled
2. All required checks are passing or will pass
3. The PR is not a draft

## Implementation

```bash
# Enable auto-merge after creating PR
gh pr merge --auto --squash <PR_NUMBER>

# Or via API
gh api repos/{owner}/{repo}/pulls/{number}/auto-merge \
  -X PUT \
  -f merge_method=squash
```

## Rationale

- Reduces manual intervention
- Merges PRs as soon as all requirements are met
- Prevents PRs from sitting idle after approval

## Related

- R45: Branch update before merge
- R47: Never dismiss reviews
