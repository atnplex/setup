---
name: perplexity-co-op
description: Perplexity research router with key rotation, validation, caching, and repo-ready artifacts.
version: 1.0.0
schema_version: 1.0.0
---

# perplexity-co-op

## Purpose

Run Perplexity research tasks with citations-first answers and deterministic, repo-ready outputs (Markdown + JSON), using 3 API keys with automatic rotation, backoff, caching, validation/repair, and multi-agent handoff artifacts.

## Inputs (parameters)

- topic (required): short title
- questions (required): list of 1–2 sentence research questions
- constraints (optional): defaults to "academic preferred; 2025-2026; actionable; include links"
- tech_profile (optional): prepend to each query to avoid generic advice
  Default: "OCI Debian ARM (systemd), Unraid 6.12.x, Docker/Compose, Bash-first automation, Tailscale mesh, Cloudflare tunnels/Zero Trust; avoid Kubernetes unless requested."
- output_mode: brief|standard|deep (default standard; controls queries/question: 1/2/3)
- output_format: research|adr (default research)
- priority (optional): p0|p1|p2 per question (default all p0)
- repo_write (bool default false)
- repo_root (optional): repo path if writing artifacts
- paths (optional; used if repo_write=true):
  - md: docs/research/perplexity/<topic-slug>.md
  - json: artifacts/perplexity/<topic-slug>.json
  - manifest: artifacts/perplexity/<topic-slug>-run.json
  - handoff: artifacts/perplexity/<topic-slug>-handoff.json
  - index: docs/research/perplexity/INDEX.md
- changelog (bool default true): append a short changelog line when updating existing MD
- dry_run (bool default false): no API calls, no repo writes; simulate rotation/cost
- debug (bool default false): sanitized verbose logs

## Environment variables

### Required secrets (never print, never commit)

- PERPLEXITY_API_KEY_1
- PERPLEXITY_API_KEY_2
- PERPLEXITY_API_KEY_3

### Optional config

- PERPLEXITY_API_BASE_URL
- PERPLEXITY_MODEL_PRIMARY
- PERPLEXITY_MODEL_FALLBACK
- PERPLEXITY_TIMEOUT_S (default 60)
- PERPLEXITY_MAX_RETRIES (default 4)
- PERPLEXITY_MAX_RETRIES_PER_QUESTION (default 2)
- PERPLEXITY_DAILY_SOFT_LIMIT_USD (default 0.50)
- PERPLEXITY_MONTHLY_SOFT_LIMIT_USD (default 15.00)
- PERPLEXITY_CACHE_ENABLED (default true)
- NOTIFICATION_WEBHOOK_URL (optional)
- TELEMETRY_WEBHOOK_URL (optional)

## Contracts (determinism + audit)

Every run must embed:

- workflow_version, schema_version
- run_id, started_at, finished_at (ISO8601)
- model_used, key_index_used
- inputs_hash, outputs_hash
- retry_events[] (reason + strategy) and key_ledger snapshot (sanitized)

## Key rotation + retry rules

Maintain runtime key_ledger:

- active_key_index 1..3
- keys[i]: status=ready|cooldown|disabled|invalid, cooldown_until, requests_count, last_error

Rotation triggers:

- 401/403 -> mark invalid; rotate immediately
- 429/rate-limit -> cooldown with exponential backoff + jitter; rotate
- quota/credit exhausted -> disable key for 24h; rotate
- timeout/network -> retry same key once; then rotate

Retry contract (bounded):

- max_retries_per_question from env
- retry_reason: 429|timeout|schema_invalid|no_citations|dead_links|low_confidence
- retry_strategy: repair|requery|fallback_model|brief_mode

If all keys unavailable:

- wait until earliest cooldown_until, then continue; if monthly_soft_limit exceeded, stop and produce handoff.

## Cost guardrails (auto-degrade)

- If estimated cost > daily soft limit: switch to brief, skip p2 questions
- If estimated cost > monthly soft limit: answer only p0/p1, defer remainder
- Always record budget_state=ok|near|over and what was deferred

## Caching (credit saver)

If PERPLEXITY_CACHE_ENABLED:

- cache_key = hash(topic + questions + constraints + tech_profile + output_mode + output_format)
- If repo_write=true and prior json exists with same cache_key: treat as cache_hit, emit manifest, stop

## Query strategy

For each question:

1) Build 1..N concise keyword queries (N by output_mode).
2) Prepend tech_profile to each query.
3) Request: answer + tradeoffs + actionable recommendation + citations (URLs).
4) If missing citations / contradictory / low confidence: requery once; then fallback model; else mark low confidence with followups.

Optional: model auto-discovery if supported; otherwise use configured primary/fallback.

## Validation gates (self-healing)

### JSON output schema (must match)

```json
{
  "meta": {
    "run_id": "...",
    "workflow_version": "1.0.0",
    "schema_version": "1.0.0",
    "topic": "...",
    "topic_slug": "...",
    "model_used": "...",
    "key_index_used": 1,
    "cache_key": "...",
    "output_mode": "...",
    "output_format": "...",
    "timestamps": {"started_at":"...","finished_at":"..."}
  },
  "results": [
    {
      "question_id": "q1",
      "priority": "p0",
      "question": "...",
      "answer": "...",
      "citations": [{"url":"...","title":null,"valid":true}],
      "confidence": "high|medium|low",
      "followups": []
    }
  ],
  "notes": {"budget_state":"ok|near|over","warnings":[],"retry_summary":{}}
}
```

If schema invalid:

- run a "repair" step (reformat only, no new facts), then revalidate; bounded retries.

### Citation/link health check (best-effort)

- HEAD/GET each citation URL with 2s timeout
- Mark valid=false when unreachable and add warning
- If require citations and all invalid/missing: requery once, else mark low confidence

### Governance compliance check

Before writing:

- redact secrets/tokens/credentials if detected
- ensure citations exist when required
- ensure Markdown headings remain stable and diff-friendly

## Markdown output rules

Always generate:

- Markdown file (research or ADR)
- JSON results file
- run manifest JSON
- handoff JSON
- PR-ready summary block (for copy/paste into PR description)

If output_format=research:

- Per question: Context, Findings, Tradeoffs, Recommendation, Sources (inline citations)
If output_format=adr:
- Title, Status=Proposed, Context, Decision, Consequences, Sources

Doc auto-update:

- If md exists and changelog=true: append one short changelog line with timestamp + what changed

## Handoff artifact (mesh-ready)

Write <topic-slug>-handoff.json:

- unresolved questions
- low-confidence items
- missing/invalid citations
- recommended next agent (Perplexity|Gemini|Copilot)
- suggested follow-up queries

## Manifest (observability)

Write <topic-slug>-run.json:

- run_id, timestamps, cache_hit
- inputs_hash, outputs_hash
- key_ledger snapshot (sanitized)
- usage_ledger + budget_state
- retry_events

## Notifications (optional)

If NOTIFICATION_WEBHOOK_URL is set and (any key invalid/disabled OR budget_state != ok OR run failed):

- POST sanitized completion report JSON

If TELEMETRY_WEBHOOK_URL is set:

- POST manifest (sanitized)

## Completion report (always, sanitized)

- answered/total, deferred count
- keys status + cooldowns
- retry summary
- budget_state + best-effort cost estimate
- artifact paths written (if repo_write=true)

## Safety

- Never print/write secrets
- Never commit secrets
- If in doubt, mark low confidence and propose followups rather than guessing
