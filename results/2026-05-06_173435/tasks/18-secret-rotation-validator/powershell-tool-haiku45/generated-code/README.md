# Secret Rotation Validator - PowerShell Implementation

## Overview
A PowerShell-based secret rotation validator that identifies secrets nearing or past their rotation deadlines, groups them by urgency level (expired/warning/ok), and generates rotation reports in multiple formats.

## Implementation Approach

### Red/Green TDD Methodology
- **Started with failing tests**: 14 comprehensive test cases covering core functionality and edge cases
- **Iteratively fixed implementation**: Built functions to pass each failing test
- **Refactored for robustness**: Enhanced error handling and edge case coverage

## Files

### Core Implementation
- **SecretRotationValidator.ps1**: Main module with 6 functions:
  - `Parse-SecretConfig`: Parses JSON configuration
  - `Test-SecretExpiration`: Checks if a secret has expired
  - `Test-SecretWarning`: Checks if a secret is in warning window
  - `Get-RotationStatus`: Categorizes secrets by status
  - `Format-RotationReport`: Generates markdown or JSON reports
  - `Invoke-SecretRotationValidator`: Main entry point

### Testing
- **Test-SecretRotationValidator.ps1**: 14 Pester test cases:
  - Parse-SecretConfig tests (2 tests)
  - Expiration/warning detection (3 tests)
  - Status categorization (1 test)
  - Report formatting (2 tests)
  - Workflow integration (1 test)
  - Edge cases (5 tests)

### CI/CD
- **.github/workflows/secret-rotation-validator.yml**: GitHub Actions workflow:
  - Triggers: push, pull_request, schedule (weekly), workflow_dispatch
  - Installs Pester and runs tests in PowerShell container
  - Validates script execution with sample data
  - Uses `mcr.microsoft.com/powershell:latest` container

### Artifacts
- **act-result.txt**: Complete output from GitHub Actions workflow via `act`
  - All 14 tests passing
  - Both markdown and JSON output validated

## Key Features

1. **Flexible Configuration**: Accepts JSON-formatted secret metadata
2. **Multiple Output Formats**: 
   - Markdown table (human-readable)
   - JSON (machine-readable)
3. **Configurable Warning Window**: Customize how many days before expiration to warn
4. **Error Handling**: Graceful handling of invalid JSON, empty configs, etc.
5. **Service Dependencies**: Tracks which services require each secret

## Test Coverage

All tests run through GitHub Actions via `act`:
- ✓ 14/14 tests passing
- ✓ 0 failures
- ✓ actionlint validation passed
- ✓ Job succeeded

## Test Cases

| Category | Count | Tests |
|----------|-------|-------|
| Configuration Parsing | 2 | Valid JSON, Invalid JSON |
| Expiration Detection | 2 | Expired, Not Expired |
| Warning Detection | 1 | In Warning Window |
| Status Categorization | 1 | Multiple statuses |
| Report Formatting | 2 | Markdown, JSON |
| Integration | 1 | Complete workflow |
| Edge Cases | 5 | Empty config, Multiple services, Days calculation, JSON validation, Warning window |

## Usage Example

```powershell
$configJson = @"
[
    {
        "name": "db-password",
        "lastRotated": "2026-04-05",
        "rotationPolicyDays": 30,
        "requiredByServices": ["api", "worker"]
    }
]
"@

$result = Invoke-SecretRotationValidator `
    -ConfigJson $configJson `
    -ReferenceDate (Get-Date) `
    -Format "markdown" `
    -WarningDays 7

Write-Output $result
```

## Validation

- **TDD Methodology**: Started with failing tests, incrementally fixed implementation
- **Comprehensive Testing**: 14 test cases covering happy path and edge cases
- **CI/CD Integration**: Full GitHub Actions workflow that runs tests in Docker
- **Actionlint Compliance**: Workflow passes actionlint security validation
- **Local Testing**: All tests verified to run correctly through `act`
