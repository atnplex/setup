# Antigravity Global Rules

> **Version**: 3.0.0
> **Updated**: 2026-02-05
> **Namespace**: `/atn`

---

## R0: Precedence

**Global Rules prevail.** This file is the entry point for all Antigravity operations.

| Path | Purpose |
|------|---------|
| `/atn/.gemini/GEMINI.md` | This file (global rules) |
| `/atn/.agent/rules/` | Detailed rule modules |
| `/atn/.gemini/antigravity/global_workflows/` | Global workflows |
| `/atn/.gemini/antigravity/skills/` | Skills |
| `/atn/baseline/` | Namespace baseline |

---

## R00: Mandatory First Action

> [!CAUTION]
> ABSOLUTE FIRST STEP FOR EVERY NEW USER REQUEST

1. **Slash command detected** → Execute that workflow directly
2. **Continuing existing thread** → Resume with context (no re-triage)
3. **Trivial question** → Answer directly
4. **All other new requests** → Execute `/triage` workflow

Pipeline: `Triage (00) → Confirmation (01) → Decomposition (02) → Execute (03) → PR/Deliver (04-05)`

---

## Core Principles

1. **Env-First**: Detect system/target before acting
2. **No Hardcoding**: Use variables and configs (`$NAMESPACE=atn`)
3. **Canonical**: UTC (ISO8601Z), smallest units (bytes, ms)
4. **Python-Spine**: Complex logic in Python
5. **Stability**: Enforce stable workspace modes

---

## Infrastructure Workflows

> [!IMPORTANT]
> For infrastructure work, **ALWAYS run `/inventory` first** to discover all available resources.

| Workflow | Purpose |
|----------|---------|
| `/inventory` | Discover ALL Tailscale machines and services (running AND stopped) |
| `/deploy-service` | Deploy Docker services to VPS1, VPS2, or Unraid |
| `/health-check` | Check service health endpoints |

**Compute Priority**: VPS1/VPS2 → Windows → Unraid (preserve Unraid for media)

---

## Rule Modules

Follow all rules in these directories:

### Format Rules

@/atn/.agent/rules/format-*.md

### Security Rules

@/atn/.agent/rules/security-*.md

### Operational Rules

@/atn/.agent/rules/operational-*.md

### Baseline Rules

@/atn/baseline/rules/*.md

---

## Quick Reference

### Formatting Standards

| Type | Standard |
|------|----------|
| Markdown | Code blocks with language, single `#` per doc |
| JSON | 2-space indent, snake_case, `jq .` validation |
| Shell | `set -euo pipefail`, shellcheck, shfmt |
| Python | PEP 8, type hints, `pathlib.Path`, Ruff/Black |
| YAML | 2-space, snake_case, yamllint |

### Git Workflow

- Branch naming: `<type>/<slug>` (feat/, fix/, refactor/)
- Worktree isolation: `$ROOT/worktrees/<type>/<slug>`
- Never merge manually - only via `gh pr merge`
- All CI checks must pass before merge

### Model Tiering

| Phase | Model |
|-------|-------|
| Triage/Decomposition | Opus Thinking |
| Simple Execution | Gemini Flash |
| Standard Execution | Sonnet 4.5 |
| Complex/Security | Opus 4.5 |

---

## Guardrails

> [!WARNING]
> Non-negotiable rules.

1. No direct pushes to main/master
2. No bypassing CI checks
3. No skipping security review for auth/permissions code
4. No dismissing review comments without addressing

---

## Directory Layout

```
/atn/
├── .gemini/
│   ├── GEMINI.md                # This file (global rules entry point)
│   └── antigravity/
│       ├── global_workflows/    # Workflows (invoked via /)
│       ├── skills/              # Skills
│       ├── personas/            # Persona definitions
│       └── mcp_config.json      # MCP configuration
└── .agent/
    ├── rules/                   # All rule modules (flat structure)
    │   ├── format-*.md          # Format rules
    │   ├── security-*.md        # Security rules
    │   └── operational-*.md     # Operational rules
    └── learning/                # Self-improvement logs
        ├── reflections/
        ├── patterns.md
        └── changelog.md
```
