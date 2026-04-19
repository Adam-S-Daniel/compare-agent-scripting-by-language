# Artifact Cleanup Script - PowerShell Solution

## Summary

This solution implements a PowerShell artifact cleanup script with retention policies, comprehensive Pester tests, and a GitHub Actions workflow that runs successfully through `act`.

## Files Created

### 1. Remove-Artifacts.ps1
Main script implementing artifact cleanup functionality:
- **Get-DeletionPlan**: Analyzes artifacts against retention policies and creates a deletion plan
- **Invoke-CleanupPlan**: Executes the plan with dry-run support
- **Format-DeletionSummary**: Formats results for display

#### Features
- **Max Age Policy**: Deletes artifacts older than specified days
- **Max Total Size Policy**: Keeps newest artifacts until total size is below limit (in MB)
- **Keep Latest N Per Workflow**: Retains only N most recent artifacts per workflow run
- **Dry Run Mode**: Preview deletions without making changes
- **Error Handling**: Validates all inputs and provides meaningful error messages

### 2. Remove-Artifacts.tests.ps1
Pester test suite with 12 comprehensive tests:
- Empty artifact list handling
- Max age policy verification
- Max total size policy verification
- Keep latest N per workflow functionality
- Space reclamation calculations
- Dry run mode behavior
- Error validation for negative/invalid inputs

**Test Results**: All 12 tests passing ✓

### 3. .github/workflows/artifact-cleanup-script.yml
GitHub Actions workflow with multiple jobs:
- **Validate Workflow**: Runs actionlint to validate workflow YAML
- **Verify Script Files**: Confirms all required script files exist
- **Run Pester Tests**: Executes all 12 Pester tests using `shell: pwsh`
- **Test Summary**: Reports overall job status

**Workflow Validation**: Passes actionlint ✓
**Act Execution**: All jobs succeed ✓

### 4. act-result.txt
Complete output from act execution showing:
- All 4 jobs succeeded
- All 12 tests passed (0 failed)
- Workflow validation successful

## Design Approach

### TDD Methodology
1. Started with failing Pester tests defining expected behavior
2. Implemented minimum code to make tests pass
3. Refactored for clarity and maintainability

### Key Implementation Details
- **Size Units**: Artifacts sizes in KB, conversions to MB for policy enforcement
- **Sorting**: Newest artifacts prioritized for retention
- **Validation**: Comprehensive input validation with meaningful error messages
- **Dry Run**: Complete support for preview mode without side effects

## Verification

✓ All 12 Pester tests pass locally
✓ All 12 Pester tests pass through GitHub Actions workflow
✓ Workflow passes actionlint validation
✓ Workflow executes successfully with `act`
✓ All jobs show "Job succeeded"
✓ act-result.txt created with full output
