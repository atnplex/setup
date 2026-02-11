---
name: prompt-optimization
description: Enhance user prompts with context from repos, history, and preferences
keywords: [prompt, optimization, context, enhancement, personalization, inference]
---

# Prompt Optimization Skill

> **Purpose**: Automatically enhance prompts with user context for better results

## Core Concept

Transform vague requests into specific, context-aware prompts by:

1. Inferring intent from user history
2. Adding repo structure context
3. Applying known preferences
4. Specifying implicit requirements

## Context Sources

| Source | Information |
|--------|-------------|
| **Repository** | Tech stack, file patterns, conventions |
| **Past conversations** | Preferences, decisions, patterns |
| **infrastructure/resources.json** | Available resources, accounts |
| **mcp-memory entities** | Stored facts about projects |

## Enhancement Pipeline

```
User Prompt → Analyze Intent → Gather Context → Enhance → Execute
    ↓              ↓               ↓              ↓
 "fix the       Identify       Check repo     "Fix the auth
  auth bug"    task type,     structure,      bug in src/auth/
               component      past fixes      login.ts using the
                                              existing error
                                              handling pattern
                                              from session.ts"
```

## Auto-Enhancement Rules

### 1. Tech Stack Detection

```yaml
# If repo has package.json with React
if: "react" in dependencies
then: Add "using React patterns and hooks"

# If repo has .go files
if: "*.go" exists
then: Add "following Go idioms and error handling"
```

### 2. Convention Inference

```yaml
# Detect naming conventions
if: files use camelCase
then: Specify "use camelCase naming"

# Detect test patterns
if: *.test.ts exists
then: Add "include tests in *.test.ts format"
```

### 3. User Preference Application

```yaml
# From past conversations
preference: "user prefers TypeScript strict mode"
apply: Add "with strict TypeScript checks"

preference: "user uses conventional commits"
apply: Follow "feat/fix/docs/chore prefix format"
```

## Prompt Enhancement Template

```markdown
## Original Request
[user's original prompt]

## Enhanced Prompt
[Enhanced with context]

### Context Added
- Tech stack: [detected stack]
- Conventions: [detected conventions]
- Related files: [relevant file paths]
- Past patterns: [similar past work]

### Implicit Requirements
- [inferred requirement 1]
- [inferred requirement 2]
```

## Integration with Pipeline

In `00-triage.md`:

```yaml
prompt_enhancement:
  enabled: true
  sources:
    - repo_structure
    - memory_entities
    - infrastructure_config
  auto_enhance:
    - tech_stack
    - conventions
    - implicit_requirements
```

## Examples

### Before/After

**Before**: "Add login feature"

**After**: "Add login feature to the Next.js app using:

- Auth pattern from existing src/auth/ directory
- Shadcn UI components matching current design
- TypeScript strict mode
- API routes in app/api/ directory
- Error handling pattern from utils/errors.ts
- Jest tests following existing test structure"

---

**Before**: "Deploy to production"

**After**: "Deploy to production using:

- Docker Compose on VPS1 (from infrastructure config)
- Tailscale for secure networking
- Health check verification before traffic switch
- Rollback plan via git revert if issues"

## Memory Integration

Store learned preferences:

```
Entity: UserPreferences
Observations:
- "Prefers TypeScript over JavaScript"
- "Uses conventional commits"
- "Wants tests for all new features"
- "Prefers Tailwind CSS over vanilla"
```
