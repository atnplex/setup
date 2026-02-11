#!/usr/bin/env pwsh
# Unified Bootstrap Script
# Works on Windows, WSL, and Linux
# Usage: irm https://raw.githubusercontent.com/yourusername/baseline/main/bootstrap.ps1 | iex

$ErrorActionPreference = "Stop"

# Detect environment
$IsWindows = $PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows
$IsWSL = Test-Path "/proc/version" -and (Get-Content "/proc/version" -Raw) -match "microsoft|WSL"
$IsLinux = $PSVersionTable.Platform -eq "Unix" -and -not $IsWSL

Write-Host "=== Unified Bootstrap ===" -ForegroundColor Cyan
Write-Host "Detecting environment..." -ForegroundColor Yellow

if ($IsWindows) {
    Write-Host "Environment: Windows" -ForegroundColor Green
    
    # Check if running as Administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "ERROR: Please run as Administrator" -ForegroundColor Red
        Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }
    
    # 1. Check WSL
    Write-Host "`n[1/5] Checking WSL..." -ForegroundColor Yellow
    $wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
    if (-not $wslInstalled) {
        Write-Host "Installing WSL (Debian)..." -ForegroundColor Red
        wsl --install -d Debian --no-launch
        Write-Host "WSL installed. Please RESTART your computer and re-run this script." -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "WSL is installed." -ForegroundColor Green
    }
    
    # 2. Enable systemd in WSL
    Write-Host "`n[2/5] Configuring WSL for systemd..." -ForegroundColor Yellow
    $wslConf = @"
[boot]
systemd=true
"@
    $wslConf | wsl --user root --exec bash -c "cat > /etc/wsl.conf"
    Write-Host "systemd enabled." -ForegroundColor Green
    
    # 3. Install Linux dependencies in WSL
    Write-Host "`n[3/5] Installing Linux dependencies in WSL..." -ForegroundColor Yellow
    wsl --user root --exec bash -c "apt-get update && apt-get install -y wget curl git unzip ca-certificates"
    Write-Host "Dependencies installed." -ForegroundColor Green
    
    # 4. Install Tailscale in WSL
    Write-Host "`n[4/5] Installing Tailscale in WSL..." -ForegroundColor Yellow
    wsl --user root --exec bash -c "curl -fsSL https://tailscale.com/install.sh | sh"
    Write-Host "Tailscale installed." -ForegroundColor Green
    
    # 5. Configure SSH
    Write-Host "`n[5/5] Configuring SSH..." -ForegroundColor Yellow
    $sshDir = "$env:USERPROFILE\.ssh"
    $keyPath = "$sshDir\id_ed25519_antigravity"
    
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    
    if (-not (Test-Path $keyPath)) {
        Write-Host "Generating SSH key..." -ForegroundColor Yellow
        ssh-keygen -t ed25519 -f $keyPath -N '""' -C "antigravity-wsl"
        Write-Host "SSH key generated." -ForegroundColor Green
    }
    
    # Get Tailscale IP from WSL
    $tailscaleIP = wsl --exec bash -c "tailscale ip -4 2>/dev/null || echo '100.114.18.47'"
    
    $sshConfig = @"
# --- Antigravity Managed: WSL Tailscale Direct (SSH) ---
Host antigravity-wsl
    HostName $tailscaleIP
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
    
    $sshConfig | Out-File -FilePath "$sshDir\config" -Encoding ascii -Force
    Write-Host "SSH config updated." -ForegroundColor Green
    
    # Now run Linux bootstrap inside WSL
    Write-Host "`n=== Running Linux Bootstrap in WSL ===" -ForegroundColor Cyan
    wsl --exec bash -c "curl -fsSL https://raw.githubusercontent.com/yourusername/baseline/main/bootstrap-linux.sh | bash"
    
    Write-Host "`n=== Bootstrap Complete ===" -ForegroundColor Cyan
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Restart WSL: wsl --terminate Debian" -ForegroundColor White
    Write-Host "2. Authenticate Tailscale: wsl tailscale up --ssh" -ForegroundColor White
    Write-Host "3. Test SSH: ssh antigravity-wsl" -ForegroundColor White
    Write-Host "4. Connect via Antigravity: Remote-SSH -> antigravity-wsl" -ForegroundColor White
    
}
elseif ($IsWSL -or $IsLinux) {
    Write-Host "Environment: Linux/WSL" -ForegroundColor Green
    
    # Run Linux bootstrap
    Write-Host "`n=== Running Linux Bootstrap ===" -ForegroundColor Cyan
    
    # 1. Install Core Tools
    Write-Host "`n[1/5] Installing core dependencies..." -ForegroundColor Yellow
    if (Get-Command apt-get -ErrorAction SilentlyContinue) {
        sudo apt-get update
        sudo apt-get install -y wget curl git unzip ca-certificates
    }
    elseif (Get-Command yum -ErrorAction SilentlyContinue) {
        sudo yum install -y wget curl git unzip ca-certificates
    }
    else {
        Write-Host "ERROR: Unsupported package manager" -ForegroundColor Red
        exit 1
    }
    Write-Host "Core tools installed." -ForegroundColor Green
    
    # 2. Install Bitwarden CLI (bw)
    Write-Host "`n[2/5] Installing Bitwarden CLI (bw)..." -ForegroundColor Yellow
    if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
        curl -L -o /tmp/bw.zip "https://vault.bitwarden.com/download/?app=cli&platform=linux"
        sudo unzip -o /tmp/bw.zip -d /usr/local/bin
        sudo chmod +x /usr/local/bin/bw
        rm /tmp/bw.zip
        Write-Host "Bitwarden CLI installed: $(bw --version)" -ForegroundColor Green
    }
    else {
        Write-Host "Bitwarden CLI already installed." -ForegroundColor Green
    }
    
    # 3. Install Bitwarden Secrets Manager (bws)
    Write-Host "`n[3/5] Installing Bitwarden Secrets Manager (bws)..." -ForegroundColor Yellow
    if (-not (Get-Command bws -ErrorAction SilentlyContinue)) {
        $version = (curl -s https://api.github.com/repos/bitwarden/sm/releases/latest | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
        Write-Host "Latest bws version: $version" -ForegroundColor Cyan
        curl -L -f -o /tmp/bws.zip "https://github.com/bitwarden/sm/releases/download/$version/bws-x86_64-unknown-linux-gnu.zip"
        cd /tmp
        unzip -o bws.zip
        sudo chmod +x bws
        sudo mv bws /usr/local/bin/bws
        rm bws.zip
        Write-Host "Bitwarden SM installed: $(bws --version)" -ForegroundColor Green
    }
    else {
        Write-Host "Bitwarden SM already installed." -ForegroundColor Green
    }
    
    # 4. Link Baseline
    Write-Host "`n[4/5] Configuring baseline directory..." -ForegroundColor Yellow
    if (Test-Path "/mnt/c/atn/baseline") {
        Write-Host "WSL detected. Using /mnt/c/atn/baseline" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path "$HOME/.atn" -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path "$HOME/.atn/baseline" -Target "/mnt/c/atn/baseline" -Force | Out-Null
    }
    else {
        Write-Host "Remote server detected." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path "$HOME/.atn" -Force | Out-Null
        if (-not (Test-Path "$HOME/.atn/baseline")) {
            Write-Host "Cloning baseline repo..." -ForegroundColor Yellow
            # TODO: Replace with your actual baseline repo URL
            # git clone https://github.com/yourusername/baseline.git ~/.atn/baseline
            Write-Host "WARNING: Baseline repo not cloned. Please set up manually." -ForegroundColor Red
        }
    }
    
    # 5. Symlink Workflows
    Write-Host "`n[5/5] Linking workflows..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "$HOME/.agent" -Force | Out-Null
    if (Test-Path "$HOME/.atn/baseline/workflows") {
        New-Item -ItemType SymbolicLink -Path "$HOME/.agent/workflows" -Target "$HOME/.atn/baseline/workflows" -Force | Out-Null
        Write-Host "Workflows linked: ~/.agent/workflows -> ~/.atn/baseline/workflows" -ForegroundColor Green
    }
    else {
        Write-Host "WARNING: No workflows found in baseline." -ForegroundColor Red
    }
    
    Write-Host "`n=== Bootstrap Complete ===" -ForegroundColor Cyan
    Write-Host "Verify with: ls -la ~/.agent/workflows" -ForegroundColor Yellow
    
}
else {
    Write-Host "ERROR: Unable to detect environment" -ForegroundColor Red
    exit 1
}
