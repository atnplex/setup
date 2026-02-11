# R56: Workflow Auto-Routing

> Automatically match user requests to relevant workflows via keywords.

## Source of Truth

`/atn/.gemini/tool_manifest.yaml` - Contains keyword mappings for:

- Tools
- Skills
- Workflows

## Routing Priority

1. **Explicit slash command** (`/crawl-docs`) → Execute immediately
2. **auto_trigger: true** → Load if keywords match
3. **Keyword match** → Suggest to user or load silently

## How It Works

```yaml
# In tool_manifest.yaml
workflows:
  crawl-docs:
    keywords: [crawl, scrape, docs, documentation, index]
    auto_trigger: false
```

When user says "crawl the API documentation", agent:

1. Scans request for keywords
2. Matches "crawl" + "documentation" → `crawl-docs`
3. Loads `/home/alex/.agent/workflows/crawl-docs.md`
4. Follows workflow steps

## Adding New Workflows

1. Create workflow file in `/home/alex/.agent/workflows/`
2. Add entry to `tool_manifest.yaml` under `workflows:`
3. Define keywords that trigger it
4. Set `auto_trigger: true` for mandatory workflows

## Keyword Guidelines

- Use action verbs: crawl, deploy, merge, check
- Use domain nouns: docs, pr, server, inventory
- Keep lists focused (5-10 keywords max)
- Avoid overly generic words that match everything
