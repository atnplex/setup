---
name: Workflow Standards
description: Defines workflow file format, location, and invocation patterns
trigger: always
---

# R91: Workflow Standards

> Standardizes workflow definitions, locations, and invocation.

## Location

**Global workflows**: `$NAMESPACE/.gemini/antigravity/global_workflows/`

> [!IMPORTANT]
> Do NOT use `.agent/workflows/` for global workflows. That location is reserved for workspace-specific overrides only.

## File Format

Every workflow file must have YAML frontmatter:

```yaml
---
name: Human Readable Name
description: Brief description shown in slash command list
model: optional-preferred-model
---
```

Followed by markdown content with steps.

## Naming Conventions

| Convention | Example |
|------------|---------|
| Use Verb-Noun format | `Deploy Service`, not `Service Deploy` |
| No abbreviations | `pull-request.md`, not `pr.md` |
| Lowercase with hyphens | `git-operations.md` |
| Pipeline workflows | `pipeline-NN-verb.md` |

## Invocation

Workflows are invoked via `/` in the agent sidebar:

- `/triage` → `pipeline-00-triage.md`
- `/git-operations` → `git-operations.md`
- `/deploy-service` → `deploy-service.md`

## Turbo Annotations

Control auto-execution of steps:

| Annotation | Scope |
|------------|-------|
| `// turbo` | Auto-run the NEXT step only |
| `// turbo-all` | Auto-run ALL steps in workflow |

Example:

```markdown
### 1. Check Status
// turbo
```bash
git status
```

```

## Pipeline Workflows

Core pipeline files follow numbered sequence:

1. `pipeline-00-triage.md` - Initial classification
2. `pipeline-01-confirm.md` - User confirmation
3. `pipeline-02-decompose.md` - Task breakdown
4. `pipeline-03-execute.md` - Implementation
5. `pipeline-04-pr-lifecycle.md` - PR handling
6. `pipeline-05-deliver.md` - Final delivery
