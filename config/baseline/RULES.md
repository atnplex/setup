# UNIVERSAL NAMESPACE RULES

**Version**: 2.0.0 | **Authority**: [R0: Precedence](#r0-precedence)

## R0: Precedence

**Global Namespace Rules prevail.** Current Context: `NAMESPACE` = `atn`
Linux Root: `$ROOT` (Default: `/$NAMESPACE/`)
Windows Root: `$ROOT_OS_WINDOWS` (Default: `C:\$NAMESPACE`)

**Global Namespace Rules (this ecosystem) prevail over repo-specific rules.**

---

## Core Principles (AI-FAST)

1. **Env-First**: Detect (system|wsl|target) before acting.
2. **No Hardcoding**: Derive via `namespace_env.py` (Respect `$NAMESPACE`).
3. **Canonical**: Use UTC (ISO8601Z) and smallest integer units (bytes, ms).
4. **Python-Spine**: All logic in Python (Modular|Deterministic|Idempotent).
5. **Stability**: Enforce stable workspace modes (Local|Remote-WSL).

---

## Rule Modules

Reference these relative to `$ROOT/baseline/rules/`:

- [01: Environment & Stability](./environment.md)
- [02: Paths & Canonicals](./paths.md)
- [03: Execution & Autonomy](./execution.md)
- [04: Governance & Health](./governance.md)
- [05: Git & Workflow](./git_workflow.md)

### Format Modules

- [Markdown Standards](./format/markdown.md)
- [JSON Standards](./format/json.md)
- [Shell Standards](./format/shell.md)
- [Python Standards](./format/python.md)

---

## Dynamic Variables

| Target | Variable | Default |
| :--- | :--- | :--- |
| Config | `NAMESPACE` | `atn` |
| Windows | `$ROOT_OS_WINDOWS` | `C:\$NAMESPACE` |
| Linux | `$ROOT` | `/$NAMESPACE/` |
