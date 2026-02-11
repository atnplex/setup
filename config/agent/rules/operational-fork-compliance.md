# R-FORK: Fork Compliance & Licensing Preservation

> **Forked repos must retain all legally required files. Clean up only what's safe.**

## Protected Files (NEVER delete without explicit user override)

| File/Pattern | Why Protected |
|-------------|---------------|
| `LICENSE`, `LICENSE.*` | Legal requirement for all OSS licenses |
| `NOTICE`, `NOTICE.*` | Required by Apache 2.0, some MIT variants |
| `COPYING`, `COPYING.*` | GPL family requirement |
| `AUTHORS`, `CONTRIBUTORS` | Attribution requirements |
| `CREDITS`, `CREDITS.*` | Attribution |
| `THIRD_PARTY_NOTICES` | Bundled dependency licenses |
| `CODE_OF_CONDUCT.md` | Community governance |
| Copyright headers in source files | Many licenses require preservation |

## Before Modifying a Fork

1. **Identify the upstream license** — read `LICENSE` file
2. **Check license requirements** — what must be preserved?
3. **Preserve attribution** — never remove original author credits
4. **Add, don't remove** — add your changes alongside originals

## Safe to Modify in Forks

- README (add your fork's purpose, keep upstream credit)
- CI/CD workflows (customize for your infra)
- Configuration files (adapt to your environment)
- Non-licensed documentation (guides, tutorials)
- Dependency versions (security updates)
- Feature additions in source code

## Cleanup Rules

When user requests cleanup/consolidation of a fork:

1. **Audit protected files first** — list what MUST stay
2. **Advise user** — "These files are required by [license], keeping them"
3. **Clean safely** — remove only build artifacts, dead code, unused configs
4. **Update README** — document fork purpose and divergence from upstream
5. **Preserve git history** — don't squash away upstream attribution commits

## Common License Requirements

| License | Must Keep | Can Modify |
|---------|-----------|------------|
| MIT | LICENSE + copyright notice | Everything else |
| Apache 2.0 | LICENSE + NOTICE + copyright | Everything else |
| GPL v2/v3 | LICENSE + COPYING + source availability | Everything else |
| BSD | LICENSE + copyright in source | Everything else |
| AGPL | Same as GPL + network use = distribution | Everything else |
