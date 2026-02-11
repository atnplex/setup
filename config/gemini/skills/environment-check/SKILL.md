---
name: environment-check
description: Verify environment capabilities before executing commands
keywords: [environment, verify, check, idempotent, fallback, commands, paths]
---

# Environment Check Skill

> **Purpose**: Verify environment capabilities before executing commands

## When to Use

> [!IMPORTANT]
> Use at the START of any task to understand what's available.

## Core Checks

### 1. Operating System

```bash
# Detect OS
uname -s  # Linux, Darwin, etc.

# Get distribution (Linux)
cat /etc/os-release 2>/dev/null || cat /etc/*-release 2>/dev/null
```

### 2. Available Commands

```bash
# Check if command exists
command -v docker >/dev/null 2>&1 && echo "docker available"
command -v npm >/dev/null 2>&1 && echo "npm available"
command -v gh >/dev/null 2>&1 && echo "gh available"
```

### 3. Path Verification

```bash
# Check paths exist before using
[ -d "/path/to/dir" ] && echo "exists" || echo "missing"
[ -f "/path/to/file" ] && echo "exists" || echo "missing"
```

### 4. Permissions

```bash
# Check write permissions
[ -w "/path/to/dir" ] && echo "writable" || echo "not writable"
```

## Idempotent Commands

Always write commands that are safe to run multiple times:

### Good (Idempotent)

```bash
# Create directory if not exists
mkdir -p /path/to/dir

# Add line only if not present
grep -q "pattern" file || echo "line" >> file

# Install only if missing
command -v tool >/dev/null 2>&1 || install_tool
```

### Bad (Not Idempotent)

```bash
# Will fail if exists
mkdir /path/to/dir

# Will duplicate
echo "line" >> file

# Will reinstall
install_tool
```

## Error Handling with Fallbacks

```bash
# Try primary, fallback to secondary
docker compose up -d 2>/dev/null || docker-compose up -d

# Try command, use default if fails
result=$(command 2>/dev/null) || result="default"

# Multiple fallbacks
tool1 2>/dev/null || tool2 2>/dev/null || echo "No tool available"
```

## Environment Verification Checklist

Before executing:

| Check | Command | Purpose |
|-------|---------|---------|
| Shell | `echo $SHELL` | Know shell syntax |
| Working dir | `pwd` | Know current location |
| Git status | `git status 2>/dev/null` | Know if in repo |
| Tmpfs | `df -h /dev/shm` | Know if tmpfs available |
| Network | `curl -s -o /dev/null -w "%{http_code}" google.com` | Check connectivity |

## Integration Pattern

At task start:

```bash
# Quick environment snapshot
echo "=== Environment Check ==="
echo "OS: $(uname -s)"
echo "Shell: $SHELL"
echo "User: $(whoami)"
echo "PWD: $(pwd)"
echo "Git: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'not in repo')"
echo "Docker: $(docker --version 2>/dev/null || echo 'not installed')"
echo "Node: $(node --version 2>/dev/null || echo 'not installed')"
```

## Common Fallback Patterns

### Package Managers

```bash
# Install package (multi-distro)
apt-get install -y pkg 2>/dev/null || \
yum install -y pkg 2>/dev/null || \
apk add pkg 2>/dev/null || \
brew install pkg 2>/dev/null
```

### Container Runtimes

```bash
# Docker or Podman
docker ps 2>/dev/null || podman ps 2>/dev/null
```

### Editors

```bash
# Open file in available editor
$EDITOR file 2>/dev/null || vim file 2>/dev/null || nano file
```
