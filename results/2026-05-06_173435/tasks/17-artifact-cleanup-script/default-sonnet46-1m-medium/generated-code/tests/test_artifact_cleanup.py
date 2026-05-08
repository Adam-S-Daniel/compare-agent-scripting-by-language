# TDD tests for artifact_cleanup.py
# Written FIRST (red phase) before the implementation exists.
# Each test defines the expected behavior, then artifact_cleanup.py is written to make them pass.

from datetime import datetime, timezone, timedelta
import pytest

from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    DeletionPlan,
    apply_retention_policies,
)

# Fixed "now" used in all tests so results are deterministic.
NOW = datetime(2026, 5, 8, tzinfo=timezone.utc)


# --- Test fixtures ---

def make_artifact(name, size_mb, days_ago, workflow_run_id="run-001"):
    created_at = NOW - timedelta(days=days_ago)
    return Artifact(name=name, size_mb=size_mb, created_at=created_at, workflow_run_id=workflow_run_id)


FIXTURES = [
    make_artifact("artifact-old-a",  50.0,  120, "run-001"),   # 120 days old, 50 MB
    make_artifact("artifact-old-b",  75.0,   90, "run-001"),   # 90 days old,  75 MB
    make_artifact("artifact-mid",   100.0,   37, "run-002"),   # 37 days old, 100 MB
    make_artifact("artifact-new",    25.0,    7, "run-002"),   # 7 days old,   25 MB
]

# Total = 250 MB


# --- Test 1: max_age_days policy (TDD red: fails until Artifact + apply_retention_policies exist) ---

def test_max_age_policy():
    """Artifacts older than max_age_days must be marked for deletion."""
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(FIXTURES, policy, now=NOW)

    deleted_names = {a.name for a in plan.to_delete}
    retained_names = {a.name for a in plan.to_retain}

    # 120, 90, 37 days old — all exceed 30-day limit
    assert "artifact-old-a" in deleted_names
    assert "artifact-old-b" in deleted_names
    assert "artifact-mid"   in deleted_names
    # 7 days old — within limit
    assert "artifact-new" in retained_names

    assert len(plan.to_delete) == 3
    assert len(plan.to_retain) == 1
    assert round(plan.space_reclaimed_mb, 2) == 225.0

    summary = plan.summary()
    assert summary["deleted"] == 3
    assert summary["retained"] == 1
    assert summary["space_reclaimed_mb"] == 225.0
    print(f"RESULT:test_max_age_policy:deleted={summary['deleted']},retained={summary['retained']},space_reclaimed={summary['space_reclaimed_mb']}")


# --- Test 2: keep_latest_n policy ---

def test_keep_latest_n_policy():
    """Only the N most-recent artifacts per workflow_run_id are retained."""
    policy = RetentionPolicy(keep_latest_n=1)
    plan = apply_retention_policies(FIXTURES, policy, now=NOW)

    deleted_names = {a.name for a in plan.to_delete}
    retained_names = {a.name for a in plan.to_retain}

    # run-001: oldest is artifact-old-a → deleted; newest is artifact-old-b → retained
    assert "artifact-old-a" in deleted_names
    assert "artifact-old-b" in retained_names
    # run-002: oldest is artifact-mid → deleted; newest is artifact-new → retained
    assert "artifact-mid" in deleted_names
    assert "artifact-new" in retained_names

    assert len(plan.to_delete) == 2
    assert len(plan.to_retain) == 2
    assert round(plan.space_reclaimed_mb, 2) == 150.0

    summary = plan.summary()
    print(f"RESULT:test_keep_latest_n_policy:deleted={summary['deleted']},retained={summary['retained']},space_reclaimed={summary['space_reclaimed_mb']}")


# --- Test 3: max_total_size_mb policy ---

def test_max_total_size_policy():
    """Oldest artifacts are deleted until total remaining size is within the limit."""
    policy = RetentionPolicy(max_total_size_mb=100.0)
    plan = apply_retention_policies(FIXTURES, policy, now=NOW)

    # Total = 250 MB. Delete oldest first until ≤ 100 MB.
    # Delete artifact-old-a (50): 200 MB remaining
    # Delete artifact-old-b (75): 125 MB remaining
    # Delete artifact-mid (100): 25 MB remaining ≤ 100 MB → stop
    deleted_names = {a.name for a in plan.to_delete}
    retained_names = {a.name for a in plan.to_retain}

    assert "artifact-old-a" in deleted_names
    assert "artifact-old-b" in deleted_names
    assert "artifact-mid"   in deleted_names
    assert "artifact-new"   in retained_names

    assert len(plan.to_delete) == 3
    assert len(plan.to_retain) == 1
    assert round(plan.space_reclaimed_mb, 2) == 225.0

    summary = plan.summary()
    print(f"RESULT:test_max_total_size_policy:deleted={summary['deleted']},retained={summary['retained']},space_reclaimed={summary['space_reclaimed_mb']}")


# --- Test 4: combined policies ---

def test_combined_policies():
    """All policies apply; an artifact is deleted if any policy marks it."""
    # max_age_days=60 marks: artifact-old-a (120d), artifact-old-b (90d)
    # keep_latest_n=1 marks: artifact-old-a (run-001 oldest), artifact-mid (run-002 oldest)
    # Combined: artifact-old-a, artifact-old-b, artifact-mid all deleted; artifact-new retained
    policy = RetentionPolicy(max_age_days=60, keep_latest_n=1)
    plan = apply_retention_policies(FIXTURES, policy, now=NOW)

    deleted_names = {a.name for a in plan.to_delete}
    assert "artifact-old-a" in deleted_names
    assert "artifact-old-b" in deleted_names
    assert "artifact-mid"   in deleted_names
    assert "artifact-new" not in deleted_names

    summary = plan.summary()
    print(f"RESULT:test_combined_policies:deleted={summary['deleted']},retained={summary['retained']},space_reclaimed={summary['space_reclaimed_mb']}")


# --- Test 5: dry-run mode ---

def test_dry_run_mode():
    """dry_run=True produces the same deletion plan but marks it as a dry run."""
    policy = RetentionPolicy(max_age_days=30)
    plan_live = apply_retention_policies(FIXTURES, policy, now=NOW, dry_run=False)
    plan_dry  = apply_retention_policies(FIXTURES, policy, now=NOW, dry_run=True)

    # Same artifacts deleted in both cases
    assert {a.name for a in plan_live.to_delete} == {a.name for a in plan_dry.to_delete}
    # dry_run flag is propagated
    assert plan_dry.dry_run is True
    assert plan_live.dry_run is False

    summary = plan_dry.summary()
    print(f"RESULT:test_dry_run_mode:deleted={summary['deleted']},retained={summary['retained']},dry_run={plan_dry.dry_run}")


# --- Test 6: empty artifact list ---

def test_empty_artifact_list():
    """No artifacts → no deletions, zero space reclaimed."""
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies([], policy, now=NOW)

    assert plan.to_delete == []
    assert plan.to_retain == []
    assert plan.space_reclaimed_mb == 0.0

    summary = plan.summary()
    print(f"RESULT:test_empty_artifact_list:deleted={summary['deleted']},retained={summary['retained']},space_reclaimed={summary['space_reclaimed_mb']}")


# --- Test 7: no policy set → nothing deleted ---

def test_no_policy():
    """A RetentionPolicy with no constraints deletes nothing."""
    policy = RetentionPolicy()
    plan = apply_retention_policies(FIXTURES, policy, now=NOW)

    assert len(plan.to_delete) == 0
    assert len(plan.to_retain) == len(FIXTURES)

    summary = plan.summary()
    print(f"RESULT:test_no_policy:deleted={summary['deleted']},retained={summary['retained']},space_reclaimed={summary['space_reclaimed_mb']}")


# --- Test 8: max_total_size already within limit → nothing deleted ---

def test_total_size_within_limit():
    """When total size is already within the limit, no artifacts are deleted."""
    policy = RetentionPolicy(max_total_size_mb=1000.0)
    plan = apply_retention_policies(FIXTURES, policy, now=NOW)

    assert len(plan.to_delete) == 0
    assert len(plan.to_retain) == len(FIXTURES)

    summary = plan.summary()
    print(f"RESULT:test_total_size_within_limit:deleted={summary['deleted']},retained={summary['retained']},space_reclaimed={summary['space_reclaimed_mb']}")
