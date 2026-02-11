# R45: Branch Update Rule

> **Version**: 1.0.0
> **Updated**: 2026-02-03
> **Authority**: [R0: Precedence](/atn/.gemini/GEMINI.md#r0-precedence)

---

## Rule Statement

**ALWAYS update branches when out of date with base branch before attempting merge.**

---

## Requirements

1. **Check Before Merge**: Before any merge attempt, verify the branch is up-to-date with its base branch.

2. **Update Automatically**: If branch is behind base:
   - Use `mcp_github-mcp-server_update_pull_request_branch` tool
   - Wait for update to complete
   - Verify CI checks pass after update

3. **Never Skip**: Do not proceed to merge if branch is behind base. "This branch is out of date" must be resolved first.

4. **Auto-Merge Consideration**: When auto-merge is enabled, branch updates may be handled automatically, but verify the setting is active.

---

## Implementation

### MCP Method (Preferred)

```bash
# Use GitHub MCP tool for speed
mcp_github-mcp-server_update_pull_request_branch(
  owner: "org-name",
  repo: "repo-name",
  pullNumber: 123
)
```

### CLI Method (Fallback)

```bash
gh pr update-branch <PR_NUMBER> --repo <OWNER>/<REPO>
```

### Browser Method (Last Resort)

Only use browser if MCP and CLI fail. Click "Update branch" button on PR page.

---

## Error Handling

| Error | Meaning | Action |
|-------|---------|--------|
| "head ref does not exist" | Branch deleted or PR merged | Check PR status first |
| "no new commits" | Already up to date | Proceed to merge |
| "merge conflicts" | Auto-update not possible | Manual conflict resolution needed |

---

## Verification

After branch update:

1. Wait for CI checks to restart
2. Confirm all checks pass
3. Verify merge requirements met
4. Proceed with merge

---

## Related Rules

- [R22: Worktree Isolation](/atn/baseline/rules/git_workflow.md)
- [R25: PR Lifecycle](/atn/baseline/rules/git_workflow.md)
