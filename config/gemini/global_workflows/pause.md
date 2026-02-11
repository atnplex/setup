---
description: Gracefully pause current work with comprehensive summary
---

# /pause Workflow

When user says `/pause`, find a good stopping point and provide a summary.

## Steps

1. **Complete Current Action**
   - Finish any in-progress tool calls
   - Don't leave partial work (half-edited files, uncommitted changes)

2. **Append to Session Log** (MANDATORY)

   Append a new entry to `/atn/.gemini/antigravity/scratch/session_log.md`:

   ```markdown
   ## YYYY-MM-DDTHH:MMZ — [Task Name] (conversation [ID])

   **Model**: [Current model name]

   ### Accomplished
   - [What was done this session]

   ### Learned
   - [Issues encountered, fixes discovered]

   ### Active Work
   - [What was in progress when pausing]

   ### Key Decisions
   - [Important decisions made]
   ```

3. **Update Todo List**
   - Sync `scratch/todo.md` with current progress
   - Mark completed items as `[x]`
   - Add any new items discovered during work

4. **Save Checkpoint** (in brain directory)

   Write `checkpoint.json`:

   ```json
   {
     "timestamp": "ISO8601Z",
     "task": "current task name",
     "status": "what was accomplished",
     "pending": ["remaining items"],
     "context": "important context for next session",
     "model": "model name",
     "resume_hint": "specific next action to take"
   }
   ```

5. **Commit if Applicable**
   - If working in a git repo with changes, commit with descriptive message
   - Don't push unless explicitly asked

6. **Provide Summary to User**

   ```markdown
   ## Session Paused ⏸️

   ### Accomplished
   - [Key items completed]

   ### State Saved
   - session_log.md ✅
   - todo.md ✅
   - checkpoint.json ✅

   ### To Resume
   Use `/resume` in any conversation — cross-session state is saved.

   ### Next Up
   - [What to do next, from todo.md]
   ```
