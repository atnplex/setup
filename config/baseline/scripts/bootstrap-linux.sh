#!/bin/bash
# Linux Bootstrap Script
# Purpose: Standardize any Linux environment (WSL, VPS, Unraid)

set -e

echo "=== Linux Environment Bootstrap ==="

# 1. Install Core Tools
echo ""
echo "[1/5] Installing core dependencies..."
if command -v apt-get &>/dev/null; then
	sudo apt-get update
	sudo apt-get install -y wget curl git unzip ca-certificates
elif command -v yum &>/dev/null; then
	sudo yum install -y wget curl git unzip ca-certificates
else
	echo "ERROR: Unsupported package manager. Please install manually: wget, curl, git, unzip"
	exit 1
fi
echo "Core tools installed."

# 2. Install Bitwarden CLI (bw)
echo ""
echo "[2/5] Installing Bitwarden CLI (bw)..."
if ! command -v bw &>/dev/null; then
	curl -L -o /tmp/bw.zip "https://vault.bitwarden.com/download/?app=cli&platform=linux"
	sudo unzip -o /tmp/bw.zip -d /usr/local/bin
	sudo chmod +x /usr/local/bin/bw
	rm /tmp/bw.zip
	echo "Bitwarden CLI installed: $(bw --version)"
else
	echo "Bitwarden CLI already installed: $(bw --version)"
fi

# 3. Install Bitwarden Secrets Manager (bws)
echo ""
echo "[3/5] Installing Bitwarden Secrets Manager (bws)..."
if ! command -v bws &>/dev/null; then
	VERSION=$(curl -s https://api.github.com/repos/bitwarden/sm/releases/latest | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
	echo "Latest bws version: $VERSION"
	cd /tmp
	curl -L -f -o bws.zip "https://github.com/bitwarden/sm/releases/download/$VERSION/bws-x86_64-unknown-linux-gnu.zip"
	unzip -o bws.zip
	sudo chmod +x bws
	sudo mv bws /usr/local/bin/bws
	rm bws.zip
	echo "Bitwarden SM installed: $(bws --version)"
else
	echo "Bitwarden SM already installed: $(bws --version)"
fi

# 4. Link Baseline (if not in WSL)
echo ""
echo "[4/5] Configuring baseline directory..."
if [ -d "/mnt/c/atn/baseline" ]; then
	echo "WSL detected. Using /mnt/c/atn/baseline"
	mkdir -p ~/.atn
	ln -sf /mnt/c/atn/baseline ~/.atn/baseline
else
	echo "Remote server detected. Cloning baseline..."
	mkdir -p ~/.atn
	if [ ! -d ~/.atn/baseline ]; then
		# TODO: Replace with your actual baseline repo URL
		# git clone https://github.com/yourusername/baseline.git ~/.atn/baseline
		echo "WARNING: Baseline repo not cloned. Please set up manually."
	fi
fi

# 5. Symlink Workflows
echo ""
echo "[5/5] Linking workflows to .agent directory..."
mkdir -p ~/.agent
if [ -d ~/.atn/baseline/workflows ]; then
	ln -sf ~/.atn/baseline/workflows ~/.agent/workflows
	echo "Workflows linked: ~/.agent/workflows -> ~/.atn/baseline/workflows"
else
	echo "WARNING: No workflows found in baseline."
fi

echo ""
echo "=== Bootstrap Complete ==="
echo "Verify with: ls -la ~/.agent/workflows"
