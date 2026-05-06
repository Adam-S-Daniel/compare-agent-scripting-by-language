# Dependency License Checker

A TypeScript/Bun-based tool for checking project dependencies against configured license allow-lists and deny-lists. Generates detailed compliance reports with full support for npm and Python projects.

## Features

- ✅ Parse `package.json` and `requirements.txt` dependency manifests
- ✅ Check licenses against configurable allow-lists and deny-lists
- ✅ Generate detailed compliance reports (text and JSON)
- ✅ Mock license database for testing
- ✅ Full test coverage with Bun's test runner
- ✅ GitHub Actions CI/CD integration
- ✅ Clear, readable output with status indicators

## Project Structure

```
src/
├── types.ts           # TypeScript interfaces and types
├── checker.ts         # Main license checking logic
├── mockLicenses.ts    # Mock license database for testing
└── cli.ts            # Command-line interface

tests/
└── checker.test.ts   # Comprehensive test suite (14 tests)

.github/workflows/
└── dependency-license-checker.yml  # GitHub Actions workflow
```

## Installation

```bash
# Install dependencies
bun install
```

## Usage

### Check Dependencies

```bash
# Check sample project
bun run src/cli.ts --manifest sample-package.json --config sample-config.json

# Check your project
bun run src/cli.ts --manifest package.json --config your-config.json

# Output as JSON
bun run src/cli.ts --manifest package.json --config config.json --format json
```

### Configuration

Create a `license-config.json` file:

```json
{
  "allowList": [
    "MIT",
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC"
  ],
  "denyList": [
    "GPL-2.0",
    "GPL-3.0",
    "AGPL-3.0",
    "Proprietary"
  ]
}
```

### Run Tests

```bash
# Run all tests
bun test

# Run with output
bun test --verbose
```

## Output Example

```
Dependency License Compliance Report
Generated: 2026-05-06T23:42:19.171Z

Summary:
  Total Dependencies: 4
  Approved:          4
  Denied:            0
  Unknown:           0

✅ APPROVED LICENSES:
  - react@^18.0.0 (MIT)
  - lodash@4.17.21 (MIT)
  - express@^4.18.0 (MIT)
  - typescript@^5.0.0 (Apache-2.0)
```

## API Reference

### parsePackageJson(packageJson)
Parse dependencies from a package.json object.

**Returns:** `Dependency[]`

### parseRequirementsTxt(content)
Parse dependencies from requirements.txt format.

**Returns:** `Dependency[]`

### checkLicenses(dependencies, config, licenseLookup?)
Check dependencies against allow/deny lists.

**Parameters:**
- `dependencies: Dependency[]`
- `config: LicenseConfig`
- `licenseLookup?: LicenseLookup` (defaults to mockLicenseLookup)

**Returns:** `Promise<ComplianceReport>`

### formatReport(report)
Format a compliance report as readable text.

**Returns:** `string`

## Test Coverage

The project includes 14 comprehensive unit tests covering:

- Manifest parsing (package.json and requirements.txt)
- License lookups
- Compliance categorization (approved/denied/unknown)
- Report generation
- Integration workflows

### Running Tests

```bash
# All tests with Bun
bun test

# Tests through GitHub Actions (simulated locally)
act push -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest
```

## GitHub Actions Integration

The included workflow (`.github/workflows/dependency-license-checker.yml`) provides:

- **Triggers:** push, pull_request, schedule, manual dispatch
- **Jobs:** 
  - Run unit tests with full coverage
  - Check sample project dependencies
  - Check this project's own dependencies
- **Full containerized testing** with `act`

## Exit Codes

- `0` - Success (no denied licenses)
- `1` - Failure (denied licenses found or errors)

## Implementation Details

### Red/Green TDD Approach

This project was built using test-driven development:

1. **Red Phase**: Write failing tests that define expected behavior
2. **Green Phase**: Implement minimum code to pass tests
3. **Refactor Phase**: Improve code quality while keeping tests green

All tests were written before implementation and drive the design.

### Mock License Database

For testing purposes, licenses are mocked:

```typescript
const mockLicenseDatabase = {
  "react": "MIT",
  "lodash": "MIT",
  "some-gpl-package": "GPL-2.0",
  // ...
};
```

This allows testing without external API calls while maintaining realistic scenarios.

## TypeScript Features Used

- Explicit type annotations
- Interfaces and types
- Async/await for license lookups
- Union types for status values
- Generic types for extensibility

## License

This tool is designed to help you manage your dependencies' licenses. Check your project's license compliance before deployment.
