# Quick Start Guide

## Installation

```bash
# Dependencies are already installed
bun install
```

## Running Tests

```bash
# Run all tests
bun test

# Expected output:
# 31 pass, 0 fail, 54 expect() calls
```

## Using the CLI

```bash
# Bump version with commits
bun run src/index.ts ./package.json \
  "feat: add new feature" \
  "fix: resolve bug"

# Use npm script
bun run bump ./package.json "feat: add feature"
```

## GitHub Actions Workflow

The workflow is automatically triggered on:
- Push to main/master
- Pull requests to main/master
- Manual dispatch

To run locally with act:
```bash
act push --rm
```

## Commit Message Examples

### Patch Version (1.0.0 → 1.0.1)
- `fix: resolve database timeout`
- `fix: prevent null pointer exception`

### Minor Version (1.0.0 → 1.1.0)
- `feat: add user authentication`
- `feat(api): implement rate limiting`

### Major Version (1.0.0 → 2.0.0)
- `feat!: redesign API endpoints`
- `feat: remove legacy support` (with BREAKING CHANGE footer)

## File Locations

- **Source Code:** `src/`
- **Tests:** `*.test.ts` files
- **Workflow:** `.github/workflows/semantic-version-bumper.yml`
- **Fixtures:** `fixtures/`
- **Results:** `act-result.txt`

## Key Commands

| Command | Purpose |
|---------|---------|
| `bun test` | Run all tests |
| `bun run src/index.ts` | Run CLI |
| `actionlint .github/workflows/semantic-version-bumper.yml` | Validate workflow |
| `act push --rm` | Test workflow locally |

## Troubleshooting

**Tests not running?**
- Ensure test files end with `.test.ts`
- Run `bun install` to install dependencies

**Workflow not detected?**
- Workflow must be at `.github/workflows/semantic-version-bumper.yml`
- Must have valid YAML syntax

**Version not bumping?**
- Check commit messages follow conventional format
- Use `git log --oneline` to see commit messages
- Each commit needs `feat:`, `fix:`, or `feat!:` prefix
