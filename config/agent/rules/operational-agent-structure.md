---
name: Agent Structure Standards
description: Defines Antigravity agent configuration locations and structure
trigger: always
---

# R90: Agent Structure Standards

> Defines the canonical locations and structure for Antigravity configuration.

## Global Configuration

All global configuration lives under `$NAMESPACE/.gemini/` (default: `/atn/.gemini/`).

| Component | Location | Purpose |
|-----------|----------|---------|
| Global Rules | `$NAMESPACE/.gemini/GEMINI.md` | Single entry point, uses `@includes` |
| Rule Modules | `$NAMESPACE/.gemini/rules/` | Detailed rules by category |
| Global Workflows | `$NAMESPACE/.gemini/antigravity/global_workflows/` | Agent-invoked via `/` |
| Skills | `$NAMESPACE/.gemini/antigravity/skills/<name>/` | Each skill has `SKILL.md` |
| Personas | `$NAMESPACE/.gemini/antigravity/personas/` | Role-specific behavior |
| MCP Config | `$NAMESPACE/.gemini/antigravity/mcp_config.json` | Tool server definitions |
| Knowledge | `$NAMESPACE/.gemini/knowledge/` | Persistent memory |

## Symlink Strategy

Global availability via symlinks from user home:

```bash
~/.gemini → $NAMESPACE/.gemini
~/.agent  → $NAMESPACE/.agent
```

## Workspace Configuration (Optional)

Workspace-specific overrides in `.agent/` within a project:

| Component | Location | Purpose |
|-----------|----------|---------|
| Workspace Rules | `.agent/rules/*.md` | Project-specific rules |
| Workspace Workflows | `.agent/workflows/*.md` | Project-specific workflows |
| Workspace Skills | `.agent/skills/<name>/` | Project-specific skills |

> [!NOTE]
> Workspace items override global items with the same name.

## Rule Triggers

Rules support these trigger modes:

| Trigger | Behavior |
|---------|----------|
| `always` | Applied to every conversation |
| `manual` | User must mention with `@rulename` |
| `glob: "*.py"` | Applied only to matching files |
| `model_decision` | Agent decides when to apply |
