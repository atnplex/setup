# Preflight Check - Mandatory Before Repo Processing

## Purpose

The preflight check is a **mandatory gate** that must pass before processing any repository. It validates the execution environment, workspace configuration, and tool availability to prevent known failure modes.

**Enforces:** See [`RULES.md`](RULES.md) for complete rule definitions

- **R1**: Environment-First Execution
- **R3**: Canonical Paths by Execution Target
- **R5**: Workspace Watcher Reliability (UNC detection)
- **R6**: Universal Time (UTC timestamps)
- **R7**: Determinism (sorted JSON)
- **R8**: Stop-the-Run Policy

## WSL File Storage Best Practice (R4)

See [RULES.md R4](RULES.md#r4-wsl-filesystem-best-practice) for complete guidance.

**Summary:** Store files in WSL filesystem when using Linux tools; avoid `/mnt/c` for performance.

## How to Run Preflight

### From WSL/Linux

```bash
cd /atn/x/repo-integrations
bash tools/preflight.sh ./preflight.json
```

### With Explicit Workspace Path (for UNC detection)

```bash
# Via environment variable
export PREFLIGHT_WORKSPACE_PATH="$(pwd)"
bash tools/preflight.sh ./preflight.json

# OR via command line argument
bash tools/preflight.sh ./preflight.json --workspace-path "$(pwd)"
```

**When to provide workspace_path:**

- To explicitly test UNC detection
- When cwd doesn't reflect the actual workspace opened by editor
- For CI/CD environments where workspace location is ambiguous

### Output

- **JSON to stdout** - For inline consumption
- **JSON to file** - For auditability (default: `./preflight.json`)
- **Exit code** - 0 (pass) or 1 (fail)

## What PASS/FAIL Means (R8)

### PASS (status: "pass")

- Execution environment supported (WSL, remote Linux, or Windows)
- Workspace mode valid (NOT windows_unc - R5)
- Required tools available (git, python3 for Linux)
- Critical paths exist (`/atn` for Linux, `C:\atn` for Windows)
- **Action:** Proceed with repo processing

### FAIL (status: "fail")

- One or more critical failures detected
- Common failures:
  - **UNC workspace** (`\\wsl.localhost` or `\\wsl$`) - Violates **R5**
  - **Missing tools** (git, python3)
  - **Missing paths** (`/atn` not found)
  - **Invalid environment** (unsupported configuration)
- **Action:** STOP IMMEDIATELY - Do NOT proceed to repo processing

## Mandatory Rule (R8)

**⛔ IF PREFLIGHT FAILS → STOP**

See [RULES.md R8](RULES.md#r8-stop-the-run-policy) for complete stop-the-run policy.

Do not continue to repo analysis, cloning, or any processing steps until preflight passes.

## Preflight Checks

### 1. Execution Context Detection

Detects:

- `execution_target`: `windows` | `wsl` | `remote_linux`
- WSL: Requires `WSL_DISTRO_NAME` set, WSLInterop present, cwd starts with "/"
- Validates current working directory is in expected filesystem

### 2. Workspace Mode Validation

Detects:

- `watcher_mode`: `wsl_remote` | `windows_unc` | `windows_local`
- **FAILS** if workspace path starts with `\\wsl.localhost` or `\\wsl$`

**UNC Workspace Failure:**

```
FAIL: UNC workspace detected (\\wsl.localhost\Debian\...)
REMEDIATION: Reopen using WSL remote mode:
  1. From WSL terminal: cd /atn/x/repo-integrations
  2. Run: code .
  3. Re-run preflight
```

### 3. Path Validation

Confirms:

- `/atn` exists (or prompts to create)
- `/mnt/c` accessible (if WSL)
- `C:\atn` accessible (if Windows or WSL with mounts)

### 4. Tool Availability

**Required:**

- git (version ≥ 2.0)
- python3 (version ≥ 3.6)

**Optional:**

- jq (JSON processing)
- gh (GitHub CLI)

**Auto-installation attempt:**

- On Debian/WSL: tries `sudo apt install -y <package>`
- Records installation attempts in notes
- FAILS if required tools still missing after attempts

## Preflight Output Structure

```json
{
  "preflight_version": "1.0.0",
  "timestamp": "2026-01-30T17:00:00-08:00",
  "status": "pass",
  "failures": [],
  "notes": [],
  "environment": {
    "execution_target": "wsl",
    "wsl_distro_name": "Debian",
    "has_wslinterop": true
  },
  "workspace": {
    "watcher_mode": "wsl_remote",
    "repo_workspace_path": "/atn/x/repo-integrations",
    "is_unc": false
  },
  "paths": {
    "linux_root": "/atn",
    "wsl_windows_mount_root": "/mnt/c",
    "windows_root": "C:\\atn",
    "cwd": "/atn/x/repo-integrations"
  },
  "detected_tools": {
    "git": { "path": "/usr/bin/git", "version": "git version 2.39.0" },
    "python3": { "path": "/usr/bin/python3", "version": "Python 3.11.2" },
    "jq": { "path": "/usr/bin/jq", "version": "jq-1.6" },
    "gh": null
  },
  "can_use_wsl": true,
  "can_use_windows": true,
  "preflight_artifact_path": "/atn/x/repo-integrations/preflight.json"
}
```

## Integration with Repo Processing

Every repo processing MUST:

1. **Start with preflight:**

   ```bash
   bash tools/preflight.sh {nn}-{repo-name}/preflight.json
   ```

2. **Check status:**

   ```python
   import json
   with open("preflight.json") as f:
       preflight = json.load(f)
   if preflight["status"] != "pass":
       print(f"PREFLIGHT FAILED: {preflight['failures']}")
       exit(1)
   ```

3. **Record in metadata.json:**
   ```json
   {
     "preflight": {
       "preflight_timestamp": "...",
       "preflight_result": "pass",
       "preflight_artifact_path": "02-actions/preflight.json"
     }
   }
   ```

## Remediation Steps

### UNC Workspace

```bash
# From WSL
cd /atn/x/repo-integrations
code .
```

### Missing /atn

```bash
sudo mkdir -p /atn
sudo chown $USER:$USER /atn
mkdir -p /atn/github /atn/x
```

### Missing Tools

```bash
sudo apt update
sudo apt install -y git python3 jq
```

### WSLInterop Missing

Check WSL configuration:

```bash
cat /etc/wsl.conf
# Ensure [interop] section has: enabled=true
```

## Known Failure Modes Prevented

1. ✅ UNC workspace causing file watcher issues
2. ✅ Missing git preventing clones
3. ✅ Missing python3 preventing automation
4. ✅ Invalid execution context (wrong shell/environment)
5. ✅ Path translation assumptions (enforces explicit translation)

## Stop-the-Run Policy

**Do not process next repo** until:

1. Known issue has documented prevention step
2. Preflight enforces that prevention
3. Preflight passes for current workspace
