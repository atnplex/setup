---
name: parallel-research
description: Fast research via parallel Flash summarization with tmpfs and consolidation
keywords: [research, parallel, summarize, fast, tmpfs, consolidate]
argument-hint: <topic or repo URLs>
model_pattern: flash-sonnet-opus
context: fork
---

# Parallel Research Skill

> **Purpose**: Accelerate research by parallelizing with fast models, then consolidating

## Pattern Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    PARALLEL RESEARCH                        │
├─────────────────────────────────────────────────────────────┤
│  Phase 1: PARALLEL (Flash/Gemini Pro)                       │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │ Summarize│ │ Summarize│ │ Summarize│ │ Summarize│          │
│  │ Repo A   │ │ Repo B   │ │ File 1   │ │ File 2   │          │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                │
│       ▼            ▼            ▼            ▼                │
│  ┌──────────────────────────────────────────────────┐       │
│  │              tmpfs (/dev/shm/)                   │       │
│  │  summary_a.md  summary_b.md  summary_1.md  ...   │       │
│  └──────────────────────────────────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│  Phase 2: CONSOLIDATE (Sonnet)                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │ Read all summaries → merge → identify patterns   │       │
│  │ Write consolidated findings to persistent file   │       │
│  └──────────────────────────────────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│  Phase 3: REASON (Opus)                                     │
│  ┌──────────────────────────────────────────────────┐       │
│  │ Deep analysis on consolidated notes              │       │
│  │ Extract insights, make decisions                 │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## When to Use

- Researching multiple repositories
- Reviewing many files for patterns
- Comparing alternatives
- Gathering information from multiple sources
- Any task where parallelization speeds things up

## Implementation

### Phase 1: Parallel Summarization

Use Flash or Gemini Pro for speed:

```bash
# Create tmpfs workspace
mkdir -p /dev/shm/research-$$

# Parallel workers write to separate files
# Worker 1: /dev/shm/research-$$/repo_a.md
# Worker 2: /dev/shm/research-$$/repo_b.md
# Worker 3: /dev/shm/research-$$/file_1.md
```

Each worker:

1. Reads source (repo, file, URL)
2. Summarizes key points
3. Writes to dedicated tmpfs file

### Phase 2: Consolidation

Use Sonnet for quality synthesis:

```bash
# Read all summaries
cat /dev/shm/research-$$/*.md > /dev/shm/research-$$/all_summaries.md

# Consolidate to persistent storage
# → ~/.gemini/antigravity/brain/<session>/research_findings.md
```

Consolidation tasks:

- Merge duplicate findings
- Identify patterns across summaries
- Organize by theme/category
- Flag items needing deeper review

### Phase 3: Deep Reasoning

Use Opus for decisions:

- Analyze consolidated findings
- Make recommendations
- Identify high-value actions
- Plan next steps

## Benefits

| Benefit | Impact |
|---------|--------|
| **Speed** | 5-10x faster than serial research |
| **Token Cost** | Flash is cheaper per token |
| **Load Distribution** | Spreads across model providers |
| **Disk I/O** | tmpfs avoids disk thrashing |
| **Quality** | Opus focuses on reasoning, not summarizing |

## tmpfs Locations

| Location | Notes |
|----------|-------|
| `/dev/shm/` | Guaranteed tmpfs on Linux |
| `/tmp/` | Often tmpfs, check with `df -h /tmp` |
| `/run/user/$UID/` | Per-user tmpfs |

## Integration

Use with:

- `context-compression` - Compress before storing
- `filesystem-context` - Manage context offloading
- `mcp-memory` - Store key findings as entities

## Example Workflow

```yaml
research_task:
  phase1_parallel:
    model: gemini-flash
    workers:
      - summarize: https://github.com/repo1/README.md
        output: /dev/shm/research/repo1.md
      - summarize: https://github.com/repo2/README.md
        output: /dev/shm/research/repo2.md
      - summarize: /path/to/local/file.md
        output: /dev/shm/research/local.md

  phase2_consolidate:
    model: sonnet
    input: /dev/shm/research/*.md
    output: ~/brain/research_findings.md
    tasks:
      - merge_duplicates
      - identify_patterns
      - categorize_findings

  phase3_reason:
    model: opus
    input: ~/brain/research_findings.md
    tasks:
      - make_recommendations
      - prioritize_actions
```

## Cleanup

Always clean up tmpfs after consolidation:

```bash
rm -rf /dev/shm/research-$$
```
