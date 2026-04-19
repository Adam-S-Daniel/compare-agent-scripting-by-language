"""Test fixtures for cleanup scenarios."""
import json
from datetime import datetime, timedelta


def create_test_case_1():
    """
    Test case 1: Basic cleanup by age.
    3 artifacts, 1 too old.
    """
    now = datetime.now()
    return {
        "artifacts": [
            {
                "name": "build-old.zip",
                "size_bytes": 5000,
                "created_at": (now - timedelta(days=31)).isoformat(),
                "workflow_run_id": "run-1",
            },
            {
                "name": "build-recent.zip",
                "size_bytes": 5000,
                "created_at": (now - timedelta(days=15)).isoformat(),
                "workflow_run_id": "run-1",
            },
            {
                "name": "build-newest.zip",
                "size_bytes": 5000,
                "created_at": now.isoformat(),
                "workflow_run_id": "run-1",
            },
        ]
    }


def create_test_case_2():
    """
    Test case 2: Multiple workflows.
    Keep latest 2 per workflow independently.
    """
    now = datetime.now()
    return {
        "artifacts": [
            {
                "name": "wf1-build-1.zip",
                "size_bytes": 1000,
                "created_at": (now - timedelta(days=4)).isoformat(),
                "workflow_run_id": "workflow-1",
            },
            {
                "name": "wf1-build-2.zip",
                "size_bytes": 1000,
                "created_at": (now - timedelta(days=3)).isoformat(),
                "workflow_run_id": "workflow-1",
            },
            {
                "name": "wf1-build-3.zip",
                "size_bytes": 1000,
                "created_at": (now - timedelta(days=2)).isoformat(),
                "workflow_run_id": "workflow-1",
            },
            {
                "name": "wf2-build-1.zip",
                "size_bytes": 1000,
                "created_at": (now - timedelta(days=3)).isoformat(),
                "workflow_run_id": "workflow-2",
            },
            {
                "name": "wf2-build-2.zip",
                "size_bytes": 1000,
                "created_at": (now - timedelta(days=1)).isoformat(),
                "workflow_run_id": "workflow-2",
            },
        ]
    }


def create_test_case_3():
    """
    Test case 3: Total size exceeded.
    5KB limit, 6KB total, should delete oldest.
    """
    now = datetime.now()
    return {
        "artifacts": [
            {
                "name": "build-1.zip",
                "size_bytes": 2000,
                "created_at": (now - timedelta(days=10)).isoformat(),
                "workflow_run_id": "run-1",
            },
            {
                "name": "build-2.zip",
                "size_bytes": 2000,
                "created_at": (now - timedelta(days=5)).isoformat(),
                "workflow_run_id": "run-1",
            },
            {
                "name": "build-3.zip",
                "size_bytes": 2000,
                "created_at": now.isoformat(),
                "workflow_run_id": "run-1",
            },
        ]
    }


def save_fixture(name: str, data: dict):
    """Save fixture to JSON file."""
    filename = f"fixtures/test_case_{name}.json"
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)


if __name__ == '__main__':
    import os
    os.makedirs('fixtures', exist_ok=True)

    save_fixture('1_basic_age', create_test_case_1())
    save_fixture('2_multiple_workflows', create_test_case_2())
    save_fixture('3_size_exceeded', create_test_case_3())

    print("✓ Test fixtures created")
