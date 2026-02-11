# R54: Redundancy Requirement

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: HIGH - prevents irreversible mistakes
> **Updated**: 2026-02-03

---

## Core Principle

**All changes should be reversible when possible.** Maintain backups before destructive operations, but balance safety with efficiency.

---

## Reversibility Tiers

### Tier 1: Instantly Reversible

- Configuration changes with clear rollback commands
- Git commits (can revert)
- File edits (with version control)

**Action**: Proceed with documented rollback command.

### Tier 2: Reversible with Backup

- Database migrations
- File system restructuring
- System configuration changes

**Action**: Create backup first, then proceed.

### Tier 3: Difficult/Impossible to Reverse

- Deleting production data
- Removing cloud resources
- Changing external service configurations

**Action**: Require explicit user confirmation with warning.

---

## Time-Based Confirmation Threshold

### Automatic Proceed (<5 minutes)

If backup/preparatory task takes less than 5 minutes:

- Create the backup automatically
- Proceed with the change
- Document the backup location

### Confirmation Required (5-10 minutes)

If backup/preparatory task takes 5-10 minutes:

- Inform user of estimated time
- Ask if they want to proceed or skip
- Honor their choice

### Mandatory Confirmation (>10 minutes)

If backup/preparatory task takes more than 10 minutes:

- **STOP** - Do not proceed
- Present time estimate
- Require explicit confirmation phrase: "You may proceed with [specific task]"

---

## Backup Standards

### Where to Store Backups

| Type | Location | Retention |
| ---- | -------- | --------- |
| Config files | `/tmp/backups/$(date +%Y%m%d)/` | Until confirmed working |
| Database | Designated backup location | Per retention policy |
| Code | Git (committed before change) | Permanent |

### Backup Naming Convention

```
<original_name>.<YYYYMMDD_HHMMSS>.bak
```

Example: `sudoers.20260203_210812.bak`

---

## Rollback Documentation

Every change must document its rollback:

```bash
# Rollback command for [change description]
<exact command to reverse the change>
```

Store rollback commands in:

- The same commit message
- An artifact comment
- `/atn/.gemini/scratch/rollback_log.md` for major changes

---

## Cross-References

- [R62: Change Verification Before Updates](/atn/.gemini/rules/operational/change-verification.md)
- [R47: Never Dismiss, Bypass, or Ignore](/atn/.gemini/rules/operational/never_dismiss.md)
