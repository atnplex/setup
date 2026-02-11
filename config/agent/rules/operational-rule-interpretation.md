# R65: Rule Interpretation Guidelines

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: MEDIUM - affects rule creation quality
> **Updated**: 2026-02-03

---

## Core Principle

When the user says "add a rule" or "add to rule", interpret intelligently rather than copying verbatim.

---

## Interpretation Guidelines

### 1. Specificity Assessment

Determine if the user wants:

| User Intent | Indicators | Action |
| ----------- | ---------- | ------ |
| **Specific** | Exact wording matters, legal/compliance | Use near-verbatim language |
| **General** | Describes a pattern, anecdote-based | Extract the principle, not the example |

### 2. Segmentation Decision

| Situation | Action |
| --------- | ------ |
| Multiple distinct concepts | Create separate rules (segmented) |
| Tightly related concepts | Single rule with subsections |
| Pattern with examples | One rule with example applications |

**Default**: Prefer segmented rules over monolithic ones.

### 3. Anecdote Processing

When user provides an anecdote:

1. **Extract the pattern** - What principle does the story illustrate?
2. **Generalize** - Make it applicable beyond the specific case
3. **Link related rules** - Connect to existing rules that apply
4. **Apply frequently** - Use as a pattern template

### 4. Rule Creation Checklist

- [ ] Does it duplicate an existing rule? → Merge or reference
- [ ] Is it truly global or context-specific? → Scope appropriately
- [ ] Can it be tested/verified? → Add verification criteria
- [ ] Does it have exceptions? → Document them

---

## Examples

### User Says

> "Add a rule that we should always check disk space before running large operations"

### Bad Interpretation ❌

Creates rule: "Always check disk space before running large operations."

### Good Interpretation ✅

Creates rule with:

- Pre-flight check pattern (disk, memory, network)
- Threshold definitions
- Specific commands to verify
- Integration with existing verification rules

---

## Cross-References

- [R52: Knowledge Persistence](/atn/.gemini/rules/operational/knowledge-persistence.md)
- [R50: Coding Principles](/atn/.gemini/rules/operational/coding-principles.md)
