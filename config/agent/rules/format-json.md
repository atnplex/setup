# JSON STANDARDS

## R32: JSON_STRUCTURE

- **Indent**: 2-space indentation.
- **Keys**: snake_case or camelCase (be consistent per project).
- **Sorting**: Keys sorted alphabetically where logical.
- **Trailing**: No trailing commas.
- **Quotes**: Double quotes only.

## R32a: JSON_VALIDATION

- **Lint**: All JSON must pass `jq .` validation.
- **Schema**: Use JSON Schema for complex configs.
