# R41: Path Referencing Standards

> **Authority**: Global formatting rule
> **Severity**: MEDIUM - ensures consistency and portability
> **Scope**: All rules, workflows, documentation, and configuration files

---

## Core Principle

**Strictly use ABSOLUTE PATHS for all tool arguments. `~/` and `@/` syntax is for documentation only.**

---

## Path Syntax

### Tool Arguments (Strict)

When invoking tools (`view_file`, `grep_search`, `write_to_file`, etc.), you MUST resolve all paths to valid absolute system paths:

```json
// ✅ Correct
{
  "AbsolutePath": "/atn/.gemini/GEMINI.md"
}

// ❌ Wrong - Do not pass @ or ~ to tools
{
  "AbsolutePath": "@/atn/.gemini/GEMINI.md"
}
```

### Documentation & Rules

Use `@/atn` to reference the top-level workspace directory only in markdown documentation:

```markdown
# ✅ Correct - Absolute path with @ syntax in docs
@/atn/.gemini/GEMINI.md
@/atn/baseline/rules/environment.md
```

### Home Directory References

For user-specific paths outside workspace:

```markdown
# ✅ Correct
/home/alex/.gemini/antigravity/mcp_config.json
```

---

## Mapping Table

| Syntax | Resolves To | Use Case |
| :--- | :--- | :--- |
| `@/atn` | `/atn` | Documentation (Workspace root) |
| `@/atn/.gemini` | `/atn/.gemini` | Documentation (Global rules) |
| `~/` | `/home/<user>/` | Documentation (User home) |
| `/absolute/path` | `/absolute/path` | **ALL Tool Arguments** |

---

## Examples by Context

### In GEMINI.md

```markdown
## Rule Modules

Reference these from `@/atn/.gemini/rules/`:

- [Format: Markdown](@/atn/.gemini/rules/format/markdown.md)
```

### In Tool Calls (Agent Actions)

```python
# ✅ Correct: Agent resolves path before calling tool
view_file(AbsolutePath="/atn/.gemini/rules/format/markdown.md")
```

---

## Why Absolute Paths?

### Problems with Relative Paths

1. **Ambiguity**: Reviewing a file vs executing a script often implies different working directories.
2. **Tool Limitations**: Many MCP tools (like `view_file`) requires absolute paths.
3. **Safety**: explicit paths prevent accidental operations on wrong files.

### Benefits of `@/atn` Syntax in Docs

1. **Unambiguous**: always resolves to `/atn` for human readers.
2. **Portable**: works regardless of current directory.

---

## Troubleshooting "File Not Found"

If you encounter "File not found" errors for files you know exist:

1. **Check the Path**: Did you pass `~/` or `@/atn` to a tool? **Resolve it first.**
2. **Check Symlinks**: Is `/atn/.gemini` a symlink? Use `readlink -f` to find the canonical path if needed.
3. **Check Visibility**: Can you see it with `ls -la <parent_dir>`?
4. **Check User Context**: Are you looking for a file in `/home/alex` but running as `root` (or vice versa)?

---

## Compliance Checklist

When writing rules, workflows, or documentation:

- [ ] All tool calls use resolved ABOSLUTE paths (starts with `/`)
- [ ] Documentation users `@/atn` for clarity
- [ ] No relative paths (`./`, `../`) in ANY context
- [ ] Symlinks documented if used

---

## References

- **Official Docs**: Antigravity path referencing standards
- **R0**: No hardcoding principle (use variables not literals)
- **GEMINI.md**: Path structure documentation
