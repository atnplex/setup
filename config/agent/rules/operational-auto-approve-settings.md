---
name: Auto-Approve Settings Enforcement
description: Ensure Antigravity IDE auto-approve settings are always active
trigger: session-start
---

# Auto-Approve Settings Enforcement

> **Settings file**: `~/.antigravity-server/data/Machine/settings.json`
> **When**: Every `/resume`, `/new-conversation`, `/checklist-preferences`

## Required Settings

All of the following MUST be present and set to the values shown:

| Key | Required Value |
|-----|----------------|
| `chat.tools.global.autoApprove` | `true` |
| `chat.tools.eligibleForAutoApproval` | `{"*": true}` |
| `chat.tools.urls.autoApprove` | `{"*": true}` |
| `chat.customAgentInSubagent.autoApprove` | `true` |
| `antigravity.autoApproveCommands` | `true` |
| `antigravity.terminal.autoApprove` | `true` |
| `antigravity.security.autoApproveCommands` | `true` |

## Enforcement Process

1. Read settings file via `mcp_mcp-filesystem_read_file`
2. Parse JSON and check each required key
3. If any key missing/wrong → merge and write via `mcp_mcp-filesystem_write_file`
4. If file was modified:
   - Notify user: "⚙️ Settings updated. Reloading window in 10 seconds."
   - Wait 10 seconds
   - Reload window

## Command Execution Safeguards

> [!IMPORTANT]
> These patterns exist because shell commands hang in the IDE terminal. Follow them ALWAYS.

| Task | Use This | NOT This |
|------|----------|----------|
| Read files | `mcp_mcp-filesystem_read_file` | `run_command: cat` |
| List dirs | `mcp_mcp-filesystem_list_directory` | `run_command: ls` |
| Git ops | `mcp_mcp-git_*` tools | `run_command: git` |
| Multi-step shell | Write script → `run_command: bash script.sh` | Piped commands |
| Remote ops | `timeout 10 ssh ...` | Unbounded SSH |

## Window Reload Protocol

When settings change requires a window reload:

1. Notify user with explanation of what changed
2. Wait exactly 10 seconds (use `mcp_mcp-playwright_browser_wait_for` with `time: 10` or equivalent)
3. Auto-reload window
