# Test Results Aggregator

A comprehensive PowerShell solution for parsing, aggregating, and analyzing test results from multiple formats and test runs. Includes TDD-driven development with Pester, GitHub Actions integration, and GitHub Actions job summary generation.

## Features

- **Multi-format support**: Parses JUnit XML and JSON test result files
- **Matrix build aggregation**: Combines results from multiple parallel test runs
- **Flaky test detection**: Identifies tests that pass in some runs but fail in others
- **Markdown reporting**: Generates formatted summaries for GitHub Actions job summaries
- **Comprehensive testing**: 22 passing Pester tests covering all functionality
- **GitHub Actions integration**: Ready-to-use workflow for CI/CD pipelines

## Architecture

### Core Components

**src/Aggregator.ps1**
- `ParseJunitXml`: Extracts test data from JUnit XML files
- `ParseJsonResults`: Extracts test data from JSON result files
- `AggregateResults`: Combines multiple test result arrays
- `CalculateTotals`: Computes summary statistics (passed, failed, skipped, duration)
- `IdentifyFlakyTests`: Detects tests with inconsistent results across runs
- `GenerateMarkdownSummary`: Creates formatted markdown reports
- `Invoke-TestAggregation`: Main entry point for end-to-end aggregation

**tests/Aggregator.Tests.ps1**
- 22 comprehensive Pester tests using red/green TDD methodology
- Tests cover all parsing, aggregation, and reporting functionality
- Fixtures provided for validation

**tests/fixtures/**
- JUnit XML samples: `passing.xml`, `failing.xml`, `mixed.xml`, `run1.xml`, `run2.xml`
- JSON samples: `passing.json`, `failing.json`, `run1.json`, `run2.json`
- Real-world test scenarios with passes, failures, skips, and flaky patterns

## Usage

### Running Tests

```powershell
# Run all Pester tests
Invoke-Pester tests/Aggregator.Tests.ps1

# Run with detailed output
Invoke-Pester tests/Aggregator.Tests.ps1 -Output Detailed
```

### Aggregating Test Results

```powershell
# Load the module
. src/Aggregator.ps1

# Parse individual files
$junitResults = ParseJunitXml "tests/fixtures/junit/passing.xml"
$jsonResults = ParseJsonResults "tests/fixtures/json/passing.json"

# Aggregate
$aggregated = AggregateResults @($junitResults, $jsonResults)
$totals = CalculateTotals $aggregated

# Detect flaky tests across runs
$run1 = ParseJunitXml "tests/fixtures/junit/run1.xml"
$run2 = ParseJunitXml "tests/fixtures/junit/run2.xml"
$flaky = IdentifyFlakyTests $run1, $run2

# Generate report
$summary = GenerateMarkdownSummary $totals $flaky "My Test Report"
Write-Output $summary
```

### Using the Main Function

```powershell
$result = Invoke-TestAggregation `
    -FilePaths @("run1.xml", "run2.json") `
    -Title "Matrix Build Results" `
    -OutputFile "summary.md"
```

## GitHub Actions Integration

The solution includes a complete CI/CD workflow at `.github/workflows/test-results-aggregator.yml`.

### Workflow Features

- **Triggers**: Push, pull request, and manual dispatch
- **Matrix support**: Can run multiple test jobs in parallel
- **Test execution**: Runs Pester tests and captures results
- **Result aggregation**: Aggregates results from all runs
- **Flaky detection**: Identifies flaky tests across matrix runs
- **Job summary**: Outputs markdown summary to GitHub Actions job summary
- **Artifact upload**: Saves summary markdown as artifact

### Running Locally with act

```bash
# Validate workflow with actionlint
actionlint .github/workflows/test-results-aggregator.yml

# Run workflow locally
act push --rm

# Run specific job
act push --rm -j 'Run Tests and Aggregate Results'
```

## Test Coverage

All 22 tests pass, covering:

✅ **ParseJunitXml**
- Parsing passing test suites
- Parsing failing tests with failure messages
- Including test class names
- Calculating total duration

✅ **ParseJsonResults**
- Parsing passing test results
- Parsing mixed results (passed, failed, skipped)
- Including error messages for failures

✅ **AggregateResults**
- Combining results from multiple files
- Tracking unique tests from different sources

✅ **CalculateTotals**
- Computing correct totals from single files
- Aggregating results from multiple sources
- Computing pass rate and duration
- Handling empty result sets

✅ **IdentifyFlakyTests**
- Detecting tests that pass and fail across runs
- Tracking pass/fail counts
- Handling runs with no flaky tests

✅ **GenerateMarkdownSummary**
- Generating markdown reports
- Including flaky test sections
- Using success/failure emojis
- Showing pass rates and duration

✅ **Main Workflow**
- End-to-end aggregation of multiple files
- Complete test pipeline validation

## Example Output

```markdown
## Test Execution Summary ✅

**Summary:**
- Total: 13
- Passed: 9
- Failed: 3
- Skipped: 1
- Pass Rate: 69.23%
- Duration: 6.46s

### 🔀 Flaky Tests

| Test | Class | Passed | Failed | Runs |
|------|-------|--------|--------|------|
| Timeout | AsyncTests | 1 | 1 | 2 |
```

## Error Handling

All functions include graceful error handling:

- File not found errors are caught and reported
- Invalid formats are handled with meaningful messages
- Empty result sets are processed correctly
- Type validation prevents runtime errors

## Files and Structure

```
.
├── src/
│   └── Aggregator.ps1                 # Main aggregation module
├── tests/
│   ├── Aggregator.Tests.ps1           # Pester test suite (22 tests)
│   └── fixtures/
│       ├── junit/                     # JUnit XML test data
│       │   ├── passing.xml
│       │   ├── failing.xml
│       │   ├── mixed.xml
│       │   ├── run1.xml
│       │   └── run2.xml
│       └── json/                      # JSON test data
│           ├── passing.json
│           ├── failing.json
│           ├── run1.json
│           └── run2.json
├── .github/
│   └── workflows/
│       └── test-results-aggregator.yml # GitHub Actions workflow
├── test-output/
│   ├── summary.md                     # Generated summary report
│   └── pester-results.xml            # Pester test results
├── act-result.txt                     # act execution log
└── README.md                          # This file
```

## Development Methodology

This project uses **red-green-refactor TDD**:

1. **Red**: Write failing Pester tests first
2. **Green**: Implement minimal code to make tests pass
3. **Refactor**: Clean up code while maintaining test coverage

All 22 tests were written before implementation and all pass.

## Testing with act

The `act-result.txt` file contains the full output from running the workflow locally with `act`:

- Shows both "Run Tests and Aggregate Results" job succeeded
- Shows "Validate Workflow" job succeeded
- Demonstrates PowerShell execution in Docker container
- Proves JSON parsing and markdown generation work correctly
- Verifies all required files exist

Key assertions from act execution:
- ✅ Both GitHub Actions jobs succeeded
- ✅ All 22 Pester tests passed
- ✅ Test results aggregated: 13 total tests (9 passed, 3 failed, 1 skipped)
- ✅ Flaky test detected: "Timeout" in AsyncTests (1 pass, 1 fail across 2 runs)
- ✅ Markdown summary generated with correct emoji and statistics
- ✅ All workflow files validated

## Requirements Met

✅ Uses PowerShell exclusively
✅ Red/green TDD methodology with Pester
✅ 22 passing tests covering all functionality
✅ Comprehensive test fixtures for JUnit XML and JSON
✅ Multi-format test result parsing
✅ Matrix build result aggregation
✅ Flaky test identification
✅ Markdown summary generation
✅ GitHub Actions workflow with proper structure
✅ actionlint validation passing
✅ Fully tested with `act` - both jobs succeeded
✅ act-result.txt artifact created with complete output
✅ Clear comments explaining approach
✅ Graceful error handling with meaningful messages

## License

This solution is provided as part of the Compare Agent Scripting by Language project.
