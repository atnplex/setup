# R83: Pre-Work Sync Requirement

> **Authority**: OPERATIONAL RULE
> **Severity**: HIGH - MANDATORY before any code modifications
> **Updated**: 2026-02-05

---

## Core Principle

> [!CAUTION]
> **NEVER work on stale files. ALWAYS sync with remote before modifying code.**

Before making any changes to files within a Git-managed directory, you MUST verify the local state against the remote source of truth.

---

## Mandatory Pre-Work Checklist

### 1. Identify Repository

Ensure you are in the correct repository and branch.

### 2. Fetch Remote State

Run `git fetch origin` (or the appropriate remote) to update remote tracking branches without merging.

### 3. Check for Discrepancies

Run `git status` to determine:

- If the local branch is **behind** the remote.
- If the local branch has **diverged** from the remote.
- If there are **untracked** or **uncommitted** changes that might conflict.

### 4. Resolve Discrepancies

- **If behind**: Perform a safe fast-forward (`git pull --ff-only`) or notify the user if manual intervention is needed.
- **If diverged**: STOP and notify the user immediately. Do not attempt to force-push or merge complex conflicts without explicit approval.
- **If in sync**: Proceed with the planned modifications.

---

## Why This is Required

1. **Avoid Merge Conflicts**: Catching remote changes early prevents painful conflicts later.
2. **Data Integrity**: Ensure you are not overwriting or undoing work committed by others (or yourself in a different session).
3. **Valid Context**: Your analysis and proposed changes must be based on the latest version of the code to be valid.

---

## Usage Example

```bash
# Before editing lib/ops/secrets.sh
cd /atn/github/atn
git fetch origin
git status

# Result: Your branch is behind 'origin/main' by 5 commits.
git pull --ff-only
# Now proceed with edits.
```

---

## Rationale

This rule ensures that the agent always operates on the most current and valid information, maintaining codebase stability and preventing "stale code" bugs.
