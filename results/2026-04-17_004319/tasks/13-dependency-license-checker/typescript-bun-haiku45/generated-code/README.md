# Dependency License Checker

A TypeScript/Bun-based tool for checking dependency licenses against allow-lists and deny-lists. Parses package.json and requirements.txt files, extracts dependencies, and generates compliance reports.

## Features

- **Red/Green TDD Implementation**: All features built using test-driven development
- **Multi-format Support**: Handles package.json (npm) and requirements.txt (Python)
- **Type-Safe**: Full TypeScript with explicit interfaces and type annotations
- **Mock License Lookups**: Includes test fixtures and mock license database
- **Comprehensive Reporting**: Generates compliance reports with approved, denied, and unknown statuses
- **GitHub Actions Integration**: CI/CD workflow with full validation

## Quick Start

### Run Tests

```bash
bun test
```

### Run CLI

Check a package.json file:
```bash
bun run cli.ts fixtures/package.json fixtures/license-config.json
```

Check a requirements.txt file:
```bash
bun run cli.ts fixtures/requirements.txt fixtures/license-config.json
```

Save report to file:
```bash
bun run cli.ts fixtures/package.json fixtures/license-config.json report.txt
```

## Project Structure

```
├── license-checker.ts          # Core library with all types and logic
├── license-checker.test.ts     # Unit tests (9 test cases)
├── cli.ts                       # CLI entry point for command-line usage
├── fixtures/
│   ├── package.json            # Test fixture for npm dependencies
│   ├── requirements.txt         # Test fixture for Python dependencies
│   └── license-config.json      # Allow/deny list configuration
├── .github/workflows/
│   └── dependency-license-checker.yml  # GitHub Actions workflow
└── act-result.txt              # Act test execution results
```

## API Reference

### `parseDependencies(manifest: DependencyManifest): Dependency[]`

Parses a dependency manifest and returns an array of dependencies with names and versions.

### `parseRequirementsTxt(content: string): Dependency[]`

Parses Python requirements.txt format with support for various version specifiers (==, >=, ~=, etc.).

### `checkLicenseCompliance(dependencies: Dependency[], config: LicenseConfig, licenseLookup: LicenseLookup): ComplianceReport`

Checks each dependency against allow/deny lists and returns a compliance report.

### `generateComplianceReport(report: ComplianceReport): string`

Generates a human-readable text report from compliance results.

## Configuration

Create a license config JSON file with allow and deny lists:

```json
{
  "allowlist": ["MIT", "Apache-2.0", "BSD-3-Clause"],
  "denylist": ["GPL-3.0", "GPL-2.0"]
}
```

## Testing

All tests are implemented using Bun's built-in test runner with 100% pass rate:

- ✅ 5 core functionality tests
- ✅ 3 requirements.txt parsing tests  
- ✅ 1 report generation test

Run with:
```bash
bun test
```

## GitHub Actions Workflow

The workflow includes:
- Unit test execution
- Fixture-based integration tests
- Actionlint validation
- Test report generation
- Multi-job parallel execution

Trigger events:
- Push to main/master branches
- Pull requests against main/master
- Weekly schedule (Sundays at 00:00 UTC)
- Manual workflow dispatch

## Development Notes

- Implementation follows red/green TDD: write failing test → implement → refactor
- Mock license database included for testing (can be replaced with real API calls)
- CLI exit code: 0 if all dependencies approved, 1 if any denied
- Graceful error handling with meaningful error messages
- No external dependencies beyond Bun stdlib and TypeScript
