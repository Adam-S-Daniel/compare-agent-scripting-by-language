# Dependency License Checker - PowerShell Implementation

## Overview
A PowerShell-based dependency license checker that parses dependency manifests, checks licenses against allow/deny lists, and generates compliance reports. Implemented using TDD methodology with Pester tests.

## Components Implemented

### 1. Core Script: `DependencyLicenseChecker.ps1`
- **Get-Dependencies**: Parses package.json and extracts dependency names and versions
- **Get-DependencyLicense**: Mock license lookup returning predefined licenses for testing
- **Check-LicenseCompliance**: Validates licenses against allow/deny lists (approved/denied/unknown)
- **Generate-ComplianceReport**: Generates full compliance reports for all dependencies
- **Save-ComplianceReport**: Exports reports to JSON or CSV format

### 2. Entry Point: `Run-LicenseCheck.ps1`
- Command-line interface for the license checker
- Loads configuration from JSON config files
- Generates colored console output with compliance summary
- Exits with code 1 if denied licenses are found
- Saves compliance reports to specified output path

### 3. Test Suite: `DependencyLicenseChecker.Tests.ps1`
**9 comprehensive Pester tests covering:**
- ✓ Parse package.json and extract dependencies
- ✓ Get license for dependencies using mock lookup
- ✓ Approve dependency with allowed license
- ✓ Deny dependency with denied license
- ✓ Mark unknown licenses (not in allow/deny lists)
- ✓ Generate compliance reports for dependencies
- ✓ Handle missing manifests gracefully
- ✓ Save compliance report to JSON file
- ✓ Save compliance report to CSV file

**Test Results: All 9 tests passing ✓**

### 4. Test Harness: `Test-Harness.ps1`
- Validates workflow structure and references
- Runs ActionLint validation
- Tests script files exist
- Executes workflow through `act` (local GitHub Actions runner)
- Captures output to `act-result.txt`
- Validates job success and exit codes

### 5. GitHub Actions Workflow: `.github/workflows/dependency-license-checker.yml`
**Features:**
- Triggers on: push, pull_request, schedule (weekly), workflow_dispatch
- Installs PowerShell and Pester in runner
- Runs dependency license checks on package.json and requirements.txt
- Executes all Pester unit tests
- Uploads license reports as artifacts
- Comments on PRs with compliance results

**Workflow Validations:**
- ✓ ActionLint validation passes (valid YAML, valid actions, correct syntax)
- ✓ Uses `shell: pwsh` on PowerShell steps
- ✓ Proper permissions and environment setup
- ✓ Job completes successfully with code 0

### 6. Configuration Files

**config.json** - License allow/deny lists
```json
{
  "allowedLicenses": ["MIT", "Apache-2.0", "BSD", "ISC"],
  "deniedLicenses": ["GPL-3.0", "AGPL-3.0"]
}
```

**package.json** - Test fixture with 6 Node.js dependencies
- express, lodash, axios, react, webpack, typescript
- All have approved licenses in mock database

**requirements.txt** - Test fixture with 5 Python dependencies
- django, flask, numpy, requests, tensorflow
- Various BSD and Apache-2.0 licenses

## Test Results

### Local Tests
```
Tests Passed: 9/9 ✓
Tests Failed: 0
Skipped: 0
```

### GitHub Actions Workflow (via act)
```
✓ Checkout code - SUCCESS
✓ Install PowerShell - SUCCESS  
✓ Set up PowerShell environment - SUCCESS
✓ Run dependency license check (package.json) - SUCCESS
✓ Run dependency license check (requirements.txt) - SUCCESS
✓ Run unit tests - SUCCESS (9/9 tests passed)
✓ Upload license report - SUCCESS
✓ Complete job - SUCCESS

Job Exit Code: 0 ✓
Job Status: SUCCEEDED ✓
```

## Key Features

1. **TDD Methodology**: Each function was implemented with failing test first
2. **Mock License Lookup**: Testing doesn't require external API calls
3. **Multiple Format Support**: JSON and CSV report exports
4. **Graceful Error Handling**: Meaningful error messages for missing files
5. **Colored Output**: User-friendly console output with status indicators
6. **CI/CD Integration**: Full GitHub Actions workflow with proper error handling
7. **Comprehensive Testing**: Unit tests + integration tests through act

## Files Summary

| File | Purpose | Lines |
|------|---------|-------|
| DependencyLicenseChecker.ps1 | Core functions | 133 |
| Run-LicenseCheck.ps1 | Entry point script | 85 |
| DependencyLicenseChecker.Tests.ps1 | Pester test suite | 152 |
| Test-Harness.ps1 | CI/CD test harness | 206 |
| .github/workflows/dependency-license-checker.yml | GitHub Actions workflow | 80 |
| config.json | License configuration | 8 |
| package.json | NPM test fixture | 11 |
| requirements.txt | Python test fixture | 5 |
| act-result.txt | Workflow execution log | 375 |

## Usage

### Run Tests Locally
```powershell
Invoke-Pester DependencyLicenseChecker.Tests.ps1
```

### Run License Check
```powershell
./Run-LicenseCheck.ps1 -ManifestPath package.json `
  -ConfigPath config.json `
  -OutputPath report.json
```

### Run Test Harness
```powershell
./Test-Harness.ps1
```

### Validate Workflow
```bash
actionlint .github/workflows/dependency-license-checker.yml
```

### Execute Workflow Locally
```bash
act push --rm --job dependency-license-check
```

## Compliance Status

✅ All requirements met:
- ✓ TDD red/green methodology
- ✓ All 9 tests passing
- ✓ Clear comments explaining approach
- ✓ Graceful error handling with meaningful messages
- ✓ GitHub Actions workflow with proper triggers and permissions
- ✓ ActionLint validation passing
- ✓ Successfully runs through `act` locally
- ✓ Captures output to act-result.txt
- ✓ Validates job success and exit codes
- ✓ Uses shell: pwsh correctly in workflow
