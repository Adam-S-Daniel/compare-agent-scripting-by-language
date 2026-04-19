# Test Results Aggregator

A PowerShell-based test results aggregation tool that parses multiple test result formats (JUnit XML and JSON), aggregates results across multiple runs, identifies flaky tests, and generates markdown summaries suitable for GitHub Actions job summaries.

## Features

- **Multi-format parsing**: Supports JUnit XML and JSON test result files
- **Result aggregation**: Combines results from multiple test runs
- **Metrics computation**: Calculates totals (passed, failed, skipped, duration)
- **Flaky test detection**: Identifies tests with inconsistent results across runs
- **Markdown generation**: Creates formatted summaries for GitHub Actions
- **GitHub Actions integration**: Direct integration with `GITHUB_STEP_SUMMARY` environment variable

## Project Structure

```
├── Test-ResultsAggregator.psm1          # Core module with all aggregation functions
├── Invoke-AggregateTestResults.ps1      # Standalone CLI script
├── Test-AggregateResults.ps1            # Pester unit tests (5 tests)
├── fixtures/                            # Sample test result files
│   ├── run1-junit.xml                   # JUnit XML fixture (8 tests)
│   ├── run1-results.json                # JSON fixture (6 tests)
│   ├── run2-junit.xml                   # JUnit XML fixture (8 tests, different results)
│   └── run2-results.json                # JSON fixture (6 tests, different results)
└── .github/workflows/
    └── test-results-aggregator.yml      # GitHub Actions workflow
```

## Implementation Approach

This project was built using **Red-Green TDD methodology**:

1. **Red Phase**: Write failing tests first
   - 5 comprehensive Pester tests covering all major functionality
   - Tests verify parsing, aggregation, flaky detection, and report generation

2. **Green Phase**: Implement minimal code to pass tests
   - `Parse-JUnitXml`: Parses JUnit XML test result files
   - `Parse-JsonTestResults`: Parses JSON test result files
   - `Aggregate-TestResults`: Aggregates results from multiple files
   - `Identify-FlakyTests`: Detects tests with inconsistent results
   - `Generate-MarkdownSummary`: Creates formatted markdown output

3. **Refactor Phase**: Clean up and optimize
   - Used proper error handling with meaningful messages
   - Clear function documentation with synopsis
   - Modular design for testability

## Usage

### Running the Aggregator Directly

```powershell
./Invoke-AggregateTestResults.ps1 -TestResultsPath "./test-results" -GithubSummary
```

### Running Unit Tests

```powershell
Invoke-Pester -Path "./Test-AggregateResults.ps1"
```

### Running via GitHub Actions

The workflow in `.github/workflows/test-results-aggregator.yml` automatically:
- Parses test results from fixture files
- Aggregates the results
- Generates a markdown summary
- Posts the summary to GitHub Actions job summary
- Runs comprehensive unit tests
- Executes end-to-end integration tests

## Fixture Data

The project includes realistic test fixtures demonstrating:

- **Multi-format support**: Both JUnit XML and JSON formats
- **Matrix builds**: Results from multiple test runs
- **Flaky tests**: Tests that pass in some runs and fail in others
  - `test_user_validation` (passes in run1, fails in run2)
  - `test_password_hashing` (passes in run1, fails in run2)
  - `test_config_validation` (passes in run1, fails in run2)
  - And others

## Workflow Validation

The GitHub Actions workflow:
- ✅ Passes actionlint validation (YAML syntax, action references)
- ✅ Works in isolated Docker containers via `act`
- ✅ Requires `pwsh` shell (pre-installed in container)
- ✅ Includes three jobs with proper dependencies
- ✅ Provides clear test and aggregation output

## Test Results Summary

All tests pass locally and through the GitHub Actions workflow:

```
Tests Passed: 5
Failed: 0
Skipped: 0
```

Unit tests verify:
1. ✅ JUnit XML parsing
2. ✅ JSON test results parsing
3. ✅ Multi-file aggregation
4. ✅ Flaky test detection
5. ✅ Markdown summary generation

Integration tests verify:
- ✅ End-to-end aggregation workflow
- ✅ Fixture file handling
- ✅ Summary generation with realistic data

## Error Handling

The implementation includes:
- Graceful handling of missing files
- Meaningful error messages
- Proper exit codes (0 for success, 1 for failures)
- Warning messages for parse errors
- Continuation on non-critical failures

## Example Output

```markdown
# Test Results Summary

## Overall Metrics
- **Total Tests**: 22
- **Passed**: ✅ 16
- **Failed**: ❌ 5
- **Skipped**: ⏭️ 1
- **Duration**: 10.7s
- **Test Runs**: 4

## ⚠️ Flaky Tests
The following tests have inconsistent results across runs:
- test_config_validation
- test_default_values
- test_email_format
- test_invalid_config
- test_password_hashing
- test_user_validation

## Pass Rate
**72.7%** (16/22)
```

## Running with `act`

```bash
# Run all jobs
act push --rm -W ./.github/workflows/test-results-aggregator.yml

# Run specific job
act push --rm -W ./.github/workflows/test-results-aggregator.yml -j test

# Results saved to act-result.txt
cat act-result.txt
```

## Files Generated During Runs

- `test-results/`: Copied fixture files for aggregation
- `act-result.txt`: Complete output from all `act` runs
- `$GITHUB_STEP_SUMMARY`: GitHub Actions job summary (in workflow)

## Key Design Decisions

1. **Modular Functions**: Each operation is a separate function for testability
2. **No Hard Failures on Parse Errors**: Script continues even if some files fail to parse
3. **Flexible Duration Handling**: Converts between milliseconds (JSON) and seconds (XML/output)
4. **Flaky Detection Algorithm**: A test is flaky if it has 2+ different states across runs
5. **GitHub Actions Integration**: Automatically populates job summary when `GITHUB_STEP_SUMMARY` is available

## Platform Support

- Windows PowerShell 5.1+
- PowerShell Core (pwsh) on Linux/macOS
- Docker containers (tested with catthehacker/ubuntu:full-latest)

## Dependencies

- PowerShell 5.1 or later
- Pester module (included in PowerShell 5.0+)
- No external NuGet packages required

## License

Created as part of the Claude Code agent benchmarking project.
