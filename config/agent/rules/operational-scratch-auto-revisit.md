# R64: Scratch Folder Auto-Revisit

> Ensure scratch folder data is "live" and actively used.

## Purpose

Data written to scratch folder should not be forgotten. This rule ensures:

1. Periodic review of pending items
2. Active learning from stored data
3. Continuous improvement based on past learnings

## Trigger Points

### At Task Start

1. **Check backlog.md** for related pending tasks
2. **Check learnings.md** for relevant prior learnings
3. **Check enhancements.md** for applicable improvements
4. **Check master_tasks.md** for dependency status

### At Task End

1. **Update backlog.md** with task status
2. **Update learnings.md** with what worked/didn't
3. **Update enhancements.md** with new ideas
4. **Clear dependencies** in master_tasks.md if applicable

### Weekly Review (Manual Trigger)

Use `/review-scratch` workflow to:

1. Review all pending items older than 7 days
2. Archive completed items older than 30 days
3. Escalate stale blockers
4. Consolidate learnings into rules

## Files to Monitor

| File | Check Frequency | Action |
|------|-----------------|--------|
| `backlog.md` | Every task | Load relevant, update |
| `learnings.md` | Every task | Apply, append |
| `enhancements.md` | Every task | Check, append |
| `master_tasks.md` | Phase changes | Update status |
| `inventory.md` | When deploying | Reference |

## Staleness Rules

| Age | Status | Action |
|-----|--------|--------|
| < 7 days | Fresh | Use actively |
| 7-14 days | Review | Check if still relevant |
| 14-30 days | Stale | Decide: complete or archive |
| > 30 days | Archive | Move to archive/ folder |

## Implementation

At conversation start, agent should:

```
1. Load tool_manifest.yaml
2. Check scratch/*.md for relevant items
3. Surface any blockers or pending high-priority tasks
4. Apply relevant learnings to current request
```

## Integration

- Works with R57 (Learning Log)
- Works with R55 (Cross-Conversation Backlog)
- Works with R60 (Surface High-Value Improvements)
