# Semantic Version Bumper

A Node.js-based semantic version bumper that determines version bumps based on conventional commits, updates package.json, and generates changelog entries.

## Project Overview

This project implements a TDD (Test-Driven Development) approach to building a semantic version bumper. It includes:

- **Core Functionality**: Parse versions, determine bump type (major/minor/patch), bump versions, read/write package.json, generate changelog entries
- **21 Unit Tests**: All passing, covering parseVersion, determineVersionBump, bumpVersion, and file I/O operations
- **Test Fixtures**: Three scenarios (feature-commit, breaking-change, patch-only) for testing different version bump scenarios
- **GitHub Actions Workflow**: Automated CI/CD pipeline that runs tests and bumps versions
- **Act Integration**: Test harness to validate the workflow runs correctly in isolated Docker containers

## Project Structure

```
.
├── src/
│   ├── semantic-version-bumper.js    # Core version bumping logic
│   ├── file-handler.js               # File I/O and changelog generation
│   └── cli.js                        # Command-line interface
├── tests/
│   ├── semantic-version-bumper.test.js  # Core function tests (13 tests)
│   ├── integration.test.js              # File I/O tests (8 tests)
│   └── fixtures/
│       ├── feature-commit.txt        # feat: commit scenario
│       ├── breaking-change.txt       # feat!: breaking change scenario
│       └── patch-only.txt            # fix: commit scenario
├── .github/
│   └── workflows/
│       └── semantic-version-bumper.yml  # GitHub Actions workflow
├── package.json                     # Node.js project configuration
├── run-act-tests.sh                 # Test harness for act
└── README.md                        # This file
```

## Features

### Version Parsing
- Parses semantic versions (major.minor.patch) with optional 'v' prefix
- Validates format and throws meaningful errors on invalid input

### Version Bump Determination
Based on conventional commit messages:
- **Breaking change** (`feat!:` or `fix!:`): Major version bump
- **Feature** (`feat:`): Minor version bump
- **Fix** (`fix:`): Patch version bump
- **Other** (chore, docs, etc.): No bump

Priority: major > minor > patch > none

### Version Bumping
- Increments appropriate version component
- Resets lower components to 0 (e.g., 1.2.3 -> 2.0.0 for major bump)

### File I/O
- Reads current version from package.json
- Updates package.json with new version while preserving other fields
- Parses commit fixtures from text files

### Changelog Generation
- Creates properly formatted changelog entries
- Groups commits by type (Breaking Changes, Features, Bug Fixes)
- Includes commit hashes and descriptions
- Adds ISO date stamps

## Usage

### Run Tests Locally
```bash
npm install
npm test
```

All 21 tests should pass:
- 13 core function tests
- 8 file I/O and integration tests

### Run Version Bumper CLI
```bash
node src/cli.js package.json tests/fixtures/feature-commit.txt
```

Output:
- Current and new version
- Updated package.json file
- Generated changelog entry
- Number of commits processed

### Run GitHub Actions Workflow Locally
```bash
# Install act (nektos/act) - handles local CI/CD execution
# Validate workflow syntax
actionlint .github/workflows/semantic-version-bumper.yml

# Run complete test harness
bash run-act-tests.sh
```

## Test Coverage

### Unit Tests (21 total)

**Core Functions (13 tests)**:
- parseVersion: Valid versions, leading 'v', invalid format handling
- determineVersionBump: Breaking changes, features, fixes, priority handling
- bumpVersion: Major, minor, patch, none scenarios

**Integration (8 tests)**:
- readVersionFromPackageJson: Valid reads, missing file, missing version field
- writeVersionToPackageJson: Update version, preserve other fields
- generateChangelogEntry: Formatting, grouping, commit parsing
- getCommitsSinceTag: Parse fixture files

### Test Fixtures

1. **feature-commit.txt**: One feat and one fix commit → minor bump (1.0.0 → 1.1.0)
2. **breaking-change.txt**: Breaking change with features and fixes → major bump (1.0.0 → 2.0.0)
3. **patch-only.txt**: Two fix commits → patch bump (1.0.0 → 1.0.1)

## GitHub Actions Workflow

The `.github/workflows/semantic-version-bumper.yml` workflow:

### Triggers
- **push**: On main/master branches
- **pull_request**: On all PRs
- **workflow_dispatch**: Manual trigger with optional test_fixture input

### Jobs
1. **Checkout code** (fetch-depth: 0 for full history)
2. **Setup Node.js** (v18)
3. **Install dependencies** (npm install)
4. **Run unit tests** (npm test)
5. **Determine fixture** (from workflow_dispatch input)
6. **Bump version** (runs CLI with selected fixture)
7. **Display results** (shows bumped version and changelog)

### Workflow Features
- Uses `actions/checkout@v4` for code checkout
- Uses `actions/setup-node@v4` for Node.js setup
- Passes test fixture via workflow_dispatch input
- Validates output with jq JSON parsing
- Displays changelog and version results

## Validation

### ActionLint Check
```bash
actionlint .github/workflows/semantic-version-bumper.yml
```
✓ Passes YAML validation
✓ Correct workflow syntax
✓ Proper action references
✓ Valid permissions and environment variables

### Act Integration Tests
```bash
bash run-act-tests.sh
```

Runs 3 complete end-to-end tests:
1. Feature commit scenario (expect 1.1.0)
2. Breaking change scenario (expect 2.0.0)
3. Patch only scenario (expect 1.0.1)

For each test:
- Resets package.json to 1.0.0
- Executes workflow via act in isolated Docker container
- Verifies version bump is correct
- Confirms all steps completed successfully

## Error Handling

### CLI Error Messages
- Invalid version format: "Invalid version format: {input}. Expected format: x.y.z or vx.y.z"
- Missing package.json: "package.json not found at {path}"
- Missing version field: "No version field found in package.json"
- Missing commits fixture: "Fixture file not found: {path}"
- Unknown bump type: "Unknown bump type: {type}"

### Graceful Degradation
- Non-conventional commits are ignored (return 'none' bump)
- Missing fields in package.json throw meaningful errors
- Invalid versions fail fast with clear error messages

## TDD Approach

This project was built using Red/Green/Refactor methodology:

1. **Red**: Write failing test first
2. **Green**: Implement minimum code to pass test
3. **Refactor**: Clean up implementation

Each feature was implemented this way:
- parseVersion tests → implementation
- determineVersionBump tests → implementation
- bumpVersion tests → implementation
- File I/O tests → implementation
- Integration tests → complete system verification

## Dependencies

- **jest** (devDependency): Testing framework
- **node-core libraries**: fs, path, child_process

## Development Notes

### Code Quality
- No external runtime dependencies (except Node.js)
- Single responsibility principle (each module has one clear purpose)
- Clear, descriptive function names
- Minimal comments (code is self-documenting)
- Proper error handling with meaningful messages

### Testing Strategy
- Isolated unit tests for each function
- Mock commit data via fixture files
- Temporary directories for file I/O testing
- Integration tests verify complete workflows
- act tests verify GitHub Actions execution

### Future Enhancements
- Support for git log parsing instead of fixtures
- CHANGELOG.md file generation
- NPM registry version checking
- Git tag creation
- Automated PR creation
