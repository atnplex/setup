# PATHS AND CANONICALS

## R3: DYNAMIC_PATHS
- **Windows**: `$ROOT_OS_WINDOWS`
- **Linux**: `$ROOT`
- **Worktree**: `$ROOT/worktrees/`

## R6: UNIVERSAL_TIME
- **Format**: ISO8601 UTC ('Z').

## R9: UNIT_STORAGE
- **Rule**: Smallest integer units (ms, bytes).

## R11: SCHEMA_NAMING
- **Standard**: `snake_case` keys for all structured data.
- **Units**: Encode units in field names (e.g., `delay_ms`).
