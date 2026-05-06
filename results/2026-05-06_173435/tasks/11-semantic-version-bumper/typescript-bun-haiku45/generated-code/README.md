# Semantic Version Bumper

A TypeScript/Bun implementation of semantic version bumping based on conventional commit messages, following TDD methodology.

## Features

- **Semantic Versioning**: Parse and bump versions (major, minor, patch) according to semver rules
- **Conventional Commits**: Analyze commit logs to determine version bump type:
  - `feat`: minor version bump
  - `fix`: patch version bump
  - Breaking changes (`!`): major version bump
- **Version File Support**: Works with both `package.json` and plain `VERSION` files
- **Changelog Generation**: Automatically generates changelog entries grouped by commit type
- **Full Test Suite**: 38 unit and integration tests using Bun's test runner
- **GitHub Actions Workflow**: Complete CI/CD pipeline with actionlint validation

## Project Structure

```
.
├── semantic-version.ts           # Version parsing and formatting
├── conventional-commits.ts       # Conventional commit analysis
├── changelog.ts                  # Changelog generation
├── bump-version.ts               # Main CLI script
├── test-fixtures.ts              # Mock data for testing
├── semantic-version.test.ts      # Unit tests for versioning
├── conventional-commits.test.ts  # Unit tests for commit analysis
├── changelog.test.ts             # Unit tests for changelog
├── integration.test.ts           # Integration tests
├── .github/workflows/
│   └── semantic-version-bumper.yml  # GitHub Actions workflow
└── act-result.txt                # Test results from act
```

## Installation & Usage

### Prerequisites
- Bun runtime (https://bun.sh)

### Run Tests
```bash
bun test
```

### Bump Version
```bash
# Interactive mode (reads commits from stdin)
cat commit-log.txt | bun bump-version.ts package.json

# Direct mode with commit log
bun bump-version.ts package.json -c "feat: add feature"

# With changelog generation
bun bump-version.ts package.json -c "feat: add feature" -o CHANGELOG.md
```

### CLI Options
```
bump-version <version-file> [options]

Arguments:
  version-file              Path to package.json or VERSION file

Options:
  -c, --commit-log <log>    Conventional commits log (default: read from stdin)
  -o, --output-changelog    Path to write generated changelog entry
```

## Test Coverage

### Unit Tests (38 total)
- **Semantic Version** (11 tests)
  - Version parsing (valid, with 'v', invalid)
  - Version bumping (major, minor, patch)
  - File reading (package.json, VERSION)
  - File writing (package.json, VERSION)

- **Conventional Commits** (14 tests)
  - Parsing various commit formats
  - Detecting breaking changes
  - Determining bump type with priority
  - Analyzing commit logs

- **Changelog** (6 tests)
  - Generating entries per version
  - Grouping commits by type
  - Handling scopes and empty logs
  - Full changelog assembly

- **Integration** (7 tests)
  - Complete workflows (patch, minor, major)
  - Mixed commit types
  - Priority handling
  - Various format support

### GitHub Actions Workflow Testing
- Runs all 38 unit tests in CI/CD pipeline
- Tests patch version bumping (1.0.0 → 1.0.1)
- Tests minor version bumping (2.0.0 → 2.1.0)
- Tests major version bumping (1.5.0 → 2.0.0)
- Tests VERSION file handling
- Validates workflow structure
- Generates changelog entries

## Test Results

All 38 tests pass with actionlint validation:

```
bun test v1.3.13
38 pass
0 fail
86 expect() calls
Ran 38 tests across 4 files. [137ms]
```

GitHub Actions workflow execution via `act`:
- ✓ actionlint validation passed
- ✓ All required scripts present
- ✓ Version bumping works correctly
- ✓ Changelog generation works correctly
- ✓ Tests run successfully in Docker containers

## Implementation Details

### Semantic Version Module
- **parseVersion()**: Parse "X.Y.Z" format (with optional 'v' prefix)
- **formatVersion()**: Convert SemVersion object to string
- **bumpVersion()**: Increment major/minor/patch according to type
- **readVersionFile()**: Extract version from package.json or VERSION
- **writeVersionFile()**: Update version while preserving file structure

### Conventional Commits Module
- **parseConventionalCommit()**: Parse commit messages using regex
  - Pattern: `type(scope)!: description`
  - Detects breaking changes with `!` indicator
- **determineBumpType()**: Prioritize commit types
  - Breaking > feat > fix > default (patch)
- **analyzeCommits()**: Process full commit log

### Changelog Module
- **generateChangelogEntry()**: Create entry for single version
  - Groups commits by type (Breaking, Features, Fixes, etc.)
  - Includes commit scope in parentheses if present
  - Uses ISO date format (YYYY-MM-DD)
- **generateFullChangelog()**: Combine multiple entries with header

### CLI Module (bump-version.ts)
- Argument parsing for flexible input
- Reads version files (package.json or VERSION)
- Analyzes commits to determine bump type
- Updates version file atomically
- Generates optional changelog
- Outputs new version for shell scripting

## GitHub Actions Workflow

The workflow (`.github/workflows/semantic-version-bumper.yml`) provides:

### Triggers
- Push to main/master branches
- Pull requests to main/master
- Manual trigger (workflow_dispatch)
- Paths filter (only on relevant file changes)

### Jobs
1. **version-bump**: Main job - runs tests and bumps version
2. **test-minor-bump**: Validates minor version bumping
3. **test-major-bump**: Validates major version bumping with breaking changes
4. **test-version-file**: Validates VERSION file handling
5. **test-workflow-structure**: Validates script files and workflow syntax
6. **report-status**: Aggregates results from all jobs

### Test Assertions
Each job verifies:
- Scripts exist and are executable
- Version bumping produces correct results
- Files are updated properly
- Changelog is generated
- All steps complete successfully

## Design Decisions

1. **TDD Approach**: Tests written first, implementation follows
2. **Explicit Types**: Full TypeScript types for safety and IDE support
3. **Minimal Dependencies**: Only uses Bun stdlib and Node.js built-ins
4. **File Format Preservation**: Maintains JSON formatting and file structure
5. **Default to Patch**: Unknown commit types default to patch bump
6. **Scope Display**: Shows commit scope in brackets for clarity

## Error Handling

- Invalid semver format throws with descriptive message
- Missing version file throws with file path
- Malformed JSON package.json throws parse error
- Non-existent flags default gracefully

## Future Enhancements

- Pre-release versions (alpha, beta)
- Metadata in version strings
- Git integration for automatic commit log extraction
- Multiple version files in monorepos
- Configuration file support (.semverrc)
- Custom changelog templates
- Dry-run mode

## License

MIT
