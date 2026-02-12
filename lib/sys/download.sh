#!/usr/bin/env bash
# Module: sys/download
# Version: 0.1.0
# Provides: Download, extract, and install helpers
# Requires: none
[[ -n "${_STDLIB_DOWNLOAD:-}" ]] && return 0
declare -g _STDLIB_DOWNLOAD=1

# ── stdlib::download::file ────────────────────────────────────────────
# Download a URL to a destination file. Falls back curl → wget.
# Usage: stdlib::download::file url dest [mode]
stdlib::download::file() {
  local url="$1"
  local dest="$2"
  local mode="${3:-}"

  if command -v curl &>/dev/null; then
    curl -fsSL -o "$dest" "$url"
  elif command -v wget &>/dev/null; then
    wget -qO "$dest" "$url"
  else
    echo "ERROR: Neither curl nor wget available" >&2
    return 1
  fi

  [[ -n "$mode" ]] && chmod "$mode" "$dest"
}

# ── stdlib::download::pipe ────────────────────────────────────────────
# Download URL to stdout (for piped installs like curl | sh).
stdlib::download::pipe() {
  local url="$1"

  if command -v curl &>/dev/null; then
    curl -fsSL "$url"
  elif command -v wget &>/dev/null; then
    wget -qO- "$url"
  else
    echo "ERROR: Neither curl nor wget available" >&2
    return 1
  fi
}

# ── stdlib::download::extract ─────────────────────────────────────────
# Download and extract an archive. Supports .tar.gz, .tar.xz, .zip.
# Usage: stdlib::download::extract url dest_dir
stdlib::download::extract() {
  local url="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  stdlib::download::file "$url" "$tmpfile"

  case "$url" in
    *.tar.gz|*.tgz)  tar -xzf "$tmpfile" -C "$dest_dir" ;;
    *.tar.xz)        tar -xJf "$tmpfile" -C "$dest_dir" ;;
    *.tar.bz2)       tar -xjf "$tmpfile" -C "$dest_dir" ;;
    *.zip)           unzip -qo "$tmpfile" -d "$dest_dir" ;;
    *)               echo "WARN: Unknown archive format, attempting tar" >&2
                     tar -xf "$tmpfile" -C "$dest_dir" ;;
  esac
}

# ── stdlib::download::binary ──────────────────────────────────────────
# Download a binary and install it to a PATH location.
# Usage: stdlib::download::binary url name [dest_dir]
stdlib::download::binary() {
  local url="$1"
  local name="$2"
  local dest_dir="${3:-/usr/local/bin}"
  local dest="${dest_dir}/${name}"

  stdlib::download::file "$url" "$dest" "755"
}

# ── stdlib::download::verify ──────────────────────────────────────────
# Download a file and verify its SHA-256 checksum.
# Usage: stdlib::download::verify url dest expected_sha256
stdlib::download::verify() {
  local url="$1"
  local dest="$2"
  local expected="$3"

  stdlib::download::file "$url" "$dest"

  local actual
  actual=$(sha256sum "$dest" | awk '{print $1}')

  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: Checksum mismatch for $dest" >&2
    echo "  Expected: $expected" >&2
    echo "  Actual:   $actual" >&2
    rm -f "$dest"
    return 1
  fi
}

# ── stdlib::download::github_release ──────────────────────────────────
# Download the latest release asset from a GitHub repo.
# Usage: stdlib::download::github_release owner repo [asset_pattern] [dest]
stdlib::download::github_release() {
  local owner="$1"
  local repo="$2"
  local pattern="${3:-}"
  local dest="${4:-}"

  local api_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"
  local release_json
  release_json=$(stdlib::download::pipe "$api_url")

  local download_url
  if [[ -n "$pattern" ]]; then
    download_url=$(echo "$release_json" | grep -oP '"browser_download_url":\s*"\K[^"]*'"$pattern"'[^"]*')
  else
    download_url=$(echo "$release_json" | grep -oP '"browser_download_url":\s*"\K[^"]*' | head -1)
  fi

  if [[ -z "$download_url" ]]; then
    echo "ERROR: No matching release asset for ${owner}/${repo} (pattern: ${pattern:-any})" >&2
    return 1
  fi

  if [[ -n "$dest" ]]; then
    stdlib::download::file "$download_url" "$dest"
  else
    printf '%s' "$download_url"
  fi
}
