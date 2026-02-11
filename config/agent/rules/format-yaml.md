# YAML STANDARDS

## R35: YAML_STRUCTURE

- **Indent**: 2-space indentation.
- **Quotes**: Use quotes for strings with special characters.
- **Multiline**: Use `|` for literal blocks, `>` for folded.
- **Lint**: yamllint mandatory.

## R35a: YAML_KEYS

- **Style**: snake_case for keys.
- **Order**: Logical grouping, not alphabetical.

## R35b: YAML_GITHUB_ACTIONS

- **Names**: Descriptive step names.
- **IDs**: Use `id:` for steps referenced later.
- **Secrets**: Always use `${{ secrets.NAME }}`, never hardcode.

## R35c: YAML_LITERAL_BLOCK_INDENTATION

- **Standard**: All content in literal block (`|`) or folded block (`>`) MUST be indented consistently.
- **Embedded Scripts**: Template literals in `github-script` actions must have ALL content lines indented.
- **Reason**: Unindented content (e.g., `**bold**` or `---`) is parsed as YAML syntax, causing errors.
- **Example (WRONG)**:

```yaml
script: |
  const body = `
**Title**  # ← YAML sees this as alias `*Title`
---        # ← YAML sees this as document separator
`;
```

- **Example (CORRECT)**:

```yaml
script: |
  const body = `
    **Title**
    ---
  `;
```

## R35d: YAML_ACTION_VERSION_PINNING

- **Standard**: Always verify action repository and version before use.
- **Pin versions**: Use `@v4`, `@stable`, or commit SHA, never `@latest`.
- **Validate**: Check action exists at `github.com/{owner}/{repo}`.
- **Common mistake**: `dtolnay/rust-action` does not exist; use `dtolnay/rust-toolchain`.
