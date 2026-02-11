---
name: Execute
description: Execute task segments in parallel worktrees
model: varies-by-segment
---

# Phase 3: Parallel Execution

## Purpose

Execute all task segments with:

- Isolated worktrees (per R22)
- Assigned personas
- Loaded skills
- Validation gates

---

## Worktree Lifecycle

### Create Worktree

```bash
# Per segment
git worktree add "$ROOT/worktrees/<type>/<slug>" -b "<type>/<slug>"

# Example
git worktree add "$ROOT/worktrees/feat/auth-middleware" -b "feat/auth-middleware"
```

### Work in Worktree

```bash
cd "$ROOT/worktrees/feat/auth-middleware"

# Load persona context
# Load skills
# Execute implementation
```

### Validation Gate

Before creating PR, pass ALL gates:

1. **Lint**: `npm run lint` / `ruff check`
2. **Type Check**: `tsc --noEmit` / `mypy`
3. **Tests**: `npm test` / `pytest`
4. **Build**: `npm run build`
5. **Security**: Check for exposed secrets

```bash
# Security scan
grep -rE '(password|secret|api[_-]?key)\s*=' --include='*.ts' --include='*.py'

# If ANY gate fails → fix before PR
```

---

## Execution Per Segment

### Input

```yaml
segment:
  id: task-001
  persona: backend-dev
  model: claude-sonnet-4.5
  skills: [api-patterns, nodejs-best-practices]
  worktree: "$ROOT/worktrees/feat/task-001"
  branch: "feat/task-001"
```

### Process

1. **Switch to worktree**

   ```bash
   cd "$ROOT/worktrees/feat/task-001"
   ```

2. **Load persona** from `global_workflows/personas/<persona>.md`

3. **Load skills** from `~/skills/` matched files

4. **Execute task** using assigned model

5. **Run validation gates**

6. **Fix issues** until all gates pass

7. **Commit and push**

   ```bash
   git add .
   git commit -m "<type>: <description>"
   git push origin feat/task-001
   ```

---

## Parallel Wave Execution

Execute waves in order:

```
Wave 1 ──────────────────────────────────────►
  ├── task-001 (parallel)
  └── task-002 (parallel)
                                              │
                                              ▼
Wave 2 ──────────────────────────────────────►
  ├── task-003 (depends on wave 1)
  └── task-004 (depends on wave 1)
```

### Wave Coordination

- Start all segments in wave simultaneously
- Wait for ALL segments in wave to complete
- Only then start next wave
- If any segment fails → fix before proceeding

---

## Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

Example:

```
feat(auth): add JWT middleware

- Implement token validation
- Add refresh token rotation
- Handle expired token errors

Closes #123
```

---

## Error Handling

### Validation Failure

```
1. Identify failing gate
2. Read error message
3. Fix in worktree
4. Re-run validation
5. Repeat until passing
```

### Conflict with Main

```bash
# Pull latest main
git fetch origin main

# Rebase
git rebase origin/main

# Resolve conflicts
# Re-run validation
```

---

## Output

```yaml
execution_result:
  segments:
    - id: task-001
      status: complete|failed
      validation:
        lint: pass|fail
        types: pass|fail
        tests: pass|fail
        build: pass|fail
        security: pass|fail
      branch: feat/task-001
      commit: abc123
      ready_for_pr: true|false
```

---

## Proceed to Phase 4

Once all segments pass validation → Phase 4 (PR Lifecycle)
