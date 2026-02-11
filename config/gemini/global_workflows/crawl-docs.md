---
description: Crawl documentation sites efficiently with parallel Jina Reader
---

# /crawl-docs Workflow

Batch crawl documentation sites using parallel Jina Reader requests.

## Usage

```
/crawl-docs <base_url>              # Crawl with auto-discovery
/crawl-docs <base_url> --sitemap    # Use sitemap.xml
/crawl-docs <url1> <url2> <url3>    # Specific URLs
```

## Steps

// turbo-all

### 1. Discover URLs

**Option A: Sitemap**

```bash
curl -s "https://example.com/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' > /dev/shm/urls.txt
```

**Option B: Manual list**

```bash
echo "https://docs.example.com/intro
https://docs.example.com/api
https://docs.example.com/config" > /dev/shm/urls.txt
```

### 2. Parallel Fetch with Jina Reader

Use parallel `read_url_content` calls with Jina prefix:

```python
# Pseudocode - agent executes via tool calls
urls = ["https://r.jina.ai/" + url for url in url_list]
# Call read_url_content in parallel (up to 10 concurrent)
```

**Rate limits:**

- No API key: 20 RPM
- With API key: 200 RPM
- Batch in groups of 10-20 for safety

### 3. Write to RAM (tmpfs)

```bash
# Write results to /dev/shm for speed
mkdir -p /dev/shm/crawl_output
```

### 4. Process with Flash

For large document sets, use Gemini Flash for summarization:

- Extract key concepts
- Build index/TOC
- Identify code examples

### 5. Persist Results

```bash
# Move from RAM to persistent storage
mv /dev/shm/crawl_output/* /atn/.gemini/knowledge/
```

## Fallback Chain (R54)

1. **Jina Reader** (`r.jina.ai/URL`) - Free, fast
2. **Firecrawl** - If Jina fails or rate limited
3. **Browser subagent** - Last resort for complex SPAs

## Anti-Bot Handling

If Cloudflare blocks:

1. Try Jina first (has some bypass)
2. Use Flaresolverr Docker container
3. Browser subagent with delays

## Example: Crawl Antigravity Docs

```bash
# Get URLs from sitemap
curl -s "https://antigravity.dev/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' | head -20 > /dev/shm/urls.txt

# Agent runs parallel Jina fetches
# Results written to /atn/.gemini/knowledge/antigravity/
```

## Output Structure

```
/atn/.gemini/knowledge/<site>/
├── index.md          # TOC and overview
├── pages/            # Individual page content
│   ├── intro.md
│   ├── api.md
│   └── config.md
└── metadata.json     # Crawl stats, timestamps
```
