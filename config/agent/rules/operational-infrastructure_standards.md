# R61: Infrastructure Standards

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: HIGH - consistency across all environments
> **Scope**: All servers, workstations, and automation
> **Updated**: 2026-02-03

---

## Server Naming Convention

| Alias | Machine | Tailscale IP | Role |
|-------|---------|--------------|------|
| **VPS1** | vps | `100.67.88.109` | Secondary VPS (older) |
| **VPS2** / **condo** | condo | `100.102.55.88` | Primary VPS (newer) |
| **Unraid** | unraid | `100.76.168.116` | Media/Storage server |
| **Windows** / **amd** | amd | `100.118.253.91` | Desktop workstation |
| **WSL** | antigravity-wsl | `100.114.18.47` | WSL2 on Windows |

---

## Access Hierarchy (Fallbacks)

Always attempt access in this order:

| Priority | Method | Command Example |
|----------|--------|-----------------|
| 1 | **Tailscale SSH** | `ssh alex@100.102.55.88` |
| 2 | **Cloudflared Tunnel** | systemd (VPS1/VPS2), plugin (Unraid) — no Docker dep |
| 3 | **Subnet Routing** | Access via local IP through tailnet |
| 4 | **External SSH** | Public IP with SSH key (disabled by default) |

---

## User Standards

### Linux Servers (VPS1, VPS2, WSL)

| Setting | Value |
|---------|-------|
| **Primary User** | `alex` |
| **Privileges** | Passwordless sudo via `visudo` |
| **Shell** | bash (default) |
| **SSH Auth** | Tailscale (no password/key needed) |

**visudo Configuration** (add to end of sudoers):

```bash
alex ALL=(ALL) NOPASSWD: ALL
```

### Service Execution Standard

> **CRITICAL**: System services (systemd) on VPS1/VPS2 MUST run as `User=alex` (not root) whenever possible.

1. **Security**: Reduces attack surface.
2. **Secrets Access**: Ensures native access to `~/.config/secrets` and `age` keys.
3. **Wrapper Requirement**: Use `/atn/github/atn/lib/ops/caddy-wrapper.sh` (or similar) to load secrets at runtime.

### Unraid

| Setting | Value |
|---------|-------|
| **Primary User** | `root` (Unraid default) |
| **SSH Auth** | Tailscale |

### Windows

| Setting | Value |
|---------|-------|
| **Access** | Via WSL (`ssh alex@100.114.18.47`) |
| **WSL Distro** | Debian 13 (trixie) |

---

## Directory Structure (Consistent Across All Servers)

```
/atn/                          # Root for ATN ecosystem
├── github/                    # Git repositories
│   └── atn/                   # Main ATN repo
├── .gemini/                   # Agent configuration
│   ├── scratch/               # Working documents
│   └── rules/                 # Rule definitions
└── worktrees/                 # Git worktree isolation

~/.cache/atn/                  # Local cache (0600 permissions)
~/.config/atn/                 # Configuration files
~/.config/atn/secrets/         # BWS access token (0600)
```

---

## tmpfs Requirements

> **ALWAYS** use tmpfs for working directories, temp files, and cache to avoid physical drive thrashing.

### Standard tmpfs Mounts

| Purpose | Path | Size |
|---------|------|------|
| Temp files | `/tmp` | System default |
| Agent scratch | `/dev/shm/atn` | 512MB |
| Cache overflow | `tmpfs` | As needed |

### Verification Before Use

```bash
# Check if path is on tmpfs
df -T /path | grep tmpfs
# Or
findmnt -n -o FSTYPE /path
```

### Code Pattern

```python
import os
import tempfile

def get_tmpfs_workdir() -> str:
    """Return tmpfs-backed working directory."""
    candidates = [
        "/dev/shm/atn",
        "/run/user/" + str(os.getuid()),
        "/tmp"  # Usually tmpfs on modern systems
    ]
    for path in candidates:
        if os.path.exists(path):
            # Verify it's tmpfs
            result = os.popen(f"df -T {path} 2>/dev/null | tail -1").read()
            if "tmpfs" in result:
                return path
    return tempfile.gettempdir()
```

---

## Naming Conventions

### Keys, Variables, Functions, Filenames

> **ALWAYS** use descriptive and unique names. Never use short or generic names for specific functions.

| ❌ Bad | ✅ Good |
|--------|---------|
| `key` | `jules_api_key_account_1` |
| `token` | `github_pat_atnplex_org` |
| `config` | `antigravity_manager_docker_config` |
| `tmp` | `pr_review_tmpfs_workdir` |
| `data` | `tailscale_network_status_json` |
| `func()` | `rotate_jules_api_key_on_rate_limit()` |
| `secret` | `bws_access_token_vps2_condo` |

### Rationale

1. **Searchability**: Descriptive names are grep-able
2. **Self-documenting**: Purpose is clear without comments
3. **Collision-free**: Unique names prevent overwrites
4. **BWS Integration**: Secrets in BWS need clear identification

---

## SSH Best Practices

### Always Use Tailscale IPs

```bash
# ❌ Bad - hostname may not resolve
ssh root@unraid

# ✅ Good - Tailscale IP always works within tailnet
ssh root@100.76.168.116
```

### SSH Config (Optional Convenience)

```bash
# ~/.ssh/config
Host vps1
    HostName 100.67.88.109
    User alex

Host vps2
    HostName 100.102.55.88
    User alex

Host unraid
    HostName 100.76.168.116
    User root

Host wsl
    HostName 100.114.18.47
    User alex
```

---

## Credentials Storage

| Type | Storage | Reference |
|------|---------|-----------|
| SSH Keys | BWS project `secrets` | `SSH_KEY_<PURPOSE>` |
| API Keys | BWS project `secrets` | `<SERVICE>_API_KEY_<QUALIFIER>` |
| Tokens | BWS project `secrets` | `<SERVICE>_TOKEN_<PURPOSE>` |
| Passwords | BWS project `secrets` | `<SERVICE>_PASSWORD_<USER>` |

See: [R70: BWS Master Reference](/atn/.gemini/rules/security/bws_master.md)

---

## External IP Access (When Enabled)

If external SSH is enabled for VPS1/VPS2:

1. **SSH Key Only** - Password auth disabled
2. **Fail2ban Active** - Auto-ban after 3 failed attempts
3. **Non-standard Port** - Not port 22
4. **Cloudflare Proxy** - If possible, use Cloudflare Spectrum
5. **Notify on Connection** - Alert to monitoring

**Default State**: DISABLED

---

## Quick Reference Commands

```bash
# Refresh Tailscale network data
tailscale status --json | jq '.Peer | to_entries[] | {name: .value.HostName, ip: .value.TailscaleIPs[0]}'

# Check if running on tmpfs
df -T . | grep tmpfs

# Test all server access
for ip in 100.67.88.109 100.102.55.88 100.76.168.116 100.114.18.47; do
  echo "Testing $ip..."
  ssh -o ConnectTimeout=5 -o BatchMode=yes $ip "hostname" 2>/dev/null || echo "FAILED: $ip"
done
```

---

## Cross-References

- [Tailscale Network Reference](/atn/.gemini/scratch/tailscale_network.md) - Full network map
- [R70: BWS Master Reference](/atn/.gemini/rules/security/bws_master.md) - Secrets management
- [SSH Remote Workflow](/home/alex/.gemini/antigravity/global_workflows/ops-ssh-remote.md) - SSH shortcuts
