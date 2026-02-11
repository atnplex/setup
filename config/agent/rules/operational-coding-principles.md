# R50: Coding Principles

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: HIGH - core development standards
> **Updated**: 2026-02-03
> **Source**: Aligned with `atnplex/atn` docs/rules/ai_standards.md

---

## 1. No Hardcoding

### Principle

**NEVER hardcode values** in scripts or configuration files. Derive values dynamically.

### Requirements

```bash
# ❌ BAD - Hardcoded
NAMESPACE="atn"
ATN_HOME="/home/alex/.atn"
CONFIG_PATH="/atn/config/settings.json"

# ✅ GOOD - Dynamic with defaults
NAMESPACE="${NAMESPACE:-atn}"
ATN_HOME="${ATN_HOME:-${HOME}/.${NAMESPACE}}"
CONFIG_PATH="${ATN_HOME}/config/settings.json"
```

### Variables to Always Define

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `NAMESPACE` | `atn` | Root namespace for all paths |
| `ATN_HOME` | `${HOME}/.${NAMESPACE}` | User-level data directory |
| `ATN_ROOT` | `/${NAMESPACE}` | System-level root |
| `LOG_DIR` | `${ATN_HOME}/logs` | Log output |
| `TMP_DIR` | `/tmp/${NAMESPACE}` | Temporary working files |

### Exception

Self-sustaining scripts that must work without external dependencies may hardcode **only** fallback defaults, clearly documented:

```bash
# Self-sustaining script - intentional hardcoded fallback
: "${NAMESPACE:=atn}"  # FALLBACK: script must work standalone
```

---

## 2. DRY (Don't Repeat Yourself)

### Principle

**Repeated code must be extracted into functions.**

### Requirements

- If code appears 2+ times, extract to a function
- If logic is complex, extract even if used once
- Functions go in `lib/`, orchestration in `scripts/`

```bash
# ❌ BAD - Repeated
echo "[INFO] Starting backup..."
rsync -av /source1 /dest1
echo "[INFO] Starting second backup..."
rsync -av /source2 /dest2

# ✅ GOOD - Function
backup() {
    local src="${1:?source required}"
    local dst="${2:?dest required}"
    log_info "Starting backup: ${src} → ${dst}"
    rsync -av "${src}" "${dst}"
}
backup /source1 /dest1
backup /source2 /dest2
```

---

## 3. Path Resolution

### Principle

**Always use variables from lib/fs/paths.sh** (or equivalent) for path resolution.

### Standard Variables

```bash
# Use these, NEVER hardcode paths
${run_dir}      # Runtime directory
${logs_dir}     # Logs directory
${atn_dir}      # Main ATN directory
${config_dir}   # Configuration files
${lib_dir}      # Library functions
```

---

## 4. Generic Over Specific

### Principle

**Use generic/default values** to protect private information.

### Requirements

- No usernames in scripts (use `${USER}`)
- No hostnames in scripts (use `$(hostname -s)`)
- No custom unique values without variable fallback

```bash
# ❌ BAD
ssh alex@condo "do something"

# ✅ GOOD
: "${SSH_USER:=${USER}}"
: "${TARGET_HOST:=$(hostname -s)}"
ssh "${SSH_USER}@${TARGET_HOST}" "do something"
```

---

## 5. Library Usage

### Principle

**Check lib/ for existing functions before implementing.**

From atnplex/atn ai_standards.md:

| Need | Use |
| ---- | --- |
| Logging | `log_info`, `log_warn` from `lib/ui/log.sh` |
| AI calls | `ai_ask` from `lib/ai/client.sh` |
| Locking | `lock_acquire` from `lib/sys/lock.sh` |
| Paths | Variables from `lib/fs/paths.sh` |

---

## Cross-References

- [R61: Infrastructure Standards](/atn/.gemini/rules/operational/infrastructure_standards.md)
- [R34: Python Format](/atn/.gemini/rules/format/python.md)
- [R33: Shell Format](/atn/.gemini/rules/format/shell.md)
- [atnplex/atn docs/rules/ai_standards.md](https://github.com/atnplex/atn/blob/main/docs/rules/ai_standards.md)
