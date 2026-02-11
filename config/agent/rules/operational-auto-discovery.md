# R59: Automatic Tool & Resource Discovery

> Dynamically discover and load relevant tools, workflows, skills, and MCP servers based on request keywords.

## SSOT

`/atn/.gemini/tool_manifest.yaml`

## Discovery Flow

```
User Request
    ↓
1. Extract Keywords
    ↓
2. Search Manifest (parallel keyword match)
    ↓
3. Evaluate Descriptions (filter false positives)
    ↓
4. Load Resources
    ↓
5. Execute with optimal pattern
```

## Step 1: Keyword Extraction

Extract meaningful keywords from user request:

- Nouns: "crawl the docs" → ["crawl", "docs"]
- Verbs: "summarize these files" → ["summarize", "files"]
- Technical terms: "deploy to VPS" → ["deploy", "VPS"]

## Step 2: Manifest Search

For each extracted keyword, search `tool_manifest.yaml`:

- Match against `keywords` arrays in workflows, skills, mcp_servers, tools
- Score: number of keyword matches
- Threshold: 2+ matches = high relevance

## Step 3: Description Evaluation

For items with 1 keyword match (potential false positive):

- Read `description` field
- Check "Use for:" section matches intent
- Discard if description doesn't match context

## Step 4: Resource Loading

Load items by priority:

1. **Always loaded**: Already available (github, fetch, git, memory, filesystem, perplexity)
2. **Triggered**: Load via `load_trigger` match (playwright for "login")
3. **Skills**: Read `path` to load SKILL.md
4. **Workflows**: Suggest `/workflow-name` if high confidence

## Step 5: Processing Pattern Selection

From `processing_patterns` section:

| If keywords match... | Then... |
|----------------------|---------|
| `parallel_io` triggers | Parallel I/O, no model |
| `parallel_flash` triggers + 3+ items | Parallel Flash calls |
| `single_reasoning` triggers | Single Pro call |
| `critical_thinking` triggers | Opus with thinking |

## Auto-Trigger Rules

| Condition | Action |
|-----------|--------|
| "crawl" + multiple URLs | Auto-invoke `/crawl-docs` |
| "deploy" + service name | Suggest `/deploy-service` |
| "summarize" + 3+ items | Use parallel Flash |
| "research" + topic | Load parallel-research skill |
| "create" + feature | Load brainstorming skill |
| "done" + task | Load verification skill |

## Low False Positive Strategy

1. **Multi-keyword required**: Single keyword match not sufficient
2. **Description validation**: Check "Use for:" matches intent
3. **Context awareness**: Consider conversation history
4. **Confidence threshold**: Only auto-trigger at 80%+ confidence
5. **Suggest vs auto**: Lower confidence = suggest, higher = auto

## Example

**Request**: "Crawl the Next.js docs and summarize each page"

1. **Keywords**: [crawl, docs, summarize, page]
2. **Matches**:
   - crawl-docs workflow: 2 matches (crawl, docs)
   - parallel-research skill: 1 match (research-related)
   - read_url_content: 1 match (page)
3. **Description check**:
   - crawl-docs: "batch crawl documentation sites" ✅
   - parallel-research: "researching multiple topics" ❌ (summarize != research)
4. **Load**: crawl-docs workflow
5. **Pattern**: "summarize" + multiple pages → parallel_flash
6. **Execute**: Crawl with parallel I/O, then summarize with parallel Flash
