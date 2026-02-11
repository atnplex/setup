---
description: Git worktree management for parallel task execution
---

# Worktree Workflow

// turbo-all

## Purpose

Manage isolated worktrees for parallel task execution per R22 from `/atn/baseline/RULES.md`.

## Worktree Location

All worktrees created at: `$ROOT/worktrees/<type>/<slug>`

## Branch Naming Convention

```
<type>/<slug>
Examples:
  feat/add-auth-middleware
  fix/broken-api-endpoint
  refactor/database-schema
  chore/update-dependencies
```

## Lifecycle Commands

### Create Worktree

```bash
# Create worktree with new branch
git worktree add "$ROOT/worktrees/feat/auth-middleware" -b feat/auth-middleware

# Verify creation
git worktree list
```

### Work in Worktree

```bash
cd "$ROOT/worktrees/feat/auth-middleware"
# ... make changes ...
git add .
git commit -m "feat: add auth middleware"
```

### Create PR

```bash
# Push branch and create PR
git push origin feat/auth-middleware
gh pr create --base main --head feat/auth-middleware --title "feat: add auth middleware" --body "Description of changes"
```

### Cleanup (After Merge)

```bash
# Branch auto-deleted on merge via GitHub settings
# Remove worktree
git worktree remove "$ROOT/worktrees/feat/auth-middleware"

# Verify cleanup
git worktree list
```

## Parallel Execution Pattern

```bash
# Create multiple worktrees for parallel tasks
git worktree add "$ROOT/worktrees/feat/task-a" -b feat/task-a
git worktree add "$ROOT/worktrees/feat/task-b" -b feat/task-b
git worktree add "$ROOT/worktrees/feat/task-c" -b feat/task-c

# Execute in parallel (each in separate process)
# Task A in worktree A
# Task B in worktree B
# Task C in worktree C

# Create PRs for all
for branch in task-a task-b task-c; do
  cd "$ROOT/worktrees/feat/$branch"
  gh pr create --base main --head "feat/$branch"
done
```

## Integration with Baseline

Follows R22 (Worktree isolation) and R25 (Merge via PR only) from `/atn/baseline/git_workflow.md`.

## Guardrails

- Never merge manually - only via `gh pr merge`
- Branch deletion automatic on merge
- Task not complete until branch deleted
