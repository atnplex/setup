---
name: Artifacts and Knowledge Standards
description: Defines artifact types, locations, and knowledge persistence
trigger: always
---

# R94: Artifacts and Knowledge Standards

> Standardizes artifact creation and knowledge persistence.

## Artifact Types

| Type | File | Purpose |
|------|------|---------|
| Task List | `task.md` | Track progress with checkboxes |
| Implementation Plan | `implementation_plan.md` | Document proposed changes |
| Walkthrough | `walkthrough.md` | Document completed work |
| Other | `*.md` | General documentation |

## Artifact Location

All artifacts for a conversation go in:

```
$NAMESPACE/.gemini/antigravity/brain/<conversation-id>/
```

## Task List Format

```markdown
# Task: <Title>

## Status: Planning|In Progress|Complete

## Completed
- [x] Done item

## In Progress
- [/] Current work

## Pending
- [ ] Future work
```

## Implementation Plan Format

Required sections:

1. **Goal Description** - What and why
2. **User Review Required** - Breaking changes, decisions needed
3. **Proposed Changes** - By component, with file links
4. **Verification Plan** - How to test

## Walkthrough Format

Document after completing work:

1. **Summary** - What was accomplished
2. **Changes Made** - With diffs/screenshots
3. **Verification** - Evidence of testing

> [!TIP]
> Embed screenshots and recordings using `![caption](/absolute/path)`

## Knowledge Persistence

Long-term memory stored in `$NAMESPACE/.gemini/knowledge/`:

| Component | Purpose |
|-----------|---------|
| `metadata.json` | Summary, timestamps, references |
| `artifacts/` | Related files and documentation |

### When to Create Knowledge Items

- Reusable patterns discovered
- Architecture decisions made
- Debugging solutions found
- Configuration documented

### Knowledge Item Structure

```
knowledge/<topic>/
├── metadata.json
└── artifacts/
    └── relevant-files.md
```

## Artifact Review Policy

Artifacts requiring user approval:

| Policy | Behavior |
|--------|----------|
| `always` | Every artifact needs approval |
| `never` | Auto-proceed without approval |
| `model_decision` | Agent decides based on risk |
