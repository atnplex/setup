# R63: Universal Linting and Formatting Standards

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: MEDIUM - ensures consistency across environments
> **Updated**: 2026-02-03

---

## Core Principle

**Maintain consistent formatting across all servers and environments.** Install and configure linters/formatters universally to prevent style drift.

---

## Required Tools Per Environment

### All Linux Servers (VPS1, VPS2, Unraid, WSL)

| Tool | Purpose | Install Command |
| ---- | ------- | --------------- |
| `shfmt` | Shell script formatting | `sudo apt install shfmt` or `go install mvdan.cc/sh/v3/cmd/shfmt@latest` |
| `shellcheck` | Shell script linting | `sudo apt install shellcheck` |
| `jq` | JSON formatting/validation | `sudo apt install jq` |
| `yq` | YAML formatting/validation | `sudo snap install yq` or `pip install yq` |
| `ruff` | Python linting/formatting | `pip install ruff` |
| `black` | Python formatting | `pip install black` |
| `prettier` | Multi-format (JS, JSON, YAML, MD) | `npm install -g prettier` |
| `markdownlint-cli` | Markdown linting | `npm install -g markdownlint-cli` |

### VSCode Extensions (Windows/WSL)

```json
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "DavidAnson.vscode-markdownlint",
    "timonwong.shellcheck",
    "charliermarsh.ruff",
    "redhat.vscode-yaml",
    "foxundermoon.shell-format"
  ]
}
```

---

## Markdown Formatting Rules

Per `markdownlint` configuration:

### Table Formatting (MD060)

Tables must have consistent spacing:

```markdown
# ❌ Bad - inconsistent spacing
|Column1|Column2|
|-------|-------|
|value1|value2|

# ✅ Good - consistent spacing
| Column1 | Column2 |
| ------- | ------- |
| value1  | value2  |
```

### Code Block Language Specification (MD040)

Always specify language for fenced code blocks:

````markdown
# ❌ Bad
```
some code
```

# ✅ Good
```bash
some code
```
````

### Heading Hierarchy (MD001)

Use sequential heading levels:

```markdown
# ❌ Bad - skips from h1 to h3
# Title
### Subsection

# ✅ Good - sequential
# Title
## Section
### Subsection
```

---

## Configuration Files

### `.markdownlint.json`

Place in project root or `~/.markdownlintrc`:

```json
{
  "default": true,
  "MD013": false,
  "MD033": false,
  "MD041": false,
  "MD060": {
    "style": "consistent"
  }
}
```

### `.prettierrc`

```json
{
  "tabWidth": 2,
  "useTabs": false,
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100,
  "proseWrap": "always"
}
```

### `ruff.toml`

```toml
line-length = 100
target-version = "py311"

[lint]
select = ["E", "F", "I", "N", "W", "UP"]
ignore = ["E501"]
```

---

## Auto-Format on Save

### VSCode Settings

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff"
  },
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  }
}
```

### Git Hooks (Pre-commit)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
  - repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.1.9
    hooks:
      - id: ruff
        args: [--fix]
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.38.0
    hooks:
      - id: markdownlint
        args: [--fix]
```

---

## Validation Commands

Quick commands to validate formatting:

```bash
# Markdown
markdownlint **/*.md

# JSON
find . -name "*.json" -exec jq . {} \; > /dev/null

# YAML
find . -name "*.yaml" -o -name "*.yml" | xargs -I {} yq . {} > /dev/null

# Shell
shellcheck **/*.sh
shfmt -d **/*.sh

# Python
ruff check .
black --check .
```

---

## Server Setup Script

Run on each server to install formatters:

```bash
#!/bin/bash
set -euo pipefail

# APT packages
sudo apt update
sudo apt install -y jq shellcheck

# Python tools
pip install --user ruff black yq

# Node tools (if npm available)
if command -v npm &> /dev/null; then
    npm install -g prettier markdownlint-cli
fi

# Go tools (if go available)
if command -v go &> /dev/null; then
    go install mvdan.cc/sh/v3/cmd/shfmt@latest
fi

echo "Formatters installed successfully"
```

---

## Cross-References

- [Format: Markdown](/atn/.gemini/rules/format/markdown.md)
- [Format: JSON](/atn/.gemini/rules/format/json.md)
- [Format: YAML](/atn/.gemini/rules/format/yaml.md)
- [Format: Shell](/atn/.gemini/rules/format/shell.md)
- [Format: Python](/atn/.gemini/rules/format/python.md)
