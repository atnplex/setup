# R48: Use Bot Reviews for Approval

> **Rule ID**: R48
> **Category**: operational
> **Severity**: SHOULD

## Rule

When human approval is needed but unavailable:

1. Request review from AI code assistants (Gemini, CodeRabbit)
2. Address ALL bot comments completely
3. Once bots approve, the PR can merge via auto-merge

## Bot Review Strategy

| Bot | Capability | How to Request |
|-----|-----------|----------------|
| `gemini-code-assist[bot]` | Full review + approve | Automatic on PR, or `@gemini-code-assist review` |
| `coderabbitai[bot]` | Review + approve | Automatic on PR, or `@coderabbitai review` |
| GitHub Copilot | Review only | Via GitHub UI |

## Getting Bot Approval

1. **Address ALL comments** - Don't skip any
2. **Push fixes** - Bots re-review on new commits
3. **Reply to comments** - Explain if not implementing
4. **Wait for re-review** - Bots will update their status

## When Bots Request Changes

```bash
# Check what changes are requested
gh pr view <NUMBER> --json reviews

# After fixing, bots will re-review automatically on push
git push origin <branch>
```

## Fallback

If bot approval is insufficient (branch protection requires human):

1. Use `atngit2` service account for approval
2. Document why human review was bypassed
3. Never bypass without addressing all comments first

## Related

- R46: Enable auto-merge
- R47: Never dismiss reviews
