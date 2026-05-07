# Artifact Cleanup Script

A PowerShell script that applies retention policies to artifacts and generates a deletion plan with summary statistics.

## Features

- **Maximum Age Policy**: Delete artifacts older than N days
- **Maximum Total Size Policy**: Delete oldest artifacts until total size is under limit
- **Keep Latest Per Workflow Policy**: Retain only the N most recent artifacts per workflow ID
- **Dry-Run Mode**: Generate deletion plan without making changes
- **Comprehensive Reporting**: Summary with artifacts to delete/retain and space reclaimed

## Script Files

### Core Script
- **`Invoke-ArtifactCleanup.ps1`** - Main artifact cleanup function with retention policy logic

### Testing
- **`Invoke-ArtifactCleanup.Tests.ps1`** - Comprehensive Pester test suite with 11 test cases
- **`run-act-tests.ps1`** - Test harness for running workflow through GitHub Actions (act)

### GitHub Actions Workflow
- **`.github/workflows/artifact-cleanup-script.yml`** - CI/CD pipeline with 3 jobs:
  - `test`: Run Pester test suite
  - `validate`: Execute functional validation tests
  - `structure`: Verify script files and syntax

## Usage

### Basic Example

```powershell
# Source the script
. ./Invoke-ArtifactCleanup.ps1

# Create artifact objects
$artifacts = @(
    @{ Name = "build-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "run1" },
    @{ Name = "build-2"; Size = 150; CreatedDate = (Get-Date).AddDays(-10); WorkflowRunId = "run1" }
)

# Generate deletion plan
$result = Invoke-ArtifactCleanup `
    -Artifacts $artifacts `
    -MaxAgeInDays 30 `
    -MaxTotalSizeInMB 500 `
    -KeepLatestPerWorkflow 5 `
    -DryRun

# View results
$result.Summary | Format-Table
$result.DeletionPlan | Format-Table
```

## Function Signature

```powershell
Invoke-ArtifactCleanup `
    -Artifacts <object[]> `
    -MaxAgeInDays <int> `
    -MaxTotalSizeInMB <int> `
    -KeepLatestPerWorkflow <int> `
    [-DryRun]
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Artifacts` | object[] | Yes | Array of artifacts with Name, Size (MB), CreatedDate, WorkflowRunId properties |
| `MaxAgeInDays` | int | Yes | Delete artifacts older than this many days |
| `MaxTotalSizeInMB` | int | Yes | Maximum total size to retain; older artifacts deleted to stay under this |
| `KeepLatestPerWorkflow` | int | Yes | Retain only this many newest artifacts per workflow ID |
| `DryRun` | switch | No | Generate plan but don't delete (plan-only mode) |

### Return Value

Returns a PSCustomObject with:

```powershell
@{
    DeletionPlan = @(...)        # Array of artifacts marked for deletion
    Summary = @{
        TotalInputArtifacts = <int>
        ArtifactsToDelete = <int>
        ArtifactsToRetain = <int>
        SpaceReclaimedMB = <int>
    }
    DryRun = <bool>              # True if executed in dry-run mode
}
```

## Testing

### Run Tests Locally

```powershell
# Install Pester (if needed)
Install-Module -Name Pester -Force

# Run all tests
Invoke-Pester -Path ./Invoke-ArtifactCleanup.Tests.ps1

# Run tests with detailed output
Invoke-Pester -Path ./Invoke-ArtifactCleanup.Tests.ps1 -Output Detailed
```

### Run Tests Through GitHub Actions (act)

```powershell
# Run the test harness
pwsh ./run-act-tests.ps1

# View workflow output
cat act-result.txt
```

## Test Coverage

The test suite includes 11 test cases covering:

1. ✅ Script loads without errors
2. ✅ Function exports correctly
3. ✅ Parameters are correct
4. ✅ Handles artifacts array input
5. ✅ Handles empty input
6. ✅ Maximum age policy enforcement
7. ✅ Dry-run mode indication
8. ✅ Maximum total size policy
9. ✅ Keep latest per workflow policy
10. ✅ Summary calculation accuracy
11. ✅ Combined policy interactions

## Retention Policy Priority

Policies are applied in order with combined effect:

1. **Age Policy** - Any artifact older than MaxAgeInDays is marked for deletion
2. **Workflow Policy** - Only keep KeepLatestPerWorkflow newest per workflow
3. **Size Policy** - Delete oldest artifacts (not marked by above policies) until under MaxTotalSizeInMB

An artifact is deleted if it matches ANY policy (OR logic between policies, not AND).

## GitHub Actions Workflow

The workflow validates the script in three ways:

### 1. Pester Tests Job
- Installs PowerShell Pester module
- Runs all 11 unit tests
- Verifies 100% pass rate

### 2. Functional Validation Job
- Tests 5 real-world scenarios:
  - Empty input handling
  - Young artifact retention
  - Old artifact deletion
  - Size limit enforcement
  - Dry-run mode indication

### 3. Structure Validation Job
- Verifies all required files exist
- Validates PowerShell syntax
- Checks script dependencies

## Validation

All tests pass validation:

```
actionlint .github/workflows/artifact-cleanup-script.yml
# (no output = valid YAML)
```

All tests pass through act:

```
Pester Test Results: 11 passed, 0 failed
Jobs with 'succeeded' status: 3
✓ Validation job completed successfully
✓ File structure validation passed
✓ Syntax validation passed
```

## Implementation Notes

- Uses TDD methodology: tests written before implementation
- All tests pass locally with `Invoke-Pester`
- All tests pass through CI/CD pipeline with `act`
- Comprehensive error handling and edge case coverage
- Clean, readable code with minimal comments (intent is clear)
- No external dependencies beyond PowerShell and Pester

## License

MIT
