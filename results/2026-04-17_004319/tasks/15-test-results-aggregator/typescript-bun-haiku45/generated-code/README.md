# Test Results Aggregator

A TypeScript/Bun solution for parsing, aggregating, and summarizing test results from multiple formats and runs, with support for identifying flaky tests.

## Features

- **Multi-format Support**: Parse JUnit XML and JSON test result formats
- **Result Aggregation**: Combine results from multiple test runs (matrix builds)
- **Statistics**: Calculate total counts, pass rates, durations, and averages
- **Flaky Test Detection**: Identify tests that pass in some runs but fail in others
- **Markdown Output**: Generate GitHub Actions-compatible summary markdown
- **GitHub Actions Integration**: Seamlessly integrates with `GITHUB_STEP_SUMMARY`

## Architecture

### Modules

- **`src/parser.ts`**: Parses JUnit XML and JSON test result files
  - `parseJunitXml()`: Parse JUnit XML format
  - `parseJsonResults()`: Parse custom JSON test result format

- **`src/aggregator.ts`**: Aggregates results and detects flaky tests
  - `aggregateResults()`: Combine results from multiple sources
  - `identifyFlakyTests()`: Find tests with inconsistent pass/fail rates

- **`src/markdown.ts`**: Generates markdown summaries
  - `generateMarkdownSummary()`: Create GitHub-friendly markdown output

- **`src/main.ts`**: CLI entry point
  - Processes test directories
  - Writes to `GITHUB_STEP_SUMMARY` in CI environments

### Test Structure (TDD)

All functionality developed using red/green TDD:

- **`tests/parser.test.ts`** (6 tests): XML and JSON parsing
- **`tests/aggregator.test.ts`** (6 tests): Aggregation and flaky detection
- **`tests/markdown.test.ts`** (3 tests): Markdown generation
- **`tests/workflow.test.ts`** (10 tests): Workflow structure validation

**All 25 tests pass.**

### Fixtures

Sample test result files for demonstration:

- **`fixtures/junit-run1.xml`**: JUnit format with 1 failed, 1 skipped test
- **`fixtures/junit-run2.xml`**: JUnit format with all tests passing
- **`fixtures/results-run3.json`**: JSON format with 1 failed test

## Usage

### Run Unit Tests

```bash
bun test
```

### Run the Aggregator

```bash
bun run src/main.ts <test-directory> [output-file]
```

Example:
```bash
bun run src/main.ts fixtures/ summary.md
```

### In GitHub Actions

The workflow at `.github/workflows/test-results-aggregator.yml` automatically:

1. Checks out code
2. Installs dependencies with Bun
3. Runs unit tests
4. Aggregates test results from fixture files
5. Writes summary to job summary and markdown file

## Output Example

```
# Test Results Summary

✅ **Overall Status**: All tests passed

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 18 |
| Passed | 15 ✅ |
| Failed | 2 ❌ |
| Skipped | 1 ⏭️ |
| Pass Rate | 88.24% |
| Total Duration | 16.42s |
| Average Duration | 5.47s |
| Runs | 3 |

## ⚠️ Flaky Tests

The following tests passed in some runs but failed in others:

| Test Name | Pass | Fail | Flaky Rate |
|-----------|------|------|------------|
| `testInvalidLogin` | 2 | 1 | 33.3% |
```

## GitHub Actions Workflow

The workflow file `.github/workflows/test-results-aggregator.yml`:

- **Triggers**: Push, PR, schedule (weekly), manual dispatch
- **Matrix**: Tests on Node 20 and 21
- **Jobs**:
  - `test`: Runs tests and aggregates results
  - `validate-workflow`: Validates workflow with actionlint
- **Validation**: All steps pass actionlint checks

### Validation

The workflow has been validated with `actionlint`:

```bash
actionlint .github/workflows/test-results-aggregator.yml
```

✅ All checks pass.

### Testing with act

The workflow has been tested locally with `act`:

```bash
act push --rm -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest
```

All jobs succeed:
- ✅ Test Results Aggregator/Run Tests-1
- ✅ Test Results Aggregator/Run Tests-2
- ✅ Test Results Aggregator/Validate Workflow

Output saved to `act-result.txt`.

## Development

### Adding New Test Formats

1. Create a new parser function in `src/parser.ts`
2. Add tests in a new test file (e.g., `tests/myformat.test.ts`)
3. Integrate into `src/main.ts` file detection logic

### Type Safety

Full TypeScript type definitions for all interfaces:

```typescript
interface ParsedResult {
  source: string;
  tests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
}

interface AggregatedResults {
  totalTests: number;
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalDuration: number;
  runCount: number;
  avgPassRate: number;
  avgFailRate: number;
  avgDuration: number;
}

interface FlakyTest {
  testName: string;
  passCount: number;
  failCount: number;
  totalRuns: number;
  flakyRate: number;
}
```

## Requirements Met

✅ TDD methodology: Failing tests written first, then implementation
✅ Bun test runner: All tests pass with `bun test`
✅ TypeScript: Full type annotations throughout
✅ Error handling: Graceful error messages for invalid input
✅ Sample fixtures: JUnit XML and JSON test result files
✅ GitHub Actions workflow: Valid, actionlint-verified workflow
✅ Workflow testing: Runs successfully with `act`
✅ All tests pass: 25/25 tests passing
