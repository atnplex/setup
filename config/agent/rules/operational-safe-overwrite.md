# R-SAFE: Safe Overwrite & Data Preservation

> **Never blindly delete or overwrite. Always check first, evaluate, and extract value.**

## Pre-Action Checks (MANDATORY)

Before ANY operation that could destroy or replace data:

1. **Check existence** — `test -e`, `ls`, `stat`, `gh api`, etc.
2. **If target exists** — read/diff it before proceeding
3. **Evaluate both versions** — determine which is more feature-complete
4. **Extract value** — pull useful code, config, logic from the existing version
5. **Merge forward** — ensure the newest version inherits all useful features

## Operations Covered

| Operation | Check Required |
|-----------|---------------|
| `cp`, `mv`, `ln -s` | Does target already exist? |
| `git clone`, `git pull` | Will it overwrite local changes? |
| `docker compose up` | Will volumes/configs be replaced? |
| Symlink/hardlink/junction | Does target path have real data? |
| File writes (agent tools) | Does file exist with different content? |
| `rm -rf`, `rm -r` | Is there data worth preserving? |
| Config overwrites | Diff old vs new, merge if needed |

## Evaluation Protocol

When existing data is found:

```
1. Read existing file/dir contents
2. Read new/replacement contents
3. Compare: which is more comprehensive?
4. Extract: any unique features, logic, or config from the "losing" version?
5. Merge: incorporate extracted value into the winner
6. Only then: proceed with the operation
```

## Anti-Patterns (NEVER do these)

- `rm -rf dir && git clone repo dir` — destroys local customizations
- `cp -f new.conf old.conf` without diffing first
- `ln -sf` over a real file without checking if it has unique content
- Force-pushing without checking remote has unique commits
- Creating files with `Overwrite: true` without reading existing content

## Exceptions

- Files known to be auto-generated (build artifacts, caches, `node_modules/`)
- Explicitly user-requested destructive operations
- Files tracked in git where `git stash` preserves the data
