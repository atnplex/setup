---
name: Learning Cycle
description: Post-task reflection and improvement cycle (auto-invoked by R95)
model: claude-sonnet-4.5
---

# Learning Cycle Workflow

> Invoked automatically after task completion per R95.

## Step 1: Generate Reflection

Create reflection file:

```bash
# Filename format
/atn/.agent/learning/reflections/$(date +%Y-%m-%d)_<task-hash>.md
```

Contents:

```markdown
# Reflection: [Task Name]

**Date**: [ISO8601]
**Duration**: [estimate]
**Outcome**: success/partial/failure

## What Happened
- Goal: [what was asked]
- Approach: [what was done]
- Result: [what happened]

## Issues
- [Issue with resolution]

## Improvements Identified
- [Improvement opportunity]
```

---

## Step 2: Pattern Detection

Check if issue is recurring:

```bash
grep -r "[issue keyword]" /atn/.agent/learning/reflections/
```

If found 2+ times → Mark as pattern in `patterns.md`

---

## Step 3: Evaluate Options

For each improvement, evaluate:

| Option | When to Use | Risk |
|--------|-------------|------|
| New Rule | Recurring constraint violation | Low |
| Modify Rule | Existing rule insufficient | Low |
| New Workflow Step | Process gap | Medium |
| Skill Enhancement | Capability gap | Medium |
| Knowledge Item | Reference needed | Low |

---

## Step 4: Propose or Apply

### Auto-Apply (Low Risk)

- Logging improvements
- Documentation updates
- Cosmetic fixes

### Propose (Medium/High Risk)

Add to `/atn/.agent/learning/proposed_changes.md`:

```markdown
### [Title]

**Status**: 🟡 Pending
**Type**: Rule/Workflow/Skill
**Risk**: Medium/High

#### Problem
[Description]

#### Recommendation
[What to change]

#### Consequences
[Potential issues]
```

---

## Step 5: Update Changelog

If change applied:

```markdown
## [Date] - [Type]

**Trigger**: [Issue that prompted change]
**Action**: [What was changed]
**File**: [Path]
```

---

## Exit Criteria

- [ ] Reflection file created
- [ ] Patterns checked
- [ ] Improvements evaluated
- [ ] Changes proposed/applied
- [ ] Changelog updated
