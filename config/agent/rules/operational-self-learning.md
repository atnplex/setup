# R-SELF-LEARN: Continuous Self-Improvement

> **Agent improves automatically with every session. User should never repeat the same guidance twice.**

## Pre-Task Learning (integrated into /resume)

Before starting new work, the agent MUST:

1. **Read recent reflections** — `ls -t /atn/.agent/learning/reflections/ | head -5`
2. **Read patterns** — `cat /atn/.agent/learning/patterns.md`
3. **Check proposed changes** — `cat /atn/.agent/learning/proposed_changes.md`
4. **Auto-apply pending low-risk improvements** — if any are marked 🟡 Pending + Low Risk, implement them
5. **Verify user preferences** — `cat /atn/.gemini/antigravity/scratch/user_preferences.md`

## During-Task Learning

When the agent discovers a better approach during work:

1. **Implement it immediately** if low-risk
2. **Create/update a rule, skill, or workflow** to encode the pattern
3. **Log it** to `session_log.md` under "Learned"
4. **Never defer learning** — if the agent identifies an improvement, it acts NOW

## Post-Task Learning (existing learning-cycle.md)

After task completion, invoke the learning cycle workflow to reflect and extract patterns.

## Batch Operations Pattern

> **Always batch similar items. Never process identical-type issues one-by-one.**

When encountering multiple issues of the same type:

1. **Inventory first** — list ALL instances before fixing any
2. **Group by type/rule** — categorize by root cause
3. **Fix by group** — one commit per rule category
4. **Verify all at once** — run full scan after batch fix

Applies to: code scanning alerts, dependabot PRs, lint errors, test failures, repo cleanup.

## Migration on /resume

When resuming in a new conversation:

1. Read `session_log.md` → extract "Learned" sections
2. Check if learned items are codified as rules/skills/workflows
3. If not codified → implement them before proceeding
4. Ensure `todo.md` items from previous session are still tracked
5. Only after migration is complete → start new work
