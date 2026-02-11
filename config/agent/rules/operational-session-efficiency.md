# Session Efficiency and Model Awareness

> Maximize output per session. Thinking model stays as coordinator — rotate accounts to extend quota, never downgrade.

## Session Monitoring

Track these signals throughout every session:

| Signal | Indicator | Action |
| ------ | --------- | ------ |
| **Long session** | 15+ exchanges or 30+ tool calls | Advise account rotation checkpoint |
| **Context degradation** | Repeating mistakes, forgetting earlier context | Advise `/pause` → `/resume` (fresh context) |
| **Bulk work ahead** | 5+ independent mechanical tasks | Dispatch to Gemini Pro via AG Manager (or manual packets) |
| **Complex decision ahead** | Architecture, security, multi-system coordination | Stay on thinking model, don't delegate |

## Account Rotation Triggers

Advise rotation (NOT downgrade) when:

- Session has been running 20+ minutes with heavy tool usage
- About to start a new major phase
- User explicitly mentions quota concern
- Natural checkpoint reached (phase complete, plan approved)

## Model Usage Rules

| Work Type | Model | Account |
| --------- | ----- | ------- |
| Planning, architecture, security | **Thinking model (Opus 4.5/4.6)** | Rotate across accounts |
| Reviewing subagent output | **Same thinking model** | Current or rotated |
| Mechanical implementation (pre-approved plan) | Gemini Pro via AG Manager | Auto-rotated |
| Bulk parsing, summarization | Gemini Flash via AG Manager | Auto-rotated |
| Never delegate | Complex debugging, design decisions | N/A |

> [!CAUTION]
> **NEVER** suggest using a less capable model for planning or coordination.
> The risk of mistakes and rework FAR exceeds any token savings.

## Anti-Waste Patterns

- Batch related changes into single tool calls
- Don't re-read files already in context
- Don't regenerate entire files when small edits suffice
- Use `scratch/` files to avoid re-researching across sessions
- Prefer account rotation over starting simpler work just to "save tokens"
