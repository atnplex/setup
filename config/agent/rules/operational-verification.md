# Verification and Completion Rules

> Consolidated from R51, R62, R84. Covers anti-hallucination, pre-action verification, completion claims, and definition of done.

## Iron Laws

```text
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
NO STATE CHANGES WITHOUT STATING EXPECTED OUTCOME
NO FACTS WITHOUT SOURCES
```

## Anti-Hallucination Guardrails

### Pre-Action Verification

Before any command that **modifies state** (deploy, delete, config change):

1. **State expected outcome** — "I expect this will..."
2. **Use dry-run first** — prefer `--dry-run`, `--check`, `-n`, `--diff` flags where available
3. **Show diff before apply** — what will change vs current state

### Source-Citing Requirement

When stating a "fact" (IP address, port, config value, feature capability):

- Cite the source: file path, command output, URL, or docs
- If from memory → verify by reading the file/running the command
- If no source available → explicitly say "I believe but haven't verified"

### Confidence Scoring

Rate confidence on non-trivial claims (1-10):

| Score | Meaning | Action |
| ----- | ------- | ------ |
| 8-10 | High confidence, verified | Proceed |
| 5-7 | Moderate, some uncertainty | Verify key assumptions first |
| 1-4 | Low, guessing | STOP — research before acting |

## Before Any Change

1. **Query current state** — document what exists now
2. **Present comparison** — current vs proposed (table format)
3. **Document reversibility** — rollback command/steps
4. **If backup takes >5-10 min** — get explicit user confirmation first

### Change Documentation Format

```markdown
## Proposed Change: [Description]
### Current State
[exact current config]
### Proposed State
[exact new config]
### Reversibility
- Fully reversible: `[rollback command]`
```

## Before Claiming Done (The Gate Function)

1. **IDENTIFY**: What command proves this claim?
2. **RUN**: Execute the FULL command (fresh, complete)
3. **READ**: Full output, check exit code, count failures
4. **VERIFY**: Does output confirm the claim?
5. **ONLY THEN**: Make the claim

## Verification Matrix

| Claim | Requires | NOT Sufficient |
| ----- | -------- | -------------- |
| Tests pass | Test output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check |
| Build succeeds | Build command: exit 0 | Linter passing |
| Bug fixed | Test original symptom | Code changed |
| Requirements met | Line-by-line checklist | Tests passing |
| Container deployed | Verify correct image + running | `docker ps` alone |

## Definition of Done Checklist

A task is **done** when:

- [ ] Behavior matches acceptance criteria
- [ ] Tests/lint/typecheck/build pass (or documented reason)
- [ ] Risky changes have rollback/flag strategy
- [ ] Code follows existing conventions
- [ ] Verification story exists

### Verification Story Template

```markdown
## Verification
### What Changed
- [Files/components modified]
### How We Know It Works
- Ran: `[command]` → Output: `[result]`
- Tests: [X passed, 0 failed]
```

### Staff Engineer Test

> "Would a staff engineer approve this diff and the verification story?"

If uncertain → not done.

## Red Flags — STOP

These words indicate unverified claims:

- "should", "probably", "seems to", "I believe", "looks like"

## Rollback Strategy

| Risk Level | Required Strategy |
| ---------- | ----------------- |
| Low | Standard git revert |
| Medium | Feature flag (disabled by default) |
| High | Feature flag + config gating + isolated commits |
