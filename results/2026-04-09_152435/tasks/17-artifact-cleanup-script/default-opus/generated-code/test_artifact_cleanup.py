#!/usr/bin/env python3
"""
Tests for artifact cleanup script — TDD style.

Each test was written as a failing test first, then the implementation
was written to make it pass. Tests cover:
  1. Parsing and validation
  2. Max age policy
  3. Keep-latest-N policy
  4. Max total size policy
  5. Combined policies
  6. Empty input
  7. Dry-run vs live mode
  8. Error handling
"""

import json
import subprocess
import sys
from datetime import datetime, timezone

from artifact_cleanup import (
    apply_keep_latest_n_policy,
    apply_max_age_policy,
    apply_max_total_size_policy,
    generate_deletion_plan,
    parse_artifacts,
)
from test_fixtures import (
    BASIC_ARTIFACTS,
    COMBINED_CONFIG,
    DRY_RUN_CONFIG,
    EMPTY_CONFIG,
    INVALID_MISSING_FIELD,
    KEEP_LATEST_CONFIG,
    MAX_AGE_CONFIG,
    MAX_SIZE_CONFIG,
    NOW_ISO,
)

NOW = datetime.fromisoformat(NOW_ISO)


# --- Test 1: Parse valid artifacts ---
def test_parse_valid_artifacts():
    """RED: parse_artifacts should return structured list from raw dicts."""
    result = parse_artifacts(BASIC_ARTIFACTS)
    assert len(result) == 7
    assert result[0]["name"] == "build-linux-latest"
    assert result[0]["size_mb"] == 50.0
    assert isinstance(result[0]["created_at"], datetime)
    assert result[0]["workflow_run_id"] == "wf-100"
    print("PASS: test_parse_valid_artifacts")


# --- Test 2: Parse rejects missing fields ---
def test_parse_rejects_missing_fields():
    """RED: parse_artifacts should raise ValueError for missing required fields."""
    try:
        parse_artifacts([{"name": "broken"}])
        assert False, "Should have raised ValueError"
    except ValueError as e:
        assert "missing fields" in str(e).lower()
    print("PASS: test_parse_rejects_missing_fields")


# --- Test 3: Parse rejects negative size ---
def test_parse_rejects_negative_size():
    """RED: parse_artifacts should reject artifacts with negative size."""
    bad = [{
        "name": "neg", "size_mb": -5, "created_at": "2026-04-01T00:00:00+00:00",
        "workflow_run_id": "wf-1"
    }]
    try:
        parse_artifacts(bad)
        assert False, "Should have raised ValueError"
    except ValueError as e:
        assert "negative" in str(e).lower()
    print("PASS: test_parse_rejects_negative_size")


# --- Test 4: Max age policy ---
def test_max_age_policy():
    """RED: artifacts older than max_age_days should be marked for deletion."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS)
    to_delete = apply_max_age_policy(artifacts, max_age_days=30, now=NOW)
    # Only test-results-ancient (40 days old) should be deleted
    assert to_delete == {"test-results-ancient"}, f"Got: {to_delete}"
    print("PASS: test_max_age_policy")


# --- Test 5: Max age with stricter threshold ---
def test_max_age_policy_strict():
    """RED: 14-day max age should delete more artifacts."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS)
    to_delete = apply_max_age_policy(artifacts, max_age_days=14, now=NOW)
    # build-linux-old (16d), build-windows-old (21d), test-results-ancient (40d)
    assert to_delete == {"build-linux-old", "build-windows-old", "test-results-ancient"}, f"Got: {to_delete}"
    print("PASS: test_max_age_policy_strict")


# --- Test 6: Keep latest N per workflow ---
def test_keep_latest_n_policy():
    """RED: only the N most recent artifacts per workflow should be retained."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS)
    to_delete = apply_keep_latest_n_policy(artifacts, keep_n=1)
    # wf-100: keep build-linux-latest, delete build-linux-old
    # wf-200: keep build-windows-latest, delete build-windows-old
    # wf-300: keep test-results-recent, delete test-results-medium & test-results-ancient
    expected = {"build-linux-old", "build-windows-old", "test-results-medium", "test-results-ancient"}
    assert to_delete == expected, f"Got: {to_delete}"
    print("PASS: test_keep_latest_n_policy")


# --- Test 7: Max total size policy ---
def test_max_total_size_policy():
    """RED: oldest artifacts should be deleted first until size is under limit."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS)
    to_delete = apply_max_total_size_policy(artifacts, max_total_size_mb=150)
    # Total 280MB, need to drop 130MB. Oldest first:
    # test-results-ancient(8)=272, build-windows-old(75)=197,
    # build-linux-old(45)=152, test-results-medium(12)=140 <= 150
    expected = {"test-results-ancient", "build-windows-old", "build-linux-old", "test-results-medium"}
    assert to_delete == expected, f"Got: {to_delete}"
    print("PASS: test_max_total_size_policy")


# --- Test 8: Combined policies ---
def test_combined_policies():
    """RED: multiple policies should combine (union of deletions)."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS)
    plan = generate_deletion_plan(
        artifacts,
        COMBINED_CONFIG["policy"],
        dry_run=True,
        now=NOW,
    )
    # max_age(14d): build-linux-old, build-windows-old, test-results-ancient
    # keep_latest_2: test-results-ancient (already in set)
    # remaining after above: 152MB < 200MB, no size deletions
    assert sorted(plan["artifacts_deleted"]) == sorted([
        "build-linux-old", "build-windows-old", "test-results-ancient"
    ]), f"Got deleted: {plan['artifacts_deleted']}"
    assert len(plan["artifacts_retained"]) == 4
    print("PASS: test_combined_policies")


# --- Test 9: Empty artifacts ---
def test_empty_artifacts():
    """RED: empty artifact list should produce empty plan."""
    plan = generate_deletion_plan([], {}, dry_run=True)
    assert plan["artifacts_deleted"] == []
    assert plan["artifacts_retained"] == []
    assert plan["total_space_reclaimed_mb"] == 0.0
    assert "No artifacts" in plan["summary"]
    print("PASS: test_empty_artifacts")


# --- Test 10: Dry run flag ---
def test_dry_run_mode():
    """RED: plan should indicate dry_run=True and include DRY RUN in summary."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS[:2])
    plan = generate_deletion_plan(artifacts, {"max_age_days": 7}, dry_run=True, now=NOW)
    assert plan["dry_run"] is True
    assert "DRY RUN" in plan["summary"]
    print("PASS: test_dry_run_mode")


# --- Test 11: Live mode ---
def test_live_mode():
    """RED: live mode should indicate dry_run=False and include LIVE in summary."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS[:2])
    plan = generate_deletion_plan(artifacts, {"max_age_days": 7}, dry_run=False, now=NOW)
    assert plan["dry_run"] is False
    assert "LIVE" in plan["summary"]
    print("PASS: test_live_mode")


# --- Test 12: Space reclaimed calculation ---
def test_space_reclaimed():
    """RED: reclaimed space should equal sum of deleted artifact sizes."""
    artifacts = parse_artifacts(BASIC_ARTIFACTS)
    plan = generate_deletion_plan(artifacts, {"max_age_days": 30}, dry_run=True, now=NOW)
    # Only test-results-ancient (8 MB) deleted
    assert plan["total_space_reclaimed_mb"] == 8.0, f"Got: {plan['total_space_reclaimed_mb']}"
    assert plan["total_space_retained_mb"] == 272.0, f"Got: {plan['total_space_retained_mb']}"
    print("PASS: test_space_reclaimed")


# --- Test 13: CLI integration via subprocess ---
def test_cli_integration():
    """RED: CLI should accept JSON config and produce expected output."""
    config = {
        "artifacts": BASIC_ARTIFACTS[:3],
        "policy": {"max_age_days": 7},
        "now": NOW_ISO,
    }
    result = subprocess.run(
        [sys.executable, "artifact_cleanup.py", "-c", "-"],
        input=json.dumps(config),
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"CLI failed: {result.stderr}"
    assert "DRY RUN" in result.stdout
    # build-linux-old is 16 days old -> deleted
    assert "build-linux-old" in result.stdout
    print("PASS: test_cli_integration")


# --- Test 14: CLI with invalid input ---
def test_cli_invalid_input():
    """RED: CLI should exit non-zero for invalid artifacts."""
    config = {"artifacts": [{"name": "broken"}], "policy": {}}
    result = subprocess.run(
        [sys.executable, "artifact_cleanup.py", "-c", "-"],
        input=json.dumps(config),
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0, "Should have failed"
    assert "ERROR" in result.stderr
    print("PASS: test_cli_invalid_input")


def run_all_tests():
    """Run all tests and report results."""
    tests = [
        test_parse_valid_artifacts,
        test_parse_rejects_missing_fields,
        test_parse_rejects_negative_size,
        test_max_age_policy,
        test_max_age_policy_strict,
        test_keep_latest_n_policy,
        test_max_total_size_policy,
        test_combined_policies,
        test_empty_artifacts,
        test_dry_run_mode,
        test_live_mode,
        test_space_reclaimed,
        test_cli_integration,
        test_cli_invalid_input,
    ]
    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"FAIL: {test.__name__}: {e}")
            failed += 1
    print(f"\n{'='*50}")
    print(f"Results: {passed} passed, {failed} failed, {len(tests)} total")
    if failed > 0:
        sys.exit(1)
    else:
        print("ALL TESTS PASSED")


if __name__ == "__main__":
    run_all_tests()
