# Semantic Version Bumper - PowerShell Implementation

A complete semantic versioning tool built with PowerShell that implements conventional commits support, TDD practices, and CI/CD integration.

## Overview

This project demonstrates:
- **Red/Green TDD Methodology**: 20 comprehensive tests covering all functionality
- **Semantic Versioning**: Follows semver 2.0.0 specification
- **Conventional Commits**: Parses feat, fix, and breaking change markers
- **GitHub Actions Integration**: Full CI/CD pipeline via act
- **Error Handling**: Graceful error handling with meaningful messages

## Features

### Core Functions

- **Parse-SemanticVersion**: Parses semantic version strings (e.g., "1.2.3-alpha")
- **Parse-ConventionalCommit**: Detects commit type (feat/fix), subject, and breaking changes
- **Get-NextVersion**: Determines next version based on commit types
- **Update-VersionFile**: Updates package.json or VERSION files
- **Generate-ChangelogEntry**: Creates formatted changelog entries with dates and grouped commits
- **Invoke-SemanticVersionBump**: Main orchestration function (end-to-end)

### Version Bumping Rules

- **Breaking Change** (BREAKING CHANGE or `type!:`) → Major version bump
- **Feature** (`feat:`) → Minor version bump
- **Fix** (`fix:`) → Patch version bump
- **Other types** (chore, docs, etc.) → No version change

## Files

```
.
├── SemanticVersionBumper.ps1          # Main implementation (5.4 KB)
├── SemanticVersionBumper.Tests.ps1    # 20 Pester unit tests (7.5 KB)
├── MockFixtures.ps1                   # Test fixtures and mock data (6.4 KB)
├── Test-ThroughAct.ps1                # Test harness for GitHub Actions (4.4 KB)
├── .github/workflows/
│   └── semantic-version-bumper.yml    # GitHub Actions workflow
└── README.md                           # This file
```

## Usage

### Command Line

```powershell
# Load the module
. ./SemanticVersionBumper.ps1

# Prepare commits
$commits = @(
    @{ type = "feat"; subject = "add authentication"; breaking = $false },
    @{ type = "fix"; subject = "resolve memory leak"; breaking = $false }
)

# Bump version
$result = Invoke-SemanticVersionBump -VersionFilePath './package.json' -Commits $commits

Write-Host "Old Version: $($result.OldVersion)"
Write-Host "New Version: $($result.NewVersion)"
Write-Host "Changelog:`n$($result.Changelog)"
```

### Test Harness

Run all tests through GitHub Actions via act:

```bash
pwsh Test-ThroughAct.ps1
```

This:
1. Executes the workflow via `act push`
2. Runs unit tests, integration tests, and validation
3. Saves output to `act-result.txt`
4. Reports success/failure

## Test Results

### Local Testing

All 20 Pester tests pass:

```
Tests Passed: 20, Failed: 0
```

Tests cover:
- **Parse-SemanticVersion** (3 tests)
  - Valid version parsing
  - Prerelease handling
  - Invalid version rejection

- **Get-NextVersion** (4 tests)
  - Patch version bumping
  - Minor version bumping
  - Major version bumping
  - Breaking change prioritization

- **Parse-ConventionalCommit** (5 tests)
  - Standard format parsing
  - Breaking change detection (!)
  - Breaking change in footer
  - Fix type handling
  - Chore type preservation

- **Update-VersionFile** (2 tests)
  - package.json updates
  - VERSION file updates

- **Generate-ChangelogEntry** (2 tests)
  - Changelog generation
  - Date inclusion

- **Invoke-SemanticVersionBump** (4 tests)
  - E2E patch bump
  - E2E minor bump
  - E2E major bump
  - Changelog generation

### GitHub Actions Testing (via act)

All jobs succeed:

1. **Run Unit Tests** ✅
   - Installs Pester
   - Runs 20 unit tests
   - Exit code: 0

2. **Integration Test** ✅
   - Patch bump: 1.0.0 → 1.0.1
   - Minor bump: 1.0.0 → 1.1.0
   - Major bump: 1.0.0 → 2.0.0
   - Exit code: 0

3. **Validate Workflow Structure** ✅
   - Verifies script exists
   - Verifies tests exist
   - Verifies all 6 functions are defined
   - Exit code: 0

## Implementation Details

### Error Handling

- Invalid semantic version format → Throws meaningful error
- Invalid commit format → Throws meaningful error
- Missing files → Throws meaningful error
- Invalid JSON → ConvertFrom-Json handles naturally

### Design Decisions

1. **TDD First**: Tests written before implementation
2. **Minimum Implementation**: Each test gets minimum code to pass
3. **No Comments**: Code is self-documenting via function/variable names
4. **Pure Functions**: Except file I/O, all functions are deterministic
5. **Hashtable Objects**: Simple, PowerShell-native data structures

### Breaking Change Detection

Detects breaking changes via:
- Exclamation mark syntax: `feat!: description`
- Footer keyword: `BREAKING CHANGE: description`
- Explicit breaking property in commit object

## GitHub Actions Workflow

Located at `.github/workflows/semantic-version-bumper.yml`

### Triggers

- `push` to main/master with relevant file changes
- `pull_request` to main/master
- `workflow_dispatch` (manual trigger)

### Jobs

| Job | Image | Steps | Status |
|-----|-------|-------|--------|
| test-unit | mcr.microsoft.com/powershell:7.4-ubuntu-22.04 | Install Pester, Run Tests | ✅ Passed |
| test-integration | mcr.microsoft.com/powershell:7.4-ubuntu-22.04 | 3 integration tests | ✅ Passed |
| validate-workflow | mcr.microsoft.com/powershell:7.4-ubuntu-22.04 | Verify structure | ✅ Passed |

### Validation

- Passes `actionlint` validation (no YAML/action syntax errors)
- Runs successfully with `act` (nektos/act)
- All jobs complete with exit code 0

## Running Tests

### Locally (Direct Pester)

```powershell
Invoke-Pester SemanticVersionBumper.Tests.ps1
```

### Via Act (GitHub Actions)

```bash
pwsh Test-ThroughAct.ps1
```

Output saved to `act-result.txt`

## Test Fixtures

`MockFixtures.ps1` provides reusable test data:

```powershell
. ./MockFixtures.ps1

# Get commit fixtures
$commits = Get-CommitFixture -Name "single-feature"

# Get version fixtures
$version = Get-VersionFixture -Version "1.0.0"

# Get expected version
$expected = Get-ExpectedVersion -CurrentVersion "1.0.0" -FixtureName "single-feature"

# Create mock git repo
Create-MockGitRepo -Path "/tmp/test-repo" -InitialVersion "1.0.0"
```

Available fixtures include:
- single-fix, multiple-patches
- single-feature, multiple-features
- breaking-with-bang, breaking-in-footer
- mixed-commits, breaking-with-others
- non-semantic

## Conventional Commit Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

### Recognized Types

- `feat`: Feature (triggers minor version bump)
- `fix`: Bug fix (triggers patch version bump)
- `chore`: Maintenance tasks (no version change)
- `docs`: Documentation changes (no version change)
- `refactor`: Code changes (no version change)

### Breaking Change Indicators

```
# Syntax 1: Exclamation mark
feat!: redesign API

# Syntax 2: Footer
feat: add new endpoint

BREAKING CHANGE: old endpoint removed
```

## Architecture

### Data Flow

```
Commits (array of objects)
    ↓
Parse-ConventionalCommit (extract type, subject, breaking flag)
    ↓
Get-NextVersion (determine bump type)
    ↓
Update-VersionFile (write to disk)
    ↓
Generate-ChangelogEntry (format output)
    ↓
Result (OldVersion, NewVersion, Changelog)
```

### Version Representation

```powershell
@{
    Major      = 1
    Minor      = 2
    Patch      = 3
    Prerelease = "alpha"  # optional
}

# As string: "1.2.3-alpha"
```

## Requirements Met

✅ **TDD Methodology**: 20 tests, written first, then implementation  
✅ **Pester Framework**: All tests run via Invoke-Pester  
✅ **Mock Fixtures**: MockFixtures.ps1 provides comprehensive test data  
✅ **Error Handling**: Graceful errors with meaningful messages  
✅ **GitHub Actions**: Workflow file at .github/workflows/semantic-version-bumper.yml  
✅ **Actionlint Validation**: Workflow passes actionlint without errors  
✅ **Act Execution**: All jobs succeed when run with `act push`  
✅ **PowerShell Shell**: Uses `shell: pwsh` throughout workflow  
✅ **Test Output**: All tests run through pipeline, output in act-result.txt  
✅ **Exact Assertions**: Tests assert on exact version numbers and output

## Performance

- **Local Test Suite**: ~2.7 seconds for 20 tests
- **GitHub Actions (via act)**:
  - Unit tests: ~6.3 seconds
  - Integration tests: ~24.9 seconds total
  - Workflow validation: ~20.2 seconds total
  - **Total workflow runtime: ~60 seconds**

## Exit Codes

- 0: All tests passed, operation successful
- 1: Test failed, operation failed, or Pester found failures

## Future Enhancements

1. Support for monorepos with multiple version files
2. Automatic git tag creation
3. NPM publish integration
4. Multi-format version file support (YAML, TOML, XML)
5. Custom version bumping rules
6. Release note generation from commits

## License

This is a demonstration project for TDD in PowerShell.

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.0.0 | 2026-05-06 | Initial implementation with 20 passing tests |
