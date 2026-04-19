# Artifact Cleanup Script

A Python-based artifact retention management tool with dry-run support, retention policies, and comprehensive testing via GitHub Actions.

## Overview

This solution implements a production-ready artifact cleanup system that:
- Applies multiple retention policies (max age, max total size, keep-latest-N)
- Generates detailed deletion plans with space reclamation summaries
- Supports dry-run mode for safe planning
- Is fully tested with 11 passing unit tests
- Runs in GitHub Actions CI/CD pipeline via `act`

## Architecture

### Core Components

**`artifact_cleanup.py`** — Core logic
- `Artifact` — Data class representing artifact metadata
- `RetentionPolicy` — Configuration for retention rules
- `DeletionPlan` — Plan with keep/delete lists and summaries
- `ArtifactCleaner` — Main engine applying policies

**`cleanup.py`** — CLI tool
- Reads artifact metadata from JSON
- Applies policies
- Generates JSON output with deletion plan
- Supports dry-run and execute modes

**`test_artifact_cleanup.py`** — 11 comprehensive tests using pytest
- Tests data structures, policies, deletion logic
- Tests edge cases (empty lists, multi-workflow scenarios)
- All tests pass

**`fixtures.py`** — Test fixture generator
- Creates test JSON files with various scenarios

### Retention Policies

The script applies three policies in order:

1. **Max Age** — Delete artifacts older than N days
2. **Keep Latest N** — Per workflow, keep only the N newest artifacts
3. **Total Size Limit** — If total size exceeds limit, delete oldest artifacts

## Running Tests

### Unit Tests (Local)
```bash
python3 -m pytest test_artifact_cleanup.py -v
```

All 11 tests pass:
- Artifact creation
- Retention policy configuration
- Age-based deletion
- Max total size enforcement
- Keep-latest-N per workflow (independently)
- Deletion plan summaries
- Dry-run mode
- Multiple workflows
- Empty/edge cases

### Integration Tests via GitHub Actions
```bash
# Generate fixtures
python3 fixtures.py

# Run workflow with act
act push --rm -j test

# Validates actionlint
actionlint .github/workflows/artifact-cleanup-script.yml
```

## CLI Usage

```bash
python3 cleanup.py --artifacts artifacts.json \
  --max-age-days 30 \
  --max-total-size 1000000000 \
  --keep-latest-n 5 \
  --dry-run \
  --output plan.json
```

### Arguments
- `--artifacts` (required) — JSON file with artifact metadata
- `--max-age-days` — Delete artifacts older than this (default: 30)
- `--max-total-size` — Delete oldest if total exceeds this (default: 1GB)
- `--keep-latest-n` — Keep this many per workflow (default: 5)
- `--dry-run` — Run without deleting (default: true)
- `--execute` — Override dry-run, actually delete
- `--output` — Save plan to JSON file

### Input Format
```json
{
  "artifacts": [
    {
      "name": "build-123.zip",
      "size_bytes": 5000000,
      "created_at": "2026-04-01T10:30:00",
      "workflow_run_id": "run-456"
    }
  ]
}
```

### Output Format
```json
{
  "dry_run": true,
  "summary": {
    "artifacts_to_delete": 5,
    "artifacts_to_keep": 10,
    "space_reclaimed_bytes": 25000000
  },
  "to_delete": [...],
  "to_keep": [...]
}
```

## GitHub Actions Workflow

**Location:** `.github/workflows/artifact-cleanup-script.yml`

**Triggers:**
- `push` to main/master branches
- `pull_request` against main/master
- `workflow_dispatch` (manual)
- `schedule` (daily at 2 AM UTC)

**Jobs:**
1. Checkout code
2. Set up Python 3.12
3. Install pytest
4. Run 11 unit tests (all pass)
5. Generate test fixtures (3 scenarios)
6. Run test case 1 (age-based deletion)
7. Run test case 2 (multi-workflow independent handling)
8. Run test case 3 (total size enforcement)
9. Verify dry-run mode
10. Create summary

**Validation:**
- All jobs show "✅ Success"
- Tests validated with assertions on exact output
- Job summary in GitHub Step Summary

## Test Cases

### Test Case 1: Age-Based Deletion
- Input: 3 artifacts (one 31 days old)
- Expected: Delete 1, keep 2
- Status: ✅ Passed

### Test Case 2: Multiple Workflows
- Input: 5 artifacts across 2 workflows
- Policy: Keep 2 per workflow
- Expected: Delete 1 (workflow-1's oldest), keep 4
- Status: ✅ Passed

### Test Case 3: Total Size Enforcement
- Input: 3 artifacts (6KB total), 5KB limit
- Expected: Delete oldest until ≤5KB
- Status: ✅ Passed

## Development Notes

### TDD Approach
- Started with failing tests
- Implemented minimal code to pass
- Refactored for clarity
- All tests pass at end of each iteration

### Design Decisions
- Used index-based tracking instead of sets (Artifact dataclass not hashable)
- Applied policies sequentially (age → keep-latest-N → total size)
- Dry-run mode is default (safe by default)
- JSON input/output for pipeline integration

### Error Handling
- Graceful error messages with meaningful context
- Validates JSON format on input
- Exits with code 0 on success

## Files

- `artifact_cleanup.py` — Core module
- `cleanup.py` — CLI tool
- `test_artifact_cleanup.py` — 11 unit tests
- `fixtures.py` — Test fixture generator
- `validate_workflow.py` — Workflow structure validator
- `.github/workflows/artifact-cleanup-script.yml` — GitHub Actions workflow
- `act-result.txt` — Complete test run output via `act`
- `README.md` — This file

## Future Enhancements

- Config file support (YAML/TOML)
- Artifact storage backend integration (S3, Azure Blob, etc.)
- Scheduling via cron
- Slack/email notifications on deletion
- Metrics export (Prometheus format)

## License

MIT (or project default)
