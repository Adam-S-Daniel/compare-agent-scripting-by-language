# Dependency License Checker

A PowerShell tool for checking project dependencies against license compliance policies. Parses dependency manifests (like `package.json`), looks up each dependency's license, and generates compliance reports with approval/denial status.

## Overview

This solution implements a complete dependency license compliance checker using **red/green Test-Driven Development** with Pester, along with a GitHub Actions workflow for automated CI/CD integration.

### Architecture

```
DependencyLicenseChecker.ps1
├── Parse-PackageJson              # Parse JSON manifest files
├── Parse-ManifestFile             # Load manifest from disk
├── Get-MockLicense                # Look up licenses (mocked for testing)
├── Check-LicenseCompliance        # Validate against allow/deny lists
├── Generate-ComplianceReport      # Produce structured report
└── Export-ComplianceReport        # Export to JSON and text formats

Check-DependencyLicenses.ps1       # CLI entry point for automation
└── Orchestrates the full workflow

DependencyLicenseChecker.Tests.ps1 # Pester test suite
├── Unit tests (parsing, license lookup, compliance checking)
├── Error handling tests
└── Integration tests (end-to-end workflow)

.github/workflows/
└── dependency-license-checker.yml # GitHub Actions workflow
    ├── Runs all Pester tests
    ├── Executes license check on test manifests
    ├── Generates and displays compliance reports
    └── Fails on denied licenses
```

## Features

- **JSON Parsing**: Extracts dependencies from `package.json` and similar manifests
- **Mock License Provider**: Simulates license lookups for testing (easily swappable for real APIs)
- **Compliance Rules**: Support for allow-lists and deny-lists
- **Status Reporting**: Three status levels - approved, denied, unknown
- **Multiple Output Formats**: JSON and human-readable text reports
- **Error Handling**: Graceful error messages for invalid input and missing files
- **GitHub Actions Integration**: Automated workflow with comprehensive reporting
- **Tested**: 10 comprehensive Pester tests covering all functionality

## Usage

### Local Testing

```powershell
# Run all Pester tests
Invoke-Pester -Path DependencyLicenseChecker.Tests.ps1 -Output Detailed

# Check a specific package.json
.\Check-DependencyLicenses.ps1 `
  -ManifestPath package.json `
  -ConfigPath license-config.json `
  -OutputPath report.json -Verbose
```

### Configuration

Create a `license-config.json` file:

```json
{
  "allowedLicenses": [
    "MIT",
    "Apache-2.0",
    "BSD-3-Clause"
  ],
  "deniedLicenses": [
    "GPL-3.0",
    "AGPL-3.0"
  ]
}
```

### Output

The tool generates two report files:

**compliance-report.json** (structured):
```json
[
  {
    "Name": "lodash",
    "Version": "4.17.21",
    "License": "MIT",
    "Status": "approved"
  },
  {
    "Name": "gpl-lib",
    "Version": "1.0.0",
    "License": "GPL-3.0",
    "Status": "denied"
  }
]
```

**compliance-report.txt** (human-readable):
```
=== DEPENDENCY LICENSE COMPLIANCE REPORT ===
Generated: 2026-05-06 23:38:10

SUMMARY:
--------
Total Dependencies: 2
Approved: 1
Denied: 1
Unknown: 0

DETAILS:
--------
lodash (4.17.21): MIT - [approved]
gpl-lib (1.0.0): GPL-3.0 - [denied]
```

## GitHub Actions Workflow

The workflow at `.github/workflows/dependency-license-checker.yml`:

- **Triggers**: Push, pull request, scheduled (weekly), and manual dispatch
- **Runs on**: Ubuntu latest with PowerShell
- **Steps**:
  1. Checkout code
  2. Run Pester test suite (10 tests)
  3. Check dependency licenses
  4. Display formatted compliance report
  5. Validate no denied licenses found
  6. Fail job if violations detected

The workflow exits with code 0 when all licenses are approved/unknown, and code 1 when denied licenses are found.

## Test Coverage

### Unit Tests (10 tests, all passing)

1. **Parsing**
   - Parse package.json with multiple dependencies
   - Handle order-independent extraction

2. **Mock License Provider**
   - Look up known licenses from mock database
   - Return correct license type for each dependency

3. **License Compliance**
   - Approve licenses in allow-list
   - Deny licenses in deny-list
   - Mark unknown licenses as unknown

4. **Report Generation**
   - Generate structured compliance report
   - Include all required fields (name, version, license, status)

5. **Error Handling**
   - Reject invalid JSON with meaningful errors
   - Fail on missing manifest files

6. **Integration**
   - Process real package.json and generate reports
   - Export to both JSON and text formats
   - Verify file creation and content

### Workflow Testing

The workflow has been validated with:
- **actionlint**: YAML syntax and structure validation ✓
- **act**: Local GitHub Actions execution simulation ✓
  - All 10 Pester tests pass
  - License check runs successfully
  - Reports generated and displayed correctly
  - Job completes with exit code 0

## Implementation Notes

### Red/Green TDD Approach

1. **Red Phase**: Write failing test for new functionality
2. **Green Phase**: Write minimal code to make test pass
3. **Refactor Phase**: Clean up without changing behavior
4. **Repeat**: For each feature

### Example: License Compliance Check

```powershell
# RED: Test fails - function doesn't exist
It "Should approve licenses in allow-list" {
    $status = Check-LicenseCompliance -LicenseType "MIT" -AllowList @("MIT") -DenyList @("GPL-3.0")
    $status | Should -Be "approved"
}

# GREEN: Minimal implementation
function Check-LicenseCompliance {
    param([string]$LicenseType, [string[]]$AllowList, [string[]]$DenyList)
    if ($DenyList -contains $LicenseType) { return "denied" }
    if ($AllowList -contains $LicenseType) { return "approved" }
    return "unknown"
}

# REFACTOR: (Already clean - no changes needed)
```

## Files

- `DependencyLicenseChecker.ps1` - Core module with all functions
- `Check-DependencyLicenses.ps1` - CLI entry point
- `DependencyLicenseChecker.Tests.ps1` - Pester test suite
- `.github/workflows/dependency-license-checker.yml` - GitHub Actions workflow
- `test-fixtures/` - Test data (sample manifests, configurations)
- `.actrc` - Docker image configuration for act
- `act-result.txt` - Output from workflow validation runs

## Testing the Workflow Locally

```bash
# Validate YAML
actionlint .github/workflows/dependency-license-checker.yml

# Simulate GitHub Actions execution
act push --rm

# Check results
cat act-result.txt | grep -E "Tests Passed|License compliance"
```

## Future Enhancements

- Support for more manifest formats (requirements.txt, go.mod, Cargo.toml)
- Integration with real license APIs (SPDX, npm registry)
- Caching of license lookups
- Custom policy files with regex matching
- PR comments with detailed violation reports
- License compatibility matrix (e.g., MIT ≠ GPL compatibility)

## Implementation Details

### Mock License Database

The mock provider includes common packages:
- lodash, axios, express, react (MIT)
- axios (Apache-2.0)
- gpl-lib (GPL-3.0)

To add real license lookups, replace `Get-MockLicense` with API calls to:
- npm registry (for JavaScript)
- PyPI (for Python)
- SPDX license database

### Error Handling Strategy

- **User Input Errors**: Missing/invalid manifests → meaningful error message
- **Configuration Errors**: Missing allow/deny lists → validation error
- **Parsing Errors**: Invalid JSON → clear parse exception
- **License Not Found**: Return "UNKNOWN" status (not an error)
- **Compliance Failures**: Exit code 1 with detailed report

## Status

✅ All 10 unit tests passing  
✅ GitHub Actions workflow validated with actionlint  
✅ Workflow execution successful via act  
✅ End-to-end testing complete  
✅ Ready for CI/CD integration
