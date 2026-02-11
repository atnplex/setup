# R47: Never Dismiss, Bypass, or Ignore

> **Rule ID**: R47
> **Category**: operational
> **Severity**: MUST

## Rule

**NEVER** do any of the following:

1. Dismiss review comments without addressing them
2. Bypass branch protection rules
3. Ignore CI failures
4. Force-merge with failing checks
5. Skip required reviews
6. Mark conversations as resolved without implementing fixes

## Proper Handling

| Situation | Wrong Approach | Correct Approach |
|-----------|---------------|------------------|
| Review comment | Dismiss it | Implement the fix or explain why not applicable |
| CI failure | Bypass/ignore | Fix the underlying issue |
| Blocking review | Dismiss reviewer | Address all comments, then request re-review |
| Enhancement suggestion | Ignore | Implement now OR create follow-up issue |

## For Bot Reviews (CodeRabbit, Gemini, etc.)

Bot suggestions MUST be handled the same as human reviews:

1. Read each comment carefully
2. Implement the suggested fix
3. If not applicable, reply explaining why
4. Resolve only after action taken

## Rationale

- Maintains code quality
- Respects review process
- Creates audit trail
- Prevents security regressions

## Related

- R46: Enable auto-merge
- R45: Branch update before merge
