# R-DEFER: Deferred Task Tracking

> **Every deferred idea, feature, or task MUST be captured in the persistent todo list.**

## When to Add to Todo

1. **User mentions a feature/idea** → add immediately with importance level
2. **Agent identifies an improvement** → add with context
3. **Task is postponed** → add with reason and original context
4. **User asks "can we do X later"** → add with user attribution

## Todo File Location

`/atn/.gemini/antigravity/scratch/todo.md` — canonical, persistent, cross-session

## Required Fields

Each todo item MUST include:

```markdown
- [ ] Description `[tags]` — Added YYYY-MM-DD, source: [user/agent/session]
```

## Importance Levels

| Level | Emoji | Meaning |
|-------|-------|---------|
| Critical | 🔴 | Blocking other work |
| Important | 🟡 | Should do soon |
| Normal | 🟢 | When time permits |
| Backlog | 🔵 | Ideas for later |

## Rules

1. **Never lose a user request** — if user mentions wanting something, it goes in todo
2. **Never defer silently** — if you postpone something, say so AND add to todo
3. **Review todo on /resume** — ensure no items are stale or forgotten
4. **Triage regularly** — re-evaluate importance levels as context changes
5. **Per-project lists** — repos can have their own todo in `.github/TODO.md`
