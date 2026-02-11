# Agent Orchestration Awareness

> Agents must be self-aware coordinators. The thinking model NEVER downgrades — it rotates accounts to extend quota. Delegation to cheaper models requires full verification.

## Hierarchy of Authority

```text
THINKING MODEL = COORDINATOR + FINAL VERIFIER
All delegated work is PROVISIONAL until the thinking model confirms it.
```

## Decision Flowchart

```
Quota running low on current account?
├─ YES → Advise: "/pause, rotate to next account, paste resume prompt"
│        (SAME thinking model, different account)
└─ NO  → Keep working

Can background work be offloaded to Gemini Pro/Flash?
├─ YES, AND headless AG is running → Auto-dispatch via AG Manager API
├─ YES, BUT manual only → Generate dispatch packets with audit requirements
└─ NO (needs reasoning) → Stay on thinking model
```

## Account Rotation Protocol

When the thinking model detects a good checkpoint (phase complete, quota pressure, long session):

**Step 1**: Get current time via `mcp_mcp-time_get_current_time` with timezone `America/Los_Angeles`

**Step 2**: Output the checkpoint block with all context:

````markdown
## 🔄 Account Rotation Checkpoint

**📅 Current Time**: [LA time, e.g. "Tuesday, Feb 10, 2026 — 12:46 PM PST"]

### 📊 Session Stats
- **Model**: [current model name]
- **Session duration**: [approximate, based on first interaction time]
- **Phases completed this session**: [list]
- **Tool calls (est.)**: [rough count]

### 🔑 Model Quota Reference (Google Pro Tier)

| Model | Tier | Thinking | Est. Limit (Pro) | Resets |
| ----- | ---- | -------- | ---------------- | ------ |
| Opus 4.6 | Highest | ✅ | ~50 msgs/5hr | Rolling window |
| Opus 4.5 | High | ✅ Optional | ~50 msgs/5hr | Rolling window |
| Sonnet 4.5 | Mid-High | ✅ Optional | ~100 msgs/5hr | Rolling window |
| Gemini 3 Pro High | High | ✅ Optional | 1000 req/day | Midnight PT |
| Gemini 3 Pro Low | Mid | ❌ | 1000 req/day | Midnight PT |
| Gemini 3 Flash | Low | ❌ | 1500 req/day | Midnight PT |
| GPT OSS 120b | Medium | ❌ | Varies | Varies |

> ⏰ **Time until daily refresh**: [calculate hours until midnight PT from current LA time]
> 💡 **Tip**: If close to midnight PT, you may want to wait for refresh rather than rotate.

> [!CAUTION]
> **Agent must NEVER guess which model it is running on.**
> Ask the user, read from AG Manager API, or check `scratch/account_tracker.md`.
> Update `account_tracker.md` at every checkpoint.

### 🔄 To Continue
1. I've saved everything to `session_log.md` and `checkpoint.json`
2. Rotate to your next Opus/Thinking account
3. Paste this into the new conversation:

```
/resume
```

### 📋 What's Next
- [Next phase/task from the plan]
````

> [!NOTE]
> Quota numbers are approximate and may vary by plan. Update this table if limits change.
> The agent should always use `mcp_mcp-time_get_current_time` for accurate LA time — never guess.

> [!IMPORTANT]
> **NEVER advise downgrading** from thinking model to standard model for planning or architecture work.
> Account rotation (same tier, different account) is ALWAYS preferred over model downgrade.

## Delegation Rules

When the thinking model dispatches work to subagents (standard or cheaper models):

### Before Delegation

1. **Snapshot current state** — record all files/settings that will be touched
2. **Write explicit instructions** — specific, self-contained, no ambiguity
3. **Define success criteria** — measurable outcomes
4. **Set audit requirements** — what the subagent must log

### Subagent Requirements

Every subagent dispatch packet MUST include:

```markdown
## Audit Trail Requirements
Before making ANY changes:
1. Save current state of all files you will modify to scratch/audit/[task-name]/before/
2. After changes, save new state to scratch/audit/[task-name]/after/
3. Write a diff summary to scratch/audit/[task-name]/changes.md
4. DO NOT delete or overwrite the "before" snapshots
```

### After Delegation (Thinking Model Verifies)

1. **Read the audit trail** — compare before/after snapshots
2. **Verify correctness** — do changes match the intent?
3. **Check for regressions** — did the subagent break anything?
4. **Accept, request fixes, or rollback** — thinking model has final say
5. **If rollback needed** — restore from before/ snapshots

## Dispatch Packet Format

````markdown
## 🚀 Subagent Task: [Title]

**Model**: [Sonnet/Gemini Pro/Flash]
**Audit**: Required — snapshot before/after all changes

```
/resume

Context: [brief context from session_log]
Task: [specific, self-contained task]
Files to modify: [list]

IMPORTANT AUDIT REQUIREMENTS:
- Before ANY changes, copy current state of modified files to scratch/audit/[task-name]/before/
- After changes, copy final state to scratch/audit/[task-name]/after/
- Write changes.md summarizing what changed and why
- Update session_log.md when done

Success criteria: [measurable]
When done: Say "Subagent complete — audit trail at scratch/audit/[task-name]/"
```
````

## Progress Tracking

For multi-subagent dispatches, create `scratch/dispatch_tracker.md`:

```markdown
## Dispatch: [Task Name] — [Date]
- [ ] Subagent 1/N: [Title] — status
- [x] Subagent 2/N: [Title] — COMPLETE, audit at scratch/audit/[name]/

Reconvene when: all N complete
Reconvene on: Thinking model (same or rotated account)
Verification: Thinking model reviews all audit trails before accepting
```

## Progressive Automation Levels

| Level | How It Works | Status |
| ----- | ------------ | ------ |
| **L1: Manual** | Agent generates prompts, user copy-pastes, thinking model verifies | ✅ NOW |
| **L2: Semi-auto** | AG Manager dispatches to Gemini Pro, thinking model reviews | Phase 3 |
| **L3: Headless** | Background agents auto-dispatch + auto-verify, user notified on completion | Phase 6 |

## Priority: Get to L2 ASAP

L2 (AG Manager auto-dispatch) is the efficiency breakthrough:

- Gemini Pro accounts (15+) handle bulk work automatically
- Thinking model only reviews results, not execute routine tasks
- Each Gemini Pro task costs ~0 against Claude/Opus quota
