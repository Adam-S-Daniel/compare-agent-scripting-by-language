# Semantic Version Bumper - PowerShell Solution

## Overview
This is a complete implementation of a semantic version bumper utility in PowerShell that follows Test-Driven Development (TDD) methodology. The solution parses version files, analyzes conventional commit messages, determines version bumps (major, minor, patch), and generates changelog entries.

## Implementation Details

### Core Components

#### 1. SemanticVersionBumper.ps1
Main implementation file containing seven public functions:

- **Get-CurrentVersion**: Parses version from package.json or version.txt files
- **Compare-Versions**: Compares two semantic versions (returns 1, 0, or -1)
- **Get-BumpType**: Analyzes conventional commits to determine bump type:
  - `feat!:` or `BREAKING CHANGE:` → major
  - `feat:` → minor
  - `fix:` → patch
  - No commits → patch (default, but no actual bump applied)
- **Bump-Version**: Increments version based on bump type (1.0.0 + major = 2.0.0)
- **Update-VersionFile**: Updates version in place in package.json or version.txt
- **Generate-ChangelogEntry**: Creates formatted changelog from commits, organized by type
- **Invoke-SemanticVersionBumper**: Main orchestration function

#### 2. SemanticVersionBumper.Tests.ps1
Comprehensive Pester test suite with 18 tests covering:
- Version parsing from different file formats
- Version comparison logic
- Conventional commit analysis
- Version bumping logic
- File updates
- Changelog generation
- End-to-end integration

All tests pass with TDD approach: failing tests written first, then minimal code to pass.

#### 3. Test Fixtures (test-fixtures/)
Mock commit data in JSON format for different scenarios:

- **patch-fix.json**: Two fix commits → expects 1.0.1 patch bump
- **minor-feature.json**: Feature and fix commits → expects 1.1.0 minor bump
- **major-breaking.json**: Breaking change with features and fixes → expects 2.0.0 major bump
- **no-changes.json**: Empty commit array → expects 1.0.0 no change

#### 4. GitHub Actions Workflow (.github/workflows/semantic-version-bumper.yml)
Production-ready CI/CD workflow featuring:

- **Triggers**: push, pull_request, workflow_dispatch
- **Matrix Testing**: Runs all 4 test fixtures in parallel (test-1, test-2, test-3, test-4)
- **Jobs**:
  - `test`: Validates version bumping against each fixture with assertions
  - `run-tests`: Executes all 18 Pester unit tests
  - `validate-workflow`: Runs actionlint for workflow validation
- **Steps per test job**:
  1. Set up test environment
  2. Copy test fixture
  3. Run semantic version bumper script
  4. Verify version file update
  5. Assert expected versions match actual output

### Key Features

1. **TDD Methodology**: Written test-first approach, all tests pass
2. **Error Handling**: Graceful handling of empty commits, missing files, null values
3. **Conventional Commits**: Full support for Conventional Commits specification with breaking change detection
4. **Flexible Input**: Works with package.json or plain version.txt files
5. **Changelog Generation**: Auto-formatted changelog with categorized commits
6. **CI/CD Ready**: GitHub Actions workflow passes actionlint validation
7. **Deterministic Testing**: Test fixtures enable reproducible tests

### Testing Results

#### Unit Tests (Pester)
- **Total Tests**: 18
- **Passed**: 18
- **Failed**: 0
- **Coverage**: Version parsing, comparison, bump detection, file updates, changelog generation, integration

#### Workflow Tests (via act)
Run with `act push --rm`:
- **test-1 (patch-fix)**: ✅ 1.0.0 → 1.0.1
- **test-2 (minor-feature)**: ✅ 1.0.0 → 1.1.0
- **test-3 (major-breaking)**: ✅ 1.0.0 → 2.0.0
- **test-4 (no-changes)**: ✅ 1.0.0 → 1.0.0 (no change)
- **run-tests**: ✅ All 18 Pester tests passed
- **validate-workflow**: ✅ actionlint validation passed

### File Structure
```
.
├── SemanticVersionBumper.ps1              (Main implementation)
├── SemanticVersionBumper.Tests.ps1        (Pester tests)
├── .github/workflows/
│   └── semantic-version-bumper.yml        (GitHub Actions workflow)
├── test-fixtures/
│   ├── patch-fix.json                     (Fix commits fixture)
│   ├── minor-feature.json                 (Feature commits fixture)
│   ├── major-breaking.json                (Breaking change fixture)
│   └── no-changes.json                    (Empty commits fixture)
└── act-result.txt                         (Workflow test output)
```

### Usage

#### Run Unit Tests
```powershell
Invoke-Pester -Path ./SemanticVersionBumper.Tests.ps1
```

#### Run Version Bumping
```powershell
. ./SemanticVersionBumper.ps1

$result = Invoke-SemanticVersionBumper -ProjectPath ./my-project -CommitsFile ./commits.json

Write-Host "New Version: $($result.NewVersion)"
Write-Host "Bump Type: $($result.BumpType)"
Write-Host "Changelog:`n$($result.Changelog)"
```

#### Run GitHub Actions Workflow Locally
```bash
act push --rm
```

### Design Decisions

1. **Empty Commits Handling**: When no commits are provided, version remains unchanged (no automatic patch bump)
2. **Default Bump Type**: Patch is the default bump type when no conventional commits found
3. **Hash Truncation**: Git hashes are truncated to 7 characters in changelog (standard short format)
4. **Parameter Flexibility**: Optional parameters with sensible defaults for robustness
5. **TDD Approach**: All functionality driven by failing tests, ensuring high quality

### Validation

- ✅ actionlint passes without errors
- ✅ All 18 unit tests pass
- ✅ All 4 workflow test fixtures pass
- ✅ Workflow structure validated
- ✅ PowerShell syntax correct
- ✅ Error handling comprehensive

### Notes

- The solution uses PowerShell 7+ (pwsh) for cross-platform compatibility
- Test fixtures enable deterministic, repeatable testing without actual git repositories
- The workflow is designed to run in isolated Docker containers via `act`
- All code follows PowerShell best practices and conventions
