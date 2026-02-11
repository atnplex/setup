# R42: Proactive MCP Server Usage

> **Version**: 2.0.0
> **Updated**: 2026-02-03
> **Authority**: [R0: Precedence](/atn/.gemini/GEMINI.md#r0-precedence)

---

## Rule Statement

**Prefer MCP tools and CLI over browser automation. Browser is a LAST RESORT.**

---

## Tool Priority Order

### For GitHub Operations

| Priority | Method | When to Use |
| -------- | ------ | ----------- |
| 1st | GitHub MCP Tools | PR management, branch updates, merging, file operations |
| 2nd | `gh` CLI | GraphQL mutations, thread resolution, complex queries |
| 3rd | Direct API (`gh api`) | Operations not in MCP or CLI |
| 4th | Browser Subagent | ONLY when no API/CLI method exists |

### Available GitHub MCP Tools

- `mcp_github-mcp-server_update_pull_request_branch` - Update branch with base
- `mcp_github-mcp-server_merge_pull_request` - Merge PRs
- `mcp_github-mcp-server_pull_request_read` - Read PR info, diff, status, comments
- `mcp_github-mcp-server_list_pull_requests` - List PRs
- `mcp_github-mcp-server_search_pull_requests` - Search PRs
- `mcp_github-mcp-server_create_pull_request` - Create PRs
- `mcp_github-mcp-server_get_file_contents` - Get file contents
- `mcp_github-mcp-server_push_files` - Push files to branch

### CLI for Thread Resolution (Not in MCP)

```bash
# Resolve PR review threads via GraphQL
/home/alex/.agent/scripts/resolve-pr-threads.sh <owner> <repo> <pr_number>

# Or manually via gh api graphql
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { id isResolved }
  }
}' -f threadId="THREAD_ID"
```

---

## Thread Resolution Guidelines

> [!IMPORTANT]
> Do NOT blindly resolve all threads. Evaluate content first.

### Before Resolving a Thread

1. **Read the thread content** using MCP or CLI
2. **Evaluate if the concern was addressed** in the code
3. **If it's a valid suggestion** that needs action → make the change first
4. **If it's informational** or already addressed → resolve with confidence
5. **If uncertain** → ask the user

### Thread Categories

| Category | Action |
| -------- | ------ |
| Bug/Security fix suggestion | Implement fix, then resolve |
| Style/formatting suggestion | Low priority, can resolve with note |
| Documentation improvement | Implement if quick, or resolve |
| Nitpick (minor preference) | Safe to resolve |
| Request for clarification | Respond or resolve if clear |

---

## Browser Subagent - Last Resort Only

Use browser automation ONLY for:

- UI interactions that have no API (e.g., enabling GitHub settings)
- Visual verification/screenshots
- Interactive debugging

**Never use browser for:**

- Resolving threads (use GraphQL)
- Merging PRs (use MCP)
- Reading PR content (use MCP)
- File operations (use MCP)

---

## Related Rules

- [R45: Branch Update Before Merge](/atn/.gemini/rules/operational/branch_update.md)
- [R25: PR Lifecycle](/atn/baseline/rules/git_workflow.md)
