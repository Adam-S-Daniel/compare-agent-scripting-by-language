# Test Results Aggregator

A TypeScript/Bun utility for parsing, aggregating, and reporting on test results from multiple test runs, with support for JUnit XML and JSON formats. Designed for CI/CD pipelines to produce GitHub Actions job summaries from matrix build test results.

## Features

- **Multiple Format Support**: Parse JUnit XML and JSON test result formats
- **Aggregation**: Combine results from multiple test runs (matrix builds)
- **Flaky Test Detection**: Identify tests that pass in some runs but fail in others
- **Markdown Reports**: Generate GitHub Actions-compatible markdown summaries
- **Type-Safe**: Full TypeScript with explicit type annotations
- **Well-Tested**: Comprehensive test suite using Bun's test runner

## Installation

```bash
bun install
```

## Usage

### Command Line

```bash
bun run src/main.ts <results-directory> [output-file]
```

**Arguments:**
- `<results-directory>`: Directory containing test result files (.xml or .json)
- `[output-file]`: Optional output file for markdown summary (defaults to stdout)

**Example:**

```bash
# Generate summary to stdout
bun run src/main.ts ./test-results/

# Save summary to file
bun run src/main.ts ./test-results/ summary.md
```

**Exit Codes:**
- `0` - All tests passed
- `1` - One or more tests failed

### Programmatic API

```typescript
import { parseJunitXml, parseJsonResults } from './src/parser';
import { aggregateResults, identifyFlakyTests } from './src/aggregator';
import { generateMarkdownSummary } from './src/markdown';

// Parse test results
const junit = parseJunitXml(xmlContent, 'run-1');
const json = parseJsonResults(jsonContent, 'run-2');

// Aggregate results
const aggregated = aggregateResults([junit, json]);

// Generate markdown
const markdown = generateMarkdownSummary(aggregated);
```

## Input Formats

### JUnit XML

Standard JUnit XML format as produced by most test frameworks:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="SuiteName" tests="3" failures="1" skipped="0" time="1.5">
    <testcase classname="com.example.Test" name="testName" time="0.5"/>
    <testcase classname="com.example.Test" name="testFails" time="0.3">
      <failure message="Assertion failed">Stack trace...</failure>
    </testcase>
    <testcase classname="com.example.Test" name="testSkipped" time="0.2">
      <skipped message="Not ready"/>
    </testcase>
  </testsuite>
</testsuites>
```

### JSON Format

Custom JSON format:

```json
{
  "suites": [
    {
      "name": "SuiteName",
      "tests": 3,
      "failures": 0,
      "skipped": 0,
      "time": 1.5,
      "cases": [
        {
          "name": "testName",
          "className": "com.example.Test",
          "status": "passed",
          "duration": 0.5
        }
      ]
    }
  ]
}
```

## Output Format

Generates a markdown summary with:
- Summary table (total tests, passed, failed, skipped, duration)
- Pass rate percentage
- Status indicator (✅ or ❌)
- Flaky tests section (if any)
- Failed tests section (if any)

Example output:

```markdown
# Test Results Summary

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 8 |
| Passed | 6 |
| Failed | 1 |
| Skipped | 1 |
| Duration | 2.45s |

**Pass Rate:** 75.0%

❌ 1 test(s) failed

## Flaky Tests

The following tests passed in some runs but failed in others:

- **com.example.Test::testFlaky**
  - Failures: 1, Passages: 1
  - Runs affected: run-1, run-2
```

## GitHub Actions Integration

The workflow file `.github/workflows/test-results-aggregator.yml` demonstrates:

1. **Checkout and setup**: Uses `actions/checkout@v4` and `oven-sh/setup-bun`
2. **Test fixture generation**: Creates sample test result files
3. **Aggregation**: Runs the aggregator script
4. **Job summary**: Writes results to GitHub Actions job summary with `$GITHUB_STEP_SUMMARY`

Trigger the workflow:
```bash
git push
# or
act push  # Test locally with act
```

## Testing

Run the complete test suite:

```bash
bun test
```

**Test coverage includes:**
- JUnit XML parsing
- JSON results parsing
- Results aggregation
- Flaky test detection
- Markdown generation
- Workflow structure validation
- Action linting

## Architecture

### Modules

- **`src/types.ts`**: Type definitions for test data
- **`src/parser.ts`**: XML and JSON parsing
- **`src/aggregator.ts`**: Results aggregation and flaky test detection
- **`src/markdown.ts`**: Markdown report generation
- **`src/main.ts`**: CLI entry point

### Design Decisions

1. **No merging of same-named suites**: Suites from different runs are kept separate to preserve run identity for flaky test detection
2. **Strict typing**: Full TypeScript with interfaces for maintainability
3. **Minimal parsing**: Regex-based parsing avoids XML parser dependencies
4. **Test-driven development**: Red-green-refactor methodology used throughout

## Matrix Build Example

For CI systems using matrix builds (e.g., testing multiple Node versions):

```yaml
strategy:
  matrix:
    node-version: [18.x, 20.x]
    os: [ubuntu-latest, macos-latest]

steps:
  - run: npm test > test-results-${{ matrix.node-version }}-${{ matrix.os }}.json
  - run: bun run src/main.ts . summary.md
```

Results from all matrix combinations are automatically aggregated, flaky tests identified, and a unified report generated.

## Development

### Add a new test
1. Write a failing test in `tests/*.test.ts`
2. Implement code to make it pass
3. Refactor for clarity
4. Verify all tests still pass with `bun test`

### Modify parsing
- Update test fixtures in `tests/fixtures/`
- Update parser tests
- Modify parser implementation in `src/parser.ts`

## Troubleshooting

**"No .xml or .json files found"**
- Ensure your results directory contains test result files with .xml or .json extensions

**"Error parsing file"**
- Verify XML is well-formed or JSON is valid
- Check that the format matches the examples above

**Act container pull error**
- Edit `.actrc` to specify a local Docker image or use `ubuntu:latest`
- Or pull the custom image: `docker build -t act-ubuntu-pwsh:latest -f Dockerfile.act .`

## License

MIT
