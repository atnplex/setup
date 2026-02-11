---
name: Skills Standards
description: Defines skill folder structure and SKILL.md format
trigger: always
---

# R92: Skills Standards

> Standardizes skill definitions and discovery.

## Location

| Type | Location |
|------|----------|
| Global Skills | `$NAMESPACE/.gemini/antigravity/skills/<skill-name>/` |
| Workspace Skills | `.agent/skills/<skill-name>/` |

## Required Files

Every skill folder MUST contain:

```
<skill-name>/
├── SKILL.md        # Required - Main instruction file
├── scripts/        # Optional - Helper scripts
├── examples/       # Optional - Reference implementations
└── resources/      # Optional - Additional assets
```

## SKILL.md Format

```yaml
---
name: Skill Name
description: Brief description for discovery
triggers:
  - keyword1
  - keyword2
---

# Skill Name

Detailed instructions for the agent...
```

## Discovery

Skills are loaded when:

1. User request contains trigger keywords
2. User explicitly mentions `@skill-name`
3. Domain detection matches skill category

## Current Skills

| Skill | Purpose |
|-------|---------|
| `brainstorming` | REQUIRED before creative work |
| `verification-before-completion` | REQUIRED before claiming done |
| `parallel-research` | Fast parallel summarization |
| `context-compression` | Reduce token usage |
| `error-recovery` | Handle failures gracefully |
| `memory-persistence` | STM/LTM separation |
| `self-reflection` | Analyze past actions |

## Usage Example

When implementing a new feature:

1. Load `brainstorming` skill first
2. Execute skill instructions
3. Proceed with implementation
4. Load `verification-before-completion` before claiming done
