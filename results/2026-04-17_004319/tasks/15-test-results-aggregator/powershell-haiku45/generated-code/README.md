# Test Results Aggregator

A PowerShell solution that parses test result files in JUnit XML and JSON formats, aggregates results across multiple files (matrix builds), identifies flaky tests, and generates markdown summaries suitable for GitHub Actions job summaries.

## Features

- **JUnit XML Parsing**: Extracts test results from standard JUnit XML format
- **JSON Parsing**: Handles custom JSON test result format
- **Result Aggregation**: Combines results across multiple test runs (simulating matrix builds)
- **Flaky Test Detection**: Identifies tests that pass in some runs but fail in others
- **Markdown Generation**: Creates formatted summaries for GitHub Actions job summaries
- **Comprehensive Testing**: Full Pester test suite with 100% pass rate

## Project Structure

```
.
├── test-results-aggregator.ps1      # Main aggregator script
├── test-results-aggregator.Tests.ps1 # Pester test suite (6 tests)
├── run-workflow-tests.ps1            # Test harness for validation
├── fixtures/                         # Sample test result files
│   ├── junit-run1.xml
│   ├── junit-run2.xml
│   ├── results-run1.json
│   └── results-run2.json
└── .github/workflows/                # GitHub Actions workflow
    └── test-results-aggregator.yml
```

## Core Functions

### Get-JunitXmlTestResults
Parses JUnit XML test result files and returns structured test data.

```powershell
$results = Get-JunitXmlTestResults -FilePath "./junit-results.xml"
```

### Get-JsonTestResults
Parses JSON test result files and returns structured test data.

```powershell
$results = Get-JsonTestResults -FilePath "./test-results.json"
```

### Aggregate-TestResults
Combines multiple test result objects into aggregated summaries.

```powershell
$aggregated = Aggregate-TestResults -TestResults @($xml1, $json1, $json2)
```

### ConvertTo-MarkdownSummary
Generates a markdown-formatted summary table of test results.

```powershell
$markdown = ConvertTo-MarkdownSummary -AggregatedResults $aggregated
```

### Find-FlakyTests
Identifies tests that have inconsistent results across multiple runs.

```powershell
$flaky = Find-FlakyTests -MultipleRuns @($run1, $run2, $run3)
```

### Invoke-TestResultsAggregator
Main function for coordinating the aggregation workflow.

## Running Tests

Run all Pester tests:

```powershell
Invoke-Pester test-results-aggregator.Tests.ps1
```

Run test validation harness:

```powershell
pwsh run-workflow-tests.ps1
```

This validates:
- Workflow structure and syntax (via actionlint)
- Local script execution
- Fixture parsing and aggregation
- Flaky test detection

## GitHub Actions Workflow

The included workflow `.github/workflows/test-results-aggregator.yml`:

- Runs on push, pull request, and scheduled (daily)
- Executes all Pester tests
- Parses and aggregates sample test fixtures
- Generates markdown summary to job summary
- Validates all required files exist

### Triggering the Workflow

```bash
git push                           # Automatically triggers on push
gh workflow run test-results-aggregator.yml  # Manual trigger
```

## Test Results

All 6 tests pass successfully:

```
Tests Passed: 6, Failed: 0, Skipped: 0
```

### Test Coverage

1. **Initialization**: Function availability verification
2. **JUnit XML Parsing**: Correctly extracts passed/failed/skipped counts
3. **JSON Parsing**: Handles custom JSON test format
4. **Aggregation**: Combines multiple test runs accurately
5. **Markdown Output**: Generates valid markdown with test metrics
6. **Flaky Detection**: Identifies inconsistent test results

## Sample Test Fixtures

The fixtures directory contains sample test result files demonstrating:

- **junit-run1.xml**: 3 passed, 1 failed, 1 skipped test
- **junit-run2.xml**: 3 passed, 2 failed (FlakyTest fails here)
- **results-run1.json**: 3 passed, 1 failed test
- **results-run2.json**: 4 passed, 1 failed (FlakyJsonTest fails here)

FlakyTest and FlakyJsonTest demonstrate flakiness (pass in run 1, fail in run 2).

## Usage Example

```powershell
# Source the script
. ./test-results-aggregator.ps1

# Parse multiple test result files
$xml1 = Get-JunitXmlTestResults -FilePath "./junit-run1.xml"
$json1 = Get-JsonTestResults -FilePath "./results-run1.json"

# Aggregate results
$results = Aggregate-TestResults -TestResults @($xml1, $json1)

# Generate markdown summary
$summary = ConvertTo-MarkdownSummary -AggregatedResults $results

# Find flaky tests
$flaky = Find-FlakyTests -MultipleRuns @($xml1, $json1)
if ($flaky) {
    Write-Host "Found $($flaky.Count) flaky test(s)"
}

# Output to GitHub Actions job summary
$summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append
```

## Implementation Notes

### TDD Methodology

This project was developed using red/green TDD:
1. Failing tests were written first for each feature
2. Minimum code was added to make tests pass
3. Code was refactored for clarity and efficiency

### XML Parsing Details

JUnit XML parsing checks for failure/skipped elements in ChildNodes rather than direct property access, accounting for PowerShell XML parsing behavior where accessing non-existent elements returns empty XmlElement objects.

### Flaky Test Detection

Tests are flagged as flaky when they have mixed results across multiple runs:
- Passed in at least one run
- Failed in at least one run

This helps identify intermittent failures and timing-sensitive tests.

## Validation Status

✓ All 6 Pester tests pass
✓ Workflow passes actionlint validation
✓ All required files present and valid
✓ Fixture parsing verified
✓ Markdown generation verified
✓ Flaky test detection verified
