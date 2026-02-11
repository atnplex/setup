# Parallel Processing and Model Selection

> Consolidated from R44, R58, R66. Covers parallelization, model tiering, and delegation.

## Core Principle

**Same quality, optimal resource usage.** Never sacrifice output quality for token savings, but use the most efficient model that produces equivalent results.

## When to Parallelize

| Scenario | Action |
| -------- | ------ |
| Multiple PRs | Parallel browser subagents |
| Multiple files to read | Parallel `view_file` / `read_multiple_files` |
| Multiple API requests | Parallel MCP calls |
| Similar operations | Batch with parallel tool calls |

**Max parallelism**: ~4-6 concurrent operations. Use `waitForPreviousTools: true` only when dependencies exist.

## Model Selection Matrix

| Task Type | Recommended Model | Fallback |
| --------- | ----------------- | -------- |
| Data gathering | Parallel I/O (no model) | — |
| Simple (classify, QA) | Flash / Ollama | — |
| Standard (code gen, refactor) | Pro / Sonnet | Flash |
| Complex (architecture, security) | Opus / Thinking | Pro |
| Reasoning-heavy | Opus Thinking | — |

## Auto-Detection Triggers

| Keywords | Approach |
| -------- | -------- |
| fetch, crawl, download, collect | Parallel I/O (free) |
| summarize, extract, classify, parse | Parallel Flash (cheap) |
| design, architect, review, plan | Single Pro/Opus (quality) |

## Token Budget Strategy

| Budget | Action |
| ------ | ------ |
| Excess tokens | Use higher-tier models freely |
| Near limit | Thrifty mode: cheaper models, less parallelism |
| At limit | Cascade: Ollama → Flash → Pro → Opus |

> If tokens are expiring unused, they are being wasted.

## Resource Priority

1. **Google Pro accounts (15+)** — rotate accounts to maximize usage
2. **Ollama on VPS1/VPS2 (24GB RAM)** — free, no limits; use for classification/triage
3. **Perplexity Pro accounts** — research and validation

## Delegation Pattern

When spawning tasks, select model based on complexity:

```yaml
child_task:
  model: <select by complexity>
  account: <rotate to unused quota>
  fallback_model: <cheaper alternative>
```

## Tool Priority Order

| Priority | Method | When to Use |
| -------- | ------ | ----------- |
| 1st | MCP tools (`mcp_*`) | Always try first |
| 2nd | Parallel Flash models | Bulk processing, research |
| 3rd | `read_url_content` | Static HTML pages |
| 4th | CLI commands | System operations |
| 5th | Browser subagent | **LAST RESORT ONLY** |

Browser subagent only when: auth required, visual verification needed, all other methods failed.

## JS Rendering Fallback Chain

1. **Jina Reader**: `https://r.jina.ai/{url}` — free, fast
2. **Firecrawl MCP**: API-based rendering
3. **Browser subagent**: Last resort

## Manual Fallback

When direct delegation isn't possible, provide copy-paste prompts with:

- Clear task description
- Output file path
- Recommended model and mode (`fast` / `planning` / `thinking`)
