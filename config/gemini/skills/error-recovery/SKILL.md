---
name: error-recovery
description: Handle failures gracefully with fallbacks and escalation
keywords: [error, recovery, fallback, retry, graceful, degradation]
---

# Error Recovery Skill

> **Purpose**: Handle agent failures gracefully without losing progress

## Core Principles

1. **Preserve context** - Never lose accumulated understanding
2. **Incremental checkpoints** - Save state frequently
3. **Graceful degradation** - Partial function > complete failure
4. **Clear escalation** - Know when to ask for help

## Common Failure Patterns

### 1. Context Exhaustion

**Symptom**: Agent forgets earlier context, enters loops

**Recovery**:

```
1. Checkpoint current state
2. Summarize key facts
3. Clear context window
4. Resume with summary + checkpoint
```

### 2. Tool Failure

**Symptom**: Command fails, API error, timeout

**Recovery**:

```bash
# Retry with backoff
command || sleep 2 && command || sleep 5 && command

# Alternative tool
primary_tool 2>/dev/null || fallback_tool

# Skip if optional
optional_command || true
```

### 3. Permission/Dependency Issues

**Symptom**: Permission denied, command not found

**Recovery**:

```bash
# Check first, then act
command -v required_tool >/dev/null 2>&1 || {
    echo "Need to install required_tool"
    # Try to install or escalate
}

# Permission fallback
sudo command 2>/dev/null || echo "Need elevated permissions"
```

### 4. Network/API Failures

**Symptom**: Timeout, rate limit, connection refused

**Recovery**:

```bash
# Retry with exponential backoff
for i in 1 2 4 8 16; do
    command && break
    sleep $i
done

# Cache responses for retry
curl -o cache.json "$URL" && cat cache.json
```

## Stop-the-Line Rule

> [!CAUTION]
> If anything unexpected happens, STOP adding features immediately.

When you encounter:

- Test failures
- Build errors
- Behavior regressions
- Unexpected exceptions

**Do NOT continue.** Instead:

1. Preserve evidence (error output, repro steps)
2. Return to diagnosis
3. Re-plan before proceeding

## Triage Checklist

Use in order when debugging:

| Step | Action |
|------|--------|
| 1. **Reproduce** | Get reliable repro (test, script, or minimal steps) |
| 2. **Localize** | Which layer? (UI, API, DB, network, build tooling) |
| 3. **Reduce** | Minimal failing case (smaller input, fewer steps) |
| 4. **Fix** | Root cause, not symptoms |
| 5. **Guard** | Add regression coverage (test or invariant checks) |
| 6. **Verify** | End-to-end for original report |

## Graceful Degradation Patterns

| Full Function | Degraded Mode | Action |
|---------------|---------------|--------|
| All tests pass | Some tests fail | Continue, note failures |
| Full deployment | Partial deploy | Deploy what works |
| Real-time data | Cached data | Use cache, warn user |
| Primary tool | Fallback tool | Use alternative |

## Escalation Protocol

When to escalate to user:

1. **3 consecutive failures** of same operation
2. **Destructive operations** without clear rollback
3. **Security-sensitive** decisions
4. **Ambiguous requirements** that affect approach
5. **Resource constraints** (out of disk, memory)

## State Preservation

Always preserve:

```json
{
  "last_successful_step": "step_name",
  "failed_step": "step_name",
  "error": "error message",
  "context_snapshot": {},
  "recovery_options": ["option1", "option2"]
}
```

## Multi-Agent Error Handling

When coordinating agents:

```
1. Isolate failure to single agent
2. Other agents continue working
3. Failed agent reports status
4. Orchestrator decides: retry/skip/escalate
```

## Integration with Pipeline

In `03-execute.md`:

```yaml
error_handling:
  retry_count: 3
  backoff: exponential
  fallback: graceful_degradation
  escalate_after: 3_failures
```
