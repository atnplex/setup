# Unified Bootstrap Scripts

One-command setup for Windows, WSL, and Linux environments.

## Quick Start

### Windows (PowerShell as Administrator)

```powershell
irm https://raw.githubusercontent.com/yourusername/baseline/main/bootstrap.ps1 | iex
```

### Linux/WSL (Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/baseline/main/bootstrap.sh | bash
```

### Local Testing

```powershell
# Windows
C:\atn\baseline\scripts\bootstrap.ps1

# Linux/WSL
bash /mnt/c/atn/baseline/scripts/bootstrap.sh
```

## What Gets Installed

- ✅ Core tools: `wget`, `curl`, `git`, `unzip`, `ca-certificates`
- ✅ Bitwarden CLI (`bw`) and Secrets Manager (`bws`)
- ✅ Workflow symlinks to `~/.agent/workflows`
- ✅ **Windows only**: WSL (Debian), Tailscale, SSH configuration

## How It Works

The bootstrap script automatically detects your environment:

- **Windows**: Installs WSL + Tailscale + SSH, then runs Linux bootstrap inside WSL
- **WSL**: Creates symlinks to `/mnt/c/atn/baseline/workflows`
- **Linux**: Clones baseline repo and creates workflow symlinks

## Files

- **bootstrap.ps1** - Unified PowerShell script with OS detection
- **bootstrap.sh** - Bash wrapper with PowerShell fallback
- **bootstrap-windows.ps1** - Legacy Windows-only script
- **bootstrap-linux.sh** - Legacy Linux-only script

## Next Steps

1. Push these scripts to your GitHub baseline repo
2. Update URLs in scripts (replace `yourusername/baseline` with your repo)
3. Test on a fresh machine!

## Troubleshooting

**Windows: "WSL not found"**

- Script will install WSL automatically
- Restart computer after WSL installation
- Re-run the bootstrap script

**Linux: "Permission denied"**

- Run with sudo: `curl -fsSL ... | sudo bash`

**Workflows not appearing**

- Verify symlink: `ls -la ~/.agent/workflows`
- Check baseline: `ls -la ~/.atn/baseline/workflows`
- Reconnect to remote host in Antigravity
