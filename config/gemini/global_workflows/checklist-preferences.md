---
description: Verify and enforce user preferences and auto-approve settings
---

# /checklist-preferences Workflow

> Ensures all user preferences and environment settings are active. Called automatically by `/resume` and `/new-conversation`, or manually as `/checklist-preferences`.

## Steps

// turbo-all

1. **Verify Antigravity Settings** (auto-approve, MCP discovery, etc.)

   > [!CAUTION]
   > Settings must be applied on the **CLIENT side** (Windows desktop), not just the remote server.
   > The Windows User settings are at: `/mnt/c/Users/Alex/AppData/Roaming/Antigravity/User/settings.json`
   > Access via SSH to `antigravity-wsl` (Tailscale: `100.114.18.47`).

   Read BOTH settings files and compare against required values:

   **Remote server settings** (read via MCP — never shell `cat`):
   Use `mcp_mcp-filesystem_read_file` on `~/.antigravity-server/data/Machine/settings.json`

   **Windows client settings** (read via SSH to WSL):
   ```bash
   timeout 10 ssh -o ConnectTimeout=5 alex@100.114.18.47 "cat '/mnt/c/Users/Alex/AppData/Roaming/Antigravity/User/settings.json'"
   ```

   **Required settings** (merge into existing, never overwrite unrelated keys):

   ```json
   {
     "chat.editing.autoAcceptDelay": 500,
     "chat.tools.eligibleForAutoApproval": { "*": true },
     "chat.useClaudeSkills": true,
     "chat.useNestedAgentsMdFiles": true,
     "chat.tools.global.autoApprove": true,
     "chat.tools.urls.autoApprove": { "*": true },
     "chat.customAgentInSubagent.enabled": true,
     "chat.customAgentInSubagent.autoApprove": true,
     "chat.mcp.discovery.enabled": {
       "claude-desktop": false,
       "antigravity": true,
       "cursor-global": false,
       "cursor-workspace": false
     },
     "chat.mcp.gallery.enabled": true,
     "antigravity.autoApproveCommands": true,
     "antigravity.terminal.autoApprove": true,
     "antigravity.security.autoApproveCommands": true,
     "search.exclude": { "**/.agent": false, "**/rules": false },
     "files.exclude": { "**/.agent": false, "**/rules": false }
   }
   ```

   - If any key is missing or wrong → update the file via MCP filesystem (read, merge, write)
   - If changes were made → notify user and reload window after 10 seconds

2. **Reload Window If Settings Changed**

   If step 1 modified the settings file:
   - Notify user: "Settings updated. Reloading window in 10 seconds to apply changes."
   - Wait 10 seconds
   - Execute window reload via command palette or equivalent

3. **Verify User Preferences** (from `user_preferences.md`)

   ```bash
   cat /atn/.gemini/antigravity/scratch/user_preferences.md
   ```

   Quick check against active environment:
   - [ ] Timezone: America/Los_Angeles
   - [ ] Language: English only
   - [ ] OS target: Linux (Debian 12)
   - [ ] Compute priority: VPS1/VPS2 → Windows → Unraid

4. **Verify Command Execution Patterns**

   Agents MUST follow these patterns to prevent hanging:
   - [ ] Use MCP filesystem tools (`mcp_mcp-filesystem_read_file`, etc.) instead of `cat`, `ls` for file ops
   - [ ] Use MCP git tools instead of shell `git` commands
   - [ ] For shell commands: always set `WaitMsBeforeAsync` ≤ 5000ms
   - [ ] For potentially long commands: use scripts with `timeout` wrapper
   - [ ] Never pipe commands in `run_command` — write a script instead

5. **Report**

   If all checks pass silently, do NOT interrupt the user — just proceed with the task.
   Only notify user if:
   - Settings file was modified (with 10s reload warning)
   - A preference cannot be enforced programmatically

## Anti-Patterns (NEVER Do These)

| ❌ Bad | ✅ Good |
|--------|---------|
| `run_command: cat file` | `mcp_mcp-filesystem_read_file` |
| `run_command: git status` | `mcp_mcp-git_git_status` |
| `run_command: ls -la dir/` | `mcp_mcp-filesystem_list_directory` |
| Piped commands | Write a script, then run it |
| No timeout on SSH | `timeout 10 ssh ...` |
