---
description: Resume work from last checkpoint without forgetting context
---

# /resume Workflow

When user says `/resume`, pick up where we left off with full context.

> [!NOTE]
> Common trigger: new conversation, returning after quota reset, switching models.

// turbo-all

## Steps

1. **Read Cross-Session State** (always available, even in new conversation)

   Use MCP filesystem tools (NOT shell commands) to read these files:
   - `/atn/.gemini/antigravity/scratch/session_log.md` — What happened in recent sessions
   - `/atn/.gemini/antigravity/scratch/todo.md` — Full backlog with priorities
   - `/atn/.gemini/antigravity/scratch/user_preferences.md` — User's preferred settings

   Use `mcp_mcp-filesystem_read_multiple_files` to read all three in one call.

2. **Self-Learning Review** (micro review — quick, focused)
   - Use `mcp_mcp-filesystem_list_directory` on `/atn/.agent/learning/reflections/` to find recent files
   - Read `patterns.md` and `proposed_changes.md` in `/atn/.agent/learning/` via MCP
   - Verify "Learned" items from recent `session_log.md` are codified as rules/skills/workflows
   - Auto-apply any pending low-risk improvements
   - This step should take < 2 minutes — not a full review

3. **Read Conversation Summaries** (provided by the system)
   - The system injects recent conversation summaries at conversation start
   - Scan them for the most recent relevant work
   - Note the conversation ID if you need to dig deeper

4. **Find Last Checkpoint** (if available)

   Use `mcp_mcp-filesystem_search_files` to find `checkpoint.json` in `~/.gemini/antigravity/brain/`.

   - Read `checkpoint.json` for task, status, pending, resume_hint
   - Read `task.md` for detailed progress
   - Read `implementation_plan.md` if it exists

5. **Run Preferences Checklist** (MANDATORY)

   Execute the `/checklist-preferences` workflow:
   - Verify `~/.antigravity-server/data/Machine/settings.json` has all auto-approve keys
   - If settings changed → notify user, reload window after 10 seconds
   - Verify command execution patterns (MCP tools over shell commands)
   - Verify `user_preferences.md` settings are active
   - Confirm current model matches session efficiency rules

6. **Verify Environment**
   - Use `mcp_mcp-git_git_status` for git status (NOT shell `git`)
   - Verify relevant files still exist via MCP filesystem tools
   - For network checks, use `run_command` with `SafeToAutoRun: true` and `WaitMsBeforeAsync: 3000`

7. **Summarize and Continue**

   ```markdown
   ## Resuming Session 🔄

   ### Last Session (from session_log)
   - [What was accomplished and when]

   ### Pending (from todo)
   - [Top 3-5 items by priority]

   ### Continuing With
   - [Next action based on resume_hint or todo priority]
   ```

8. **Continue Working** (do NOT wait for confirmation unless unclear)
   - If checkpoint has a clear `resume_hint`, execute it
   - If user provided context with `/resume`, incorporate it
   - Only ask for confirmation if state is ambiguous

## Tool Usage Rules (CRITICAL)

> [!CAUTION]
> NEVER use shell commands for operations that have MCP equivalents.
> All `run_command` calls MUST use `SafeToAutoRun: true` for read-only operations.

| ❌ Bad | ✅ Good |
|--------|---------|
| `run_command: cat file` | `mcp_mcp-filesystem_read_file` |
| `run_command: git status` | `mcp_mcp-git_git_status` |
| `run_command: ls dir/` | `mcp_mcp-filesystem_list_directory` |
| `run_command: ls -t ... \| head` | `mcp_mcp-filesystem_list_directory` + sort in logic |
| `SafeToAutoRun: false` on reads | `SafeToAutoRun: true` on ALL read-only ops |

## Context Recovery Priority

1. **session_log.md** — Most reliable cross-session context (append-only)
2. **todo.md** — Full backlog with priorities and tags
3. **Conversation summaries** — System-provided, covers recent sessions
4. **checkpoint.json** — Detailed snapshot from specific session
5. **task.md** — Progress tracking for specific task
6. **Git history** — Last resort, check recent commits

## Anti-Hallucination

- Do NOT assume what was done — READ the files
- Do NOT claim to remember past sessions — VERIFY from sources
- If sources conflict, prefer session_log > checkpoint > memory
