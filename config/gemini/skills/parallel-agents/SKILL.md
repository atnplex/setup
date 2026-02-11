---
name: parallel-agents
description: Dispatch multiple agents to work on independent tasks concurrently
keywords: [parallel, subagent, concurrent, dispatch, independent, multi-task]
---

# Dispatching Parallel Agents

> **Purpose**: Parallelize independent tasks across multiple agents for faster completion

## When to Use

- 2+ independent tasks that can work without shared state
- Multiple failures in different subsystems
- Tasks with no sequential dependencies

## When NOT to Use

- Related failures (fixing one might fix others)
- Need full system context first
- Agents would interfere (editing same files)
- Exploratory debugging where scope is unknown

## The Pattern

### 1. Identify Independent Domains

Group tasks by what they affect:

```
Task A: Component X changes
Task B: Component Y changes
Task C: Component Z changes
```

Each domain should have:

- Separate files/subsystems
- No shared state
- Independent success criteria

### 2. Dispatch Agents

For each domain, spawn an agent with:

```yaml
agent_dispatch:
  - domain: "Component X"
    task: "Fix issue in component X"
    context: "Relevant files: src/x/*.ts"
    return: "Summary of changes made"

  - domain: "Component Y"
    task: "Fix issue in component Y"
    context: "Relevant files: src/y/*.ts"
    return: "Summary of changes made"
```

### 3. Use Worktrees for Isolation

Each agent should work in its own worktree:

```bash
# Create isolated worktrees
git worktree add ../worktrees/fix-x feat/fix-x
git worktree add ../worktrees/fix-y feat/fix-y
```

This prevents conflicts and allows parallel git operations.

### 4. Collect and Integrate

After agents complete:

1. Review each summary
2. Check for conflicts
3. Run full test suite
4. Merge changes

## Integration with Pipeline

Use in `03-execute.md` when task decomposition identifies parallel segments:

```yaml
parallel_segments:
  - segment_id: 1
    type: independent
    agent: flash  # Fast model for simple tasks
    worktree: fix-component-a

  - segment_id: 2
    type: independent
    agent: sonnet  # Standard model
    worktree: fix-component-b
```

## Benefits

| Benefit | Impact |
|---------|--------|
| **Speed** | N problems in time of 1 |
| **Focus** | Narrow scope per agent |
| **Independence** | No interference |
| **Parallelization** | Concurrent execution |

## Real Example

**Scenario**: 6 test failures across 3 files

**Analysis**: Independent domains (abort, batch, race conditions)

**Dispatch**:

```
Agent 1 → agent-tool-abort.test.ts
Agent 2 → batch-completion-behavior.test.ts
Agent 3 → tool-approval-race-conditions.test.ts
```

**Result**: All fixes independent, no conflicts, full suite green

## Verification After Completion

1. **Review summaries** - Understand each change
2. **Check conflicts** - Did agents edit same code?
3. **Run full suite** - Verify integration
4. **Spot check** - Agents can make systematic errors
