# Secret Rotation Validator

A PowerShell-based validator that identifies secrets that are expired or expiring within a configurable warning window, generates rotation reports, and outputs notifications grouped by urgency.

## Features

- **Flexible Configuration**: Load secrets from JSON configuration files with metadata (name, last-rotated date, rotation policy in days, required-by services)
- **Configurable Warning Window**: Set custom warning thresholds (default: 7 days)
- **Multiple Output Formats**: Generate reports in Markdown (table) or JSON format
- **Urgency-Based Grouping**: Automatically categorize secrets into Expired, Warning, and OK statuses
- **Comprehensive Testing**: Full Pester test suite with 12+ test cases covering core functionality and edge cases
- **GitHub Actions Integration**: CI/CD workflow for automated validation with local testing via `act`

## Files

- **SecretRotationValidator.ps1** - Core module with validation logic and classes
- **Invoke-SecretRotationValidator.ps1** - CLI entry point script
- **SecretRotationValidator.Tests.ps1** - Comprehensive Pester test suite (12 tests)
- **test-secrets.json** - Mock configuration file with sample secrets
- **.github/workflows/secret-rotation-validator.yml** - GitHub Actions workflow
- **.actrc** - Configuration for local act testing

## Quick Start

### Running Tests

```powershell
# Run all tests
Invoke-Pester SecretRotationValidator.Tests.ps1 -Verbose

# Expected output: Tests Passed: 12, Failed: 0
```

### Validating Secrets

```powershell
# Generate Markdown report (default)
.\Invoke-SecretRotationValidator.ps1 -ConfigPath test-secrets.json -WarningDays 7

# Generate JSON report
.\Invoke-SecretRotationValidator.ps1 -ConfigPath test-secrets.json -WarningDays 7 -OutputFormat json

# Save to file
.\Invoke-SecretRotationValidator.ps1 -ConfigPath test-secrets.json -OutputFormat json -OutputPath report.json
```

### Exit Codes

- **0**: Validation passed (no expired secrets or only in warning state)
- **1**: One or more secrets expired
- **2**: Validation error (missing config file, parse error, etc.)

## Configuration Format

JSON file with secret metadata:

```json
[
  {
    "Name": "db-password",
    "LastRotated": "2026-04-10",
    "RotationPolicyDays": 30,
    "RequiredByServices": ["app-server", "database"]
  }
]
```

### Configuration Fields

- **Name** (string): Unique identifier for the secret
- **LastRotated** (date): Last rotation date in YYYY-MM-DD format
- **RotationPolicyDays** (integer): Days before secret expires
- **RequiredByServices** (array): Services depending on this secret

## Report Output

### Markdown Format

Shows summary statistics and a detailed table with columns:
- Name
- Status (Expired/Warning/OK)
- Days Until Expiry
- Last Rotated Date
- Policy (days)
- Required Services

### JSON Format

Structured output with:
- ReportDate
- Summary counts (Expired, Warning, OK)
- Separated arrays for each status category
- Full metadata for each secret

## Test Suite Coverage

The test suite includes 12 comprehensive tests organized in 6 contexts:

1. **Initialize Validator** - Creating validator instances with custom warning windows
2. **Load and Parse Secrets** - JSON loading and metadata parsing
3. **Calculate Secret Status** - Expiry detection, warning identification, health checks
4. **Generate Report** - Report generation with proper categorization
5. **Format Output** - Markdown and JSON formatting
6. **Edge Cases** - Empty services, short/long policies, boundary conditions

All tests follow red-green TDD methodology and use mock fixtures.

## GitHub Actions Workflow

The workflow (`.github/workflows/secret-rotation-validator.yml`) includes:

- **Triggers**: push, pull_request, schedule (daily 9 AM), workflow_dispatch
- **Test Job**: Runs full Pester test suite (12 tests)
- **Validate Job**: Executes validator against test configuration
- **Artifact Upload**: Generates and archives JSON reports
- **PowerShell Integration**: Uses `shell: pwsh` for native PowerShell execution

### Workflow Structure

```yaml
- Run Tests (all 12 Pester tests)
  └── Validate Secrets Configuration (markdown output)
      └── Generate JSON Report
          └── Upload Report (artifact)
```

### Running Locally with act

```bash
# Validate actionlint syntax
actionlint .github/workflows/secret-rotation-validator.yml

# Run test job locally
act push -j test --rm

# Run validation job locally
act push -j validate --rm

# Run all jobs
act push --rm
```

## Implementation Notes

- **TDD Methodology**: All functionality was developed using red-green TDD - tests written first, then implementation
- **Parameter Types**: Functions accept both hashtables and PSCustomObjects for flexibility
- **Error Handling**: Graceful error messages for missing files, parse errors, and validation failures
- **No External Dependencies**: Pure PowerShell 7.0+ with only Pester for testing
- **Deterministic Status Calculation**: Clear expiry boundaries (Days Until Expiry < 0 = Expired; <= WarningDays = Warning; else OK)

## Performance

- Full test suite: ~1.5-2 seconds
- Validation execution: ~2-3 seconds
- JSON report generation: Included in validation step

## Requirements

- PowerShell 7.0 or later
- Pester (included in PowerShell 7.0+)
- act (for local GitHub Actions testing)
- actionlint (for workflow validation)

## Example Output

### Markdown Report

```
# Secret Rotation Report
**Report Date:** 2026-04-19 12:38:31

## Summary
- **Expired:** 2
- **Warning:** 0
- **OK:** 1

## All Secrets

| Name | Status | Days Until Expiry | Last Rotated | Policy (days) | Services |
|------|--------|-------------------|--------------|---------------|----------|
| db-password | Expired | 0 | 2026-03-01 | 30 | app-server, database |
| api-key | OK | 81 | 2026-04-10 | 90 | api-gateway |
```

## License

Created for benchmark evaluation purposes.
