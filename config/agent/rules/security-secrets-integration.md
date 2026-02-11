---
trigger: always_on
---

# Secrets Integration Reference

> **Authority**: GLOBAL SECURITY RULE
> **Scope**: Operational details for secrets system — known issues, wrapper scripts, MCP patterns

---

## Known Issues & Required Fixes

> [!CAUTION]
> These issues were encountered and MUST be avoided.

### BWS `secret get` Requires UUID

- `bws secret get <key_name>` fails — it needs the UUID, not the key name
- **Fix**: `bws secret list | jq -r '.[] | select(.key == "<name>") | .value'`
- **Implemented in**: `mcp_with_secrets.sh:get_from_bws()`

### keyctl Fails in Subshells/Docker

- `keyctl` returns empty in subshells or non-interactive contexts
- **Fix**: Always fallback to direct `age -d` decryption if keyctl fails
- **Implemented in**: `mcp_with_secrets.sh:load_bws_token()`

### Age Key Storage

- Age key stays **LOCAL ONLY** at `/$NAMESPACE/.config/secrets/age.key`
- **NEVER upload age key to BWS** — it's the local decryption key

### Secrets Exposure in Logs

- Secrets visible in `bash -x` traces
- **Fix**: Pipe directly into env vars, avoid intermediate assignments

---

## Key Paths Reference

```
/atn/github/atn/
├── lib/
│   ├── bootstrap/secrets.py     # Python SecretManager
│   └── ops/
│       ├── secrets.sh           # Generic secrets ops
│       └── secrets_bws.sh       # BWS-specific primitives
└── scripts/
    ├── setup/
    │   ├── setup_bws.sh         # BWS CLI installer
    │   └── refresh_secrets.sh   # Cache refresh
    ├── ops/
    │   └── sync_secrets.sh      # Multi-node distribution
    └── qa/
        └── scan_secrets.sh      # Secret detection

~/.config/atn/secrets/age.key         # Local age private key
~/.config/atn/secrets/bws_token.age   # Encrypted BWS token
~/.config/atn/secrets/secrets.age     # Zero-touch bootstrap (primary)
~/.cache/atn/secrets.json             # Local cache (600 perms)
```

---

## MCP Server Secret Injection

Wrapper script: `$NAMESPACE/.gemini/antigravity/scripts/mcp_with_secrets.sh`

Pattern detection in `export_mcp_secrets()`:

| MCP Pattern | Secrets Exported |
|-------------|------------------|
| `*cloudflare*` | `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` |
| `*github*` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `*perplexity*` | `PERPLEXITY_API_KEY` |

To add a new MCP server with secrets:

```json
{
  "new-server": {
    "command": "/home/alex/.gemini/antigravity/scripts/mcp_with_secrets.sh",
    "args": ["npx", "-y", "@org/mcp-server-name"]
  }
}
```

---

## Caching Strategy

| Setting | Value |
|---------|-------|
| Location | `~/.cache/atn/secrets.json` |
| Permissions | `0600` |
| TTL | 1 hour (configurable via `SECRET_CACHE_TTL`) |
| Fallback | BWS API on cache miss |

---

## Mandatory Action on Seeing Exposed Secrets

1. **STOP** current task
2. **ALERT** user: "Found exposed secret in [file]"
3. **CONFIRM** how to proceed
4. **MIGRATE** to BWS
5. **REMOVE** from file
6. **ROTATE** (consider compromised)
7. **DOCUMENT** in security incidents log
