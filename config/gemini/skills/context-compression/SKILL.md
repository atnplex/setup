---
name: context-compression
description: Compress and summarize context to reduce token usage
keywords: [compress, summarize, token, context, reduce, optimize]
---

# Context Compression Skill

> **Purpose**: Reduce token usage by summarizing and compressing context

## When to Use

- Context window approaching limits
- Long conversation history needs summarization
- Tool outputs are verbose and can be condensed
- Retrieved documents need distillation

## Compression Strategies

### 1. Progressive Summarization

Summarize at increasing levels of abstraction:

```
Level 1: Keep all details
Level 2: Summarize to key points
Level 3: Extract only decisions/facts
Level 4: Single-line summary
```

### 2. Semantic Chunking

Group related information together before compressing:

```
1. Identify semantic boundaries
2. Group by topic/purpose
3. Compress each group independently
4. Maintain cross-references
```

### 3. Information Hierarchy

Prioritize by recency and relevance:

```
HIGH: Current task details, recent user messages
MEDIUM: Background context, earlier decisions
LOW: Historical info, completed tasks
EVICT: Superseded info, resolved issues
```

## Implementation

### Compress Tool Outputs

```markdown
BEFORE (500 tokens):
[Full git log output with all fields]

AFTER (50 tokens):
Recent commits:
- abc123: feat: add auth
- def456: fix: login bug
- ghi789: docs: update readme
```

### Compress Conversation History

```markdown
BEFORE: 20 message turns
AFTER:
## Session Summary
- User requested auth feature
- Created AuthProvider component
- Tests passing
- Awaiting review
```

### Compress Retrieved Documents

```markdown
BEFORE: Full 5000-line file
AFTER:
## File: auth.ts (summary)
- Exports: AuthProvider, useAuth, AuthContext
- Key functions: login(), logout(), refresh()
- Depends on: jwt-decode, axios
```

## MCP Integration

Use mcp-memory to:

- Store compressed summaries
- Retrieve distilled context
- Track what's been compressed

## Metrics

Track compression effectiveness:

- Tokens before/after
- Information preservation score
- Retrieval accuracy on compressed data
