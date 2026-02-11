---
description: Close completed conversations, extract learnings, and start fresh
---

# /new-conversation Workflow

> Clean break from previous work. Learn, improve, then begin new tasks.

## Steps

1. **Read Recent Session State**

   ```bash
   cat /atn/.gemini/antigravity/scratch/session_log.md | tail -80   # Recent sessions
   cat /atn/.gemini/antigravity/scratch/todo.md                     # Current backlog
   cat /atn/.gemini/antigravity/scratch/user_preferences.md         # User settings
   ```

2. **Run Preferences Checklist** (MANDATORY)

   Execute the `/checklist-preferences` workflow:
   - Verify `~/.antigravity-server/data/Machine/settings.json` has all auto-approve keys
   - If settings changed → notify user, reload window after 10 seconds
   - Verify command execution patterns (MCP tools over shell commands)

3. **Extract Learnings from Recent Sessions**

   - Parse "Learned" sections from `session_log.md`
   - For each learned item, check if it's codified:
     - Search rules: `grep -r "[keyword]" /atn/.agent/rules/`
     - Search skills: `grep -r "[keyword]" /atn/.gemini/antigravity/skills/`
     - Search workflows: `grep -r "[keyword]" /atn/.gemini/antigravity/global_workflows/`
   - If NOT codified → implement as rule/skill/workflow NOW

4. **Pattern Detection**

   ```bash
   # Check for recurring issues
   cat /atn/.agent/learning/patterns.md 2>/dev/null
   ls -t /atn/.agent/learning/reflections/ 2>/dev/null | head -5
   ```

   - Read recent reflections
   - If same issue appears 2+ times → escalate to rule/workflow

5. **Process Proposed Changes**

   ```bash
   cat /atn/.agent/learning/proposed_changes.md 2>/dev/null
   ```

   - Auto-apply low-risk pending improvements
   - Present medium/high-risk proposals to user

6. **Migrate Outstanding Work**

   - Review `todo.md` for any items that should be re-prioritized
   - Check for stale items (> 7 days old, no progress)
   - Archive completed items
   - Ensure nothing is lost from previous sessions

7. **Cleanup**

   - Verify no stuck background processes
   - Verify no stale git worktrees or branches
   - Update `session_log.md` with cleanup summary

8. **Present Summary**

   ```markdown
   ## New Conversation Ready 🚀

   ### Learnings Applied
   - [Rules/skills/workflows created or updated]

   ### Outstanding Work
   - [Top 3-5 todo items by priority]

   ### Ready For
   - [What the user wants to work on next]
   ```

## Key Differences from /resume

| Aspect | /resume | /new-conversation |
|--------|---------|-------------------|
| Purpose | Continue existing tasks | Start fresh after cleanup |
| Task state | Restore and continue | Archive and close |
| Learning | Quick review | Full extraction + implementation |
| Cleanup | Minimal | Thorough |
