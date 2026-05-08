# Dependency License Checker

A PowerShell-based tool for checking project dependencies against allow-list and deny-list of software licenses, with comprehensive test coverage using Pester.

## Overview

This solution implements a dependency license compliance checker that:
- Parses dependency manifests (package.json for Node.js, requirements.txt for Python)
- Extracts dependency names and versions
- Checks each dependency against configurable allow/deny license lists
- Generates human-readable compliance reports
- Uses mocks for license lookups (enabling testing without external APIs)
- Includes a GitHub Actions workflow for CI/CD integration

## Architecture

### Core Components

1. **Check-DependencyLicenses.ps1** - Main PowerShell module
   - `Invoke-LicenseCheck` - Validates license configuration
   - `Get-Dependencies` - Parses manifest files (JSON/TXT)
   - `Get-LicenseForDependency` - Looks up licenses via mock provider
   - `New-ComplianceReport` - Generates categorized report
   - `Format-ComplianceReport` - Displays human-readable output
   - `Invoke-DependencyLicenseCheck` - Main orchestration function

2. **Check-DependencyLicenses.Tests.ps1** - Comprehensive test suite (12 tests)
   - License configuration validation
   - Manifest parsing (package.json and requirements.txt)
   - License lookup and mocking
   - Compliance report generation
   - Error handling and edge cases
   - Report formatting

3. **.github/workflows/dependency-license-checker.yml** - CI/CD Pipeline
   - Runs on push, pull_request, and manual trigger
   - Creates test fixtures and configuration
   - Executes Pester test suite
   - Checks compliance on real manifests
   - Generates compliance report artifact

## Test Results

All 12 tests pass successfully with 100% pass rate:

```
Tests Passed: 12, Failed: 0, Skipped: 0
Execution time: 1.91s
```

### Test Coverage

| Context | Test Count | Status |
|---------|-----------|--------|
| Basic License Configuration | 1 | ✅ PASS |
| Parse package.json Manifest | 1 | ✅ PASS |
| License Lookup Mock | 1 | ✅ PASS |
| License Compliance Report | 1 | ✅ PASS |
| Error Handling | 1 | ✅ PASS |
| Parse requirements.txt Manifest | 1 | ✅ PASS |
| Multiple License Categories | 1 | ✅ PASS |
| Version Extraction Accuracy | 1 | ✅ PASS |
| Unsupported Manifest Format | 1 | ✅ PASS |
| License Configuration Validation | 2 | ✅ PASS |
| Format Report Output | 1 | ✅ PASS |

## Usage

### Local Testing

Run all tests with Pester:
```powershell
Invoke-Pester -Path ./Check-DependencyLicenses.Tests.ps1
```

### Programmatic Usage

```powershell
# Import the module
. ./Check-DependencyLicenses.ps1

# Define configuration
$config = @{
    allowed = @("MIT", "Apache-2.0", "BSD-3-Clause")
    denied = @("GPL-3.0", "AGPL-3.0")
}

# Mock license data
$mockLicenses = @{
    "lodash" = "MIT"
    "react" = "MIT"
    "gpl-pkg" = "GPL-3.0"
}

# Parse dependencies
$dependencies = Get-Dependencies -ManifestPath "./package.json"

# Generate compliance report
$report = New-ComplianceReport -Dependencies $dependencies -Config $config -MockLicenses $mockLicenses

# Display report
Format-ComplianceReport -Report $report
```

### GitHub Actions Integration

The workflow runs automatically on:
- Push to main/master branches
- Pull requests against main/master
- Manual workflow dispatch trigger

Workflow steps:
1. Checkout code
2. Create license configuration
3. Run Pester test suite (12 tests)
4. Check package.json compliance
5. Check requirements.txt compliance
6. Generate compliance report

## Supported Manifest Formats

### package.json (Node.js)
- Parses both `dependencies` and `devDependencies`
- Extracts exact versions as specified
- Example:
  ```json
  {
    "dependencies": {
      "lodash": "4.17.21",
      "express": "4.18.2"
    }
  }
  ```

### requirements.txt (Python)
- Parses semantic version specifiers (==, >=, <=, etc.)
- Ignores comments and blank lines
- Example:
  ```
  requests==2.28.1
  django>=3.2.0
  flask>=2.1.0
  ```

## Report Output

### Console Output Format
```
=== Dependency License Compliance Report ===

Total Dependencies: 4

✓ Approved (4):
  - lodash (4.17.21): MIT
  - express (4.18.2): MIT
  - react (18.0.0): MIT
  - jest (29.0.0): MIT

✗ Denied (0):

? Unknown (0):

Summary:
  Compliant: 4 / 4
  Non-Compliant: 0 / 4
```

## Configuration

License configuration is defined as a JSON file with `allowed` and `denied` arrays:

```json
{
  "allowed": ["MIT", "Apache-2.0", "BSD-3-Clause", "ISC"],
  "denied": ["GPL-3.0", "AGPL-3.0"]
}
```

## Error Handling

- **Missing manifest file**: Throws error with clear message
- **Unsupported file format**: Rejects with format error
- **Invalid configuration**: Validates presence of required keys
- **Unknown licenses**: Categorizes as "unknown" for manual review

## GitHub Actions Workflow Validation

The workflow has been validated:
- ✅ actionlint: All YAML syntax is valid
- ✅ GitHub Actions: Proper trigger events and permissions
- ✅ act simulation: Workflow executes successfully in Docker

## Development Notes

### TDD Approach
This solution was developed using Test-Driven Development (Red-Green-Refactor):
1. Write failing test first
2. Implement minimum code to pass
3. Refactor for clarity and maintainability

### Test Fixtures
- `test-fixtures/simple-package.json` - Node.js package manifest with 4 dependencies
- `test-fixtures/requirements.txt` - Python requirements with 3 dependencies

### Helper Functions
- `ConvertTo-Hashtable` - Recursively converts PSObjects to hashtables
- `Create-TestFile` - Test helper for creating temporary files

## Future Enhancements

Potential improvements:
- External license lookup service integration (npmjs.org, PyPI)
- Support for additional manifest formats (Gemfile, Cargo.toml, pom.xml)
- License SPDX identifier validation
- Caching of license lookups
- JSON output format option
- CSV/HTML report generation
- License exception handling
- Dependency tree resolution

## Files

- `Check-DependencyLicenses.ps1` - Main module (280+ lines)
- `Check-DependencyLicenses.Tests.ps1` - Test suite (220+ lines, 12 tests)
- `.github/workflows/dependency-license-checker.yml` - CI/CD workflow
- `test-fixtures/simple-package.json` - Node.js test fixture
- `test-fixtures/requirements.txt` - Python test fixture
- `act-result.txt` - Workflow execution results
- `README.md` - This file

## License

This tool is provided as-is for validating third-party dependency licenses in your projects.
