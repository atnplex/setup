# GIT AND WORKFLOW GOVERNANCE

## R21: Branch Protection

- **Rule**: No direct pushes to main.
- **Constraint**: No admin/bypass mechanisms.

## R22: Worktree Isolation

- **Path**: `$ROOT/worktrees/<type>/<slug>`

## R23: Atomic Deliverables

- **Logic**: Small, scoped PRs; no unrelated refactors.

## R24: PR Readiness

- **Rule**: Local check verification mandatory. Open PR only when complete.
- **Security**: Document auth/secret/perm changes in PR description.

## R25: Merge and Cleanup

- **Method**: Merge via PR only. Confirm branch deletion before 'done'.

## R26: Merge Queue Protocol

- **Rule**: Use Merge Queue when required. No direct PR merge if queue is enforced.

## R27: Squash Message Policy

- **Policy**: Use PR title as final commit subject; ensure PR title + number compliance.

## R28: Workflow Requirements

- **Standard**: All workflows MUST support `merge_group` trigger.
