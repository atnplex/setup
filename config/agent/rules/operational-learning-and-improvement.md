# Learning, Reflection, and Improvement

> Consolidated from R57, R60, R70, R95. Covers post-task learning, proactive improvement, and mandatory reflection.

## Core Principle

After every task: **reflect, learn, implement**. Don't just complete work — identify what caused friction and fix the root cause.

## Post-Task Reflection (Mandatory)

Before claiming any task complete:

1. **Reflect**: What issues were encountered? How were they resolved?
2. **Evaluate**: Is this recurring? Can it be prevented?
3. **Implement**: Fix it now if safe, or log for later

### Decision Tree

```text
Issue identified
     │
     ├─ Recurring? ─No──→ Log in patterns.md, monitor
     │      │
     │     Yes
     │      │
     ├─ Prevention possible? ─No──→ Create knowledge item
     │      │
     │     Yes
     │      │
     ├─ What type?
     │      │
     │      ├─ Constraint/Policy → New/modify RULE
     │      ├─ Procedural fix → Modify WORKFLOW
     │      └─ Capability gap → Enhance SKILL
     │
     └─ Auto-apply if low risk, else add to proposed_changes.md
```

## The Key Question

> "What specific thing, if available at the start, would have made this task trivial?"

Evaluate for:

| Check | Action |
| ----- | ------ |
| Missing context? | Add to scratch docs or rules |
| Missing tool? | Promote script to `/scripts/` |
| Friction? | Update bootstrap, Dockerfile, or env rules |
| Repeated logic? | Extract to shared library or workflow |

## Proactive Improvement Suggestions

When spotting optimization opportunities, suggest with:

1. **Current state** — what exists now
2. **Proposed change** — specific steps
3. **Impact** — breaking changes, migration needs
4. **Benefits** — quantify where possible

### Auto-Implement If Safe

**Do not just suggest — implement if low-risk:**

- Non-destructive documentation updates
- Creating new helper scripts
- Updating agent scratchpad/memory

## Learning Log

After every task, update `/atn/.agent/learning/`:

| File | Purpose |
| ---- | ------- |
| `reflections/YYYY-MM-DD_<hash>.md` | Per-task reflection |
| `patterns.md` | Recurring issues |
| `changelog.md` | Auto-applied changes |
| `proposed_changes.md` | Changes needing approval |

### Log Format

```markdown
## [Date] - [Task Summary]
### Learned
- [What was discovered]
### Mistakes
- [What went wrong and why]
### Rules Created/Updated
- [R##: Rule Name] - [Brief change description]
### For Next Time
- [What to remember]
```

## Auto-Apply vs. Approval

| Risk Level | Action |
| ---------- | ------ |
| Low (cosmetic, logging) | Auto-apply, log to changelog |
| Medium (behavior change) | Propose, await approval |
| High (security, breaking) | Propose, require explicit approval |

## Enforcement

A task is NOT complete until:

- [ ] Reflection generated
- [ ] Learning files updated (if applicable)
- [ ] Proposed changes logged (if any)
- [ ] Todo list updated with any new items
