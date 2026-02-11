---
name: self-reflection
description: Analyze past actions/outputs to improve future attempts via Reflexion pattern
keywords: [reflection, reflexion, metacognition, learning, improvement, retry]
---

# Self-Reflection Skill

> **Purpose**: Learn from failures and improve through structured reflection

## The Reflexion Pattern

```
┌──────────────────────────────────────────────────────┐
│                  REFLEXION LOOP                       │
├──────────────────────────────────────────────────────┤
│  1. ATTEMPT → Try the task                           │
│  2. OBSERVE → Capture outcome + feedback             │
│  3. REFLECT → Analyze what went wrong/right          │
│  4. STORE   → Save lesson to memory                  │
│  5. RETRY   → Use lessons in next attempt            │
└──────────────────────────────────────────────────────┘
```

## When to Use

- After task failure or suboptimal result
- Before retrying a failed operation
- At end of complex tasks to capture lessons
- When encountering novel situations

## Reflection Template

After any significant action, generate a reflection:

```markdown
## Reflection on: [Task Name]

### What Happened
- Attempted: [action taken]
- Result: [success/failure/partial]
- Feedback: [error messages, test results, etc.]

### Analysis
- Root cause: [why did this happen]
- What worked: [what went right]
- What failed: [what went wrong]

### Lessons Learned
- [Concrete takeaway 1]
- [Concrete takeaway 2]

### For Next Attempt
- [Specific adjustment to make]
```

## Integration with Memory

Store reflections in mcp-memory:

```
Entity: ReflectionLog
Observations:
- "Git push failed: forgot to stage files - always use git status first"
- "Test failed due to async timing - use waitFor instead of fixed delays"
- "Build error from missing dep - check package.json before importing"
```

## Metacognitive Checks

Before major decisions, ask:

| Check | Question |
|-------|----------|
| **Confidence** | How sure am I this will work? |
| **Knowledge** | Do I have enough context? |
| **Alternatives** | What other approaches exist? |
| **Risks** | What could go wrong? |

## System 2 Thinking

For complex problems, slow down:

```
1. Pause before acting
2. Explicitly state the goal
3. List possible approaches
4. Evaluate each approach
5. Choose with reasoning
6. Execute deliberately
7. Reflect on outcome
```

## Failure Recovery with Reflection

When a task fails 2+ times:

```
1. STOP - Don't retry immediately
2. REFLECT - What pattern am I repeating?
3. SEARCH - Look for similar past failures
4. ADJUST - Change approach fundamentally
5. RETRY - With new strategy
```

## Lessons Storage Location

Store lessons in artifacts for persistence:

```
/atn/.agent/learning/
├── reflections/           # Individual task reflections
│   └── YYYY-MM-DD_<hash>.md
├── patterns.md            # Recurring issue patterns
├── proposed_changes.md    # Pending improvements
└── changelog.md           # Applied changes
```

---

## Concrete Output Format

When generating reflection, produce structured output:

```yaml
reflection:
  task: "[Task Name]"
  date: "[ISO8601]"
  outcome: success|partial|failure

  issues:
    - description: "[What went wrong]"
      resolution: "[How it was fixed]"
      recurring: true|false

  improvements:
    - title: "[Improvement name]"
      type: rule|workflow|skill|knowledge
      priority: high|medium|low
      risk: low|medium|high
      rationale: "[Why this improvement]"
```

---

## Improvement Evaluation Matrix

Before proposing any change, evaluate:

| Question | Weight |
|----------|--------|
| Will this prevent the issue? | High |
| Could this cause new issues? | High |
| Is this the simplest solution? | Medium |
| Does similar already exist? | Medium |

### Decision Criteria

| Score | Action |
|-------|--------|
| All High positive | Auto-apply if low risk |
| Mixed | Add to proposed_changes.md |
| Any High negative | Do not implement |

---

## Integration with R95

This skill is invoked by R95 (Mandatory Post-Task Reflection).

After generating reflection:

1. Check for recurring patterns
2. Evaluate improvement options
3. Update learning files
4. Proceed with `notify_user`
