# Environment Matrix Generator for GitHub Actions

## Overview
A PowerShell-based solution that generates GitHub Actions build matrices with support for:
- OS options and language versions
- Include/exclude rules for matrix combinations
- Max-parallel and fail-fast configuration
- Matrix size validation
- JSON output suitable for `strategy.matrix`

## Files Created

### 1. MatrixGenerator.ps1
Main script implementing the matrix generation logic with three functions:

- **New-EnvironmentMatrix**: Core function that generates the cartesian product of all dimensions
- **Test-ExcludedCombination**: Helper function for checking if a combination matches exclude rules
- **Export-MatrixJson**: Helper function for converting matrix to JSON format

### 2. MatrixGenerator.Tests.ps1
Comprehensive test suite using Pester framework with 8 test cases covering:
- Basic matrix generation with 2D combinations
- Exclude rules functionality
- Include rules for custom combinations
- Max-parallel configuration
- Fail-fast configuration
- Matrix size validation and error handling
- JSON output validation

### 3. .github/workflows/environment-matrix-generator.yml
GitHub Actions workflow that:
- Triggers on push, pull_request, schedule, and workflow_dispatch
- Uses Ubuntu with PowerShell (pwsh shell)
- Runs Pester test suite
- Validates matrix generation with multiple test scenarios
- Tests all configuration options
- Passes actionlint YAML validation

### 4. run-tests.sh
Test harness script that:
- Validates workflow structure and file existence
- Runs actionlint validation on the workflow
- Executes all tests through `act` (GitHub Actions local runner)
- Captures comprehensive output to `act-result.txt`
- Verifies all test outcomes

## Test Results

All tests pass successfully with 100% pass rate:

✓ 8 Pester unit tests pass
✓ All workflow validation steps pass
✓ All integration tests through GitHub Actions pass
✓ Matrix generation produces correct JSON output
✓ Exclude/include rules work correctly
✓ Configuration options properly set in output
✓ Matrix size validation prevents oversized matrices
✓ actionlint YAML validation passes

## Usage Examples

```powershell
# Basic matrix
$config = @{
    os = @("ubuntu-latest", "windows-latest")
    language = @("3.9", "3.10")
    max_parallel = 4
    fail_fast = $true
}
$matrix = New-EnvironmentMatrix -Configuration $config

# With excludes
$config = @{
    os = @("ubuntu-latest", "windows-latest")
    language = @("3.9", "3.10")
    exclude = @(
        @{ os = "windows-latest"; language = "3.9" }
    )
}
$matrix = New-EnvironmentMatrix -Configuration $config

# Export to JSON
$json = Export-MatrixJson -Matrix $matrix -OutputPath "matrix.json"
```

## Implementation Notes

- Follows Red-Green-Refactor TDD methodology
- All tests runnable with `Invoke-Pester`
- Graceful error handling with meaningful messages
- Comprehensive comments explaining approach
- Handles edge cases (empty arrays, size limits)
- Supports arbitrary additional properties in combinations
- Uses proper JSON serialization for GitHub Actions compatibility

## Validation

The solution has been validated:
- All Pester tests pass
- All workflow steps execute successfully
- GitHub Actions workflow passes actionlint validation
- Complete workflow executes successfully through `act`
- Output saved to `act-result.txt` for audit trail
