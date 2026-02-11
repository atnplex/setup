# R83: Auto-Accept SSH Host Keys

## Purpose

Automatically accept SSH host key verification prompts when cloning repositories, avoiding interactive prompts that block automation.

## Rule

When using SSH to clone or interact with Git repositories, set the `StrictHostKeyChecking` option to `accept-new`:

```bash
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
git clone git@github.com:owner/repo.git
```

Or use HTTPS with GitHub CLI authentication:

```bash
# Preferred: Use HTTPS which uses gh auth token
git clone https://github.com/owner/repo.git
```

## Why `accept-new` instead of `no`

- `accept-new`: Accepts new host keys but warns if a known host's key changes (security risk)
- `no`: Accepts all keys without warning (less secure)

## Application

Apply when:

- Cloning repositories in automated workflows
- Running git operations in CI/CD pipelines
- Any non-interactive context where host key prompts would block

## Examples

```bash
# Option 1: Environment variable
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
git clone git@github.com:atnplex/repo.git

# Option 2: SSH config (~/.ssh/config)
Host github.com
    StrictHostKeyChecking accept-new

# Option 3: Use HTTPS (recommended for automation)
git clone https://github.com/atnplex/repo.git
```
