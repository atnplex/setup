# Global Workflow: Process Pull Requests (Org-Wide) v1.2.0

## What Changed in v1.2.0

- **Security-First Processing**: Added mandatory Phase 2.5 for vulnerability remediation
- **No Bypass Policy**: Explicit rules against dismissing reviews without fixing issues
- **Auto-Remediation**: Automated fixes for common security patterns
- **Reviewer Engagement**: Structured response templates for bot/human reviewers
- **Evidence-Based Decisions**: All merge decisions must document security validation

## Purpose

Systematically process all open PRs across an organization (default: `atnplex`) to drive the backlog to zero. This workflow enforces strict quality gates with **security-first evaluation** while ensuring compatibility with both Linux/Bash and Windows/PowerShell environments.

## Platform Profiles (MANDATORY SELECTION)

Select one profile based on your environment and stick to it for all command blocks.

> PROFILE: LINUX_BASH
>
> - Shell: Bash (v4+)
> - Tools: `jq`, `sed`, `awk`, standard utils.
> - Syntax: `export VAR=val`, `command | jq ...`, `while read` loops.

> PROFILE: WINDOWS_POWERSHELL
>
> - Shell: PowerShell 7+ (pwsh) or Windows PowerShell 5.1.
> - Tools: Native cmdlets (`ConvertFrom-Json`, `Where-Object`, `Select-Object`).
> - Syntax: `$Var = "val"`, `command | ConvertFrom-Json`, `foreach ($x in $y)`.

## Guardrails (Non-Negotiable)

- **No direct pushes to main.**
- **No bypassing required checks, approvals, or branch protection.**
- **No dismissing reviews without addressing concerns** (document reasons if override needed).
- **No disabling CI/lint/tests to force green checks.**
- **No force-push unless unavoidable** (must explain why).
- **No manual branch deletion** (rely on repo settings).
- **No unrelated refactors.** Fix only what's needed for the PR.
- **No merging with known security vulnerabilities** unless documented exception.
- **Bot Policy**: Treat suggestions as proposals. Adopt if good; reply with evidence if rejecting.

---

## Security Policy (NEW)

### Never Bypass Without Evaluation

1. **All "Changes Requested" reviews must be addressed** by either:
   - Fixing the issue
   - Providing evidence why it's not applicable
   - Documenting acceptance of risk (with approval from repo owner)

2. **Security findings MUST be fixed before merge**:
   - Command injection vulnerabilities
   - Exposed secrets/credentials
   - Weak file permissions
   - Path traversal risks
   - SQL/NoSQL injection
   - XSS vulnerabilities

3. **Automated review dismissal is FORBIDDEN** unless:
   - Bot has auto-approved after fixes
   - Human reviewer has re-reviewed
   - Issue is demonstrably false positive (document evidence)

---

## JSON Fields: How to Verify Each Run

Never guess JSON fields. Commands have different valid fields.

- Verify: Run `<cmd> --help` and check the "JSON Fields" section.
- Drift Check: If a field fails, it may have been renamed in your `gh` version.

## GitHub CLI Versioning

Policy: If commands/fields differ, upgrade `gh`.

```bash
gh --version
```

---

## Phase 0: Environment & Tooling Discovery

Goal: Select profile, inventory tools, verify auth, and create workspace.

### 1. Select Profile & Create Workspace

LINUX_BASH

```bash
echo "Shell: $SHELL"; echo "OSTYPE: $OSTYPE"
gh --version || echo "CRITICAL: gh missing"
jq --version || echo "CRITICAL: jq missing"
mkdir -p .pr_work
```

WINDOWS_POWERSHELL

```powershell
Write-Host "PSVersion: $($PSVersionTable.PSVersion)"
if (Get-Command gh -ErrorAction SilentlyContinue) { gh --version } else { Write-Error "gh missing" }
New-Item -ItemType Directory -Force -Path .pr_work | Out-Null
```

### 2. Auth Check

BOTH PROFILES

```bash
gh auth status
# Verify identity safely (no permissions field)
gh api user --jq "{login: .login}"
```

### 3. Tooling Plan Map

| Task | LINUX_BASH | WINDOWS_POWERSHELL | Fallback Strategy |
|------|------------|--------------------|-------------------|
| Inventory | `gh search prs ... > file` | `gh search prs ... | Out-File` | Repo enumeration |
| Hydrate | `gh pr view ... >> file` | `gh pr view ... | Add-Content` | Web scraping |
| Logic | `if [[ ... ]]; then` | `if ($True) { ... }` | Manual decision |

---

## Phase 1: Org-Wide PR Discovery (Inventory + Hydration)

Goal: Build a hydrated worklist. `gh search` has limited fields; we must hydrate details with `gh pr view`.

Set your org once per run:

```bash
export ORG="${ORG:-atnplex}"
```

### Step 1: Inventory (Search)

Fields: number, title, repository, author, isDraft, updatedAt, url

LINUX_BASH

```bash
gh search prs --help | grep -i owner || true

gh search prs --owner "$ORG" --state open --json number,title,repository,author,isDraft,updatedAt,url --limit 100 > .pr_work/open_prs_inventory.json

cat .pr_work/open_prs_inventory.json | jq '.'
```

WINDOWS_POWERSHELL

```powershell
gh search prs --help | Select-String -Pattern "owner" | Out-Null

gh search prs --owner $env:ORG --state open `
  --json number,title,repository,author,isDraft,updatedAt,url `
  --limit 100 | Out-File .pr_work/open_prs_inventory.json -Encoding utf8

Get-Content .pr_work/open_prs_inventory.json | ConvertFrom-Json
```

### Step 2: Hydration (Details)

Fields: mergeable, reviewDecision, statusCheckRollup, files, commits, headRefName, baseRefName, updatedAt, url, title

LINUX_BASH

```bash
rm -f .pr_work/open_prs_hydrated.ndjson

cat .pr_work/open_prs_inventory.json | jq -c '.[]' | while read -r pr; do
  repoName=$(echo "$pr" | jq -r 'if (.repository|type)=="object" then .repository.name else (.repository|split("/")[1]) end')
  num=$(echo "$pr" | jq -r '.number')
  fullRepo="$ORG/$repoName"

  echo "Hydrating $fullRepo #$num..."
  gh pr view "$num" -R "$fullRepo" --json mergeable,reviewDecision,statusCheckRollup,files,commits,headRefName,baseRefName,updatedAt,url,title | jq -c '.' >> .pr_work/open_prs_hydrated.ndjson
done
```

WINDOWS_POWERSHELL

```powershell
$prs = Get-Content .pr_work/open_prs_inventory.json | ConvertFrom-Json
$outFile = ".pr_work/open_prs_hydrated.ndjson"
if (Test-Path $outFile) { Remove-Item $outFile }

foreach ($pr in $prs) {
    if ($pr -eq $null) { continue }
    $repoName = if ($pr.repository -is [string]) { $pr.repository.Split('/')[1] } else { $pr.repository.name }
    $num = $pr.number
    $fullRepo = "$env:ORG/$repoName"

    Write-Host "Hydrating $fullRepo #$num..."
    $json = gh pr view "$num" -R "$fullRepo" `
      --json mergeable,reviewDecision,statusCheckRollup,files,commits,headRefName,baseRefName,updatedAt,url,title
    $json | Add-Content $outFile -Encoding utf8
}
```

### Step 3: Create Prioritized Worklist (task.md)

Create `task.md` and list PRs with columns:

- Repo, PR number, title, classification (security/bug/perf/feature/docs), status, notes

---

## Phase 2: Process OPEN PRs

Goal: Iterate list until checked off.

### Step A: Analysis

- Read: `gh pr view -R OWNER/REPO <N> --json title,body,commits,reviews`
- Diff: `gh pr diff -R OWNER/REPO <N>`
- Checks: `gh pr checks -R OWNER/REPO <N>`
- **Reviews**: `gh api repos/OWNER/REPO/pulls/<N>/reviews`

### Step B: Security Scan (PRE-PROCESSING)

**Before any fixes, scan for vulnerabilities:**

LINUX_BASH

```bash
# Checkout PR
gh pr checkout -R OWNER/REPO <N>

# Scan for common issues
echo "=== Security Scan PR #<N> ===" > .pr_work/security_scan_<N>.txt

# 1. Check for exposed secrets
echo "Checking for secrets..." >> .pr_work/security_scan_<N>.txt
git diff main... | grep -iE '(password|secret|token|api_key|private_key)' >> .pr_work/security_scan_<N>.txt || echo "No secrets found" >> .pr_work/security_scan_<N>.txt

# 2. Check for command injection (shell execution with user input)
echo "Checking for command injection..." >> .pr_work/security_scan_<N>.txt
git diff main... | grep -E 'exec|spawn|system|eval|popen' >> .pr_work/security_scan_<N>.txt || echo "No dangerous commands" >> .pr_work/security_scan_<N>.txt

# 3. Check for weak permissions
echo "Checking file permissions..." >> .pr_work/security_scan_<N>.txt
git diff main... | grep -E 'chmod|0777|0666' >> .pr_work/security_scan_<N>.txt || echo "No weak permissions" >> .pr_work/security_scan_<N>.txt

# 4. Check for SQL injection patterns
echo "Checking for SQL injection..." >> .pr_work/security_scan_<N>.txt
git diff main... | grep -iE '\$\{.*\}.*SELECT|string.*\+.*SELECT|`.*SELECT' >> .pr_work/security_scan_<N>.txt || echo "No SQL injection patterns" >> .pr_work/security_scan_<N>.txt

cat .pr_work/security_scan_<N>.txt
```

### Step C: Plan Comment (WITH SECURITY FINDINGS)

```bash
gh pr comment -R OWNER/REPO <N> --body "## Processing Plan
- Classification: (Security/Bug/Feature)
- Action: (Merge/Close/Fix)
- **Security Findings**: (List from scan or 'None detected')
- Validation: (List tests)
- Done Criteria: (Green checks, resolved threads, zero vulns)"
```

---

## Phase 2.5: Vulnerability Remediation (NEW - MANDATORY)

**If reviews show "Changes Requested" or security scan finds issues, MUST complete this phase.**

### Step 1: Extract Review Feedback

LINUX_BASH

```bash
# Get all review comments
gh api repos/OWNER/REPO/pulls/<N>/reviews | jq -r '.[] | select(.state=="CHANGES_REQUESTED") | {author: .user.login, body: .body}' > .pr_work/changes_requested_<N>.json

cat .pr_work/changes_requested_<N>.json
```

### Step 2: Categorize Issues

Create `.pr_work/remediation_plan_<N>.md`:

```markdown
# Remediation Plan for PR #<N>

## Security Issues (MUST FIX)
- [ ] Command injection in file.js:123
- [ ] Exposed secret in script.sh:45
- [ ] Weak permissions (777) in deploy.sh:67

## Code Quality (SHOULD FIX)
- [ ] Deprecated dependency
- [ ] Inefficient algorithm

## Style/Nitpicks (OPTIONAL)
- [ ] Formatting inconsistency
```

### Step 3: Auto-Remediation Patterns

**Command Injection Fix**:

Before (UNSAFE):

```javascript
exec(`echo ${userInput} | command`)
```

After (SAFE):

```javascript
import { spawn } from 'child_process';
const proc = spawn('command', [], { stdio: 'pipe' });
proc.stdin.write(userInput);
proc.stdin.end();
```

**Secret Handling Fix**:

Before (UNSAFE):

```bash
read -p "Token: " TOKEN
```

After (SAFE):

```bash
read -sp "Token (hidden): " TOKEN
echo "" # newline after hidden input
chmod 600 credentials.txt
```

**Permission Fix**:

Before (UNSAFE):

```bash
chmod 777 config.env
```

After (SAFE):

```bash
chmod 600 config.env  # owner read/write only
```

### Step 4: Implement Fixes

1. **Checkout** the PR branch
2. **Apply fixes** following patterns above
3. **Commit** with clear message:

   ```bash
   git commit -m "security: Fix command injection in dev-tools server

   - Replace shell piping with child_process.spawn
   - Add input sanitization
   - Fixes CodeRabbit security finding

   Addresses review from @coderabbitai[bot]"
   ```

4. **Push** fixes

### Step 5: Respond to Reviewers

**Template for Bot Reviews**:

```bash
gh pr comment -R OWNER/REPO <N> --body "## Security Fixes Applied

Addressed findings from @coderabbitai:

### Command Injection
- **Issue**: User input passed directly to shell in \`dev-tools-mcp-server/index.js\`
- **Fix**: Replaced \`exec\` with \`spawn\`, input now sanitized
- **Commit**: abc123def

### Weak Permissions
- **Issue**: \`.env\` files created without restrictive permissions
- **Fix**: Added \`chmod 600\` after all credential file creation
- **Commit**: def456ghi

### Secret Exposure
- **Issue**: \`read -p\` displays secrets in terminal
- **Fix**: Changed to \`read -sp\` (silent mode)
- **Commit**: ghi789jkl

All critical security issues have been resolved. Ready for re-review."
```

**Request Re-Review**:

```bash
gh pr review -R OWNER/REPO <N> --comment --body "@coderabbitai Please re-review - all security findings addressed"
```

### Step 6: Verify Fixes

```bash
# Re-run security scan
gh pr diff -R OWNER/REPO <N> | grep -iE '(exec.*userInput|read -p.*token|chmod 777)' && echo "STILL VULNERABLE" || echo "FIXES VERIFIED"
```

### Step 7: Document Exceptions (If Any)

**If a finding is not applicable**:

```markdown
## Security Review Exception

**Finding**: CodeQL flagged potential SQL injection in query.js:45
**Analysis**: False positive - input is validated via schema (see validator.js:23)
**Evidence**: Unit test coverage shows parameterized queries (tests/query.test.js:89)
**Approved by**: @repo-owner
**Risk**: None - no user input reaches SQL layer
**Action**: Documented exception, no code change needed
```

---

## Phase 3: Quality Gates (MUST PASS - Enhanced)

### Gate 1: Security Validation

- [ ] No "Changes Requested" reviews remaining
- [ ] All security findings fixed or documented
- [ ] No secrets in diff: `git diff main... | grep -iE 'password|secret|token'`
- [ ] No command injection: Manual code review
- [ ] No weak permissions: `git diff main... | grep -E 'chmod.*777|chmod.*666'`

### Gate 2: Code Quality

- [ ] All required checks GREEN
- [ ] No failing tests
- [ ] Linters pass
- [ ] CodeQL/security scans pass

### Gate 3: Review Approval

- [ ] All reviewers approved OR
- [ ] Documented exceptions with owner approval

### Gate 4: Final Diff Review

```bash
gh pr diff -R OWNER/REPO <N> | less
# Manual sanity check - look for:
# - Unexpected file changes
# - Large binary additions
# - Config changes that could break production
```

---

## Phase 4: Merge (Only After All Gates Pass)

**Pre-Merge Checklist**:

```bash
# 1. Verify all gates
cat .pr_work/gates_<N>.txt

# 2. Final status check
gh pr checks -R OWNER/REPO <N>

# 3. Verify no changes-requested
gh api repos/OWNER/REPO/pulls/<N>/reviews | jq -r '.[] | select(.state=="CHANGES_REQUESTED")'
# Should return empty

# 4. Merge
gh pr merge -R OWNER/REPO <N> --merge --delete-branch
```

**Squash Policy**: Use `--squash` ONLY if:

- History is messy (many fixup commits)
- Documented reason in PR comment

**Never Merge If**:

- Any security gate fails
- Unresolved "Changes Requested"
- CI checks failing
- No approval from required reviewers

---

## Phase 5: Decision Matrix (Conflicts / Duplicates)

- Drafts:
  - Active & Valuable -> Finish & Merge (after security review).
  - Stale (>30d) & Empty -> Close (comment reasons).
- Conflicts:
  - Simple: Fix forward.
  - Complex: Rebase (if confident) or Close (if superseded).
- Duplicates:
  - Keep best. Close others with "Superseded by #<Winner>".

---

## Phase 6: Salvage Pass (Closed Unmerged)

Goal: Recover value from closed/abandoned PRs.

### Step 1: Scan for Candidates

LINUX_BASH

```bash
gh search prs --owner "$ORG" --state closed --search "-is:merged" --json number,title,repository,author,updatedAt,url --limit 50 > .pr_work/closed_unmerged_inventory.json
```

WINDOWS_POWERSHELL

```powershell
gh search prs --owner $env:ORG --state closed --search "-is:merged" `
  --json number,title,repository,author,updatedAt,url `
  --limit 50 | Out-File .pr_work/closed_unmerged_inventory.json -Encoding utf8
```

### Step 2: Evaluation & Extraction

For high-value candidates:

1. **Security scan first**: Check for vulns before salvaging
2. Create branch: `git checkout -b salvage/feature-name`
3. Cherry-pick commits or extract file contents
4. **Fix any security issues** before creating new PR
5. PR attribution: "Originally authored by @user in #old-pr"

---

## Phase 7: Verification & Artifacts

### 1. Final Verification

```bash
gh search prs --owner "$ORG" --state open --json number
```

### 2. Artifacts

- `task.md`: Final checklist status with security validation column
- `walkthrough.md`: Summary of Merged, Closed, and Salvaged items
- `.pr_work/security_audit.md`: All security findings and remediations

---

## Emergency Bypass Procedure (Use Sparingly)

**Only if absolutely necessary** (e.g., critical hotfix), document bypass:

```bash
# Create bypass record
cat > .pr_work/bypass_<N>.md <<EOF
## Emergency Bypass - PR #<N>

**Date**: $(date)
**Reason**: Critical production hotfix
**Risk Assessment**: Low - changes reviewed manually
**Approver**: @owner-username
**Security Review**: Findings documented and accepted
**Rollback Plan**: Revert commit abc123 if issues arise
EOF

# Admin merge (only if you have permissions)
gh pr merge -R OWNER/REPO <N> --admin --merge

# Document in PR
gh pr comment -R OWNER/REPO <N> --body-file .pr_work/bypass_<N>.md
```

---

## Self-Test (Dry Run) - MANDATORY

Run this BEFORE starting Phase 1 to verify full stack.

LINUX_BASH

```bash
echo "=== DRY RUN (Bash) ==="
mkdir -p .pr_work
echo "gh version: $(gh --version | head -n 1)"
gh auth status

# 1. Inventory Test
gh search prs --owner "$ORG" --state open --json number,title,repository,updatedAt --limit 3 > .pr_work/dryrun.json
echo "Inventory Sample:"
cat .pr_work/dryrun.json | jq '.'

# 2. Hydration Test (if any exist)
first_num=$(jq -r '.[0].number // empty' .pr_work/dryrun.json)
repoName=$(jq -r '.[0].repository.name // empty' .pr_work/dryrun.json)
if [[ -z "$repoName" ]]; then
  repoName=$(jq -r 'if (.[0].repository|type)=="string" then (.[0].repository|split("/")[1]) else empty end' .pr_work/dryrun.json)
fi

if [[ -n "$first_num" && -n "$repoName" ]]; then
  echo "Hydrating test: $ORG/$repoName #$first_num"
  gh pr view "$first_num" -R "$ORG/$repoName" --json mergeable,reviewDecision,statusCheckRollup

  # Security test
  echo "Testing security scan..."
  gh pr diff -R "$ORG/$repoName" "$first_num" | grep -iE '(password|secret|token)' && echo "FOUND SECRETS" || echo "No secrets detected"
else
  echo "No open PRs found for dry run (or parse error)."
fi

echo "Dry run complete" > .pr_work/selftest.log
```

WINDOWS_POWERSHELL

```powershell
Write-Host "=== DRY RUN (PowerShell) ==="
New-Item -ItemType Directory -Force -Path .pr_work | Out-Null
gh --version
gh auth status

# 1. Inventory Test
gh search prs --owner $env:ORG --state open `
  --json number,title,repository,updatedAt --limit 3 `
  | Out-File .pr_work/dryrun.json -Encoding utf8
$dry = Get-Content .pr_work/dryrun.json | ConvertFrom-Json
Write-Host "Inventory Sample:"
$dry | Format-Table

# 2. Hydration Test (if any exist)
if ($dry.Count -gt 0) {
    $first = if ($dry -is [array]) { $dry[0] } else { $dry }
    $num = $first.number
    $repoName = if ($first.repository -is [string]) { $first.repository.Split('/')[1] } else { $first.repository.name }
    Write-Host "Hydrating test: $env:ORG/$repoName #$num"
    gh pr view "$num" -R "$env:ORG/$repoName" --json mergeable,reviewDecision,statusCheckRollup

    # Security test
    Write-Host "Testing security scan..."
    gh pr diff -R "$env:ORG/$repoName" "$num" | Select-String -Pattern "(password|secret|token)" -CaseSensitive:$false
} else {
    Write-Host "No open PRs found for dry run."
}

"Dry run complete" | Out-File .pr_work/selftest.log -Encoding utf8
```

---

## Summary of Security Enhancements

| Category | Enhancement |
|----------|-------------|
| **Policy** | No bypass without documented evaluation |
| **Scanning** | Automated security pattern detection |
| **Remediation** | Auto-fix templates for common vulns |
| **Engagement** | Structured reviewer response protocol |
| **Gates** | Security validation required before merge |
| **Audit Trail** | All findings and fixes documented |

---

Verified Cross-Platform Workflow v1.2.0 - Security-First Edition
