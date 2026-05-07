# Secret Rotation Validator

A PowerShell script and test suite that validates secret rotation policies and identifies expired or expiring secrets.

## Overview

This solution identifies secrets that are expired or expiring within a configurable warning window, generates rotation reports, and outputs notifications grouped by urgency (expired, warning, ok). It supports multiple output formats (markdown table, JSON) and integrates with GitHub Actions for CI/CD pipelines.

## Development Approach

This project uses **Red/Green Test-Driven Development (TDD)**:

1. **Test First** - Write comprehensive Pester tests before implementing functionality
2. **Minimal Implementation** - Write the minimum code to make tests pass
3. **Refactor** - Clean up and optimize as needed

### Test Results

All 11 tests pass:
- ✅ `Get-SecretStatus` function tests (4 tests)
- ✅ `Invoke-SecretRotationValidator` function tests (4 tests)  
- ✅ `Format-SecretRotationReport` function tests (3 tests)

```
Tests Passed: 11, Failed: 0, Skipped: 0, Inconclusive: 0
```

## Files

### Core Scripts

- **`Invoke-SecretRotationValidator.ps1`** - Main module with three functions:
  - `Get-SecretStatus` - Determines if a secret is expired, warning, or ok
  - `Invoke-SecretRotationValidator` - Validates all secrets and categorizes by status
  - `Format-SecretRotationReport` - Formats results as markdown or JSON

- **`Validate-SecretRotation.ps1`** - CLI entry point that:
  - Loads secrets from JSON or CSV configuration files
  - Runs the validator
  - Returns appropriate exit codes (0=ok, 1=expired, 2=error)

- **`Test-SecretRotationValidator.ps1`** - Comprehensive Pester test suite

### Test Fixtures

- **`fixtures/healthy-secrets.json`** - 3 healthy secrets with no expiration concerns
- **`fixtures/mixed-secrets.json`** - 4 secrets with expired, warning, and healthy status

### GitHub Actions

- **`.github/workflows/secret-rotation-validator.yml`** - CI/CD pipeline with 4 jobs:
  1. **Run Tests** - Executes all Pester unit tests
  2. **Validate Healthy Secrets** - Tests markdown output format
  3. **Validate Mixed Secrets** - Tests handling of expired secrets
  4. **Validate JSON Output** - Tests JSON format output

### Build Artifacts

- **`.actrc`** - Act configuration specifying Docker image for local testing
- **`act-result.txt`** - Test results from running workflow via act

## Usage

### Run Unit Tests

```powershell
Invoke-Pester -Path Test-SecretRotationValidator.ps1
```

### Validate Secrets from Configuration File

```powershell
# Markdown output (default)
./Validate-SecretRotation.ps1 -ConfigPath secrets.json

# JSON output
./Validate-SecretRotation.ps1 -ConfigPath secrets.json -OutputFormat json

# Custom warning window (default 7 days)
./Validate-SecretRotation.ps1 -ConfigPath secrets.json -WarningWindow 14
```

### Configuration File Format

JSON format (`secrets.json`):
```json
[
  {
    "Name": "db-password",
    "LastRotated": "2026-04-20",
    "RotationPolicyDays": 30,
    "RequiredBy": ["api", "worker"]
  }
]
```

### Output Format - Markdown

```
## Expired Secrets
| Secret Name | Days Overdue | Required By | Last Rotated |
|---|---|---|---|
| db-password | 5 | api, worker | 2026-04-20 |

## Warning - Expiring Soon
| Secret Name | Days Until Expiry | Required By | Last Rotated |
|---|---|---|---|
| api-key | 3 | web-service | 2026-04-27 |

## Healthy Secrets
| Secret Name | Days Until Expiry | Required By | Last Rotated |
|---|---|---|---|
| cache-key | 20 | cache-service | 2026-04-10 |
```

### Output Format - JSON

```json
{
  "expired": [
    {
      "Name": "db-password",
      "DaysSinceRotation": 35,
      "RotationPolicyDays": 30,
      "DaysOverdue": 5,
      "RequiredBy": ["api", "worker"],
      "Status": "expired"
    }
  ],
  "warning": [...],
  "ok": [...]
}
```

## Exit Codes

- **0** - All secrets healthy
- **1** - One or more secrets expired
- **2** - Configuration or execution error

## GitHub Actions Workflow

The workflow runs on:
- **push** to main/master branches
- **pull_request** to main/master branches
- **schedule** - Weekly (Sunday at midnight)
- **workflow_dispatch** - Manual trigger

Each job uses `shell: pwsh` to run PowerShell scripts in GitHub Actions.

### Local Testing with Act

```bash
# Install act (GitHub Actions local runner)
# https://github.com/nektos/act

# Run workflow locally
act push --rm

# Capture output to file
pwsh test-harness.ps1
```

## Architecture

### Status Determination Logic

```
LastRotated + RotationPolicyDays = ExpirationDate
DaysSinceRotation = Today - LastRotated

if DaysSinceRotation > RotationPolicyDays:
  Status = "expired"
  DaysOverdue = DaysSinceRotation - RotationPolicyDays
else if DaysSinceRotation > (RotationPolicyDays - WarningWindow):
  Status = "warning"
  DaysUntilExpiry = RotationPolicyDays - DaysSinceRotation
else:
  Status = "ok"
  DaysUntilExpiry = RotationPolicyDays - DaysSinceRotation
```

### Key Design Decisions

1. **No External Dependencies** - Uses only PowerShell built-ins and Pester
2. **Flexible Input Handling** - Accepts both hashtables and PSCustomObjects from JSON
3. **Multiple Output Formats** - Markdown for human review, JSON for tool integration
4. **Error Handling** - Meaningful error messages for configuration issues
5. **Exit Codes** - Scripts return appropriate exit codes for CI/CD pipeline decisions

## Testing Strategy

### Unit Tests (Pester)

11 comprehensive tests covering:
- Expired secret detection
- Warning status for secrets expiring soon
- Healthy secret identification
- Custom warning windows
- Multiple secret handling
- Error cases (empty secrets, missing config)
- Output format validation (markdown, JSON)
- RequiredBy service list formatting

### Integration Tests (GitHub Actions)

4 workflow jobs testing:
- Unit test execution via act
- Markdown output validation
- JSON output parsing
- Exit code handling
- Mixed secret scenarios

### Test Fixtures

Two JSON configuration files:
- **healthy-secrets.json**: 3 secrets, all healthy
- **mixed-secrets.json**: 4 secrets, varied status (expired, warning, ok)

## Requirements

- PowerShell 7+ (or Windows PowerShell 5.1)
- Pester testing framework (pre-installed with PowerShell 5+)
- Docker (for running workflow locally via act)

## Notes

- Date parsing handles both `datetime` objects and ISO 8601 strings
- RequiredBy services are comma-separated in CSV, arrays in JSON
- The warning window is configurable (default 7 days)
- All calculations use days as the unit (no hours/minutes)
- Reports omit sections with no matching secrets
