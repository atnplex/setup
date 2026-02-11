# UNIVERSAL NAMESPACE RULES

**Version**: 2.3.0 | **Authority**: [R0: Precedence](#r0-precedence)

## R0: Precedence

**Global Namespace Rules prevail.** Current Context: `NAMESPACE` = `atn`
Linux Root: `$ROOT`
Windows Root: `$ROOT_OS_WINDOWS`

---

## Core Principles (AI-FAST)

1. **Env-First**: Detect target + mode.
2. **No Hardcoding**: Derive via `namespace_env.py`.
3. **Canonical**: UTC and smallest units.
4. **Python-Spine**: Logic in Python.
5. **Stability**: Enforce stable workspace modes.

---

## Rule Modules

- [01: Environment](./environment.md)
- [02: Paths](./paths.md)
- [03: Execution](./execution.md)
- [04: Governance](./governance.md)
- [05: Git Workflow](./git_workflow.md)
- [Formatting](./format/formatting.md)
- [Markdown](./format/markdown.md)
- [JSON](./format/json.md)
- [Shell](./format/shell.md)
- [Python](./format/python.md)
- [06: Scripting](./scripting.md)

---

## Dynamic Variables

| Target | Variable | Default |
| :--- | :--- | :--- |
| Config | `NAMESPACE` | `atn` |
| Windows | `$ROOT_OS_WINDOWS` | `C:\$NAMESPACE` |
| Linux | `$ROOT` | `/$NAMESPACE/` |
