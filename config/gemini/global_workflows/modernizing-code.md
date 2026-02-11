---
description: Modernize code by identifying redundancy, extracting patterns, and improving maintainability
---

# Modernizing Code Workflow

## Purpose

While working on any codebase, continuously identify and implement improvements:

- Remove redundant/unused code
- Extract repeated patterns into reusable functions
- Replace hardcoded values with constants/variables
- Derive values from other values instead of duplicating
- Apply DRY (Don't Repeat Yourself) principles

## Triggers

Apply this workflow when:

1. Touching existing code for any reason
2. Reviewing files for fixes
3. Adding new features to existing modules
4. Fixing security vulnerabilities

## Discovery Checklist

### 1. Redundant Code

- [ ] Duplicate function implementations
- [ ] Copy-pasted code blocks
- [ ] Unused imports/modules
- [ ] Dead code paths (unreachable conditions)
- [ ] Commented-out code (should be deleted, not commented)

### 2. Repeated Patterns

- [ ] Same logic in multiple places → extract to function
- [ ] Similar error handling → create error handler utility
- [ ] Common data transformations → create mapper functions
- [ ] Repeated try/catch blocks → create wrapper

### 3. Hardcoded Values

- [ ] Magic numbers → named constants
- [ ] Repeated strings → string constants
- [ ] Config values in code → move to config file
- [ ] Environment-specific values → use env variables

### 4. Derivable Values

- [ ] Values computed from others → compute instead of store
- [ ] Related config values → derive from base
- [ ] Version numbers → single source of truth
- [ ] URLs with common base → construct from base + path

## Action Patterns

### Extract Function

```
// Before: Repeated code
doA(); doB(); doC();
// ... elsewhere ...
doA(); doB(); doC();

// After: Extracted function
function doABC() { doA(); doB(); doC(); }
doABC();
doABC();
```

### Define Constants

```
// Before: Magic values
if (status === 200) { ... }
if (timeout > 5000) { ... }

// After: Named constants
const HTTP_OK = 200;
const DEFAULT_TIMEOUT_MS = 5000;
if (status === HTTP_OK) { ... }
if (timeout > DEFAULT_TIMEOUT_MS) { ... }
```

### Derive Values

```
// Before: Duplicate related values
const API_URL = "https://api.example.com";
const AUTH_URL = "https://api.example.com/auth";
const USER_URL = "https://api.example.com/users";

// After: Derive from base
const API_BASE = "https://api.example.com";
const AUTH_URL = `${API_BASE}/auth`;
const USER_URL = `${API_BASE}/users`;
```

## Language-Specific Tips

### Rust

- Use `impl` blocks to group related methods
- Create traits for shared behavior
- Use `From`/`Into` for type conversions
- Leverage derive macros: `#[derive(Clone, Debug)]`
- Use `const` for compile-time constants

### TypeScript/JavaScript

- Extract to utility files in `utils/`
- Use barrel exports (`index.ts`)
- Prefer `const` over `let`
- Use template literals for string building
- Leverage destructuring for cleaner code

### Python

- Use `@dataclass` for data containers
- Extract to separate modules in `utils/`
- Use `functools` for common patterns
- Define constants in `constants.py`
- Use type hints for clarity

## MCP Servers to Use

1. **mcp-memory**: Store patterns found for future reference

   ```
   mcp_mcp-memory_create_entities: Record code patterns
   mcp_mcp-memory_add_observations: Note improvements made
   ```

2. **grep_search**: Find duplicate patterns

   ```
   grep_search: Search for repeated strings/patterns
   ```

3. **view_file_outline**: Understand file structure

   ```
   view_file_outline: See all functions/classes at a glance
   ```

## Logging Improvements

When making improvements, log them:

```bash
# Record in knowledge graph for future reference
mcp_mcp-memory_create_entities:
  - name: "CodeImprovement_<repo>_<date>"
    entityType: "code_improvement"
    observations:
      - "Extracted X into reusable function Y"
      - "Replaced magic number with constant Z"
```

## Integration with Security Fixes

When fixing security issues, look for:

- Other similar vulnerable patterns to fix
- Opportunity to create secure-by-default utilities
- Shared validation functions
- Centralized error handling

// turbo-all
