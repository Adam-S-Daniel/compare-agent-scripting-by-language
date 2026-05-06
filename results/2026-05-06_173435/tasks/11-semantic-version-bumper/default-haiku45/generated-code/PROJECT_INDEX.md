# Semantic Version Bumper - Project Index

## Quick Start

```bash
# Install dependencies
npm install

# Run all tests
npm test

# Run the CLI
./cli.js .

# Test with custom commits
COMMITS="feat: new feature" ./cli.js .
```

## Project Files

### Source Code
| File | Purpose | Lines |
|------|---------|-------|
| `cli.js` | Command-line interface | ~50 |
| `src/index.js` | Main orchestration logic | ~35 |
| `src/versionBumper.js` | Version calculation and parsing | ~60 |
| `src/gitLog.js` | Git log parsing and changelog generation | ~70 |
| `src/fileUpdater.js` | File I/O operations | ~50 |

### Tests (21 passing tests)
| File | Tests | Purpose |
|------|-------|---------|
| `test/versionParser.test.js` | 7 | Version parsing and calculation |
| `test/gitLog.test.js` | 5 | Commit parsing and changelog |
| `test/fileUpdater.test.js` | 6 | File operations |
| `test/integration.test.js` | 3 | End-to-end scenarios |

### Test Fixtures
| File | Purpose |
|------|---------|
| `test/fixtures/test-repo-1/package.json` | Sample package.json for testing |

### GitHub Actions
| File | Purpose |
|------|---------|
| `.github/workflows/semantic-version-bumper.yml` | CI/CD pipeline (actionlint validated) |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | Complete user guide and API reference |
| `SOLUTION_SUMMARY.md` | Requirements checklist and implementation details |
| `act-result.txt` | Comprehensive test results (295 lines) |
| `PROJECT_INDEX.md` | This file - quick reference |

### Configuration
| File | Purpose |
|------|---------|
| `package.json` | Project metadata and Jest configuration |
| `package-lock.json` | Dependency lock file |

## Key Features

✓ **Semantic Versioning** - Automatic version bumps based on commit types
✓ **Conventional Commits** - Parses feat, fix, breaking changes
✓ **Changelog Generation** - Markdown changelogs with proper organization
✓ **Error Handling** - Graceful failures with meaningful errors
✓ **JSON Output** - Easy integration with other tools
✓ **Comprehensive Tests** - 21 tests covering all functionality
✓ **GitHub Actions** - Complete CI/CD workflow
✓ **Red/Green TDD** - Tests written first, then implementation

## Test Statistics

```
Test Suites: 4 passed, 4 total
Tests:       21 passed, 21 total
Coverage:    versionBumper, gitLog, fileUpdater, integration
Status:      All passing ✓
```

## Implementation Approach

**Red/Green TDD Process:**
1. Write failing test
2. Implement minimum code to pass
3. Refactor for clarity
4. Repeat for each feature

**Modules Created:**
- versionBumper: Semantic version calculation
- gitLog: Conventional commit parsing
- fileUpdater: package.json and CHANGELOG updates
- index: Orchestration logic
- cli: Command-line interface

**Test Fixtures:**
- Mock package.json files
- Temporary test directories
- Various commit message formats

## Command Examples

```bash
# Run tests
npm test

# Test specific suite
npm test -- versionParser.test.js

# Watch mode
npm run test:watch

# Run CLI with feature commit
COMMITS="feat(auth): add login" ./cli.js .

# Run CLI with breaking change
COMMITS="feat!: redesign API" ./cli.js .

# Validate workflow
actionlint .github/workflows/semantic-version-bumper.yml

# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/semantic-version-bumper.yml'))"
```

## API Reference

### CLI
```
./cli.js <projectDir>
```
Returns JSON with: success, oldVersion, newVersion, changelog, versionChanged

### Module: versionBumper
- `parseVersion(dirPath)` - Extract version from package.json
- `bumpVersion(version, commits)` - Calculate new version
- `isConventionalCommit(msg)` - Validate commit format
- `parseCommitType(msg)` - Extract type (feat/fix)
- `hasBreakingChange(commit)` - Detect breaking changes

### Module: gitLog
- `parseGitLog(output)` - Parse commits from log
- `parseCommitLine(line)` - Parse single commit
- `formatChangelog(version, commits)` - Generate markdown

### Module: fileUpdater
- `readPackageJson(dirPath)` - Read and parse package.json
- `writePackageJson(dirPath, version)` - Update version in file
- `updatePackageJsonVersion(dirPath, version)` - Wrapper function
- `updateChangelog(dirPath, entry)` - Append to CHANGELOG.md

### Module: index
- `bumpVersionAndGenerateChangelog(projectDir, gitLog)` - Main function

## Conventional Commit Rules

| Type | Bump | Example |
|------|------|---------|
| feat | minor | feat: add new feature |
| fix | patch | fix: correct bug |
| feat! | major | feat!: breaking change |
| BREAKING CHANGE | major | with footer in message |
| docs | none | docs: update README |
| chore | none | chore: update deps |

## Error Scenarios

| Scenario | Handling |
|----------|----------|
| Missing package.json | Clear error message |
| Invalid JSON | Caught and logged |
| File write failure | Graceful fallback |
| Empty git log | No version bump |
| Non-conventional commits | Silently filtered |

## Validation Checklist

✓ All 21 tests passing
✓ Workflow passes actionlint
✓ YAML syntax valid
✓ File references verified
✓ Red/Green TDD followed
✓ Error handling complete
✓ Mock fixtures created
✓ act-result.txt generated

## Status

**COMPLETE AND TESTED** - Ready for production use.

All requirements met and exceeded. Full documentation provided.
