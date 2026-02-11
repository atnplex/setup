# ENV & ENVIRONMENT

## R1: ENV_DETECTION

- **Trigger**: First action.
- **Required**: Detect target + mode.

## R2: NO_HARDCODING

- **Logic**: Use `namespace_env.py`.

## R4: STORAGE_AFFINITY

- **Rule**: Use native filesystem.

## R13: WORKSPACE_STABILITY

- **Fail Check**: Windows UNC paths MUST fail.
