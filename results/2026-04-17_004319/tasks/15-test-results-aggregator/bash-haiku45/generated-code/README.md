# Test Results Aggregator

A Bash script to parse, aggregate, and summarize test results from multiple test frameworks (JUnit XML and JSON formats). Identifies flaky tests and generates markdown summaries suitable for GitHub Actions job summaries.

## Features

- **Multi-format support**: Parse JUnit XML and JSON test result files
- **Aggregation**: Combine test results across multiple files and runs
- **Flaky test detection**: Identify tests that pass inconsistently across runs
- **Markdown generation**: Create professional test summary reports
- **CI/CD integration**: GitHub Actions workflow included
- **Comprehensive testing**: 12+ unit tests with bats-core

## Prerequisites

- Bash 4.0+
- `jq` (for JSON parsing)
- `bc` (for decimal arithmetic)
- `bats` (for running tests)
- `shellcheck` (for code quality checks)

## Installation

```bash
# Clone/download the repository
cd test-results-aggregator

# Make scripts executable
chmod +x aggregate-results.sh test-workflow-integration.sh

# Install dependencies (if needed)
npm install -g bats
```

## Usage

### Basic Usage

Aggregate test results from multiple files:

```bash
./aggregate-results.sh result1.xml result2.json
```

### With Output File

Save the aggregated summary to a markdown file:

```bash
./aggregate-results.sh -o summary.md test-results/*.xml
```

### Help

```bash
./aggregate-results.sh --help
```

## Examples

### Example 1: Aggregate JUnit XML Results

```bash
./aggregate-results.sh \
  results/run1-junit.xml \
  results/run2-junit.xml \
  results/run3-junit.xml \
  -o test-summary.md
```

### Example 2: Mix XML and JSON Results

```bash
./aggregate-results.sh \
  test-results/unit-tests.xml \
  test-results/integration-tests.json \
  -o summary.md
```

### Example 3: GitHub Actions Integration

The included workflow automatically runs when you push or create a pull request:

```yaml
# .github/workflows/test-results-aggregator.yml
- name: Aggregate test results
  run: |
    ./aggregate-results.sh \
      test-results/*.xml \
      test-results/*.json \
      -o summary.md
```

## Input Formats

### JUnit XML

Standard JUnit XML format supported by most test frameworks:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="my-tests" tests="3" failures="1" skipped="0" time="2.5">
    <testcase name="test_pass" classname="MyTest" time="0.5"/>
    <testcase name="test_fail" classname="MyTest" time="0.6">
      <failure message="Expected 5 but got 3">assertion failed</failure>
    </testcase>
    <testcase name="test_skip" classname="MyTest" time="0.0">
      <skipped message="Not implemented"/>
    </testcase>
  </testsuite>
</testsuites>
```

### JSON Format

Custom JSON format for test results:

```json
{
  "tests": 3,
  "passed": 2,
  "failed": 1,
  "skipped": 0,
  "duration": 2.3,
  "testcases": [
    {
      "name": "test_api_call",
      "classname": "api_tests",
      "time": 0.8,
      "status": "passed"
    },
    {
      "name": "test_error_handling",
      "classname": "api_tests",
      "time": 0.6,
      "status": "failed",
      "message": "Timeout exceeded"
    }
  ]
}
```

## Output Format

The script generates a markdown summary with:

- Total test counts (passed, failed, skipped)
- Total duration
- List of flaky tests (tests with inconsistent results across runs)

Example output:

```markdown
# Test Results Summary

## Summary Statistics

- **Passed**: 15
- **Failed**: 2
- **Skipped**: 1
- **Duration**: 8.5s

## Flaky Tests

The following tests passed in some runs but failed in others:

- `test_network_retry`
- `test_cache_timeout`
```

## Testing

### Run Unit Tests

```bash
bats tests/test_aggregator.bats
```

### Run Integration Tests

```bash
./test-workflow-integration.sh
```

This validates:
- Workflow YAML structure
- Actionlint compliance
- Script functionality
- Integration with CI/CD

### Validate Script Quality

```bash
# Check syntax
bash -n aggregate-results.sh

# Check with shellcheck
shellcheck -x aggregate-results.sh
```

## Implementation Details

### Architecture

The script uses a red/green/refactor TDD approach with the following components:

1. **Parsers**: `parse_junit_xml()`, `parse_json_results()`
   - Extract test counts and durations from files
   - Return normalized JSON format

2. **Aggregators**: `aggregate_junit_files()`
   - Combine results from multiple test runs
   - Calculate totals across files

3. **Flaky Detection**: `detect_flaky_tests()`
   - Compare test results across runs
   - Identify tests with inconsistent results

4. **Report Generator**: `generate_markdown_summary()`
   - Format results as markdown
   - Include summary statistics

5. **Main Function**: CLI entry point
   - Parse command-line arguments
   - Orchestrate parsing and aggregation
   - Output or save results

### Dependencies

- **jq**: JSON extraction and parsing (used in aggregation)
- **bc**: Decimal arithmetic for duration calculations
- **sed/grep/awk**: XML parsing without external libraries
- **bash 4.0+**: Associative arrays, extended globbing

### Error Handling

- Missing files are logged but don't stop processing
- Invalid formats are skipped with error messages
- Graceful fallbacks for missing data (defaults to 0)

## GitHub Actions Workflow

The included workflow (`.github/workflows/test-results-aggregator.yml`):

**Triggers:**
- Push to main/master branches
- Pull requests against main/master branches
- Manual trigger via `workflow_dispatch`

**Steps:**
1. Checkout code
2. Install dependencies
3. Create test fixtures
4. Run unit tests (bats)
5. Aggregate test results
6. Validate output

## Test Coverage

The test suite includes:

- ✓ Script existence and structure validation
- ✓ JUnit XML parsing
- ✓ JSON result parsing
- ✓ Multi-file aggregation
- ✓ Flaky test detection
- ✓ Markdown generation
- ✓ Error handling for missing files
- ✓ Syntax validation (bash -n)
- ✓ Code quality (shellcheck)
- ✓ End-to-end workflows

## Troubleshooting

### Script not found
```bash
chmod +x aggregate-results.sh
```

### jq not found
```bash
# Ubuntu/Debian
apt-get install -y jq

# macOS
brew install jq
```

### Tests failing
```bash
# Run with verbose output
bats -t tests/test_aggregator.bats
```

### Workflow validation error
```bash
# Check YAML syntax
actionlint .github/workflows/test-results-aggregator.yml
```

## License

MIT

## Author

Generated using Bash scripting best practices with TDD methodology.
