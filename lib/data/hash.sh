#!/usr/bin/env bash
# Module: data/hash
# Version: 0.1.0
# Provides: Hashing, checksum, and encoding utilities
# Requires: none
[[ -n "${_STDLIB_HASH:-}" ]] && return 0
declare -g _STDLIB_HASH=1

# ── stdlib::hash::md5 ─────────────────────────────────────────────────
# MD5 hash of a string.
stdlib::hash::md5() {
  printf '%s' "$1" | md5sum | awk '{print $1}'
}

# ── stdlib::hash::sha256 ──────────────────────────────────────────────
# SHA-256 hash of a string.
stdlib::hash::sha256() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

# ── stdlib::hash::sha256_file ─────────────────────────────────────────
# SHA-256 checksum of a file.
stdlib::hash::sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

# ── stdlib::hash::hmac_sha256 ─────────────────────────────────────────
# HMAC-SHA256 for API authentication.
# Usage: stdlib::hash::hmac_sha256 key data
stdlib::hash::hmac_sha256() {
  local key="$1" data="$2"
  printf '%s' "$data" | openssl dgst -sha256 -hmac "$key" -binary | xxd -p -c 256
}

# ── stdlib::hash::base64_encode ───────────────────────────────────────
# Base64 encode a string.
stdlib::hash::base64_encode() {
  printf '%s' "$1" | base64 -w 0
}

# ── stdlib::hash::base64_decode ───────────────────────────────────────
# Base64 decode a string.
stdlib::hash::base64_decode() {
  printf '%s' "$1" | base64 -d
}

# ── stdlib::hash::crc32 ───────────────────────────────────────────────
# CRC32 checksum of a string (requires cksum).
stdlib::hash::crc32() {
  printf '%s' "$1" | cksum | awk '{print $1}'
}
