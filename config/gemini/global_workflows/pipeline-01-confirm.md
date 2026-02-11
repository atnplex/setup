---
name: Confirmation
description: User confirms approach and provides additional input
model: user-interaction
---

# Phase 1: User Confirmation

## Purpose

Ensure user understands and approves the approach before execution.

---

## Input

From triage (Phase 0):

- Classification results
- Detected domain/complexity
- Proposed personas and models
- Skill recommendations

---

## Confirmation Dialog

### Present Summary

```markdown
## Triage Summary

**Your Request**: [brief summary]

**Detected**:
- Domain: [frontend/backend/etc.]
- Complexity: [simple/standard/complex]
- Risk: [low/medium/high]

**Proposed Approach**:
- Persona: [X]
- Model: [X]
- Estimated time: [X min]

**Skills to Load**: [list]

### Your Selected Option: [A/B/C]

Do you want to proceed? Any adjustments?
```

---

## User Inputs to Capture

1. **Confirmation**: Yes/No/Modify
2. **Scope adjustments**: Add/remove requirements
3. **Priority signals**: Speed vs thoroughness
4. **Constraints**: Time limits, specific approaches

---

## Decision Tree

```
User confirms?
├── Yes → Proceed to Phase 2 (Decomposition) or Phase 3 (Execute)
├── Modify → Update parameters, re-confirm
└── No → Return to triage with feedback
```

---

## Skip Conditions

May skip directly to Phase 3 (Execute) if:

- Complexity = simple
- User selected Quick Path (A)
- No decomposition needed
- Single persona sufficient

Otherwise → proceed to Phase 2 (Decomposition)

---

## Output

```yaml
confirmation_result:
  user_approved: true|false
  modifications: []
  final_approach:
    path: quick|detailed|custom
    persona: X
    model: X
    skip_decomposition: true|false
  proceed_to: phase_2|phase_3
```
