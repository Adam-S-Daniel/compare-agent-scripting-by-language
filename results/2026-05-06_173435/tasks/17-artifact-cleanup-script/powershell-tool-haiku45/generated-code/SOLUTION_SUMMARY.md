# Artifact Cleanup Script - Solution Summary

## Overview
A complete PowerShell artifact cleanup solution with retention policy enforcement, comprehensive test suite, and GitHub Actions integration.

## Files Created

### Main Implementation
- **ArtifactCleanup.ps1** (5.6 KB)
  - Core script with artifact validation and deletion planning
  - Functions: `Validate-Artifact`, `Get-DeletionPlan`
  - Supports dry-run mode for safe preview

### Comprehensive Test Suite
- **ArtifactCleanup.Tests.ps1** (9.4 KB)
  - 17 test cases using Pester framework
  - **Test Results: 17 Passed, 0 Failed**
  - Coverage:
    - Data validation (2 tests)
    - Max age retention policy (2 tests)
    - Max total size retention policy (2 tests)
    - Keep latest N per workflow policy (2 tests)
    - Multiple policies combined (1 test)
    - Deletion plan summary (3 tests)
    - Dry-run mode (2 tests)
    - Error handling (3 tests)

### GitHub Actions Workflow
- **.github/workflows/artifact-cleanup-script.yml** (2.2 KB)
  - Trigger events: push, pull_request, schedule, workflow_dispatch
  - Runs on ubuntu-latest
  - Steps:
    1. Checkout code
    2. Run Pester tests
    3. Upload test results
    4. Generate test output log
  - Uses actions/checkout@v4

### Validation & Test Execution
- **act-result.txt** (32.5 KB)
  - Complete GitHub Actions workflow execution output via act
  - All 17 tests passed
  - Exit code: 0 (success)
  - Job status: succeeded

## Features Implemented

### Retention Policies
1. **MaxAgeInDays**: Delete artifacts older than specified days
2. **MaxTotalSizeInMB**: Keep total artifact size under limit (deletes oldest first)
3. **KeepLatestPerWorkflow**: Maintain N latest artifacts per workflow

### Core Functions
- `Validate-Artifact`: Ensures required properties (Name, Size, CreatedDate, WorkflowRunId)
- `Get-DeletionPlan`: Applies retention policies and returns deletion plan

### Output Specification
```powershell
$plan = @{
    ToDelete = [array] # Artifacts marked for deletion
    ToRetain = [array] # Artifacts to keep
    Summary = @{
        ArtifactsDeleted = [int]
        ArtifactsRetained = [int]
        TotalSpaceReclaimedBytes = [int]
        TotalSpaceReclaimedMB = [double]
        ToString = [string]
    }
    DryRun = [bool] # Safety flag for preview mode
}
```

## Validation Results

### Actionlint
✓ Workflow validation passed (no errors)

### Pester Tests
```
Tests Passed: 17
Tests Failed: 0
Tests Skipped: 0
Execution Time: ~0.75 seconds
```

### GitHub Actions with act
✓ Workflow executed successfully via `act push --rm`
✓ All tests ran in Docker container
✓ Exit code: 0
✓ Job status: succeeded

## Test Coverage

### Positive Tests
- Accept valid artifact objects
- Mark old artifacts for deletion
- Keep new artifacts
- Enforce size limits
- Track per-workflow limits
- Apply multiple policies together
- Calculate accurate summaries

### Negative Tests
- Reject artifacts missing required properties
- Throw on empty artifact list
- Throw on empty policies
- Provide meaningful error messages

### Edge Cases
- Dry-run mode verification
- Human-readable size formatting
- Per-workflow policy isolation
- Cumulative policy application

## Running Tests Locally

### Direct Execution
```powershell
Invoke-Pester ArtifactCleanup.Tests.ps1
```

### Via GitHub Actions
```bash
act push --rm -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:pwsh-latest
```

## Usage Example

```powershell
# Define artifacts
$artifacts = @(
    @{ Name = "build-123"; Size = 1048576; CreatedDate = (Get-Date).AddDays(-35); WorkflowRunId = "workflow-1" },
    @{ Name = "build-124"; Size = 2097152; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "workflow-1" },
    @{ Name = "build-125"; Size = 524288; CreatedDate = (Get-Date).AddDays(-1); WorkflowRunId = "workflow-2" }
)

# Define retention policies
$policies = @{
    MaxAgeInDays = 30
    MaxTotalSizeInMB = 2
    KeepLatestPerWorkflow = 2
}

# Generate deletion plan (dry-run mode)
$plan = Get-DeletionPlan -Artifacts $artifacts -Policies $policies -DryRun $true

# Review results
Write-Host "Artifacts to delete: $($plan.ToDelete.Count)"
Write-Host "Artifacts to retain: $($plan.ToRetain.Count)"
Write-Host "Space reclaimed: $($plan.Summary.TotalSpaceReclaimedMB) MB"
```

## Architecture

The solution follows Red/Green TDD methodology:
1. **Red**: Comprehensive test suite written first with all requirements
2. **Green**: Implementation written to pass all tests
3. **Refactor**: Code optimized for clarity and efficiency

All tests must pass before feature is considered complete.
