# Baseline Template: Repository# Processing Task: [REPO_NAME]

## Repo Information

- **Name:** [REPO_NAME]
- **GitHub URL:** https://github.com/atnplex/[REPO_NAME]
- **Processing Date:** [DATE]

---

## Modular Task Skeleton

Follow phases A → B → C → D → E → F (see task-skeleton.md for details)

### A) Obtain Information ⏳

- [ ] Run preflight: `bash tools/preflight.sh [NN]-[REPO_NAME]/preflight.json`
- [ ] Check preflight.json status (must be "pass")
- [ ] Validate execution_target and watcher_mode
- [ ] Gather repo metadata (description, language, last_updated)
- [ ] Scan repo structure (if cloned) or fetch via gh CLI

### B) Plan Execution ⏳

- [ ] List viable execution targets (windows|wsl|remote_linux)
- [ ] Select execution_target based on:
  - Tool availability
  - Repo requirements (bash scripts → Linux)
  - Performance (WSL filesystem preferred)
- [ ] Document decision + rationale in metadata.json
- [ ] Define path mappings (linux_root, windows_root if needed)

### C) Ensure Dependencies ⏳

- [ ] Verify required tools from preflight
- [ ] Attempt installation of missing tools (if allowed)
- [ ] Validate installations successful
- [ ] Record any unresolved dependencies
- [ ] If critical deps missing → STOP with remediation steps

### D) Implement (Discovery & Extraction) ⏳

- [ ] Locate repo at correct path (prefer WSL filesystem if execution_target=wsl)
- [ ] Scan for README files
- [ ] Check for CONTRIBUTING guides
- [ ] Search for .github/ templates
- [ ] Look for docs/ directory
- [ ] Find standardization-related files
- [ ] Analyze folder structure (top 3 levels)
- [ ] Identify naming patterns
- [ ] Extract relevant content to findings.md
- [ ] Document folder structure in analysis.md
- [ ] Note naming conventions
- [ ] Extract policies and guidelines
- [ ] Capture path references
- [ ] Record metadata in metadata.json

### E) Verify ⏳

- [ ] Validate all expected files created
- [ ] Check analysis.md completeness
- [ ] Confirm findings.md has raw content
- [ ] Verify metadata.json schema compliance
- [ ] Ensure preflight results recorded
- [ ] Review for consistency

### F) Record & Integrate ⏳

- [ ] Mark processing complete in task.md
- [ ] Update metadata.json with final status
- [ ] Compare findings with 00-consolidated/
- [ ] Identify conflicts or novel patterns
- [ ] Update consolidated standards documents
- [ ] Update PROCESSING_LOG.md
- [ ] Prepare for user review

---

## Notes

**Key Observations:**
[Record insights during processing]

**Recommendations:**
[Suggestions for standardization]

**Next Steps:**
[What needs review or user decision]
