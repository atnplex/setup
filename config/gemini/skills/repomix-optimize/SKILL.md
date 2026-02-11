---
name: repomix-optimize
description: Pack repositories into AI-friendly formats to reduce token usage
keywords: [repomix, optimize, token, pack, compress, repository, codebase]
argument-hint: <repo path or URL>
---

# Repomix Optimization Skill

> **Purpose**: Pack codebases into AI-friendly formats for efficient LLM consumption

## Overview

[Repomix](https://github.com/yamadashy/repomix) is a CLI tool that packs repositories into optimized formats for AI models. It:

- Shows token counts per file and total
- Formats code for better AI understanding
- Supports multiple output formats (plain, XML, Markdown)
- Respects .gitignore and security checks

## When to Use

- Before analyzing a large codebase
- When context window is limited
- For research on unfamiliar repositories
- To get token estimates before processing

## Installation

```bash
# Via npm
npm install -g repomix

# Or use directly via npx
npx repomix
```

## Quick Usage

### Pack Current Directory

```bash
repomix
# Output: repomix-output.txt
```

### Pack Specific Directory

```bash
repomix path/to/project
```

### Pack Remote Repository

```bash
repomix --remote https://github.com/user/repo
```

## Output Formats

| Format | Flag | Best For |
|--------|------|----------|
| Plain Text | `--style plain` | Most models |
| XML | `--style xml` | Claude (structured) |
| Markdown | `--style markdown` | Documentation-heavy |

## Token Optimization

### Exclude Files

```bash
repomix --ignore "*.test.ts,*.spec.ts,node_modules/**"
```

### Include Only Specific Paths

```bash
repomix --include "src/**,lib/**"
```

### Compress Output

```bash
repomix --compress
```

## Integration Pattern

### For Research Tasks

```bash
# 1. Pack remote repo to tmpfs
npx repomix --remote https://github.com/user/repo \
  --output /dev/shm/repo_packed.txt \
  --style plain

# 2. Check token count
wc -w /dev/shm/repo_packed.txt

# 3. Feed to Flash model for summarization
# 4. Consolidate findings
```

### For Codebase Analysis

```bash
# Pack with token info
npx repomix --show-tokens

# Output includes:
# - Token count per file
# - Total token count
# - Estimated cost per model
```

## Example Output

```
📦 Repomix Output
================

Repository: my-project
Total Files: 45
Total Tokens: 23,456

Top files by tokens:
- src/api.ts: 3,200 tokens
- src/database.ts: 2,800 tokens
- src/auth.ts: 2,100 tokens

[Packed content follows...]
```

## Benefits

| Benefit | Impact |
|---------|--------|
| Token visibility | Know exactly what fits in context |
| Optimized format | Better AI comprehension |
| Security | Respects .gitignore, uses Secretlint |
| Flexibility | Multiple output formats |

## Alternatives

- **Manual selection**: Cherry-pick files (time-consuming)
- **Context compression**: Summarize after loading (uses tokens first)
- **Outline-only**: Use `view_file_outline` (less detail)

## Integration with Pipeline

Use in parallel-research skill:

1. Run repomix on target repos
2. Write packed output to tmpfs
3. Process with Flash models
4. Consolidate with Sonnet
