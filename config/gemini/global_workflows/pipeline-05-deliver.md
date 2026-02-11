---
name: Deliver
description: Final delivery of results to user
model: claude-sonnet-4.5
---

# Phase 5: Results Delivery

## Purpose

Provide user with:

1. Summary of completed work
2. Links to merged PRs
3. Any recommendations
4. Next steps

---

## Delivery Format

```markdown
## ✅ Task Complete

### Summary
[Brief description of what was accomplished]

### Merged PRs

| PR | Title | Status |
|----|-------|--------|
| [#123](link) | feat: add auth | ✅ Merged |
| [#124](link) | feat: add tests | ✅ Merged |

### Changes Made

**Files Modified**: X
**Lines Added**: +Y
**Lines Removed**: -Z

### Key Changes
- [Component A]: Description
- [Component B]: Description

### Testing
- [x] All tests passing
- [x] Linting clean
- [x] Build successful

### Documentation
- Updated: [list of docs]
- New: [list of new docs]

---

## Recommendations

### Immediate
- [ ] Test in staging environment
- [ ] Run integration tests

### Future Improvements
- Consider: [suggestion 1]
- Consider: [suggestion 2]

---

## Next Steps

1. Pull latest main: `git pull origin main`
2. Deploy to staging: [instructions]
3. Verify: [test steps]
```

---

## Cleanup Verification

Before delivery, confirm:

```bash
# All worktrees removed
git worktree list

# All branches merged and deleted
gh pr list --state merged --limit 10
git branch -a | grep -v "main\|master"

# Main is up to date
git log --oneline -5
```

---

## Memory Update

Store task completion in memory:

```yaml
memory_entry:
  task_id: "<conversation-id>"
  completed: true
  completed_at: "2026-02-02T23:45:00Z"

  work:
    segments_completed: N
    prs_merged: [123, 124]
    total_changes: "+Y/-Z"

  skills_used: [list]
  personas_used: [list]

  lessons:
    - "Learned: X"
    - "Note: Y"
```

---

## User Feedback Request

```markdown
## Feedback

How did this go? Any issues or suggestions?

Rate: ⭐⭐⭐⭐⭐ (1-5)

Your feedback helps improve the pipeline.
```

---

## Output

```yaml
delivery_result:
  status: complete
  prs_merged: [123, 124]
  changes:
    files: N
    additions: +Y
    deletions: -Z

  artifacts:
    - walkthrough.md
    - implementation_plan.md

  next_steps: [list]
  recommendations: [list]
```
