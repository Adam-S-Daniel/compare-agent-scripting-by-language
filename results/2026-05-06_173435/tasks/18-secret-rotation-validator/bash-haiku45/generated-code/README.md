# Secret Rotation Validator

A Bash utility to identify expired and expiring secrets based on rotation policies, with comprehensive testing and CI/CD integration.

## Features

- **Metadata-driven**: Configuration file specifies secret names, rotation dates, policies, and required services
- **Flexible reporting**: Identifies secrets by urgency (EXPIRED, WARNING, OK)
- **Multiple output formats**: Markdown tables and JSON for easy integration
- **Configurable warning window**: Set how many days in advance to warn about upcoming rotations
- **Comprehensive error handling**: Validates JSON syntax and required fields
- **Fully tested**: 15 unit tests using bats-core and red-green TDD methodology
- **CI/CD ready**: GitHub Actions workflow included with `act` local testing support

## Requirements

- Bash 4.0+
- `jq` for JSON parsing
- `bats-core` for testing (optional, required for running tests)
- `date` command (standard on Linux/macOS)

## Installation

```bash
chmod +x secret-rotation-validator.sh
```

## Usage

### Basic Usage

```bash
./secret-rotation-validator.sh \
  --config secrets.json \
  --warning-days 7
```

### Command-Line Options

```
--config FILE               Path to JSON config file (required)
--warning-days DAYS         Days before due date to warn (default: 7)
--format FORMAT             Output format: markdown or json (default: markdown)
--current-date DATE         Current date in YYYY-MM-DD format (default: today)
--help                      Show help message
```

### Output Formats

#### Markdown Table (Default)
```
## EXPIRED

| Name | Status | Days Until Due | Last Rotated | Required By |
|------|--------|-----------------|--------------|-------------|
| ssl-cert|EXPIRED|-4|2026-02-01|load-balancer, api-service |

## WARNING

| Name | Status | Days Until Due | Last Rotated | Required By |
|------|--------|-----------------|--------------|-------------|
| db-password|WARNING|2|2026-05-03|api-service, worker-service |

## OK

| Name | Status | Days Until Due | Last Rotated | Required By |
|------|--------|-----------------|--------------|-------------|
| api-key|OK|7|2026-05-01|frontend |
```

#### JSON
```json
{
  "summary": {
    "warning_days": 7,
    "current_date": "2026-05-06"
  },
  "secrets": [
    {
      "name": "db-password",
      "status": "WARNING",
      "days_until_due": 2,
      "last_rotated": "2026-05-03",
      "required_by": ["api-service", "worker-service"]
    }
  ]
}
```

## Configuration File Format

The configuration file is JSON with a `secrets` array containing secret objects:

```json
{
  "secrets": [
    {
      "name": "db-password",
      "last_rotated": "2026-05-03",
      "rotation_policy_days": 30,
      "required_by": ["api-service", "worker-service"]
    },
    {
      "name": "api-key",
      "last_rotated": "2026-05-01",
      "rotation_policy_days": 90,
      "required_by": ["frontend"]
    }
  ]
}
```

### Required Fields

- `name`: Secret identifier (string)
- `last_rotated`: Last rotation date in YYYY-MM-DD format
- `rotation_policy_days`: Number of days between required rotations
- `required_by`: Services that depend on this secret (array of strings)

## Examples

### Check secrets with 14-day warning window
```bash
./secret-rotation-validator.sh \
  --config secrets.json \
  --warning-days 14 \
  --format markdown
```

### Generate JSON report for CI/CD integration
```bash
./secret-rotation-validator.sh \
  --config secrets.json \
  --warning-days 7 \
  --format json > report.json
```

### Check specific date (for testing)
```bash
./secret-rotation-validator.sh \
  --config secrets.json \
  --warning-days 7 \
  --current-date 2026-05-15
```

## Testing

### Run Unit Tests

```bash
bats tests/secret-rotation-validator.bats
```

All tests follow red-green-refactor TDD methodology:

1. **Test 1-3**: Basic functionality (existence, help, config validation)
2. **Test 4-6**: Config parsing and output formats
3. **Test 7-9**: Status determination (EXPIRED, WARNING, OK)
4. **Test 10-12**: Output structure and headers
5. **Test 13-15**: Error handling and validation

### Run Workflow Tests Locally

```bash
bash run-workflow-tests.sh
```

Tests the GitHub Actions workflow using `act` and saves results to `act-result.txt`.

### Validate Script

```bash
# Syntax validation
bash -n secret-rotation-validator.sh

# Shellcheck linting
shellcheck secret-rotation-validator.sh
```

## CI/CD Integration

### GitHub Actions

The included workflow (`.github/workflows/secret-rotation-validator.yml`) provides:

- **Automatic triggers**: push, pull_request, daily schedule, manual dispatch
- **Dependency installation**: jq, bats-core
- **Script validation**: bash syntax and shellcheck
- **Unit test execution**: All 15 tests must pass
- **Status reporting**: Markdown and JSON output

### Running Locally with `act`

```bash
# Requires Docker to be running
act push --rm
```

Validates that the workflow executes correctly in a Docker container before pushing to GitHub.

## Status Determination Logic

For each secret:

1. **Due Date** = Last Rotated + Policy Days
2. **Days Until Due** = Due Date - Current Date
3. **Status**:
   - `EXPIRED`: Days Until Due < 0 (overdue)
   - `WARNING`: 0 ≤ Days Until Due < Warning Window
   - `OK`: Days Until Due ≥ Warning Window

### Examples

Given current date 2026-05-06 with 7-day warning window:

| Secret | Last Rotated | Policy | Due Date | Days Until | Status |
|--------|------------|--------|---------|-----------|--------|
| db-password | 2026-05-03 | 5 days | 2026-05-08 | +2 | WARNING |
| api-key | 2026-05-01 | 12 days | 2026-05-13 | +7 | OK |
| ssl-cert | 2026-02-01 | 90 days | 2026-04-30 | -6 | EXPIRED |

## Error Handling

The script handles errors gracefully:

- **Missing config file**: Error message and exit code 1
- **Invalid JSON**: Error message pointing to the config file
- **Missing required fields**: Indicates which field is missing
- **Invalid date format**: Message showing expected YYYY-MM-DD format

Example:
```
$ ./secret-rotation-validator.sh --config missing.json
Error: Config file not found: missing.json

$ ./secret-rotation-validator.sh --config bad.json
Error: Invalid JSON in config file: bad.json

$ ./secret-rotation-validator.sh --config incomplete.json
Error: Secret missing required field: last_rotated
```

## Architecture

### Script Structure

- **Argument parsing**: `parse_args()` - handles command-line options
- **Validation**: `validate_config()` - checks file existence and JSON syntax
- **Date calculations**: `days_between()` - computes days between two dates
- **Status determination**: `get_status()` - determines EXPIRED/WARNING/OK
- **Output formatting**: `output_markdown()` and `output_json()` - generates reports
- **Main flow**: `main()` - orchestrates the entire process

### Test Coverage

All major functions have dedicated tests:
- JSON parsing and validation
- Date calculations across month/year boundaries
- Status determination for all three states
- Output format correctness
- Error conditions and edge cases

## Implementation Notes

- Uses POSIX-compliant Bash to maximize compatibility
- Relies on `jq` for robust JSON parsing (no regex-based parsing)
- Date calculations use Unix epoch time for accuracy
- Process substitution for streaming JSON to avoid subshell issues with error handling
- Strict mode (`set -euo pipefail`) for reliability

## License

This utility is provided as-is for demonstration and testing purposes.
