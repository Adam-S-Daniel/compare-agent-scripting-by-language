# Semantic Version Bumper - PowerShell Implementation

A PowerShell solution for semantic version bumping based on conventional commit messages, with full GitHub Actions workflow integration and comprehensive test coverage.

## Features

- **Semantic Versioning**: Parses and updates version strings following semver rules
- **Conventional Commits**: Analyzes commit messages to determine version bump type:
  - `feat:` → Minor version bump
  - `fix:` → Patch version bump
  - `BREAKING CHANGE:` → Major version bump
- **Changelog Generation**: Creates formatted changelog entries from commits
- **GitHub Actions Integration**: Complete workflow for CI/CD pipelines
- **TDD Approach**: 9 comprehensive Pester tests covering all functionality

## Files

### Core Scripts
- **semantic-version-bumper.ps1** - Main library with versioning logic
- **bump-version.ps1** - CLI entry point for scripts and workflows
- **test-fixtures.ps1** - Test data for multiple scenarios

### Testing
- **semantic-version-bumper.tests.ps1** - 9 Pester tests (all passing)
- **run-integration-tests.ps1** - Integration test harness
- **validate-workflow.ps1** - Workflow structure validation (13 checks, all passing)

### GitHub Actions
- **.github/workflows/semantic-version-bumper.yml** - Complete workflow
  - Installs PowerShell and Pester
  - Runs all unit tests
  - Performs version bump
  - Generates changelog
  - Validates artifacts

### Test Results
- **act-result.txt** - Integration test results (3 successful test runs through act)

## Test Results

### Unit Tests
✅ All 9 Pester tests pass:
- Parse version from package.json
- Bump minor version for feat commits
- Bump patch version for fix commits
- Bump major version for breaking changes
- Priority handling for multiple commit types
- Update package.json correctly
- Generate changelog entries
- End-to-end workflow

### Integration Tests via Act
✅ 3 test cases run through GitHub Actions workflow:
1. `complex-breaking`: 3.2.1 → 4.0.0
2. `simple-minor`: 1.0.0 → 1.1.0
3. `breaking-change`: 1.0.0 → 2.0.0

### Workflow Validation
✅ All 13 validation checks pass:
- Workflow file structure
- YAML syntax
- PowerShell usage (`shell: pwsh`)
- Script file references
- Required steps present
- actionlint validation

## Usage

### Direct Script Usage
```powershell
./bump-version.ps1 -PackagePath package.json -ChangelogPath CHANGELOG.md -CommitsFile commits.txt
```

### GitHub Actions Workflow
The workflow automatically:
1. Installs PowerShell 7.6+
2. Installs Pester testing framework
3. Runs all unit tests
4. Bumps version based on commits
5. Generates changelog
6. Outputs version information

### Testing
```powershell
# Run unit tests
Invoke-Pester -Path ./semantic-version-bumper.tests.ps1

# Validate workflow
pwsh -File validate-workflow.ps1

# Run integration tests
pwsh -File run-integration-tests.ps1
```

## Implementation Highlights

- **Red/Green TDD**: Tests written first, then implementation
- **Cross-platform**: Uses PowerShell 7 Core on Linux/Windows/macOS
- **Error handling**: Graceful failures with meaningful error messages
- **CI/CD ready**: Full GitHub Actions integration with proper exit codes
- **Artifact generation**: Creates act-result.txt with all test output

## Architecture

```
semantic-version-bumper.ps1
├── Get-CurrentVersion()        # Parse version from file
├── Get-NextVersion()           # Determine bump based on commits
├── Update-VersionFile()        # Persist new version
├── Get-Changelog()             # Generate changelog
└── Update-SemanticVersion()    # Orchestrate workflow

bump-version.ps1
└── Entry point for CLI/GHA

GitHub Actions Workflow
├── Install PowerShell
├── Install Pester
├── Run Tests
├── Bump Version
└── Verify & Output
```

## Performance

- Unit tests: ~0.7 seconds (9 tests)
- Workflow execution: ~3-4 minutes per act run (includes package installation)
- Total benchmark time for 3 act runs: ~12 minutes
