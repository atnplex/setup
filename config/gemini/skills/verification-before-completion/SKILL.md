---
name: verification-before-completion
description: "REQUIRED before claiming work complete. Run verification commands and confirm output before making success claims. Evidence before assertions."
keywords: [verify, test, complete, done, check, evidence, finish]
disable-model-invocation: true
---

# Verification Before Completion

## When to Use

> [!IMPORTANT]
> Use BEFORE any claim of completion AND during planning/execution phases.

### During Planning

- Verify environment (OS, shell, available commands)
- Check paths exist before operating on them
- Confirm dependencies are available

### During Execution

- Make commands idempotent (safe to run multiple times)
- Implement error handling with fallbacks
- Verify each step before proceeding

### Before Completion

- Run all verification commands fresh
- Evidence before claims, always

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

Before claiming ANY status:

1. **IDENTIFY**: What command proves this claim?
2. **RUN**: Execute the FULL command (fresh, complete)
3. **READ**: Full output, check exit code, count failures
4. **VERIFY**: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. **ONLY THEN**: Make the claim

Skip any step = lying, not verifying

## Verification Matrix

| Claim | Requires | NOT Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check |
| Build succeeds | Build command: exit 0 | Linter passing |
| Bug fixed | Test original symptom: passes | Code changed |
| Requirements met | Line-by-line checklist | Tests passing |

## Red Flags - STOP

These words indicate unverified claims:

- "should"
- "probably"
- "seems to"
- "I believe"
- "looks like"

## Correct Patterns

### Tests

```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

### Build

```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter ≠ compiler)
```

### Requirements

```
✅ Re-read plan → Create checklist → Verify each → Report
❌ "Tests pass, phase complete"
```

## When to Apply

**ALWAYS before:**

- Any variation of success/completion claims
- Any expression of satisfaction
- Committing or PR creation
- Moving to next task
- Delegating to agents

## Excuse Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Partial check is enough" | Partial proves nothing |

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.

## Definition of Done Integration

Before marking ANY task complete, verify against:

> See: [R51: Definition of Done](/atn/.gemini/rules/operational/definition-of-done.md)

### Staff Engineer Test

Ask yourself:

> "Would a staff engineer approve this diff and the verification story?"

If uncertain → not done.

### Verification Story Template

```markdown
## Verification

### What Changed
- [Files/components modified]

### How We Know It Works
- Ran: `[command]`
- Output: `[result]`
- Tests: [X passed, 0 failed]
```
