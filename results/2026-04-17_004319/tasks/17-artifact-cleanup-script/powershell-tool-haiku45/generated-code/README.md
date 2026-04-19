# Artifact Cleanup Script

A PowerShell-based artifact lifecycle management tool with retention policies, dry-run support, and comprehensive Pester test coverage.

## Features

- **Retention Policies**
  - Max age deletion (artifacts older than N days)
  - Max total size enforcement (delete oldest until under limit)
  - Keep-latest-N per workflow (ensure minimum recent artifacts per workflow ID)

- **Dry-Run Mode**
  - Preview deletion plan without making changes
  - Generate detailed reports of what would be deleted/retained

- **Comprehensive Reporting**
  - Space reclamation summary
  - Artifact retention vs. deletion breakdown
  - Human-readable cleanup plans

## Files

| File | Purpose |
|------|---------|
| `Clean-Artifacts.ps1` | Main script with artifact cleanup functions |
| `Clean-Artifacts.Tests.ps1` | Pester test suite (8 test cases) |
| `.github/workflows/artifact-cleanup-script.yml` | GitHub Actions workflow for CI/CD |
| `act-result.txt` | Test execution results via `act` |

## Usage

### Basic Cleanup Plan

```powershell
# Source the script
. ./Clean-Artifacts.ps1

# Create or load artifacts
$artifacts = @(
    @{ Name = "build-1"; Size = 100MB; CreatedAt = (Get-Date).AddDays(-15); WorkflowId = "main" },
    @{ Name = "build-2"; Size = 50MB; CreatedAt = (Get-Date).AddDays(-5); WorkflowId = "main" }
)

# Generate cleanup plan
$plan = Invoke-CleanupPlan `
    -Artifacts $artifacts `
    -MaxAgeDays 7 `
    -MaxTotalSizeMB 500 `
    -KeepLatestPerWorkflow 3

# Display summary
$summary = Format-CleanupSummary -Plan $plan
Write-Host $summary
```

### Dry-Run Preview

```powershell
# Execute in dry-run mode (no deletions)
Invoke-Cleanup -Plan $plan -DryRun $true
```

### Actual Cleanup

```powershell
# Execute actual cleanup (delete artifacts)
Invoke-Cleanup -Plan $plan -DryRun $false
```

## API Reference

### `Invoke-CleanupPlan`

Generates a deletion plan based on retention policies.

**Parameters:**
- `Artifacts` [object[]]: Array of artifact objects with Name, Size, CreatedAt, WorkflowId
- `MaxAgeDays` [int]: Delete artifacts older than this many days (default: 30)
- `MaxTotalSizeMB` [int]: Maximum total size before forced deletions (default: 1000)
- `KeepLatestPerWorkflow` [int]: Minimum recent artifacts per workflow (default: 3)

**Returns:** Hashtable with:
- `ToDelete`: Artifacts marked for deletion
- `ToKeep`: Artifacts to retain
- `TotalSpaceReclaimed`: Size of deleted artifacts
- `DeleteCount`: Number of artifacts to delete
- `KeepCount`: Number of artifacts to keep

### `Format-CleanupSummary`

Generates a human-readable summary of the cleanup plan.

**Parameters:**
- `Plan` [hashtable]: Output from `Invoke-CleanupPlan`

**Returns:** [string] Formatted summary

### `Invoke-Cleanup`

Executes the cleanup plan.

**Parameters:**
- `Plan` [hashtable]: Output from `Invoke-CleanupPlan`
- `DryRun` [bool]: If true, preview only; if false, delete (default: true)

**Returns:** [bool] DryRun flag value

## Testing

### Run All Tests

```bash
pwsh -Command "Invoke-Pester Clean-Artifacts.Tests.ps1"
```

### Test Coverage

The test suite covers:
1. **Parse-ArtifactData**: Mock data parsing
2. **Test-ArtifactRetention-MaxAge**: Deletion by age
3. **Test-ArtifactRetention-MaxSize**: Deletion by size limit
4. **Test-ArtifactRetention-KeepLatest**: Per-workflow retention
5. **Invoke-CleanupPlan**: Plan generation
6. **Invoke-Cleanup**: Normal and dry-run modes
7. **Format-CleanupSummary**: Summary formatting (2 test cases)

**Result:** All 8 tests passing ✓

### GitHub Actions Workflow

The workflow file `.github/workflows/artifact-cleanup-script.yml` includes:

- **Triggers:** push, pull_request, workflow_dispatch
- **Jobs:** Single "Run Pester Tests" job
- **Steps:**
  1. Checkout code
  2. Verify test file exists
  3. Run Pester tests with Detailed output
  4. Test cleanup plan generation
  5. Test dry-run mode
  6. Test summary generation

- **Container:** `ghcr.io/catthehacker/ubuntu:full-latest` (includes pwsh/Pester)
- **Shell:** PowerShell (`shell: pwsh`)

### Testing with `act`

Validate the workflow locally:

```bash
# Run workflow via act
act push --rm

# View results in act-result.txt
cat act-result.txt
```

**Result:** Job succeeded with all steps passing ✓

## Implementation Notes

### Design Decisions

1. **Policy Application Order**
   - Max age policy applied first
   - Keep-latest-N policy applied to remaining artifacts
   - Max total size policy applied last to enforce hard limit

2. **Retention Logic**
   - Artifacts are sorted by creation date (oldest first) for deletion
   - Multiple policies can trigger deletion; artifact only marked once
   - Space calculation accounts for null/empty artifact sets

3. **Error Handling**
   - Graceful handling of empty artifact lists
   - Proper calculation of space reclaimed even with no deletions
   - Meaningful error messages in workflow steps

### Code Quality

- Clear function documentation with examples
- No unnecessary comments (code is self-documenting)
- Consistent PowerShell naming conventions
- TDD methodology applied throughout

## Validation

### Workflow Validation

```bash
actionlint .github/workflows/artifact-cleanup-script.yml
# Result: Validation passed (no errors)
```

### Test Execution

- **Local tests:** 8/8 passing
- **GitHub Actions (via act):** All steps passing
- **Job status:** Succeeded

## Future Enhancements

Potential improvements for future versions:
- Support for additional metadata (author, tags)
- Custom retention policy combinations
- Artifact move/archive instead of delete
- Metrics and monitoring integration
- Parallel deletion for large artifact sets
