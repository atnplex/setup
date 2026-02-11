# R-PROCESS: Command Execution Hygiene

> **Every command must be time-bounded. Never leave processes running unmonitored.**

## Root Causes of Stuck Processes (2026-02-10 incident)

1. **No timeouts on network calls**: `gh api`, `curl`, `ssh` commands issued without `--connect-timeout` or `-m` flags
2. **Background commands never checked**: commands sent to background with `WaitMsBeforeAsync=500` then forgotten
3. **Loops without exit conditions**: `for path in /api/v1/...` loop ran 1+ hour because each iteration waited indefinitely
4. **`gh api` hangs on async operations**: GitHub PATCH endpoints that trigger server-side work (e.g., code scanning disable) block `gh api` until completion — `curl` returns immediately with 202

## Rules

### 1. ALWAYS Set Timeouts — No Exceptions

> [!CAUTION]
> EVERY `run_command` call MUST use `timeout <seconds>` as the outermost wrapper.
> This includes local commands like `cat`, `grep`, `jq` when piped to/from other tools.

```bash
# Network commands
timeout 15 curl -m 30 ...                  # timeout + curl's own limit
timeout 10 ssh -o ConnectTimeout=5 ...     # timeout + SSH's own limit
timeout 15 gh api ... 2>&1                  # gh api can hang indefinitely

# Local commands with pipes (THESE ALSO HANG)
timeout 10 bash -c 'cat file.json | python3 -c "..."'   # pipe buffering!
timeout 5 jq '.key' file.json              # even local reads

# Better: use file-reading tools (view_file, mcp read_file) instead of cat/jq
# They never hang and don't create terminal sessions
```

### 1a. Prefer File Tools Over Shell Pipes

When reading file contents, ALWAYS prefer:
- `view_file` / `view_file_outline` — Reliable, no hang risk
- `mcp_mcp-filesystem_read_file` — Direct file read
- `grep_search` — Pattern search without pipes

Only use shell pipes when transforming data (not just reading it).

### 2. Use `WaitMsBeforeAsync` Appropriately

| Command Type | WaitMsBeforeAsync | Rationale |
|-------------|-------------------|-----------|
| Local reads (ls, cat, grep) | 3000-5000 | Should complete instantly |
| Git local ops (status, diff) | 5000 | Depends on repo size |
| Network API calls (gh, curl) | 10000 | May be slow but should timeout |
| SSH commands | 10000 | Network dependent |
| Long-running (sleep, loops) | 500 | Intentionally background |

### 3. Track Background Commands

- After backgrounding a command, check status within 60s
- If status is still RUNNING after 2 checks (120s total), investigate
- Never have more than 3 background commands running simultaneously
- Kill stuck commands explicitly — don't just abandon them

### 4. Prefer Direct curl Over gh api

For GitHub API calls that may trigger async operations:

- Use `curl -m 30` with explicit timeout
- Parse HTTP status code with `-w "%{http_code}"`
- `gh api` blocks until completion for some endpoints — curl returns immediately with 202

### 5. Periodic Cleanup

- Before starting new work blocks, check for orphaned processes
- After a task completes, verify no background commands are still running
- If user reports stuck processes, root-cause BEFORE killing

### 6. Root Cause Analysis Required

When bypassing or fixing an issue:

1. Fix the immediate problem
2. Identify WHY it happened
3. Create/update rules or skills to prevent recurrence
4. Log the finding in session_log.md under "Learned"
