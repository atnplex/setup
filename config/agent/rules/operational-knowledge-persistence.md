# R52: Knowledge Persistence

> **Authority**: GLOBAL OPERATIONAL RULE
> **Severity**: HIGH - prevents context loss and repetition
> **Updated**: 2026-02-03

---

## Core Principle

**Capture knowledge proactively.** When discovering relevant data, relationships, or patterns through any means (web scrape, code review, user discussion, command output), immediately record it in an appropriate persistent location.

---

## What to Capture

| Discovery Type | Example | Storage Location |
| -------------- | ------- | ---------------- |
| **Infrastructure data** | Tailscale IPs, server specs | `/atn/.gemini/scratch/tailscale_network.md`, `inventory.md` |
| **User preferences** | Naming conventions, access patterns | Rules in `/atn/.gemini/rules/` |
| **Relationships** | Service dependencies, API connections | MCP Memory or relevant docs |
| **Credentials/Secrets** | API keys, tokens | BWS (never in files) |
| **Patterns** | Code conventions, workflow preferences | Rules or skill docs |
| **Commands that worked** | SSH shortcuts, useful one-liners | Workflow files |

---

## Storage Methods (Priority Order)

1. **Rules** (`/atn/.gemini/rules/`) - For preferences and standards that should always apply
2. **Scratch docs** (`/atn/.gemini/scratch/`) - For reference data (inventories, network maps)
3. **MCP Memory** - For relationships and cross-session context
4. **Workflow files** - For operational procedures and commands
5. **BWS** - For secrets (SSOT, never duplicated elsewhere)

---

## Triggers for Capture

Capture knowledge when:

- User explains a preference or convention
- A command reveals infrastructure data (IPs, hostnames, services)
- Web scrape returns useful reference information
- Error resolution reveals a pattern
- Discussion reveals relationships between systems
- User corrects an assumption

---

## Format Requirements

When creating persistent records:

1. **Be specific** - Include exact values, not summaries
2. **Include source** - Note where the data came from
3. **Add timestamp** - When was this discovered/updated
4. **Cross-reference** - Link to related documents
5. **Make findable** - Use descriptive filenames and headers

---

## Anti-Patterns (Never Do)

| ❌ Bad | ✅ Good |
| ------ | ------- |
| Relying on context to remember IPs | Recording IPs in `tailscale_network.md` |
| Asking user to repeat preferences | Creating a rule file |
| Assuming infrastructure details | Querying and documenting |
| Storing secrets in scratch files | Using BWS exclusively |

---

## Automatic Discovery Hooks

When executing commands, automatically extract and store:

```bash
# Tailscale network → tailscale_network.md
tailscale status --json

# Server specs → inventory.md
hostname; uname -a; free -h; df -h

# Docker services → inventory.md or service docs
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# Git remotes → project docs
git remote -v
```

---

## Cross-References

- [R61: Infrastructure Standards](/atn/.gemini/rules/operational/infrastructure_standards.md)
- [Tailscale Network Reference](/atn/.gemini/scratch/tailscale_network.md)
- [Inventory](/atn/.gemini/scratch/inventory.md)
