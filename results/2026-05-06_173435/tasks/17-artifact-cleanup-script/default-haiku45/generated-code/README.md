# Artifact Cleanup Script

A production-ready Python script for managing build artifact retention policies in CI/CD environments.

## Overview

This project implements a sophisticated artifact lifecycle management system using **Red/Green TDD methodology**. The script evaluates build artifacts against configurable retention policies and generates detailed deletion plans.

### Features

- **Three Retention Policies** that work together:
  1. **Max Age**: Delete artifacts older than N days
  2. **Keep Latest N**: Retain only the latest N artifacts per workflow run
  3. **Max Size**: Enforce maximum total storage with oldest-first deletion
  
- **Dry-Run Mode**: Plan deletions without actually deleting files
- **JSON Output**: Structured metrics for integration with other tools
- **Comprehensive Tests**: 10 unit tests + 4 integration tests (all passing)
- **GitHub Actions Ready**: Full CI/CD pipeline with actionlint validation

## Quick Start

### Run Unit Tests

```bash
python3 -m pytest tests/test_artifact_cleanup.py -v
```

### Use the CLI

```bash
# Generate test fixtures
python3 test_fixtures.py

# Run cleanup analysis
python3 cleanup_cli.py \
  --artifacts test_data/fixture_simple.json \
  --max-age 30 \
  --max-size 1024 \
  --keep-latest 5 \
  --dry-run
```

### Run via GitHub Actions

```bash
# Validate workflow
actionlint .github/workflows/artifact-cleanup-script.yml

# Run locally with act
act push --rm
```

## Project Structure

```
.
├── artifact_cleanup.py              # Core logic (data models + algorithms)
├── cleanup_cli.py                   # Command-line interface
├── test_fixtures.py                 # Test data generator
├── tests/
│   └── test_artifact_cleanup.py    # 10 comprehensive unit tests
├── .github/workflows/
│   └── artifact-cleanup-script.yml # GitHub Actions workflow
├── test_data/                       # Generated test fixtures
├── act-result.txt                   # Workflow execution results
└── README.md                        # This file
```

## Architecture

### Core Module: `artifact_cleanup.py`

**Data Models:**
- `Artifact`: Represents a build artifact with metadata
- `RetentionPolicy`: Configuration for retention constraints
- `DeletionPlan`: Output with deletion decisions and metrics

**Main Algorithm:**
- `ArtifactCleanup`: Applies retention policies in order

### CLI Tool: `cleanup_cli.py`

Provides command-line interface for artifact analysis:
- Load artifacts from JSON
- Accept policy parameters
- Support dry-run mode
- Output results as JSON or text

### Test Fixtures: `test_fixtures.py`

Generates realistic test data for four scenarios:
1. **Simple**: Age-based deletion (3 artifacts)
2. **Keep Latest**: Keep N per run ID (5 artifacts)
3. **Size Limit**: Total size enforcement (3 artifacts)
4. **Combined**: All policies together (6 artifacts)

## Test Coverage

### Unit Tests (10 tests)
- ✅ Artifact model creation
- ✅ Retention policy validation
- ✅ Policy application (age, keep-latest, size)
- ✅ Deletion plan metrics
- ✅ Dry-run mode
- ✅ Error handling

### Integration Tests (4 tests)
- ✅ Age-based deletion with CLI
- ✅ Keep-latest enforcement per run ID
- ✅ Total size limit enforcement
- ✅ Combined policies in one analysis

## TDD Methodology

This project was built following **Red/Green TDD**:

1. **Red Phase**: Write failing tests that define expected behavior
2. **Green Phase**: Implement minimum code to make tests pass
3. **Refactor Phase**: Improve code quality while maintaining test coverage

### Example: Age-Based Deletion Test

```python
def test_delete_by_age(self):
    """FAILING TEST: Should delete artifacts older than max_age_days."""
    policy = RetentionPolicy(
        max_age_days=30,
        max_total_size_bytes=float('inf'),
        keep_latest_n=float('inf')
    )
    cleanup = ArtifactCleanup(artifacts, policy)
    plan = cleanup.generate_plan()
    
    # Verify old artifact was marked for deletion
    deleted_names = [a.name for a in plan.artifacts_to_delete]
    self.assertIn("db-run-1.sql", deleted_names)
```

## Retention Policy Algorithm

Policies are applied in this order:

```
Input: Artifacts + Policy
  ↓
1. Delete by age (max_age_days)
  ↓
2. Keep latest N per run ID (keep_latest_n)
  ↓
3. Enforce size limit, delete oldest first (max_total_size_bytes)
  ↓
Output: DeletionPlan with metrics
```

## JSON Input Format

```json
[
  {
    "name": "build-output.zip",
    "size_bytes": 1048576,
    "created_at": "2026-05-01T12:00:00",
    "workflow_run_id": "run-123"
  },
  ...
]
```

## JSON Output Format

```json
{
  "dry_run": true,
  "summary": {
    "total_artifacts": 10,
    "artifacts_to_delete": 3,
    "artifacts_to_retain": 7,
    "space_reclaimed_bytes": 3145728,
    "space_reclaimed_mb": 3.0,
    "retained_size_bytes": 7340032
  },
  "artifacts_to_delete": [...],
  "artifacts_to_retain": [...]
}
```

## Error Handling

The script handles errors gracefully:

- **ValueError**: Invalid policy parameters (negative values)
- **FileNotFoundError**: Missing input JSON file
- **JSONDecodeError**: Malformed JSON input
- **IOError**: Cannot write output file

All errors include meaningful messages for debugging.

## GitHub Actions Integration

The workflow (`artifact-cleanup-script.yml`):
- Triggers on: `push`, `pull_request`, `workflow_dispatch`
- Runs on: `ubuntu-latest`
- Steps:
  1. Checkout code
  2. Setup Python 3.12
  3. Install pytest
  4. Generate test fixtures
  5. Run unit tests
  6. Execute CLI with 4 test cases
  7. Validate results
  8. Generate act-result.txt

## Running Tests

### Local Testing
```bash
# Run all tests
python3 -m pytest tests/ -v

# Run specific test class
python3 -m pytest tests/test_artifact_cleanup.py::TestArtifactCleanup -v

# Run with coverage
python3 -m pytest tests/ --cov=artifact_cleanup
```

### CI/CD Testing
```bash
# Validate workflow syntax
actionlint .github/workflows/artifact-cleanup-script.yml

# Run in Docker container (requires act and Docker)
act push --rm
```

## Test Results

All 14 tests pass successfully:

```
✅ 10 unit tests (pytest)
✅ 4 CLI integration tests (fixtures)
✅ Workflow validation (actionlint)
✅ Docker container execution (act)

Exit Code: 0
Status: 🏁 Job succeeded
```

See `act-result.txt` for complete workflow execution details.

## Performance

- Unit tests: 70ms
- Each CLI test case: 600-800ms
- Total workflow execution: ~15 seconds

## Future Enhancements

Possible extensions:
- Delete actual files (not just plan generation)
- Database backend for artifact metadata
- Web API for remote artifact analysis
- Webhook integration for automated cleanup
- Metrics export to monitoring systems

## License

This project is part of the agent scripting benchmark suite.
