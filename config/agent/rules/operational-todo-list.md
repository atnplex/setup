---
description: Persistent cross-session todo list with triage and task linking
trigger: always_on
---

# Persistent Todo List

Location: `/atn/.gemini/antigravity/scratch/todo.md`

## Purpose

A running list of tasks, ideas, and action items mentioned across all conversations. Updated continuously by any agent. Survives session boundaries.

## Format

```markdown
# Todo List - Updated: <ISO8601Z timestamp>

## 🔴 Critical (blocking work)
- [ ] <task> `[tags]` — Added <date> from <conversation-topic>

## 🟡 Important (should do soon)
- [ ] <task> `[tags]` — Added <date> from <conversation-topic>

## 🟢 Normal (when time permits)
- [ ] <task> `[tags]` — Added <date> from <conversation-topic>

## 🔵 Ideas (backlog)
- [ ] <task> `[tags]` — Added <date> from <conversation-topic>

## ✅ Completed
- [x] <task> — Completed <date>
```

## Rules

1. **Always add**: When user mentions something to do, add it immediately
2. **Always tag**: Use inline tags like `[infra]`, `[security]`, `[skills]`, `[config]`, `[deploy]`, `[mcp]`
3. **Always link**: Note the conversation topic or ID it came from
4. **Triage on add**: Assign priority based on context
5. **Mark on complete**: Move to Completed section with date
6. **Never delete**: Completed items stay for audit trail
7. **Check before work**: Read the todo list at session start to pick up forgotten items

## Agent Behavior

- On `/pause`: Review todo list, add any mentioned-but-not-tracked items
- On `/resume`: Read todo list for context on what's pending
- During work: Add items as they come up naturally
- After completing work: Mark items done
