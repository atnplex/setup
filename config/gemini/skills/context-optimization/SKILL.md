---
name: context-optimization
description: Optimize context window usage for maximum effectiveness
keywords: [context, optimize, attention, token, efficiency, focus]
---

# Context Optimization Skill

> **Purpose**: Maximize context effectiveness within attention limits

## Core Principle

Context windows are constrained not by raw tokens but by **attention mechanics**.
As context grows, models exhibit:

- "Lost in the middle" phenomenon
- U-shaped attention curves (edges get more attention)
- Attention scarcity on important details

## When to Use

- Starting complex multi-file tasks
- Preparing context for difficult reasoning
- Optimizing for accuracy on critical work
- Reducing hallucination risk

## Optimization Strategies

### 1. Position Matters

Place critical information at:

- **Beginning**: Task definition, constraints
- **End**: Current question, action needed
- **Avoid middle** for crucial details

```
[System prompt + key constraints]
[Lower priority context...]
[Current task + question]  ← Most attention
```

### 2. Signal-to-Noise Ratio

Maximize high-signal tokens:

```
HIGH SIGNAL:
- Exact error messages
- Relevant code snippets
- Specific requirements

LOW SIGNAL (minimize):
- Boilerplate explanations
- Repeated information
- Verbose tool outputs
```

### 3. Just-In-Time Loading

Load context only when needed:

```
DON'T: Load all 50 files upfront
DO: Load relevant files as task progresses
```

### 4. Context Partitioning

Split large tasks into focused context windows:

```
Partition 1: Backend API changes
Partition 2: Frontend component updates
Partition 3: Test implementation
```

## Anti-Patterns

### Lost in the Middle

```
❌ [Important A] [Tons of filler] [Important B]
   └── B may be forgotten

✅ [Important A] [Important B] [Filler if needed]
```

### Context Bloat

```
❌ Load entire codebase into context
✅ Load only files being modified + immediate deps
```

### Repetition Tax

```
❌ Repeat instructions in every message
✅ Reference once, rely on system prompt
```

## Implementation Checklist

- [ ] Place task definition at context start
- [ ] Place current question/action at end
- [ ] Remove superseded information
- [ ] Compress verbose tool outputs
- [ ] Load files just-in-time
- [ ] Partition large tasks

## Metrics

Monitor context health:

- Total tokens in use vs limit
- Percentage of high-signal content
- Task success rate vs context size
