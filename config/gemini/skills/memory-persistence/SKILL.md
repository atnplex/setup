---
name: memory-persistence
description: Maintain context across sessions with STM/LTM separation
keywords: [memory, persistence, context, session, checkpoint, state]
---

# Memory Persistence Skill

> **Purpose**: Maintain context and state across agent sessions

## Memory Architecture

```
┌─────────────────────────────────────────────────────┐
│                 MEMORY LAYERS                        │
├─────────────────────────────────────────────────────┤
│  STM (Short-Term)  │  LTM (Long-Term)               │
│  - Context window  │  - External storage            │
│  - mcp-memory      │  - Filesystem artifacts        │
│  - Conversation    │  - Vector DB (optional)        │
│  - Limited tokens  │  - Unlimited capacity          │
└─────────────────────────────────────────────────────┘
```

## Strategies

### 1. Checkpoint State at Decision Points

Save state when making significant decisions:

```bash
# Checkpoint to artifacts directory
CHECKPOINT_FILE="$ARTIFACTS_DIR/checkpoint_$(date +%s).json"
```

```json
{
  "timestamp": "2026-02-03T00:25:00Z",
  "task": "current task name",
  "progress": ["step 1 done", "step 2 in progress"],
  "decisions": ["chose approach A because..."],
  "context": {"key": "value"}
}
```

### 2. Summarize on Context Overflow

When context grows large:

```
1. Extract key facts/decisions
2. Summarize conversation history
3. Write detailed log to file
4. Continue with compressed context
```

### 3. Agentic Note-Taking

Proactively write progress to files:

```markdown
# Session Notes - 2026-02-03

## Progress
- Completed X
- Working on Y

## Decisions
- Chose A over B because...

## Blockers
- Waiting on user approval for Z
```

### 4. Entity Memory (mcp-memory)

Use graph-based memory for entities:

```
Entity: ProjectName
Observations:
- "Uses React 18 with TypeScript"
- "Deployed on Vercel"
- "Has 3 active branches"
```

## When to Checkpoint

| Event | Action |
|-------|--------|
| Task start | Create initial checkpoint |
| Major decision | Record decision + rationale |
| Error recovery | Snapshot current state |
| Before research | Note context before context switch |
| Task complete | Final summary checkpoint |

## Integration with Artifacts

Use the artifacts directory for persistence:

```
brain/<conversation-id>/
├── task.md           # Active task checklist
├── checkpoint.json   # State snapshot
├── decisions.md      # Decision log
└── walkthrough.md    # Final summary
```

## Session Resume Pattern

When resuming a session:

1. Check for checkpoint files
2. Load last state
3. Review task.md status
4. Continue from last checkpoint

## Infrastructure Notes

| Resource | Availability | Usage |
|----------|--------------|-------|
| Google Pro | 15+ accounts | Heavy Gemini usage OK |
| Perplexity Pro | 5+ accounts | Parallel research OK |
| OneDrive | 2x 1TB | Cloud backup of artifacts |
| mcp-memory | Always | Session entities |
