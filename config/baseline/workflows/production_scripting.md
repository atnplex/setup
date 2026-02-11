---
description: how to create production-grade ecosystem scripts
---
# Workflow: Create Production-Grade Script

Follow these steps when creating any script intended for the ecosystem.

1. **Reference the Checklist**: View [scripting_standard.md](file:///C:/atn/baseline/rules/scripting_standard.md) to ensure compliance.
2. **Implementation Steps**:
    - **Header**: Define `$IsManual` by checking TTY or `--setup` flag.
    - **Bootstrap**: Use a `Confirm-Health` function to check dependencies.
    - **Remediation**:
        - If manual: `Write-Host "Please run choco install ..."` or attempt `winget`.
        - If automation: Download minimal binary to `./bin/portable`.
    - **Logic**: Ensure all file operations are wrapped in `Test-Path` or equivalent "If-Not-Exists" checks.
3. **Verification**:
    - Run the script once on a clean system.
    - Run the script again immediately to verify idempotence.
    - Manually break a dependency and verify self-healing.

// turbo-all
4.  **Registration**: Add the script to the appropriate `index` or `RULES.md` module.
