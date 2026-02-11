# R67: Path Standards

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: HIGH - prevents path resolution errors
> **Updated**: 2026-02-03

---

## Core Principle

Define ONE absolute root path, then derive all other paths relative to it.

---

## Standard Root Definition

```bash
# NAMESPACE defines the root
: "${NAMESPACE:=atn}"
ATN_ROOT="/${NAMESPACE}"

# All paths derive from root
ATN_CONFIG="${ATN_ROOT}/config"
ATN_SCRIPTS="${ATN_ROOT}/scripts"
ATN_LIB="${ATN_ROOT}/lib"
ATN_LOGS="${ATN_ROOT}/logs"
ATN_BIN="${ATN_ROOT}/bin"
ATN_GITHUB="${ATN_ROOT}/github"
```

---

## Path Types and Usage

### 1. Absolute Paths

Use for:

- Tool arguments that require absolute paths
- Configuration files specifying locations
- Cross-component references
- Antigravity tool calls (ALWAYS absolute)

```bash
# Antigravity requires absolute paths
/atn/.gemini/rules/operational/path-standards.md  # ✅ Correct
rules/operational/path-standards.md               # ❌ Will fail
```

### 2. Relative Paths

Use for:

- References within the same component
- GitHub repository internal links
- Strongly linked files (helper libraries)

```bash
# Within a repo, relative is fine
source "lib/helper.sh"     # Relative to script location
source "${lib_dir}/helper.sh"  # Or use variable
```

### 3. GitHub Repository Paths

In GitHub repos, use:

- **Absolute for external refs**: Full URL or from repo root
- **Relative for internal refs**: From current file location

```markdown
<!-- Good: Relative within repo -->
See [helper functions](../lib/helper.sh)

<!-- Good: Absolute from repo root -->
See [helper functions](/lib/helper.sh)
```

---

## Antigravity-Specific Requirements

Antigravity tools accept either:

1. **Absolute path** - Always works
2. **Relative path from workspace** - Inconsistent, avoid

### Recommendation

**ALWAYS use absolute paths for Antigravity tools.**

```python
# ✅ Always works
view_file("/atn/.gemini/rules/operational/path-standards.md")

# ❌ May fail depending on context
view_file("rules/operational/path-standards.md")
```

---

## Linter Path Resolution Bug

### Issue

The linter incorrectly doubles paths, showing:

```text
/atn/atn/.gemini/...  # WRONG - doubled prefix
```

When the actual path is:

```text
/atn/.gemini/...      # CORRECT
```

### Root Cause

Linter may be concatenating workspace root with absolute paths.

### Workaround

Until fixed, ignore "file does not exist" warnings that show doubled paths like `/atn/atn/...`.

### Fix Investigation (TODO)

1. Check markdownlint configuration for workspace root
2. Verify `.markdownlint.json` path resolution settings
3. Consider creating `.markdownlintrc` with proper root

---

## Directory Structure Standard

```text
/${NAMESPACE}/                    # ATN_ROOT (e.g., /atn/)
├── .gemini/                      # Gemini/Antigravity config
│   ├── rules/                    # Global rules
│   ├── workflows/                # Workflow definitions
│   ├── scratch/                  # Working documents
│   └── antigravity/              # Agent-specific config
├── baseline/                     # Reference namespace
├── bin/                          # Executable scripts
├── config/                       # Configuration files
├── github/                       # Cloned repositories
│   ├── atn/                      # Main repo
│   ├── organizr/                 # Service configs
│   └── ...
├── lib/                          # Shared libraries
├── logs/                         # Log files
├── scripts/                      # Orchestration scripts
└── appdata/                      # Application data (VPS only)
```

---

## Cross-References

- [R50: Coding Principles](/atn/.gemini/rules/operational/coding-principles.md)
- [R61: Infrastructure Standards](/atn/.gemini/rules/operational/infrastructure_standards.md)
