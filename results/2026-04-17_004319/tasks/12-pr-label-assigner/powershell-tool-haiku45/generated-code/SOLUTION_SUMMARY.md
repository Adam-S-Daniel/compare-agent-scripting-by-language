# PR Label Assigner - PowerShell Solution

## Summary
A complete PowerShell-based PR label assigner with TDD-driven tests, GitHub Actions workflow, and end-to-end validation through `act`.

## Files Created

### 1. **Assign-PRLabels.ps1** (4.3 KB)
Core implementation with:
- `Get-PRLabels`: Main function that assigns labels based on glob pattern rules
- `Test-GlobMatch`: Pattern matching against file paths
- `ConvertGlobToRegex`: Converts glob patterns (**, *) to regex
- Features:
  - Glob pattern support: `docs/**`, `src/**.js`, `**.test.ps1`
  - Multiple labels per file
  - Priority ordering when rules conflict
  - Case-insensitive matching
  - Label deduplication

### 2. **Assign-PRLabels.Tests.ps1** (5.7 KB)
Comprehensive Pester test suite with 13 tests:
- **Simple path matching** (2 tests): Exact paths, glob patterns
- **Multiple labels** (1 test): Multiple labels per file
- **Priority ordering** (1 test): First-match priority
- **Error handling** (2 tests): Invalid inputs, empty rules
- **No matching rules** (1 test): Empty result set
- **Deduplication** (1 test): Duplicate label removal
- **Pattern variations** (3 tests): **, * patterns, case-insensitivity
- **Real-world scenario** (1 test): Complete PR with multiple file types

### 3. **.github/workflows/pr-label-assigner.yml** (5.6 KB)
Production GitHub Actions workflow with:
- **Triggers**: push, pull_request, schedule, workflow_dispatch
- **Jobs**: 
  - "Run PR Label Assigner Tests": Executes all Pester tests
  - "Validate Workflow Structure": Verifies script files and workflow config
- **Steps**:
  - PowerShell/Pester installation
  - Pester test execution (13 tests)
  - Label assignment validation
  - Priority ordering verification
  - Glob pattern testing
  - Workflow structure validation

### 4. **act-result.txt** (32 KB)
Complete test execution output from `act push --rm`:
- ✅ All 13 Pester tests passed
- ✅ Label assignment: `api, backend, documentation, tests`
- ✅ Priority ordering test passed
- ✅ Glob pattern tests passed (**, *, case-insensitive)
- ✅ Both GitHub Actions jobs succeeded

## Test Results

### Pester Tests (Local)
```
Tests Passed: 13
Failed: 0
Skipped: 0
```

### GitHub Actions via act
```
[Run PR Label Assigner Tests]     🏁 Job succeeded
[Validate Workflow Structure]     🏁 Job succeeded
```

### actionlint Validation
✅ Passed - Workflow is syntactically valid and uses correct action references

## Design Approach (TDD)

1. **Write failing tests first**: Created 13 test cases covering all functionality
2. **Implement minimum code**: Built functions to satisfy tests
3. **Refactor**: Optimized glob pattern matching and label deduplication
4. **Validate workflow**: Created GitHub Actions workflow to run tests in CI/CD
5. **Integration testing**: Ran through `act` to verify in container environment

## Key Features

### Glob Pattern Support
- `**` - Matches any number of directories (e.g., `docs/**` matches all files under docs/)
- `*` - Matches within a single path segment (e.g., `**.test.ps1` matches all test files)
- Case-insensitive matching (e.g., `docs/**` matches `DOCS/README.MD`)

### Rule Configuration
```powershell
$rules = @{
    'docs/**' = @('documentation')
    'src/api/**' = @('api', 'backend')
    'src/**' = @('backend')
    '**.test.ps1' = @('tests')
}
```

### Priority Ordering
```powershell
$rules = @(
    @{ pattern = 'src/api/**'; labels = @('api'); priority = 1 }
    @{ pattern = 'src/**'; labels = @('backend'); priority = 2 }
)
$labels = Get-PRLabels -Files $files -Rules $rules -UsePriority $true
```

## Workflow Validation

- ✅ actionlint: No errors
- ✅ PowerShell shell: Uses `shell: pwsh`
- ✅ Container: Runs in ghcr.io/catthehacker/ubuntu:pwsh-latest
- ✅ Permissions: Minimal (contents: read)
- ✅ Dependencies: Installs PowerShell and Pester on-demand
- ✅ Idempotent: Safe to run multiple times

## Error Handling

- ✅ Null/empty file paths: Throws meaningful error
- ✅ Empty rules: Throws error
- ✅ Invalid patterns: Handled gracefully
- ✅ No matches: Returns empty set

## Performance

- Pester tests: ~1.47 seconds
- All workflow steps: ~41 seconds
- Pattern matching: O(n*m) where n=files, m=rules
