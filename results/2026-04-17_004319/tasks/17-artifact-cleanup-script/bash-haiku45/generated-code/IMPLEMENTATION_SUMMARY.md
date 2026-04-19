# Artifact Cleanup Script - Implementation Summary

## Overview
A complete Bash-based artifact retention policy engine with GitHub Actions integration, developed using red/green TDD methodology.

## Files Created

### Main Script
- **artifact-cleanup.sh** - Core cleanup script with:
  - Retention policy filtering (max-age, max-size, keep-latest-N)
  - Dry-run mode support
  - JSON-based artifact processing
  - Detailed cleanup plan generation with size calculations
  - Error handling and validation

### Testing
- **artifact-cleanup.bats** - Comprehensive test suite with 10 tests:
  1. Parse artifacts JSON with metadata
  2. Calculate artifact age in days
  3. Filter artifacts by age (max-age policy)
  4. Support dry-run mode
  5. Generate summary with space calculations
  6. Filter by total size (max-size policy)
  7. Keep latest N per workflow (keep-latest policy)
  8. Apply all policies combined
  9. Handle empty artifact lists
  10. Error on missing input files

### GitHub Actions Workflow
- **.github/workflows/artifact-cleanup-script.yml** - Full CI/CD pipeline with:
  - Triggers: push, pull_request, schedule, workflow_dispatch
  - Dependency installation (bats, jq, shellcheck)
  - Script syntax validation
  - Shellcheck linting
  - Comprehensive test execution
  - Test plan generation with sample data
  - Output captured to act-result.txt

## Test Results

All tests pass both locally and through GitHub Actions:
- ✅ 10/10 unit tests passing
- ✅ Bash syntax validation passing
- ✅ Shellcheck validation passing
- ✅ actionlint workflow validation passing
- ✅ Act/Docker execution successful

## Key Features

### Retention Policies
1. **Max Age**: Remove artifacts older than specified days
2. **Max Size**: Keep total artifacts under size limit (newest first)
3. **Keep Latest**: Maintain latest N artifacts per workflow run

### Output
- JSON-based deletion plan with detailed breakdown
- Human-readable summary with size formatting
- Dry-run mode for safe preview before deletion
- Graceful error handling with meaningful messages

### Validation
- Compliant with shellcheck best practices
- Valid Bash syntax (bash -n)
- GitHub Actions actionlint compatible
- Works in isolated Docker containers via act
- No external service dependencies

## Usage

### Local Testing
```bash
# Run all tests
bats artifact-cleanup.bats

# Test specific functionality
bats artifact-cleanup.bats -f "dry-run"
```

### Script Usage
```bash
# Generate cleanup plan (dry-run)
./artifact-cleanup.sh artifacts.json \
  --max-age 30 \
  --max-size 10240 \
  --keep-latest 10 \
  --dry-run

# Parse and summarize
source artifact-cleanup.sh
plan=$(cleanup_artifacts artifacts.json --max-age 30)
summary=$(generate_summary <(echo "$plan"))
```

### GitHub Actions Execution
- Automatically triggers on push/PR
- Can be triggered manually via workflow_dispatch
- Scheduled runs supported (cron)
- All output logged to act-result.txt

## Artifact Output
- **act-result.txt** - Complete workflow execution log with:
  - Syntax validation results
  - Shellcheck linting output
  - All 10 test results (pass/fail)
  - Example cleanup plan generation
  - Job status and completion message

## Architecture Notes

### TDD Methodology
- Started with failing tests
- Implemented minimum code to pass
- Refactored for clarity and efficiency
- Added comprehensive edge case coverage

### Function Decomposition
- `calculate_age()` - Date arithmetic
- `parse_artifacts()` - JSON loading
- `filter_by_age()` - Age-based filtering
- `filter_by_size()` - Size-based filtering with sorting
- `filter_by_latest()` - Workflow-grouped filtering
- `apply_all_policies()` - Combined policy application
- `generate_summary()` - Human-readable reporting

### Error Handling
- Validates input file existence
- Handles empty artifact arrays
- Returns meaningful error messages
- Non-zero exit codes on failures

## Technology Stack
- **Language**: Bash (POSIX compatible)
- **Testing**: bats-core (TAP format)
- **JSON Processing**: jq
- **Linting**: shellcheck
- **CI/CD**: GitHub Actions
- **Local Testing**: act (nektos/act)

## Requirements Satisfied
✅ Red/green TDD methodology with failing tests first
✅ bats-core testing framework
✅ All tests passing (10/10)
✅ Clear implementation approach comments
✅ Graceful error handling
✅ #!/usr/bin/env bash shebang
✅ shellcheck validation
✅ bash -n syntax validation
✅ GitHub Actions workflow with proper triggers
✅ actionlint validation passing
✅ Act local execution successful
✅ act-result.txt artifact generated
✅ Test output capture and verification
✅ Job success status verification
