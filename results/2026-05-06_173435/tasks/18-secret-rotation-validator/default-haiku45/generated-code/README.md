# Secret Rotation Validator

A Python-based tool for validating secret rotation status and generating compliance reports. Identifies expired and expiring secrets, groups them by urgency, and supports multiple output formats.

## Features

- **Secret Status Classification**: Categorizes secrets as EXPIRED, WARNING, or OK
- **Configurable Warning Window**: Set custom thresholds for warning notifications
- **Multiple Output Formats**: 
  - Markdown tables (for reports and documentation)
  - JSON (for programmatic consumption)
- **Comprehensive Metadata**:
  - Secret name and last rotation date
  - Rotation policy (days between rotations)
  - Required-by services list
  - Days until expiry calculation

## Architecture

### Core Components

1. **secret_validator.py** - Main script with core functionality
   - `SecretStatus` enum (EXPIRED, WARNING, OK)
   - `SecretConfig` data class
   - `validate_secrets()` - Core validation logic
   - `generate_markdown_report()` - Markdown output
   - `generate_json_report()` - JSON output
   - `load_config()` - JSON config file parsing
   - CLI interface via `argparse`

2. **test_secret_validator.py** - Comprehensive test suite
   - Unit tests for all components
   - Test fixtures for various scenarios
   - TDD approach: all tests written before implementation

3. **.github/workflows/secret-rotation-validator.yml** - CI/CD Pipeline
   - Runs on push, pull_request, schedule, and manual trigger
   - Validates workflow syntax with actionlint
   - Runs all tests through GitHub Actions
   - Compatible with `act` for local testing

## Testing

### Run Unit Tests Locally

```bash
python3 -m pytest test_secret_validator.py -v
```

### Run Through GitHub Actions Locally

```bash
act push --rm
```

### Test Coverage

- 13 comprehensive unit tests
- Status classification (expired, warning, ok)
- Report generation (markdown, JSON)
- Configuration loading
- Error handling

## Usage

### Configuration Format

Create a JSON file with secret metadata:

```json
[
  {
    "name": "database_password",
    "last_rotated": "2026-05-01",
    "rotation_policy_days": 30,
    "required_by_services": ["api", "worker"]
  }
]
```

### CLI Usage

**Generate markdown report (default):**
```bash
python secret_validator.py --config secrets.json
```

**Generate JSON report:**
```bash
python secret_validator.py --config secrets.json --format json
```

**Custom warning window (3 days):**
```bash
python secret_validator.py --config secrets.json --warning-days 3
```

### Example Output

**Markdown Table:**
```
| Name | Status | Services | Days Until Expiry |
|------|--------|----------|------------------|
| database_password | EXPIRED | api, worker | -96 |
| api_key_external | WARNING | integration-service | 3 |
| jwt_signing_key | OK | auth-service, api | 24 |
```

**JSON Output:**
```json
{
  "timestamp": "2026-05-07T01:14:39.554161",
  "summary": {
    "expired": 1,
    "warning": 1,
    "ok": 2
  },
  "secrets": [...]
}
```

## Test Results

All tests pass successfully through GitHub Actions:
- ✅ 13/13 unit tests pass
- ✅ Workflow validates with actionlint
- ✅ Execution successful in act (Docker containers)

## Development Notes

### TDD Approach

This project follows Red/Green TDD methodology:
1. Each test was written first (RED - failing)
2. Minimal code was added to make it pass (GREEN)
3. Code was refactored as needed

### Error Handling

- Missing config files raise `FileNotFoundError` with meaningful messages
- Invalid JSON in config raises `json.JSONDecodeError`
- Graceful exit with status code 1 on errors

### Design Decisions

- Used Python 3.12+ for modern syntax and type hints
- Dataclass for config (clean, immutable representation)
- Enum for status (type-safe, self-documenting)
- Simple datetime arithmetic for expiry calculation
- Modular functions for easy testing and reuse

## CI/CD Pipeline

The GitHub Actions workflow:
- Checks out code
- Sets up Python 3.12
- Installs pytest dependency
- Runs all unit tests
- Tests both markdown and JSON output formats
- Validates workflow syntax
- Creates detailed output logs

**Workflow triggers:**
- `push` to main/master branches
- `pull_request` to main/master branches
- Daily schedule (midnight UTC)
- Manual trigger with optional parameters

## Files

- `secret_validator.py` - Main script
- `test_secret_validator.py` - Test suite
- `fixtures.json` - Sample configuration data
- `.github/workflows/secret-rotation-validator.yml` - CI/CD workflow
- `run_act_tests.py` - Act test harness
- `act-result.txt` - Test execution results
- `README.md` - This file

## License

This is a test/benchmark project.
