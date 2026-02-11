---
name: filesystem-context
description: Use filesystem for dynamic context offloading and persistence
keywords: [filesystem, offload, persist, scratchpad, memory, file]
---

# Filesystem Context Skill

> **Purpose**: Extend context beyond window limits using filesystem

## Core Concept

The filesystem is infinite context storage. Use it to:

- Offload completed work
- Store intermediate results
- Persist learnings across sessions
- Create scratchpads for complex reasoning

## When to Use

- Context approaching limits
- Multi-step tasks with intermediate results
- Information needed later but not now
- Complex reasoning requiring scratch space

## Patterns

### 1. Scratchpad Pattern

Create temporary file for complex reasoning:

```
Location: ~/scratch/<task-id>/scratch.md

Contents:
## Reasoning Steps
1. First I need to...
2. Considering options...
3. Decision: ...

## Intermediate Results
- Found 5 files matching pattern
- Identified 3 potential issues
```

### 2. Context Offload Pattern

Move completed context to file:

```
Location: ~/scratch/<task-id>/context-history.jsonl

# Append completed turns:
{"role": "summary", "content": "Completed auth implementation", "timestamp": "..."}
{"role": "summary", "content": "Fixed 3 bugs in login flow", "timestamp": "..."}
```

### 3. Just-In-Time Loading

Store and retrieve as needed:

```
~/scratch/<task-id>/
├── current-focus.md      # Always loaded
├── completed-work.md     # Load when reviewing
├── reference-data.json   # Load when needed
└── decisions.md          # Load for context
```

### 4. Append-Only Memory

Use JSONL for persistent memory:

```jsonl
{"type": "decision", "content": "Using PostgreSQL for database", "reason": "Team expertise"}
{"type": "learning", "content": "Auth refresh needs 5-min buffer", "source": "bug-123"}
{"type": "preference", "content": "User prefers dark mode examples"}
```

## Implementation

### Creating Scratchpad

```bash
mkdir -p ~/scratch/$(date +%Y%m%d-%H%M%S)
```

### Writing Context

Use mcp-filesystem to write intermediate results

### Reading Context

Re-read files when context needed

### Cleaning Up

Archive or delete after task completion

## Directory Structure

```
~/scratch/
├── active/               # Current task scratchpads
│   └── <task-id>/
│       ├── scratch.md
│       ├── decisions.md
│       └── context.jsonl
├── archive/              # Completed tasks
└── persistent/           # Cross-session learnings
    ├── user-preferences.jsonl
    ├── project-patterns.jsonl
    └── common-fixes.jsonl
```

## Integration with MCP Memory

Use mcp-memory for structured entities.
Use filesystem for:

- Large text blocks
- Intermediate work products
- Session-specific data
