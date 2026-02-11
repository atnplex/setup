---
name: git-ops
description: Git add, commit, and push operations
disable-model-invocation: true
---

# Git Operations

Commit and push changes in the current repository.

## Steps

1. Check status: `git status`
2. Review changes: `git diff`
3. Stage: `git add <files>` or `git add -A`
4. Commit: `git commit -m "<descriptive message>"`
5. Push: `git push`

## Notes

- All git read commands (status, diff, log) are safe to auto-run
- For force push or rebase, always ask user first
- Follow branch naming: `<type>/<slug>` (feat/, fix/, refactor/)
