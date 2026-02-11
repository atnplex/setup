---
description: Restore GitHub connectivity (SSH/HTTPS) using Bitwarden backups
---

# Fix GitHub Connectivity

This workflow runs the resilience skill to verify and restore usage of GitHub resources.

1. Run the connectivity skill
// turbo

```bash
/home/alex/.agent/skills/github-connector/ensure-connection.sh
```

1. Validation

```bash
gh auth status
ssh -T git@github.com 2>&1 | head -n 1
```
