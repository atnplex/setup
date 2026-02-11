# Task Skeleton - Modular Execution Framework

## Purpose

ALL repository processing tasks MUST follow this modular skeleton to ensure reproducibility and drift resistance across runs and AI agents.

## Skeleton Structure

Every task follows **6 phases** (A → B → C → D → E → F):

### A) Obtain Information (Parallelizable)

**Purpose:** Gather all facts before making decisions

**Actions:**

- Run preflight check
- Detect environment (execution_target, watcher_mode)
- Check tool availability
- Determine current workspace mode
- Query repo metadata (if cloning from GitHub)

**Outputs:**

- `preflight.json`
- Environment facts
- Tool inventory
- Workspace validation

**Parallelization:** Concurrent commands where possible

```python
# Example: parallel info gathering
futures = [
    executor.submit(run_preflight),
    executor.submit(detect_git_version),
    executor.submit(check_repo_exists),
    executor.submit(scan_directory_structure)
]
```

---

### B) Plan Execution

**Purpose:** Decide HOW to execute based on facts

**Actions:**

- List viable execution targets (windows|wsl|remote_linux)
- Select best path based on:
  - Tool availability
  - Performance (WSL filesystem > `/mnt/c`)
  - Compatibility
- Record decision + rationale

**Outputs:**

- Execution plan document
- Selected execution_target
- Path mappings
- Fallback strategy

**Example Decision:**

```
DECISION: execution_target=wsl
RATIONALE:
  - Repo uses bash scripts → requires Linux
  - WSL available with all tools
  - Workspace in wsl_remote mode (optimal)
  - /atn exists → use /atn/github/{repo}
FALLBACK: If WSL fails → remote_linux (Debian VPS)
```

---

### C) Ensure Dependencies

**Purpose:** Install/enable missing tools; record what can't be fixed

**Actions:**

- Check for missing required tools
- Attempt installation (if allowed)
- Validate installations
- Record missing items + remediation attempted

**Outputs:**

- Tool installation log
- List of resolved dependencies
- List of unresolved dependencies (if any)
- Fallback recommendations

**Policy:**

- Try safe, common installation methods first
- Log all attempts
- If critical dep missing → FAIL with exact commands needed

```bash
# Example
if ! command -v git &>/dev/null; then
    echo "Attempting: sudo apt install -y git"
    if sudo apt install -y git; then
        echo "✅ git installed"
    else
        echo "❌ FAIL: Cannot install git"
        echo "REMEDIATION: Manually run: sudo apt install -y git"
        exit 1
    fi
fi
```

---

### D) Implement Changes

**Purpose:** Execute the actual work (minimal, deterministic)

**Actions:**

- Make file edits
- Run scripts
- Clone repos
- Process data
- Generate outputs

**Principles:**

- Minimal changes only
- Deterministic (same inputs → same outputs)
- Atomic where possible
- Reversible (snapshots before destructive ops)

**Outputs:**

- Modified files
- Generated artifacts
- Processing logs

---

### E) Verify Results

**Purpose:** Confirm changes had desired effect

**Actions:**

- Re-run checks/tests
- Validate file integrity
- Confirm expected state
- Compare before/after

**Outputs:**

- Verification summary
- Test results
- Validation status (pass/fail)
- Diff summary

**Example:**

```bash
# Verify git clone succeeded
if [ -d "/atn/github/repo/.git" ]; then
    echo "✅ Clone successful"
    git -C /atn/github/repo log -1 --oneline
else
    echo "❌ FAIL: .git directory not found"
    exit 1
fi
```

---

### F) Record Artifacts

**Purpose:** Document what happened for future reference

**Actions:**

- Update metadata.json (preflight results, execution_target, paths)
- Write processing logs
- Create summary documents
- Capture metrics

**Outputs:**

- `metadata.json` (updated)
- `task.md` (updated)
- Processing log entry
- Artifacts committed/saved

**Policy:**

- Do NOT proceed to next step if verify failed
- Always record outcome (success or failure)
- Include timestamps, versions, decisions

---

## Integration with Baseline

### Baseline Files Enhanced

**00-baseline/task.md** now includes:

```markdown
## A) Obtain Information ⏳

- [ ] Run preflight (see preflight.md)
- [ ] Check preflight.json status
- [ ] Validate environment
- [ ] Gather repo facts

## B) Plan Execution ⏳

- [ ] List execution options
- [ ] Select execution_target
- [ ] Document decision rationale

## C) Ensure Dependencies ⏳

- [ ] Check tool availability
- [ ] Attempt installations
- [ ] Record missing deps

## D) Implement ⏳

- [ ] [Task-specific actions]

## E) Verify ⏳

- [ ] Run verification checks
- [ ] Validate results

## F) Record ⏳

- [ ] Update metadata.json
- [ ] Write summary
- [ ] Commit artifacts
```

---

## Example: Processing Repo #2 (actions)

### A) Obtain

```bash
# Preflight
bash /atn/x/repo-integrations/tools/preflight.sh 02-actions/preflight.json

# Parallel info gathering
gh repo view atnplex/actions --json name,description,updatedAt &
gh repo clone atnplex/actions /tmp/actions-preview --depth 1 &
wait
```

### B) Plan

```
DECISION: execution_target=wsl
RATIONALE:
  - GitHub Actions = YAML workflows
  - Need git, yq (YAML processor)
  - WSL has all tools
  - Use /atn/github/actions (WSL filesystem)
FALLBACK: None needed (read-only analysis)
```

### C) Ensure

```bash
# Check yq
if ! command -v yq &>/dev/null; then
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi
```

### D) Implement

```bash
# Clone to WSL filesystem
git clone https://github.com/atnplex/actions /atn/github/actions

# Analyze workflows
find /atn/github/actions/.github/workflows -name "*.yml" -o -name "*.yaml"
```

### E) Verify

```bash
# Confirm clone
test -d /atn/github/actions/.git && echo "✅ Clone OK"

# Validate YAML
for f in /atn/github/actions/.github/workflows/*.{yml,yaml}; do
    yq eval '.' "$f" >/dev/null && echo "✅ $f valid"
done
```

### F) Record

```json
{
  "repo_name": "actions",
  "execution_target": "wsl",
  "watcher_mode": "wsl_remote",
  "paths": {
    "linux_root": "/atn/github/actions"
  },
  "preflight": {
    "preflight_result": "pass",
    "preflight_artifact_path": "02-actions/preflight.json"
  }
}
```

---

## Enforcement

✅ Preflight prevents known failure modes
✅ Task skeleton ensures complete execution
✅ Metadata captures decisions for repeatability
✅ Stop-the-run policy prevents cascading failures

**Result:** Any AI agent or human can reproduce this task by following the same skeleton with the same inputs.
