# Environment Matrix Generator - PowerShell Solution

## Overview
A complete PowerShell implementation of a GitHub Actions matrix generator using test-driven development (TDD), Pester testing framework, and GitHub Actions workflow integration.

## Files Created

### 1. `environment-matrix-generator.ps1` (183 lines)
Main script with the following functions:
- `ConvertTo-GitHubActionsMatrix` - Core function that generates matrices from configuration
- `Get-CartesianProduct` - Creates cartesian product of dimension arrays
- `Remove-ExcludedCombinations` - Filters out excluded combinations

**Features:**
- ✅ Multi-dimensional matrix generation (OS, language, features)
- ✅ Include rules to add extra combinations
- ✅ Exclude rules to filter combinations
- ✅ max-parallel configuration support
- ✅ fail-fast configuration support
- ✅ Matrix size validation with configurable limits
- ✅ Feature flag support via hashtable configuration
- ✅ Valid JSON output compatible with GitHub Actions

### 2. `environment-matrix-generator.tests.ps1` (156 lines)
Comprehensive Pester test suite with 10 test cases:
- Basic matrix generation (2 OS combinations)
- Multi-dimensional matrix (cartesian product)
- Feature flags handling (boolean flags)
- Include rules functionality
- Exclude rules functionality
- Max-parallel configuration
- Fail-fast configuration
- Matrix size validation and rejection
- Error handling with meaningful messages
- JSON output validation

**All tests pass: 10/10 ✅**

### 3. `.github/workflows/environment-matrix-generator.yml` (130 lines)
Complete GitHub Actions workflow with:
- Triggers: push, pull_request, workflow_dispatch
- `shell: pwsh` for PowerShell execution
- Pester unit test execution
- Matrix generation examples
- Include/exclude rule validation
- Feature flags testing
- Matrix size validation testing
- Proper error handling
- Comprehensive output logging

**Validation:**
- ✅ actionlint passes without errors
- ✅ Runs successfully with `act` (GitHub Actions local runner)
- ✅ All workflow steps succeed (✅ Job succeeded)

## Test Results Summary

### Unit Tests (Pester)
- Total: 10 tests
- Passed: 10
- Failed: 0
- Execution time: ~1.32 seconds

### Integration Tests (GitHub Actions Workflow)
- Pester tests: ✅ 10/10 passed
- Matrix generation: ✅ 9-combination 3D matrix (3 OS × 3 language versions)
- Include/Exclude rules: ✅ 4-combination matrix with proper filtering
- Feature flags: ✅ 4-combination matrix with 2 boolean flags
- Matrix size validation: ✅ Correctly rejected oversized matrix (9 > 5 limit)

### Workflow Execution
- Job status: ✅ Succeeded
- Exit code: 0
- Execution completed successfully through `act` container
- No external dependencies required

## Usage Example

```powershell
# Load the script
. ./environment-matrix-generator.ps1

# Create configuration
$config = @{
    os = @('ubuntu-latest', 'windows-latest', 'macos-latest')
    language = @('1.0', '1.1', '1.2')
    'max-parallel' = 6
    'fail-fast' = $false
    include = @(
        @{ os = 'macos-m1'; language = '1.0'; arch = 'arm64' }
    )
    exclude = @(
        @{ os = 'macos-latest'; language = '1.1' }
    )
}

# Generate matrix
$matrix = ConvertTo-GitHubActionsMatrix -Configuration $config

# Output as JSON
$matrix | ConvertTo-Json -Depth 10
```

## TDD Approach

The solution followed strict red-green-refactor TDD:
1. **Red**: Wrote 10 failing Pester tests covering all requirements
2. **Green**: Implemented functions to make all tests pass
3. **Refactor**: Cleaned up code, improved error messages, optimized cartesian product logic

## Key Design Decisions

1. **Hashtable-based configuration**: Simple PowerShell-native format
2. **Cartesian product via nested loops**: Efficient for typical use cases
3. **Include/exclude as separate operations**: Clear separation of concerns
4. **Array-based matrix.include**: GitHub Actions compatible format
5. **Configurable max-matrix-size**: Prevents accidental large matrices
6. **Comprehensive error handling**: Meaningful error messages for debugging

## GitHub Actions Integration

The workflow demonstrates:
- ✅ Proper `shell: pwsh` usage in all steps
- ✅ Actions/checkout@v4 for code retrieval
- ✅ Pester for automated testing
- ✅ Real-world matrix examples and validation
- ✅ Graceful error handling
- ✅ Clear output logging
- ✅ Compatibility with `act` local runner

## Performance

- Unit test execution: ~1.3 seconds
- Full workflow execution (via act): ~15-20 seconds
- Matrix generation for 3D case: <1 second

## Artifacts

The `act-result.txt` file contains:
- Complete workflow execution output
- All test results with timestamps
- Matrix JSON examples
- Validation confirmations
- Job status and exit codes
