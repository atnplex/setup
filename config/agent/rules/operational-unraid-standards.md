# R68: Unraid-Specific Standards

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: CRITICAL - ensures Unraid stability
> **Updated**: 2026-02-03

---

## Unraid Architecture Understanding

### OS Boot Sequence

1. **USB boot device** loads OS into RAM
2. **System services** start from RAM (always available)
3. **Array starts** (mounts physical disks under `/mnt`)
4. **User shares** become available (virtual, physically on `/mnt`)
5. **Docker** starts (requires array, located on user shares)

### Key Implications

| Component | Available | Depends On |
| --------- | --------- | ---------- |
| OS/System Services | Always | USB → RAM |
| Plugins | Always | USB → RAM |
| `/mnt/disk*` | After array start | Healthy disks |
| `/mnt/user/*` | After array start | Healthy disks |
| Docker | After array start | User shares |

---

## Critical Rules

### 1. Never Exit 1 in Go Files

Unraid .go files run during boot. A failed script can prevent boot completion.

```bash
# ❌ NEVER - can break boot
if [[ ! -f "$required_file" ]]; then
    echo "Missing file!"
    exit 1
fi

# ✅ ALWAYS - graceful fallback
if [[ ! -f "$required_file" ]]; then
    echo "Warning: Missing file, using defaults"
    # Continue with defaults or skip functionality
fi
```

### 2. Remote Access Independence

Remote access services MUST NOT depend on array/disks:

```text
✅ System services (plugins, static binaries)
✅ Tailscale (system service)
✅ Cloudflared tunnel (static binary or plugin)
✅ SSH (system service)

❌ Docker containers (require array)
❌ User share scripts (require array)
```

### 3. Persistence Locations

| Type | Location | Survives Reboot |
| ---- | -------- | --------------- |
| Boot config | `/boot/config/` | Yes (USB) |
| Plugins | `/boot/config/plugins/` | Yes (USB) |
| Static binaries | `/boot/config/plugins/user.scripts/` or `/boot/extra/` | Yes (USB) |
| User data | `/mnt/user/` | Yes (disk array) |
| System RAM | `/tmp`, `/var` | No |

---

## Tmpfs Requirements

### Verification Before Use

Every script using tmpfs MUST verify:

```bash
verify_tmpfs() {
    local dir="${1:?Directory required}"
    local min_space_mb="${2:-100}"

    # 1. Check if truly tmpfs
    if ! mount | grep -q "tmpfs.*${dir}"; then
        echo "Warning: ${dir} is not tmpfs"
        return 1
    fi

    # 2. Check writability
    if ! touch "${dir}/.write_test" 2>/dev/null; then
        echo "Error: ${dir} is not writable"
        return 1
    fi
    rm -f "${dir}/.write_test"

    # 3. Check available space
    local avail_mb
    avail_mb=$(df -m "${dir}" | awk 'NR==2 {print $4}')
    if [[ "${avail_mb}" -lt "${min_space_mb}" ]]; then
        echo "Error: ${dir} has only ${avail_mb}MB (need ${min_space_mb}MB)"
        return 1
    fi

    return 0
}

# Usage
verify_tmpfs "/tmp" 500 || exit 1
```

### Standard Tmpfs Locations on Unraid

| Path | Size | Purpose |
| ---- | ---- | ------- |
| `/tmp` | ~48GB | General temp |
| `/var/log` | 128MB | System logs |
| `/logs` | 10GB | Custom log mount |
| `/dev/shm` | 48GB | Shared memory |

---

## Service Redundancy Pattern

### Multiple Access Methods

```text
Primary:   Tailscale SSH (system service, no disk dependency)
Secondary: Cloudflared tunnel (plugin/static binary)
Tertiary:  External SSH (requires port forwarding)
Last:      Physical console access
```

### Consistent Setup Across Servers

Maintain the same services/access methods on all servers:

| Service | VPS1 | VPS2 | Unraid |
| ------- | ---- | ---- | ------ |
| Tailscale | ✅ | ✅ | ✅ |
| SSH | ✅ | ✅ | ✅ |
| Docker | ✅ | ✅ | ✅ (array-dependent) |
| Cloudflared | ✅ (systemd) | ✅ (systemd) | ✅ (plugin) |

---

## GitHub as SSOT Pattern

### Deployment Flow

```text
GitHub (SSOT) → Deploy Script → Live System

1. Edit files in GitHub
2. Commit changes
3. Deploy script pulls and copies
4. Live system updated
```

### Never Edit Live Directly

```bash
# ❌ BAD - editing live files
vim /mnt/user/appdata/service/config.json

# ✅ GOOD - edit in repo, deploy
git clone atnplex/service-config
vim config.json
git commit -am "Update config"
./scripts/deploy.sh
```

---

## Automation Standards

### Self-Healing Requirements

All automation MUST:

1. **No human input** - Fully automated execution
2. **Auto-correcting** - Handle common failures
3. **Fallbacks** - Alternative paths when primary fails
4. **Idempotent** - Safe to run repeatedly

```bash
# Pattern: Attempt with fallback
attempt_action() {
    if ! primary_method; then
        log_warn "Primary failed, trying fallback"
        if ! fallback_method; then
            log_error "All methods failed"
            return 1
        fi
    fi
}
```

---

## Cross-References

- [R61: Infrastructure Standards](/atn/.gemini/rules/operational/infrastructure_standards.md)
- [R50: Coding Principles](/atn/.gemini/rules/operational/coding-principles.md)
- [atnplex/atn docs/DESIGN_NOTES.md](/atn/github/atn/docs/DESIGN_NOTES.md)
