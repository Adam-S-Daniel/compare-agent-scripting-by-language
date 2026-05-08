"""
Generate test fixture data for GitHub Actions workflow.

Creates JSON files with artifact metadata for different test scenarios.
"""
import json
from datetime import datetime, timedelta
from pathlib import Path


def generate_fixture_simple():
    """
    Simple fixture: 3 artifacts from same run, delete the oldest by age.

    Policy: max_age=20 days, max_size=5 MB, keep_latest=3
    Expected: Delete oldest (25 days old), keep 2 recent ones.
    """
    now = datetime.now()
    artifacts = [
        {
            "name": "app-v1.0.tar.gz",
            "size_bytes": 512 * 1024,
            "created_at": (now - timedelta(days=25)).isoformat(),
            "workflow_run_id": "run-001"
        },
        {
            "name": "app-v1.1.tar.gz",
            "size_bytes": 512 * 1024,
            "created_at": (now - timedelta(days=10)).isoformat(),
            "workflow_run_id": "run-001"
        },
        {
            "name": "app-v1.2.tar.gz",
            "size_bytes": 512 * 1024,
            "created_at": (now - timedelta(days=2)).isoformat(),
            "workflow_run_id": "run-001"
        },
    ]
    return {
        "name": "simple",
        "description": "Delete by age policy",
        "policy": {
            "max_age_days": 20,
            "max_total_size_mb": 5,
            "keep_latest_n": 3
        },
        "expected_deletes": 1,
        "expected_keep": 2,
        "artifacts": artifacts
    }


def generate_fixture_keep_latest():
    """
    Keep latest N fixture: 5 artifacts, keep only 2 latest per run.

    Policy: max_age=inf, max_size=inf, keep_latest=2
    Expected: Delete 1 artifact per run ID.
    """
    now = datetime.now()
    artifacts = [
        {
            "name": "build-run1-v1.tar",
            "size_bytes": 1024 * 1024,
            "created_at": (now - timedelta(days=30)).isoformat(),
            "workflow_run_id": "build-001"
        },
        {
            "name": "build-run1-v2.tar",
            "size_bytes": 1024 * 1024,
            "created_at": (now - timedelta(days=20)).isoformat(),
            "workflow_run_id": "build-001"
        },
        {
            "name": "build-run1-v3.tar",
            "size_bytes": 1024 * 1024,
            "created_at": (now - timedelta(days=10)).isoformat(),
            "workflow_run_id": "build-001"
        },
        {
            "name": "test-run1-v1.tar",
            "size_bytes": 2048 * 1024,
            "created_at": (now - timedelta(days=25)).isoformat(),
            "workflow_run_id": "test-001"
        },
        {
            "name": "test-run1-v2.tar",
            "size_bytes": 2048 * 1024,
            "created_at": (now - timedelta(days=5)).isoformat(),
            "workflow_run_id": "test-001"
        },
    ]
    return {
        "name": "keep_latest",
        "description": "Keep latest N per workflow run",
        "policy": {
            "max_age_days": float('inf'),
            "max_total_size_mb": float('inf'),
            "keep_latest_n": 2
        },
        "expected_deletes": 2,
        "expected_keep": 3,
        "artifacts": artifacts
    }


def generate_fixture_size_limit():
    """
    Size limit fixture: Total size 6 MB, limit to 4 MB.

    Policy: max_age=inf, max_size=4 MB, keep_latest=inf
    Expected: Delete oldest artifacts until under 4 MB.
    """
    now = datetime.now()
    artifacts = [
        {
            "name": "archive-old.zip",
            "size_bytes": 2 * 1024 * 1024,
            "created_at": (now - timedelta(days=50)).isoformat(),
            "workflow_run_id": "archive-001"
        },
        {
            "name": "archive-med.zip",
            "size_bytes": 2 * 1024 * 1024,
            "created_at": (now - timedelta(days=20)).isoformat(),
            "workflow_run_id": "archive-001"
        },
        {
            "name": "archive-new.zip",
            "size_bytes": 2 * 1024 * 1024,
            "created_at": (now - timedelta(days=2)).isoformat(),
            "workflow_run_id": "archive-001"
        },
    ]
    return {
        "name": "size_limit",
        "description": "Enforce maximum total size limit",
        "policy": {
            "max_age_days": float('inf'),
            "max_total_size_mb": 4,
            "keep_latest_n": float('inf')
        },
        "expected_deletes": 1,
        "expected_keep": 2,
        "artifacts": artifacts
    }


def generate_fixture_combined():
    """
    Combined policies fixture: Apply age + size + keep_latest together.

    Tests interaction of all three policies.
    """
    now = datetime.now()
    artifacts = [
        {
            "name": "old-expired.tar",
            "size_bytes": 500 * 1024,
            "created_at": (now - timedelta(days=100)).isoformat(),
            "workflow_run_id": "job-001"
        },
        {
            "name": "job1-v1.tar",
            "size_bytes": 1000 * 1024,
            "created_at": (now - timedelta(days=40)).isoformat(),
            "workflow_run_id": "job-001"
        },
        {
            "name": "job1-v2.tar",
            "size_bytes": 1000 * 1024,
            "created_at": (now - timedelta(days=25)).isoformat(),
            "workflow_run_id": "job-001"
        },
        {
            "name": "job1-v3.tar",
            "size_bytes": 1000 * 1024,
            "created_at": (now - timedelta(days=5)).isoformat(),
            "workflow_run_id": "job-001"
        },
        {
            "name": "job2-v1.tar",
            "size_bytes": 1500 * 1024,
            "created_at": (now - timedelta(days=15)).isoformat(),
            "workflow_run_id": "job-002"
        },
        {
            "name": "job2-v2.tar",
            "size_bytes": 1500 * 1024,
            "created_at": (now - timedelta(days=1)).isoformat(),
            "workflow_run_id": "job-002"
        },
    ]
    return {
        "name": "combined",
        "description": "Combined age + size + keep_latest policies",
        "policy": {
            "max_age_days": 30,
            "max_total_size_mb": 5,
            "keep_latest_n": 2
        },
        "expected_deletes": 3,
        "expected_keep": 3,
        "artifacts": artifacts
    }


def generate_all_fixtures():
    """Generate all test fixtures."""
    return [
        generate_fixture_simple(),
        generate_fixture_keep_latest(),
        generate_fixture_size_limit(),
        generate_fixture_combined(),
    ]


def save_fixtures(output_dir: str = "test_data"):
    """Save fixtures to disk as JSON files."""
    Path(output_dir).mkdir(exist_ok=True)

    fixtures = generate_all_fixtures()
    fixture_files = {}

    for fixture in fixtures:
        filename = f"{output_dir}/fixture_{fixture['name']}.json"
        # Save only the artifacts array, not metadata
        with open(filename, 'w') as f:
            json.dump(fixture['artifacts'], f, indent=2)

        fixture_files[fixture['name']] = {
            'file': filename,
            'policy': fixture['policy'],
            'expected_deletes': fixture['expected_deletes'],
            'expected_keep': fixture['expected_keep'],
            'description': fixture['description']
        }

    # Save metadata separately
    with open(f"{output_dir}/fixtures_metadata.json", 'w') as f:
        json.dump(fixture_files, f, indent=2)

    print(f"Saved {len(fixtures)} fixtures to {output_dir}/")
    return fixture_files


if __name__ == '__main__':
    save_fixtures()
