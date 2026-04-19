# Secret Rotation Validator - PowerShell Implementation

A PowerShell solution for validating secret rotation status, identifying expired or expiring secrets, and generating rotation reports in multiple formats.

## Project Structure

```
.
├── Invoke-SecretRotationValidator.ps1       # Main script with core logic
├── Invoke-SecretRotationValidator.Tests.ps1 # Pester test suite (8 tests)
├── run-all-tests.ps1                        # Comprehensive test harness
├── run-act-tests.ps1                        # GitHub Actions workflow tester
├── .github/workflows/
│   └── secret-rotation-validator.yml        # GitHub Actions workflow
└── act-result.txt                           # Test execution results
```

## Features

### Core Functionality
- **Secret Status Analysis**: Categorizes secrets as expired, warning, or ok
- **Configurable Warning Window**: Default 7-day warning period before expiration
- **Rotation Report Generation**: Groups notifications by urgency level
- **Multiple Output Formats**: Markdown table and JSON output

### Workflow Jobs
1. **Validate Secret Rotation** - Runs Pester tests in GitHub Actions
2. **Test Markdown Output Format** - Validates markdown report generation
3. **Test JSON Output Format** - Validates JSON report generation

## Usage

### Local Testing with Pester

```powershell
# Run all Pester tests
Invoke-Pester -Path "Invoke-SecretRotationValidator.Tests.ps1"
```

### Comprehensive Test Suite

```powershell
# Run all tests including local Pester and GitHub Actions via act
./run-all-tests.ps1
```

### Direct Script Usage

```powershell
. ./Invoke-SecretRotationValidator.ps1

$secrets = @(
    @{
        name = "api-key-prod"
        lastRotated = "2026-04-01"
        rotationPolicyDays = 30
        requiredByServices = @("api", "scheduler")
    }
)

$report = Get-RotationReport -Secrets $secrets -ReferenceDate (Get-Date) -WarningWindow 7
$markdown = Get-MarkdownReport -Report $report
Write-Output $markdown
```

## Test Coverage

### Pester Tests (8 total)
1. **Parse Configuration**: Validates secret config object parsing
2. **Expired Status**: Identifies secrets past rotation date
3. **Warning Status**: Identifies secrets within warning window
4. **OK Status**: Identifies secrets outside warning window
5. **Report Generation**: Groups secrets by urgency
6. **Days Calculation**: Accurate expiration day calculation
7. **Markdown Formatting**: Valid markdown table output
8. **JSON Formatting**: Valid JSON output with parsed validation

### GitHub Actions Workflow Tests
- Validates Pester tests run successfully in CI
- Tests Markdown report generation and formatting
- Tests JSON report generation and validation
- Confirms workflow structure is correct
- Validates against actionlint requirements

## Requirements

### Local Execution
- PowerShell 7.0+ (pwsh)
- Pester module (installed via `Install-Module -Name Pester`)

### GitHub Actions / act Execution
- PowerShell 7.0+
- Pester module
- Docker (for running tests via act)
- actionlint (for workflow validation)

## Test Results

All tests pass successfully:
- ✅ 8/8 Pester tests passing locally
- ✅ 3/3 GitHub Actions workflow jobs passing
- ✅ Workflow validation passing
- ✅ actionlint validation passing

See `act-result.txt` for detailed test execution logs.

## GitHub Actions Workflow

The workflow triggers on:
- `push` to main/master branches
- `pull_request` to main/master branches
- `workflow_dispatch` (manual trigger)

### Install Steps
- Checks out code
- Installs PowerShell 7.x from Microsoft packages
- Installs Pester module for testing

### Validation Jobs
- Runs Pester test suite (8 tests)
- Generates and validates Markdown format reports
- Generates and validates JSON format reports

## Error Handling

The implementation includes:
- Clear error messages for invalid inputs
- Exit codes indicating success (0) or failure (non-zero)
- Graceful handling of date parsing
- Validation of secret configuration structure
