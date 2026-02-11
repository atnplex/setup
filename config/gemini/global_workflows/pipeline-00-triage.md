---
name: Triage
description: Initial processing of ALL user requests
model: claude-opus-4.5-thinking
---

# Phase 0: Triage Pipeline

> [!IMPORTANT]
> ALL user input MUST go through this phase first. No exceptions.

## Model Selection

**REQUIRED: Claude Opus 4.5 Thinking**

Triage requires deep reasoning for:

- Risk assessment
- Complexity estimation
- Domain detection
- Breaking change identification

---

## Step 1: Intent Classification

Analyze user input for:

| Factor | Assessment |
|--------|------------|
| **Specificity** | Direct command or needs clarification? |
| **Complexity** | Simple (1-2 steps) or Complex (needs decomposition)? |
| **Domain** | Frontend / Backend / DevOps / Security / Mixed? |
| **Scope** | Single file / Multi-file / Multi-component? |
| **Risk** | Low / Medium / High / Critical? |

### Complexity Indicators

**Simple** (Gemini Flash suitable):

- Single file edit
- Clear, specific request
- No architectural decisions
- No security implications

**Standard** (Sonnet 4.5 suitable):

- Multi-file changes
- Feature implementation
- Test writing
- Documentation

**Complex** (Opus 4.5 required):

- Architecture decisions
- Security changes
- Refactoring
- Database schema changes
- Breaking changes

---

## Step 2: Context Gathering

### Search User's Repos

```bash
# Search for relevant context
gh search repos --owner atnplex "<keywords>" --json name,description --limit 5

# If specific repo mentioned
gh repo view atnplex/<repo> --json name,description,readme
```

### Load Relevant Skills

1. Extract keywords from request
2. Match keywords to `~/skills/manifest.yaml`
3. Load matched SKILL.md files
4. Apply to context

### Check Baseline Rules

- Review `/atn/baseline/RULES.md`
- Check for applicable workflows
- Note any constraints

---

## Step 3: Risk Assessment

### Security Scan

Flag if request involves:

- [ ] Authentication/authorization changes
- [ ] Credential handling
- [ ] File permission changes
- [ ] External API keys
- [ ] User data processing
- [ ] Command execution

If ANY flagged → **Require Opus 4.5 + Security Auditor persona**

### Breaking Change Check

Flag if request involves:

- [ ] API signature changes
- [ ] Database schema migration
- [ ] Dependency major version bump
- [ ] Configuration format change
- [ ] Removal of features

If ANY flagged → **Notify user explicitly**

---

## Step 4: Generate Options

Present user with structured choices:

```markdown
## How would you like to proceed?

**A) Quick Path** (~15 min)
- Direct implementation
- Model: Sonnet 4.5
- Best for: Simple, well-defined tasks
- Risk: [Low/Medium]

**B) Detailed Path** (~45 min)
- Full planning → decomposition → execution → verification
- Model: Opus Thinking → Sonnet
- Best for: Complex tasks, architecture
- Risk: Minimal (thorough review)

**C) Custom**
- Specify your preferences
- Model/persona selection
- Scope adjustments

### Detected Context
- Domain: [X]
- Complexity: [X]
- Personas: [X, Y]
- Skills: [X, Y, Z]
```

---

## Step 5: Wait for Confirmation

- Present options
- Wait for user selection
- Capture any additional requirements
- Proceed to Phase 1 (Confirmation) or Phase 2 (Decomposition)

---

## Output Format

After triage, document:

```yaml
triage_result:
  classification:
    intent: direct|clarification_needed
    complexity: simple|standard|complex
    domain: [frontend, backend, devops, security]
    risk_level: low|medium|high|critical

  context:
    repos_searched: []
    skills_loaded: []
    baseline_rules: []

  assignment:
    primary_persona: X
    model: X
    supporting_personas: []

  flags:
    security_review: true|false
    breaking_change: true|false
    needs_decomposition: true|false

  user_option_selected: A|B|C
```
