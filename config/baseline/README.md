# Baseline README

## Purpose

This directory (`00-baseline`) contains template files used as the starting point for processing each repository in the atnplex organization.

## Template Files

| File            | Purpose                            |
| --------------- | ---------------------------------- |
| `task.md`       | Processing checklist for each repo |
| `analysis.md`   | Structured analysis template       |
| `findings.md`   | Raw extracted content storage      |
| `metadata.json` | Machine-readable repo metadata     |

## Usage

When processing a new repository:

1. **Copy this baseline** to a new numbered directory:

   ```bash
   cp -r /atn/x/repo-integrations/00-baseline /atn/x/repo-integrations/{nn}-{repo-name}
   ```

2. **Replace placeholders** in each file:
   - `[REPO_NAME]` → actual repo name
   - `[DATE]` → current date in ISO format
   - `[LANGUAGE]` → primary programming language
   - `[DESCRIPTION]` → repo description

3. **Follow task.md** checklist to process the repository

4. **Fill in analysis.md** with findings

5. **Extract content** to findings.md

6. **Update metadata.json** with actual values

## Processing Order

Repositories are processed in order of most recently updated:

1. `01-homelab-env` - Existing homelab environment
2. `02-actions` - GitHub Actions workflows
3. `03-legacy-actions` - Legacy actions archive
4. ... (continue for all 18 repos)

## Final Output

After all repos are processed, findings are consolidated into `/atn/x/repo-integrations/99-consolidated/` with unified standards documents.
