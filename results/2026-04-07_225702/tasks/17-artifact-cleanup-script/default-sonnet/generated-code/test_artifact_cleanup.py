# Artifact Cleanup Script - Test Suite
# Using red/green TDD: each test is written before its implementation.
# Tests are organized in the order functionality is built up.

import pytest
from datetime import datetime, timedelta, timezone
from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    apply_retention_policies,
    generate_deletion_plan,
    DeletionPlan,
)


# ---------------------------------------------------------------------------
# Fixtures / mock data
# ---------------------------------------------------------------------------

def make_artifact(name, size_mb, age_days, workflow_run_id):
    """Helper: create an Artifact with a computed creation date."""
    created_at = datetime.now(timezone.utc) - timedelta(days=age_days)
    return Artifact(
        name=name,
        size_bytes=int(size_mb * 1024 * 1024),
        created_at=created_at,
        workflow_run_id=workflow_run_id,
    )


# ---------------------------------------------------------------------------
# TDD Cycle 1 – Artifact data model
# ---------------------------------------------------------------------------

class TestArtifactModel:
    def test_artifact_has_required_fields(self):
        """An Artifact must carry name, size_bytes, created_at, and workflow_run_id."""
        now = datetime.now(timezone.utc)
        art = Artifact(
            name="build-output.zip",
            size_bytes=10_485_760,  # 10 MB
            created_at=now,
            workflow_run_id="run-001",
        )
        assert art.name == "build-output.zip"
        assert art.size_bytes == 10_485_760
        assert art.created_at == now
        assert art.workflow_run_id == "run-001"

    def test_artifact_size_mb_property(self):
        """Artifact.size_mb should return size in megabytes (float)."""
        art = Artifact(
            name="test.zip",
            size_bytes=5_242_880,  # 5 MB exactly
            created_at=datetime.now(timezone.utc),
            workflow_run_id="run-002",
        )
        assert art.size_mb == pytest.approx(5.0)


# ---------------------------------------------------------------------------
# TDD Cycle 2 – RetentionPolicy data model
# ---------------------------------------------------------------------------

class TestRetentionPolicy:
    def test_policy_defaults(self):
        """RetentionPolicy with no arguments should be permissive (no deletion)."""
        policy = RetentionPolicy()
        assert policy.max_age_days is None
        assert policy.max_total_size_bytes is None
        assert policy.keep_latest_n is None

    def test_policy_with_values(self):
        """RetentionPolicy should store the provided constraints."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=500 * 1024 * 1024,
            keep_latest_n=3,
        )
        assert policy.max_age_days == 30
        assert policy.max_total_size_bytes == 500 * 1024 * 1024
        assert policy.keep_latest_n == 3


# ---------------------------------------------------------------------------
# TDD Cycle 3 – Max-age policy
# ---------------------------------------------------------------------------

class TestMaxAgePolicy:
    def test_artifact_older_than_max_age_is_deleted(self):
        """An artifact older than max_age_days must appear in the to-delete set."""
        old_artifact = make_artifact("old.zip", size_mb=5, age_days=40, workflow_run_id="run-1")
        policy = RetentionPolicy(max_age_days=30)

        plan = apply_retention_policies([old_artifact], policy)

        assert old_artifact in plan.to_delete

    def test_artifact_within_max_age_is_retained(self):
        """An artifact younger than max_age_days must NOT be in the to-delete set."""
        new_artifact = make_artifact("new.zip", size_mb=5, age_days=10, workflow_run_id="run-2")
        policy = RetentionPolicy(max_age_days=30)

        plan = apply_retention_policies([new_artifact], policy)

        assert new_artifact not in plan.to_delete

    def test_artifact_exactly_at_max_age_boundary_is_retained(self):
        """An artifact whose age equals max_age_days exactly is retained (boundary: inclusive keep)."""
        boundary_artifact = make_artifact("boundary.zip", size_mb=5, age_days=30, workflow_run_id="run-3")
        policy = RetentionPolicy(max_age_days=30)

        plan = apply_retention_policies([boundary_artifact], policy)

        assert boundary_artifact not in plan.to_delete


# ---------------------------------------------------------------------------
# TDD Cycle 4 – Keep-latest-N per workflow
# ---------------------------------------------------------------------------

class TestKeepLatestNPolicy:
    def test_oldest_artifacts_deleted_when_exceeding_keep_n(self):
        """When a workflow has more than keep_latest_n artifacts, the oldest are deleted."""
        artifacts = [
            make_artifact("a1.zip", size_mb=1, age_days=10, workflow_run_id="wf-A"),
            make_artifact("a2.zip", size_mb=1, age_days=5, workflow_run_id="wf-A"),
            make_artifact("a3.zip", size_mb=1, age_days=1, workflow_run_id="wf-A"),
        ]
        policy = RetentionPolicy(keep_latest_n=2)

        plan = apply_retention_policies(artifacts, policy)

        # a1 is oldest → should be deleted
        assert artifacts[0] in plan.to_delete
        # a2 and a3 are the two newest → retained
        assert artifacts[1] not in plan.to_delete
        assert artifacts[2] not in plan.to_delete

    def test_independent_workflows_each_respect_keep_n(self):
        """keep_latest_n applies per workflow, not globally."""
        artifacts = [
            make_artifact("wf1-old.zip", size_mb=1, age_days=20, workflow_run_id="wf-1"),
            make_artifact("wf1-new.zip", size_mb=1, age_days=2, workflow_run_id="wf-1"),
            make_artifact("wf2-old.zip", size_mb=1, age_days=15, workflow_run_id="wf-2"),
            make_artifact("wf2-new.zip", size_mb=1, age_days=3, workflow_run_id="wf-2"),
        ]
        policy = RetentionPolicy(keep_latest_n=1)

        plan = apply_retention_policies(artifacts, policy)

        assert artifacts[0] in plan.to_delete      # wf-1 old
        assert artifacts[1] not in plan.to_delete  # wf-1 new (kept)
        assert artifacts[2] in plan.to_delete      # wf-2 old
        assert artifacts[3] not in plan.to_delete  # wf-2 new (kept)


# ---------------------------------------------------------------------------
# TDD Cycle 5 – Max total size policy
# ---------------------------------------------------------------------------

class TestMaxTotalSizePolicy:
    def test_oldest_artifacts_deleted_when_total_exceeds_limit(self):
        """When total size exceeds max_total_size_bytes, oldest artifacts are deleted first."""
        artifacts = [
            make_artifact("big-old.zip",    size_mb=200, age_days=30, workflow_run_id="wf-X"),
            make_artifact("big-middle.zip", size_mb=200, age_days=15, workflow_run_id="wf-X"),
            make_artifact("big-new.zip",    size_mb=200, age_days=1,  workflow_run_id="wf-X"),
        ]
        # Limit is 250 MB → must delete until ≤ 250 MB
        policy = RetentionPolicy(max_total_size_bytes=250 * 1024 * 1024)

        plan = apply_retention_policies(artifacts, policy)

        # After deleting oldest (200 MB) we still have 400 MB → delete middle too
        # After deleting middle (200 MB) we have 200 MB ≤ 250 MB → stop
        assert artifacts[0] in plan.to_delete      # oldest deleted
        assert artifacts[1] in plan.to_delete      # middle deleted
        assert artifacts[2] not in plan.to_delete  # newest retained

    def test_no_deletion_when_within_size_limit(self):
        """No artifacts are deleted purely on size grounds when total is within the limit."""
        artifacts = [
            make_artifact("a.zip", size_mb=50, age_days=10, workflow_run_id="wf-Y"),
            make_artifact("b.zip", size_mb=50, age_days=5,  workflow_run_id="wf-Y"),
        ]
        policy = RetentionPolicy(max_total_size_bytes=200 * 1024 * 1024)

        plan = apply_retention_policies(artifacts, policy)

        assert len(plan.to_delete) == 0


# ---------------------------------------------------------------------------
# TDD Cycle 6 – Combined policies (union of all deletion sets)
# ---------------------------------------------------------------------------

class TestCombinedPolicies:
    def test_all_policies_applied_together(self):
        """Artifacts are deleted if they violate ANY policy."""
        artifacts = [
            # Too old
            make_artifact("too-old.zip",    size_mb=10,  age_days=60, workflow_run_id="wf-Z"),
            # Newest of the workflow group → kept by age, but violates keep_n=1
            make_artifact("second.zip",     size_mb=10,  age_days=5,  workflow_run_id="wf-Z"),
            # The very latest
            make_artifact("latest.zip",     size_mb=10,  age_days=1,  workflow_run_id="wf-Z"),
        ]
        policy = RetentionPolicy(
            max_age_days=30,
            keep_latest_n=1,
            max_total_size_bytes=500 * 1024 * 1024,
        )

        plan = apply_retention_policies(artifacts, policy)

        assert artifacts[0] in plan.to_delete   # violates max_age
        assert artifacts[1] in plan.to_delete   # violates keep_latest_n (only latest kept)
        assert artifacts[2] not in plan.to_delete


# ---------------------------------------------------------------------------
# TDD Cycle 7 – Deletion plan summary
# ---------------------------------------------------------------------------

class TestDeletionPlanSummary:
    def test_deletion_plan_counts(self):
        """DeletionPlan.summary should report correct retained/deleted counts."""
        artifacts = [
            make_artifact("del-1.zip", size_mb=100, age_days=90, workflow_run_id="wf-1"),
            make_artifact("del-2.zip", size_mb=50,  age_days=80, workflow_run_id="wf-1"),
            make_artifact("keep-1.zip", size_mb=20, age_days=5,  workflow_run_id="wf-1"),
        ]
        policy = RetentionPolicy(max_age_days=30)

        plan = apply_retention_policies(artifacts, policy)
        summary = plan.summary()

        assert summary["artifacts_deleted"] == 2
        assert summary["artifacts_retained"] == 1

    def test_deletion_plan_space_reclaimed(self):
        """DeletionPlan.summary should report total space reclaimed in bytes."""
        artifacts = [
            make_artifact("big.zip",   size_mb=100, age_days=90, workflow_run_id="wf-1"),
            make_artifact("small.zip", size_mb=50,  age_days=80, workflow_run_id="wf-1"),
            make_artifact("keep.zip",  size_mb=20,  age_days=5,  workflow_run_id="wf-1"),
        ]
        policy = RetentionPolicy(max_age_days=30)

        plan = apply_retention_policies(artifacts, policy)
        summary = plan.summary()

        expected_reclaimed = int((100 + 50) * 1024 * 1024)
        assert summary["space_reclaimed_bytes"] == expected_reclaimed

    def test_deletion_plan_lists_deleted_artifact_names(self):
        """DeletionPlan should list the names of all artifacts marked for deletion."""
        artifacts = [
            make_artifact("old-a.zip", size_mb=10, age_days=60, workflow_run_id="wf-A"),
            make_artifact("old-b.zip", size_mb=10, age_days=45, workflow_run_id="wf-A"),
            make_artifact("new-c.zip", size_mb=10, age_days=5,  workflow_run_id="wf-A"),
        ]
        policy = RetentionPolicy(max_age_days=30)

        plan = apply_retention_policies(artifacts, policy)

        deleted_names = {a.name for a in plan.to_delete}
        assert "old-a.zip" in deleted_names
        assert "old-b.zip" in deleted_names
        assert "new-c.zip" not in deleted_names


# ---------------------------------------------------------------------------
# TDD Cycle 8 – generate_deletion_plan (top-level entrypoint)
# ---------------------------------------------------------------------------

class TestGenerateDeletionPlan:
    def test_returns_deletion_plan_instance(self):
        """generate_deletion_plan should return a DeletionPlan."""
        artifacts = [make_artifact("x.zip", size_mb=5, age_days=10, workflow_run_id="wf-1")]
        policy = RetentionPolicy()

        result = generate_deletion_plan(artifacts, policy)

        assert isinstance(result, DeletionPlan)

    def test_dry_run_does_not_mutate_artifact_list(self):
        """generate_deletion_plan in dry-run mode returns a plan but does not alter the input list."""
        artifacts = [make_artifact("y.zip", size_mb=5, age_days=100, workflow_run_id="wf-2")]
        original_count = len(artifacts)
        policy = RetentionPolicy(max_age_days=30)

        generate_deletion_plan(artifacts, policy, dry_run=True)

        # Input list must be unchanged
        assert len(artifacts) == original_count

    def test_dry_run_plan_marks_artifacts_for_deletion(self):
        """Even in dry-run mode, the returned plan should correctly identify artifacts to delete."""
        old = make_artifact("stale.zip", size_mb=10, age_days=90, workflow_run_id="wf-3")
        new = make_artifact("fresh.zip", size_mb=10, age_days=2,  workflow_run_id="wf-3")
        policy = RetentionPolicy(max_age_days=30)

        plan = generate_deletion_plan([old, new], policy, dry_run=True)

        assert old in plan.to_delete
        assert new not in plan.to_delete
        assert plan.dry_run is True

    def test_non_dry_run_plan_is_marked_accordingly(self):
        """A plan generated without dry_run=True should have dry_run=False."""
        artifacts = [make_artifact("z.zip", size_mb=5, age_days=5, workflow_run_id="wf-4")]
        policy = RetentionPolicy()

        plan = generate_deletion_plan(artifacts, policy)

        assert plan.dry_run is False
