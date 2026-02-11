# PYTHON STANDARDS

## R34: PYTHON_ARCH

- **Style**: PEP 8 compliance.
- **Types**: Type hints required for function signatures.
- **Pathing**: Use `pathlib.Path`, relative to `$ROOT`.

## R34a: PYTHON_IMPORTS

- **Order**: stdlib → third-party → local (blank line between).
- **Absolute**: Prefer absolute imports over relative.
- **No star**: Never use `from module import *`.

## R34b: PYTHON_DOCSTRINGS

- **Format**: Google-style docstrings.
- **Required**: All public functions/classes/modules.

## R34c: PYTHON_LINTING

- **Linter**: Ruff preferred (fast, comprehensive).
- **Formatter**: Black or Ruff format.
- **Type check**: mypy for type validation.
