# Dependency License Checker (PowerShell)

A TDD-developed PowerShell utility that checks software dependencies against a license compliance policy.

## Quick Start

### Run Tests
```powershell
Invoke-Pester DependencyLicenseChecker.Tests.ps1
```

### Check Dependencies
```powershell
./Run-LicenseCheck.ps1 -ManifestPath package.json -ConfigPath config.json -OutputPath report.json
```

### Run Full Test Suite Including GitHub Actions
```powershell
./Test-Harness.ps1
```

## Project Structure

```
├── DependencyLicenseChecker.ps1       # Core functions
├── Run-LicenseCheck.ps1               # Command-line entry point
├── DependencyLicenseChecker.Tests.ps1 # Pester tests (9 tests)
├── Test-Harness.ps1                  # CI/CD test harness
├── config.json                        # License allow/deny config
├── package.json                       # NPM test fixture
├── requirements.txt                   # Python test fixture
├── .github/workflows/
│   └── dependency-license-checker.yml # GitHub Actions workflow
└── act-result.txt                     # Workflow execution log
```

## Features

- **Parse Manifests**: Extracts dependencies from package.json, requirements.txt, etc.
- **License Lookup**: Mock database with pre-defined licenses for testing
- **Compliance Checking**: Validates against configurable allow/deny lists
- **Report Generation**: JSON/CSV compliance reports
- **CI/CD Integration**: Full GitHub Actions workflow
- **TDD Approach**: 9 comprehensive Pester tests

## Test Results

- ✅ All 9 unit tests passing
- ✅ GitHub Actions workflow succeeds (via act)
- ✅ ActionLint validation passes
- ✅ Graceful error handling

## Configuration

Edit `config.json` to customize allowed/denied licenses:

```json
{
  "allowedLicenses": ["MIT", "Apache-2.0", "BSD"],
  "deniedLicenses": ["GPL-3.0", "AGPL-3.0"]
}
```

## Output Example

```
Dependency License Checker
================================================
Approved (6):
  ✓ express@4.18.0 [MIT]
  ✓ lodash@4.17.21 [MIT]
  ✓ react@18.2.0 [MIT]
  ✓ webpack@5.88.0 [MIT]
  ✓ typescript@5.0.0 [Apache-2.0]
  ✓ axios@1.4.0 [MIT]

[SUCCESS] All dependencies have approved or unknown licenses!
```

## Implementation Notes

- **TDD Methodology**: Written with failing test first, then minimal implementation
- **Mock License Database**: No external API calls needed for testing
- **Comprehensive Error Handling**: Validates manifest files and handles edge cases
- **CI/CD Ready**: Workflow installs PowerShell/Pester and executes tests automatically

See IMPLEMENTATION_SUMMARY.md for detailed technical documentation.
