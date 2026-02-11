---
description: Standards for file naming, workflow titles, and avoiding abbreviations.
---

# R82: Naming Standards

> **Authority**: Global
> **Scope**: All filenames, workflow titles, and task names.

## Core Principles

1. **Explicit Over Implicit**: Do not use abbreviations that reduce clarity for the sake of brevity.
2. **Action-Oriented Workflows**: Workflows describe *actions*, so they must follow a Verb-Noun structure.

## Rules

### 1. No Common Abbreviations in Names

Do not use common developer abbreviations in filenames or workflow titles. Spell them out.

| Forbidden | Required |
|-----------|----------|
| `pr` | `pull-request` |
| `k8s` | `kubernetes` |
| `repo` | `repository` |
| `config` | `configuration` (unless standard file like .config) |
| `auth` | `authentication` |

### 2. Workflow Naming: Verb-Noun

All workflows must describe an action.

- **Correct**: `manage-pull-requests.md`, `deploy-service.md`, `audit-security.md`
- **Incorrect**: `pull-requests.md`, `deployment.md`, `security.md`

### 3. Global Workflow Location

Global workflows that apply across repositories or the organization must reside in:

```bash
/atn/.gemini/antigravity/global_workflows/
```

### 4. Symlink Truth

The user home directory `.gemini` must always be a symlink to the persistent storage:

```bash
~/.gemini -> /atn/.gemini
```

Any reference to `.gemini` paths should use the derived path or the symlink, assuming `~/.gemini` is the entry point for user-facing operations.
