# Secret Rotation Validator

A Python-based solution that identifies expired and expiring secrets, generates rotation reports, and supports multiple output formats.

## Features

- **Secret Tracking**: Manage secrets with metadata (name, last-rotated date, rotation policy, required services)
- **Urgency Classification**: Categorize secrets as EXPIRED, WARNING, or OK based on configurable warning window
- **Multiple Output Formats**: Generate reports in Markdown (table) or JSON format
- **CLI Interface**: Command-line tool for CI/CD integration
- **Exit Code Signaling**: Returns non-zero on expired secrets for CI pipeline use
- **Comprehensive Testing**: 14 test cases covering all functionality

## Files

- `secret_validator.py` - Core library with Secret, SecretValidator, and RotationReport classes
- `secret_validator_cli.py` - CLI entry point for running validation
- `test_secret_validator.py` - 14 comprehensive pytest test cases
- `fixtures_mixed.json` - Test fixture with mixed urgency secrets (includes expired)
- `fixtures_all_ok.json` - Test fixture with all secrets in OK status
- `.github/workflows/secret-rotation-validator.yml` - GitHub Actions workflow

## Usage

### CLI

```bash
# Check secrets in markdown format
python3 secret_validator_cli.py fixtures_all_ok.json --output-format markdown

# Check secrets in JSON format
python3 secret_validator_cli.py fixtures_all_ok.json --output-format json

# Custom warning window (default: 7 days)
python3 secret_validator_cli.py config.json --warning-days 14
```

### As a Library

```python
from secret_validator import Secret, SecretValidator
from datetime import datetime

validator = SecretValidator(warning_window_days=7)
validator.add_secret(Secret(
    name="api_key",
    last_rotated=datetime(2026, 4, 10),
    rotation_policy_days=30,
    required_by=["api-service"]
))

report = validator.generate_report()
print(report.to_markdown())
```

## Configuration Format

JSON configuration file with secrets array:

```json
[
  {
    "name": "api_key",
    "last_rotated": "2026-04-10T00:00:00",
    "rotation_policy_days": 30,
    "required_by": ["api-service", "webhook-handler"]
  }
]
```

## Test Results

All 14 tests pass (verified locally and through GitHub Actions via `act`):

- **TestSecretCreation**: 3 tests - Secret object creation and expiry detection
- **TestSecretValidator**: 2 tests - Validator initialization and urgency categorization
- **TestRotationReport**: 2 tests - Markdown and JSON output generation
- **TestComplexScenarios**: 4 tests - Mixed urgencies, multiple service dependencies, expiry calculations
- **TestCLI**: 3 tests - CLI integration, output formats, error handling

## GitHub Actions Workflow

The workflow (`.github/workflows/secret-rotation-validator.yml`):
- Runs on: push, pull_request, schedule (9am daily), and manual dispatch
- Jobs:
  - **Run Tests**: Executes all 14 pytest test cases
  - **Validate Configuration**: Validates JSON fixture files
  - **Validator Check**: Tests validator on real fixture data with both output formats
- All jobs complete successfully

Exit Code Behavior:
- Code 0: All secrets OK or in WARNING status
- Code 1: One or more secrets EXPIRED (signals to CI/CD that action needed)

## TDD Approach

This solution was built using Red/Green TDD methodology:
1. Write failing tests first
2. Implement minimal code to make tests pass
3. Refactor and add tests for additional features
4. Repeat for each piece of functionality

All tests pass at every stage.
