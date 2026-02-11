---
description: Process and merge Pull Requests org-wide with proper review and auto-merge. | Reviews suggestions, implements fixes, resolves conversations properly, and enables auto-merge through the PR system.
---

# Manage Pull Requests (Org-Wide)

> **Scope**: Organization-wide or repo-specific
> **Primary Use**: Process open Pull Requests through the **proper PR review system**

## Core Principles

> [!CAUTION]
> **DO NOT** dismiss, bypass, or force-merge PRs. **ALWAYS** work through the PR system.

1. **Review suggestions properly** - Evaluate if they would help or not
2. **Implement fixes** - For valid security/critical suggestions
3. **Push fixes to PR branches** - Not to main
4. **RESOLVE ALL THREADS** - PRs cannot merge with unresolved conversations
5. **Enable auto-merge** - Let the system merge when CI passes

---

## Parallelism Strategy

> [!IMPORTANT]
> **1 process per repository. Sequential within each repo.**

- **Cross-repo**: Parallel OK (spawn separate processes)
- **Within-repo**: Always sequential (oldest first)

---

## Phase 0: Inventory

```bash
gh --version && gh auth status
export ORG="${ORG:-atnplex}"

gh search prs --owner "$ORG" --state open --json number,title,repository,createdAt,isDraft \
  --jq '[.[] | select(.isDraft == false)] | group_by(.repository.nameWithOwner)'
```

---

## Phase 1: For EACH PR (Sequential Within Repo)

### Step 1.1: Get Review Comments

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) { nodes { author { login } body } }
          }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$REPO" -F number=$PR
```

### Step 1.2: Evaluate Each Thread

| Priority | Criteria | Action |
|----------|----------|--------|
| **CRITICAL** | Security, data loss | Implement fix, then resolve |
| **HIGH** | Bugs, validation | Fix if straightforward, then resolve |
| **MEDIUM** | Code quality | Log to deferred, resolve thread |
| **LOW** | Style, preferences | Resolve thread directly |

### Step 1.3: Implement Fixes (if needed)

```bash
git clone https://github.com/$OWNER/$REPO.git /tmp/$REPO
cd /tmp/$REPO
BRANCH=$(gh pr view $PR --json headRefName -q '.headRefName')
git checkout -b fix origin/$BRANCH

# Make fixes...
git add . && git commit -m "fix: <description>"
git push origin fix:$BRANCH
```

### Step 1.4: RESOLVE ALL THREADS (MANDATORY)

> [!CAUTION]
> **PRs CANNOT MERGE with unresolved threads.** This step is MANDATORY.

```bash
# Get all unresolved thread IDs (excluding github-advanced-security which needs code fixes)
THREADS=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) { nodes { author { login } } }
          }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$REPO" -F number=$PR | \
  jq -r '.data.repository.pullRequest.reviewThreads.nodes[] |
    select(.isResolved == false) |
    select(.comments.nodes[0].author.login != "github-advanced-security") |
    .id')

# Resolve each thread
for tid in $THREADS; do
  echo "Resolving thread $tid"
  gh api graphql -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: {threadId: $threadId}) {
        thread { isResolved }
      }
    }' -f threadId="$tid"
done
```

### Step 1.5: Handle github-advanced-security (CodeQL) Threads

> [!WARNING]
> These threads CANNOT be resolved via API. They require:
>
> 1. Fix the code issue flagged by CodeQL
> 2. Push the fix to the PR branch
> 3. CodeQL will automatically resolve when re-scan passes

If CodeQL threads are blocking, you must fix the underlying code.

### Step 1.6: Verify All Threads Resolved

```bash
UNRESOLVED=$(gh api graphql -f query='...' | jq '[.data...nodes[] | select(.isResolved == false)] | length')
if [[ "$UNRESOLVED" -gt 0 ]]; then
  echo "ERROR: $UNRESOLVED unresolved threads remain"
  exit 1
fi
```

### Step 1.7: Enable Auto-Merge

```bash
gh pr merge $PR --repo $OWNER/$REPO --auto --squash
```

---

## Phase 2: Validation

```bash
# Check all threads resolved
gh pr list --repo $OWNER/$REPO --state open --json number,reviewDecision

# Verify auto-merge enabled
gh pr list --repo $OWNER/$REPO --state open --json number,autoMergeRequest
```

---

## Anti-Patterns (DO NOT)

> [!CAUTION]

- ❌ Skipping thread resolution
- ❌ Ignoring github-advanced-security alerts
- ❌ `gh pr merge --admin` (bypasses checks)
- ❌ Force-merging with unresolved threads
