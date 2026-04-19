# Dependency License Checker

A Bash-based tool to parse project dependencies and check their licenses against configurable allow/deny lists.

## Features

- **Multiple Format Support**: Parses `package.json` (npm/Node.js) and `requirements.txt` (Python)
- **License Validation**: Checks dependencies against configurable allow-lists and deny-lists
- **Mocked License Database**: Includes a mock license database for testing (easily extensible)
- **Comprehensive Testing**: Full test suite with bats-core framework
- **CI/CD Ready**: GitHub Actions workflow included

## Usage

### Basic Usage

```bash
./dependency-license-checker.sh --manifest <path-to-manifest> [--config <path-to-config>]
```

### Examples

**Parse package.json without configuration:**
```bash
./dependency-license-checker.sh --manifest package.json
```

**Parse with license configuration:**
```bash
./dependency-license-checker.sh --manifest package.json --config license-config.json
```

**Parse requirements.txt:**
```bash
./dependency-license-checker.sh --manifest requirements.txt --config license-config.json
```

## Configuration File Format

Create a `license-config.json` file to specify allowed and denied licenses:

```json
{
  "allowlist": ["MIT", "Apache-2.0", "BSD-3-Clause"],
  "denylist": ["GPL-3.0", "AGPL-3.0"]
}
```

## Output Format

The tool generates a compliance report with the following columns:

```
DEPENDENCY                VERSION         LICENSE         STATUS
===============================================================================
lodash                    4.17.21         MIT             APPROVED
express                   4.18.2          MIT             APPROVED
mystery-lib               1.0.0           Unlicense       UNKNOWN
viral-lib                 1.0.0           GPL-3.0         DENIED
```

### Status Values

- **APPROVED**: License is in the allowlist
- **DENIED**: License is in the denylist
- **UNKNOWN**: License is not in either list (when allowlist is specified)

## Supported Manifest Formats

### package.json (Node.js/npm)

Automatically extracts:
- `dependencies`
- `devDependencies`

### requirements.txt (Python)

Parses standard Python requirements format:
```
requests==2.28.1
django==4.1.0
```

## Testing

### Run All Tests

```bash
bats test_license_checker.bats
```

### Run Tests via GitHub Actions

```bash
act push --rm -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest
```

### Test Coverage

- Unit tests (bats framework)
- Manifest parsing (package.json and requirements.txt)
- License validation (allow/deny lists)
- Error handling (missing files, invalid formats)
- Output formatting

## Script Files

- `dependency-license-checker.sh` - Main checker script
- `test_license_checker.bats` - Test suite (bats format)
- `run-tests.sh` - Test harness for CI/CD validation
- `.github/workflows/dependency-license-checker.yml` - GitHub Actions workflow

## Dependencies

- `bash` (≥4.0)
- `jq` (for JSON parsing)
- `bats` (for testing)

## Mock License Database

The script includes a built-in mock license database for testing:

```bash
declare -A LICENSE_DB=(
    [lodash]="MIT"
    [express]="MIT"
    [jest]="MIT"
    [requests]="Apache-2.0"
    [django]="BSD-3-Clause"
    [viral-license-lib]="GPL-3.0"
    ...
)
```

To extend with additional packages, edit the `LICENSE_DB` array in `dependency-license-checker.sh`.

## Error Handling

The script handles errors gracefully:

- **Missing manifest file**: Returns error and displays helpful message
- **Invalid manifest format**: Skips malformed lines safely
- **Missing configuration**: Defaults to showing UNKNOWN status
- **JSON parsing errors**: Logs errors but continues processing

## Exit Codes

- `0` - Success
- `1` - Error (manifest file not found, invalid format, etc.)

## License

This tool is provided as-is for testing and development purposes.
