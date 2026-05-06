# Test Results Aggregator

A Bash script for parsing test result files in multiple formats (JUnit XML and JSON), aggregating results across multiple files, computing totals, identifying flaky tests, and generating a markdown summary suitable for GitHub Actions job summaries.

## Features

- **Multi-format support**: Parses both JUnit XML and JSON test result formats
- **Aggregation**: Combines results across multiple test runs (e.g., matrix builds)
- **Flaky test detection**: Identifies tests that pass in some runs but fail in others
- **Markdown output**: Generates GitHub Actions-compatible markdown summaries
- **Error handling**: Graceful error messages for missing or invalid files
- **Validation**: Passes shellcheck and bash -n syntax validation

## Usage

### Basic Usage

```bash
# Parse a single JUnit XML file
source test-results-aggregator.sh
parse_junit_xml fixtures/build-1-tests.xml

# Parse a JSON test result file
parse_json_tests fixtures/build-3-tests.json

# Aggregate results from multiple files
aggregate_test_results fixtures/build-1-tests.xml fixtures/build-2-tests.xml fixtures/build-3-tests.json

# Find flaky tests
find_flaky_tests fixtures/build-1-tests.xml fixtures/build-2-tests.xml

# Generate a markdown summary
generate_markdown_summary fixtures/build-1-tests.xml fixtures/build-2-tests.xml
```

### In GitHub Actions

The workflow file `.github/workflows/test-results-aggregator.yml` automatically:
- Runs all bats tests
- Validates test fixtures
- Verifies the script passes shellcheck
- Generates a sample markdown summary for the job summary

## Test Format Support

### JUnit XML

Expected structure:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="test-suite" tests="5" failures="1" skipped="0" time="2.5">
  <testcase classname="com.example.TestClass" name="testMethod" time="0.1"/>
  <testcase classname="com.example.TestClass" name="testFailure" time="0.2">
    <failure message="error message">failure details</failure>
  </testcase>
  <testcase classname="com.example.TestClass" name="testSkipped" time="0.05">
    <skipped/>
  </testcase>
</testsuite>
```

### JSON

Expected structure:
```json
{
  "tests": [
    {
      "name": "testMethod",
      "class": "com.example.TestClass",
      "status": "passed",
      "duration": 0.1
    },
    {
      "name": "testFailure",
      "class": "com.example.TestClass",
      "status": "failed",
      "duration": 0.2,
      "error": "error message"
    }
  ],
  "summary": {
    "total": 2,
    "passed": 1,
    "failed": 1,
    "skipped": 0,
    "duration": 2.5
  }
}
```

## Testing

Run the test suite with bats:

```bash
bats tests/test_aggregator.bats
```

### Test Coverage

The test suite includes 8 tests:
1. Parse a single JUnit XML file
2. Parse a JSON test result file
3. Aggregate results from multiple XML files
4. Identify flaky tests
5. Generate markdown summary
6. Handle mixed XML and JSON files
7. Error handling for missing files
8. Compute total duration across all files

## Fixtures

Sample test result files are provided in the `fixtures/` directory:
- `build-1-tests.xml`: JUnit XML with mixed pass/fail/skip results
- `build-2-tests.xml`: JUnit XML with different failure patterns
- `build-3-tests.json`: JSON format with pass/fail results
- `build-4-tests.json`: JSON format for aggregation testing

## Implementation Notes

The script uses:
- `grep` with PCRE patterns for parsing
- `awk` for floating-point arithmetic (duration calculations)
- Bash associative arrays for tracking test results
- Pure Bash string manipulation (no external dependencies except for testing)

## Requirements

- Bash 4.0+
- `grep` with `-P` flag (PCRE support)
- `awk` (for numeric calculations)
- For testing: `bats-core`
- For validation: `shellcheck`

## Workflow Validation

The GitHub Actions workflow includes:
- Fixture validation (XML and JSON schema checks)
- Shellcheck validation
- Bash syntax validation
- Comprehensive bats test execution
- Sample markdown generation for job summary

To validate locally:

```bash
# Check YAML syntax
actionlint .github/workflows/test-results-aggregator.yml

# Run workflow with act
act push --rm -P ubuntu-latest=ubuntu:latest
```
