"""
Generate test fixture JSON files with dates relative to today.
Run this before executing artifact_cleanup.py in CI so fixture dates
stay valid regardless of when the workflow runs.
"""
import json
import os
from datetime import datetime, timezone, timedelta


def days_ago(n: int) -> str:
    """Return an ISO-8601 UTC timestamp for N days ago."""
    dt = datetime.now(timezone.utc) - timedelta(days=n)
    return dt.isoformat()


MB = 1024 * 1024


def main():
    os.makedirs("fixtures", exist_ok=True)

    # TC1: age-policy — 2 artifacts >30 days old, 2 recent
    # Expected: delete 2 (10MB+20MB=30MB), keep 2
    tc1 = [
        {"name": "old-artifact-1", "size": 10 * MB, "created_at": days_ago(45), "workflow_run_id": "run-1"},
        {"name": "old-artifact-2", "size": 20 * MB, "created_at": days_ago(31), "workflow_run_id": "run-2"},
        {"name": "new-artifact-1", "size": 15 * MB, "created_at": days_ago(10), "workflow_run_id": "run-3"},
        {"name": "new-artifact-2", "size": 5 * MB,  "created_at": days_ago(1),  "workflow_run_id": "run-4"},
    ]
    with open("fixtures/tc1_age_policy.json", "w") as f:
        json.dump(tc1, f, indent=2)

    # TC2: keep-latest-2 — workflow-A has 4 (delete 2 oldest), workflow-B has 1 (keep)
    # Expected: delete 2 (a-oldest + a-old), keep 3
    tc2 = [
        {"name": "a-oldest", "size": 5 * MB,  "created_at": days_ago(20), "workflow_run_id": "workflow-A"},
        {"name": "a-old",    "size": 5 * MB,  "created_at": days_ago(15), "workflow_run_id": "workflow-A"},
        {"name": "a-recent", "size": 5 * MB,  "created_at": days_ago(5),  "workflow_run_id": "workflow-A"},
        {"name": "a-newest", "size": 5 * MB,  "created_at": days_ago(1),  "workflow_run_id": "workflow-A"},
        {"name": "b-only",   "size": 10 * MB, "created_at": days_ago(10), "workflow_run_id": "workflow-B"},
    ]
    with open("fixtures/tc2_keep_latest.json", "w") as f:
        json.dump(tc2, f, indent=2)

    # TC3: max-size 150MB — total=280MB, delete oldest until <=150MB
    # 100+80=180MB deleted, 60+40=100MB kept  → delete 2, keep 2
    tc3 = [
        {"name": "big-oldest",   "size": 100 * MB, "created_at": days_ago(30), "workflow_run_id": "run-1"},
        {"name": "big-old",      "size": 80 * MB,  "created_at": days_ago(20), "workflow_run_id": "run-2"},
        {"name": "med-recent",   "size": 60 * MB,  "created_at": days_ago(10), "workflow_run_id": "run-3"},
        {"name": "small-newest", "size": 40 * MB,  "created_at": days_ago(1),  "workflow_run_id": "run-4"},
    ]
    with open("fixtures/tc3_max_size.json", "w") as f:
        json.dump(tc3, f, indent=2)

    # TC4: combined — max_age_days=30 + keep_latest_n=2
    # workflow-A: a-old-1(40d), a-old-2(35d) deleted by age;
    #             after age removal 3 remain: a-new-1(5d), a-new-2(2d), a-new-3(1d)
    #             keep-2 removes the oldest survivor: a-new-1
    # Expected: delete 3 (a-old-1, a-old-2, a-new-1), keep 2
    tc4 = [
        {"name": "a-old-1", "size": 10 * MB, "created_at": days_ago(40), "workflow_run_id": "wf-A"},
        {"name": "a-old-2", "size": 10 * MB, "created_at": days_ago(35), "workflow_run_id": "wf-A"},
        {"name": "a-new-1", "size": 10 * MB, "created_at": days_ago(5),  "workflow_run_id": "wf-A"},
        {"name": "a-new-2", "size": 10 * MB, "created_at": days_ago(2),  "workflow_run_id": "wf-A"},
        {"name": "a-new-3", "size": 10 * MB, "created_at": days_ago(1),  "workflow_run_id": "wf-A"},
    ]
    with open("fixtures/tc4_combined.json", "w") as f:
        json.dump(tc4, f, indent=2)

    print("Fixtures generated successfully.")
    # Print expected values for reference
    print("TC1 expected: ARTIFACTS_TO_DELETE=2, SPACE_RECLAIMED_BYTES=31457280")
    print("TC2 expected: ARTIFACTS_TO_DELETE=2, ARTIFACTS_TO_KEEP=3")
    print("TC3 expected: ARTIFACTS_TO_DELETE=2, ARTIFACTS_TO_KEEP=2")
    print("TC4 expected: ARTIFACTS_TO_DELETE=3, ARTIFACTS_TO_KEEP=2")


if __name__ == "__main__":
    main()
