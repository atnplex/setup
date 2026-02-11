# Windows Bootstrap Script
# Purpose: Auto-configure Windows for Linux development via WSL + Tailscale + SSH

#Requires -RunAsAdministrator

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "=== Windows-to-Linux Bootstrap ===" -ForegroundColor Cyan

# 1. Check WSL Installation
Write-Host "`n[1/6] Checking WSL..." -ForegroundColor Yellow
$wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wslInstalled) {
    Write-Host "WSL not found. Installing..." -ForegroundColor Red
    if (-not $DryRun) {
        wsl --install -d Debian --no-launch
        Write-Host "WSL installed. Please RESTART your computer and re-run this script." -ForegroundColor Green
        exit 0
    }
} else {
    Write-Host "WSL is installed." -ForegroundColor Green
}

# 2. Enable systemd in WSL
Write-Host "`n[2/6] Configuring WSL for systemd..." -ForegroundColor Yellow
$wslConf = @"
[boot]
systemd=true
"@
if (-not $DryRun) {
    $wslConf | wsl --user root --exec bash -c "cat > /etc/wsl.conf"
    Write-Host "systemd enabled in WSL." -ForegroundColor Green
}

# 3. Install Core Linux Tools
Write-Host "`n[3/6] Installing Linux dependencies (wget, curl, git)..." -ForegroundColor Yellow
if (-not $DryRun) {
    wsl --user root --exec bash -c "apt-get update && apt-get install -y wget curl git unzip ca-certificates"
    Write-Host "Core tools installed." -ForegroundColor Green
}

# 4. Install Tailscale in WSL
Write-Host "`n[4/6] Installing Tailscale in WSL..." -ForegroundColor Yellow
if (-not $DryRun) {
    wsl --user root --exec bash -c "curl -fsSL https://tailscale.com/install.sh | sh"
    Write-Host "Tailscale installed. Run 'wsl tailscale up --ssh' to authenticate." -ForegroundColor Green
}

# 5. Configure SSH
Write-Host "`n[5/6] Configuring SSH..." -ForegroundColor Yellow
$sshDir = "$env:USERPROFILE\.ssh"
$keyPath = "$sshDir\id_ed25519_antigravity"

if (-not (Test-Path $keyPath)) {
    Write-Host "Generating SSH key..." -ForegroundColor Yellow
    if (-not $DryRun) {
        ssh-keygen -t ed25519 -f $keyPath -N '""' -C "antigravity-wsl"
        Write-Host "SSH key generated: $keyPath" -ForegroundColor Green
    }
}

$sshConfig = @"
# --- Antigravity Managed: WSL Tailscale Direct (SSH) ---
Host antigravity-wsl
    HostName 100.114.18.47
    User alex
    IdentityFile "$keyPath"
    CheckHostIP no
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    IdentitiesOnly yes
    LogLevel ERROR

# --- Antigravity Managed: Local WSL Access (Bridge) ---
Host local-wsl-antigravity
    HostName localhost
    User root
    Port 2222
    IdentityFile "$keyPath"
    IdentitiesOnly yes
    CheckHostIP no
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    LogLevel ERROR
"@

if (-not $DryRun) {
    $sshConfig | Out-File -FilePath "$sshDir\config" -Encoding ascii -Force
    Write-Host "SSH config updated." -ForegroundColor Green
}

# 6. Verify Baseline Directory
Write-Host "`n[6/6] Verifying baseline directory..." -ForegroundColor Yellow
if (-not (Test-Path "C:\atn\baseline")) {
    Write-Host "WARNING: C:\atn\baseline not found. Please ensure your rules/workflows are there." -ForegroundColor Red
} else {
    Write-Host "Baseline directory found: C:\atn\baseline" -ForegroundColor Green
}

Write-Host "`n=== Bootstrap Complete ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart WSL: wsl --terminate Debian" -ForegroundColor White
Write-Host "2. Authenticate Tailscale: wsl tailscale up --ssh" -ForegroundColor White
Write-Host "3. Test SSH: ssh antigravity-wsl" -ForegroundColor White
Write-Host "4. Connect via Antigravity: Remote-SSH -> antigravity-wsl" -ForegroundColor White
