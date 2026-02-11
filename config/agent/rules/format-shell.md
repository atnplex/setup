# SHELL STANDARDS

## R33: BASH_BEST_PRACTICE

- **Header**: `#!/bin/bash` followed by `set -euo pipefail`.
- **Lint**: Shellcheck mandatory before commit.
- **Format**: shfmt with default settings.

## R33a: BASH_VARIABLES

- **Quoting**: Always quote variables: `"$VAR"` not `$VAR`.
- **Braces**: Use `${VAR}` for clarity in strings.
- **Defaults**: Use `${VAR:-default}` for optional vars.

## R33b: BASH_FUNCTIONS

- **Declaration**: Use `function_name() { }` syntax.
- **Local vars**: Declare with `local` inside functions.
- **Exit codes**: Return meaningful codes, 0 = success.

## R33c: BASH_SAFETY

- **No sudo in scripts**: Require elevated privileges explicitly.
- **Temp files**: Use `mktemp` for temporary files.
- **Cleanup**: Trap EXIT for cleanup: `trap cleanup EXIT`.
