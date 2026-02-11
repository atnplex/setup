# FORMATTING STANDARDS

## R15: MD_CODE_BLOCKS

- **Standard**: All fenced code blocks MUST specify a language.
- **Examples**: `bash`, `python`, `json`, `yaml`, `typescript`, `markdown`
- **No bare blocks**: Never use ``` without a language identifier.

## R16: MD_HEADINGS

- **Standard**: Single `#` per document (title), sequential nesting.
- **Rule**: No skipping levels (e.g., `##` to `####`).
- **Lint**: Must pass MD025 (single-title/single-h1).

## R17: MD_TABLES

- **Standard**: Surrounded by blank lines.
- **Pipe spacing**: Spaces around content (`| text |`), including separator row.
- **Separator row**: Use `| --- |` not `|---|` (spaces required for MD060).
- **Alignment**: Use `:---`, `:---:`, `---:` for alignment.
- **Lint**: Must pass MD060 (table-column-style).

**Example (CORRECT)**:

```markdown
| Header | Header |
| ------ | ------ |
| Data   | Data   |
```

**Example (WRONG)**:

```markdown
| Header | Header |
|--------|--------|
| Data   | Data   |
```

## R18: MD_LISTS

- **Standard**: Consistent markers (`-` preferred), blank lines between sections.
- **Nesting**: 2-space indentation for sub-items.

## R19: MD_LINKS

- **Standard**: Descriptive link text, no bare URLs.
- **Format**: `[description](url)` not `https://example.com`
