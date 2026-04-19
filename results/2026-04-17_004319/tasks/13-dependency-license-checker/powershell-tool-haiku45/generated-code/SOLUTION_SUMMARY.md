# Dependency License Checker - PowerShell Implementation

## Overview
A fully tested PowerShell-based dependency license checker that:
- Parses package.json and requirements.txt manifests
- Extracts dependency names and versions
- Checks licenses against allow-lists and deny-lists
- Generates compliance reports
- Uses mocked license lookups for testing
- Integrates with GitHub Actions CI/CD

## Files Created

### Core Implementation
- **DependencyLicenseChecker.ps1** - Main script with:
  - `Parse-PackageJson()` - Parse npm package.json files
  - `Parse-RequirementsTxt()` - Parse Python requirements.txt files
  - License compliance checking logic
  - Support for custom license lookup functions

### Tests
- **DependencyLicenseChecker.Tests.ps1** - Pester test suite with 5 tests:
  1. Parse package.json - Extract dependencies and versions
  2. Parse requirements.txt - Handle Python version specifiers (==, >=, etc.)
  3. Generate compliance report - Test license checking with mock lookup
  4. Handle denied licenses - Verify GPL and other denied licenses are marked
  5. Handle unknown licenses - Verify missing licenses are marked as unknown

### GitHub Actions Workflow
- **.github/workflows/dependency-license-checker.yml** - CI/CD pipeline:
  - Triggers: push, pull_request, workflow_dispatch, schedule (weekly)
  - Two jobs:
    1. **test** - Runs all Pester tests
    2. **compliance-check** - Runs license checker on test fixtures
  - Uses `shell: pwsh` for proper PowerShell integration
  - Creates test fixtures with mock data
  - Verifies no denied licenses in dependencies

### Workflow Validation
- **.actrc** - Configuration for local `act` testing with PowerShell support
- **act-result.txt** - Complete output from successful workflow execution

## Test Results

✅ **All 5 Pester Tests Passed**
✅ **Workflow passed actionlint validation**
✅ **GitHub Actions workflow executes successfully via `act`**
✅ **Both jobs completed successfully:**
   - Run Pester Tests job: ✓ All 5 tests passed
   - Check Test Fixtures job: ✓ License checking validated

## Key Features

### Dependency Parsing
- Handles npm package.json with nested dependency objects
- Handles Python requirements.txt with various version specifiers:
  - Exact: `package==1.0.0`
  - Minimum: `package>=1.0.0`
  - Range: `package>=1.0.0,<2.0.0`
  - Compatible: `package~=1.4.5`

### License Compliance
- Three status categories:
  - **approved** - License in allow-list
  - **denied** - License in deny-list  
  - **unknown** - License not in either list
- Accepts custom license lookup function (mock for testing)
- Allows/denies lists as hashtables

### Error Handling
- Graceful handling of invalid manifest file types
- Support for comments and empty lines in requirements.txt
- Proper exit codes on errors

## Usage Example

```powershell
# Check a package manifest with license verification
$licenseLookup = {
    param($packageName)
    @{
        "lodash" = "MIT"
        "express" = "MIT"
    }[$packageName]
}

$allowed = @{ "MIT" = $true; "Apache-2.0" = $true }
$denied = @{ "GPL" = $true }

./DependencyLicenseChecker.ps1 `
    -ManifestPath "package.json" `
    -AllowedLicenses $allowed `
    -DeniedLicenses $denied `
    -LicenseLookup $licenseLookup
```

## TDD Methodology

The implementation followed red/green TDD:
1. Write failing test first
2. Implement minimum code to pass test
3. Refactor and optimize
4. Repeat for each feature

This ensured comprehensive test coverage and clean, maintainable code.

## Validation

All validation steps passed:
- ✅ `Invoke-Pester` tests: 5/5 passed
- ✅ `actionlint` workflow validation: 0 errors
- ✅ `act push --rm` workflow execution: Both jobs succeeded
- ✅ License compliance checking: All fixtures processed correctly

## Running Tests

Local testing:
```bash
pwsh -Command "Invoke-Pester -Path DependencyLicenseChecker.Tests.ps1"
```

GitHub Actions workflow:
```bash
act push --rm
```
