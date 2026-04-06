"""
TDD tests for artifact cleanup script.
Tests are written first (red), then implementation makes them pass (green).
"""

import pytest
from datetime import datetime, timedelta
from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    apply_retention_policies,
    generate_deletion_plan,
    DeletionPlan,
)

# --- Test fixtures ---

def make_artifact(name, size_mb, days_old, workflow_run_id):
    """Helper to create test artifacts with relative dates."""
    created_at = datetime.now() - timedelta(days=days_old)
    return Artifact(
        name=name,
        size_bytes=size_mb * 1024 * 1024,
        created_at=created_at,
        workflow_run_id=workflow_run_id,
    )


# === RED PHASE 1: Test Artifact dataclass creation ===

class TestArtifact:
    def test_artifact_creation(self):
        """Artifact can be created with required fields."""
        now = datetime.now()
        artifact = Artifact(
            name="build-output.zip",
            size_bytes=1024,
            created_at=now,
            workflow_run_id="run-123",
        )
        assert artifact.name == "build-output.zip"
        assert artifact.size_bytes == 1024
        assert artifact.created_at == now
        assert artifact.workflow_run_id == "run-123"

    def test_artifact_size_in_mb(self):
        """Artifact exposes size in megabytes."""
        artifact = Artifact(
            name="test.zip",
            size_bytes=5 * 1024 * 1024,
            created_at=datetime.now(),
            workflow_run_id="run-1",
        )
        assert artifact.size_mb == 5.0

    def test_artifact_age_in_days(self):
        """Artifact exposes age in days."""
        artifact = Artifact(
            name="old.zip",
            size_bytes=100,
            created_at=datetime.now() - timedelta(days=30),
            workflow_run_id="run-1",
        )
        assert artifact.age_days >= 30


# === RED PHASE 2: Test RetentionPolicy ===

class TestRetentionPolicy:
    def test_policy_defaults(self):
        """RetentionPolicy has sensible defaults."""
        policy = RetentionPolicy()
        assert policy.max_age_days is None
        assert policy.max_total_size_bytes is None
        assert policy.keep_latest_n is None

    def test_policy_with_all_options(self):
        """RetentionPolicy can be configured with all options."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=100 * 1024 * 1024,
            keep_latest_n=5,
        )
        assert policy.max_age_days == 30
        assert policy.max_total_size_bytes == 100 * 1024 * 1024
        assert policy.keep_latest_n == 5


# === RED PHASE 3: Test max_age_days policy ===

class TestMaxAgePolicyFilter:
    def test_artifacts_older_than_max_age_are_deleted(self):
        """Artifacts older than max_age_days should be marked for deletion."""
        artifacts = [
            make_artifact("old.zip", 10, days_old=60, workflow_run_id="run-1"),
            make_artifact("new.zip", 10, days_old=10, workflow_run_id="run-2"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        assert any(a.name == "old.zip" for a in to_delete)
        assert any(a.name == "new.zip" for a in to_keep)

    def test_artifacts_under_max_age_boundary_are_kept(self):
        """Artifacts younger than max_age_days should be kept (29 days < 30-day limit)."""
        artifacts = [
            make_artifact("recent.zip", 5, days_old=29, workflow_run_id="run-1"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        assert any(a.name == "recent.zip" for a in to_keep)
        assert len(to_delete) == 0


# === RED PHASE 4: Test keep_latest_n policy ===

class TestKeepLatestNPolicy:
    def test_keep_latest_n_per_workflow(self):
        """Only keep the N most recent artifacts per workflow run ID."""
        artifacts = [
            make_artifact("artifact-1.zip", 5, days_old=5, workflow_run_id="workflow-A"),
            make_artifact("artifact-2.zip", 5, days_old=10, workflow_run_id="workflow-A"),
            make_artifact("artifact-3.zip", 5, days_old=15, workflow_run_id="workflow-A"),
            make_artifact("artifact-4.zip", 5, days_old=1, workflow_run_id="workflow-B"),
        ]
        policy = RetentionPolicy(keep_latest_n=2)
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        # workflow-A: keep newest 2, delete oldest
        assert any(a.name == "artifact-3.zip" for a in to_delete)
        assert any(a.name == "artifact-1.zip" for a in to_keep)
        assert any(a.name == "artifact-2.zip" for a in to_keep)
        # workflow-B only has 1, keep it
        assert any(a.name == "artifact-4.zip" for a in to_keep)

    def test_keep_latest_n_with_single_artifact(self):
        """Single artifact should always be kept when keep_latest_n >= 1."""
        artifacts = [
            make_artifact("only.zip", 5, days_old=100, workflow_run_id="workflow-A"),
        ]
        policy = RetentionPolicy(keep_latest_n=1)
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        assert any(a.name == "only.zip" for a in to_keep)
        assert len(to_delete) == 0


# === RED PHASE 5: Test max_total_size policy ===

class TestMaxTotalSizePolicy:
    def test_oldest_artifacts_deleted_when_over_size_limit(self):
        """When total size exceeds limit, delete oldest artifacts first."""
        artifacts = [
            make_artifact("newest.zip", 20, days_old=1, workflow_run_id="run-1"),
            make_artifact("middle.zip", 20, days_old=5, workflow_run_id="run-2"),
            make_artifact("oldest.zip", 20, days_old=10, workflow_run_id="run-3"),
        ]
        # 60MB total, limit 40MB -> delete 1 oldest artifact (20MB)
        policy = RetentionPolicy(max_total_size_bytes=40 * 1024 * 1024)
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        assert any(a.name == "oldest.zip" for a in to_delete)
        assert any(a.name == "newest.zip" for a in to_keep)
        assert any(a.name == "middle.zip" for a in to_keep)

    def test_no_deletion_when_under_size_limit(self):
        """No deletion when total size is under the limit."""
        artifacts = [
            make_artifact("small.zip", 5, days_old=1, workflow_run_id="run-1"),
            make_artifact("small2.zip", 5, days_old=2, workflow_run_id="run-2"),
        ]
        policy = RetentionPolicy(max_total_size_bytes=100 * 1024 * 1024)
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        assert len(to_delete) == 0
        assert len(to_keep) == 2


# === RED PHASE 6: Test combined policies ===

class TestCombinedPolicies:
    def test_combined_age_and_keep_latest(self):
        """Combined policies: artifact deleted if ANY policy marks it for deletion."""
        artifacts = [
            make_artifact("a1.zip", 5, days_old=60, workflow_run_id="wf-A"),  # old
            make_artifact("a2.zip", 5, days_old=5, workflow_run_id="wf-A"),   # recent
            make_artifact("a3.zip", 5, days_old=3, workflow_run_id="wf-A"),   # recent
        ]
        policy = RetentionPolicy(max_age_days=30, keep_latest_n=2)
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        # a1 is old (>30 days), should be deleted
        assert any(a.name == "a1.zip" for a in to_delete)
        # a2 and a3 are recent and within keep_latest_n=2
        assert any(a.name == "a2.zip" for a in to_keep)
        assert any(a.name == "a3.zip" for a in to_keep)


# === RED PHASE 7: Test DeletionPlan generation ===

class TestDeletionPlan:
    def test_deletion_plan_summary(self):
        """DeletionPlan summarizes space reclaimed and artifact counts."""
        artifacts = [
            make_artifact("old1.zip", 10, days_old=60, workflow_run_id="run-1"),
            make_artifact("old2.zip", 20, days_old=50, workflow_run_id="run-2"),
            make_artifact("new1.zip", 5, days_old=5, workflow_run_id="run-3"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        plan = generate_deletion_plan(artifacts, policy)
        assert plan.artifacts_deleted == 2
        assert plan.artifacts_retained == 1
        assert plan.space_reclaimed_bytes == 30 * 1024 * 1024

    def test_deletion_plan_contains_artifact_names(self):
        """DeletionPlan includes names of artifacts to delete."""
        artifacts = [
            make_artifact("old.zip", 10, days_old=60, workflow_run_id="run-1"),
            make_artifact("new.zip", 5, days_old=5, workflow_run_id="run-2"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        plan = generate_deletion_plan(artifacts, policy)
        assert "old.zip" in [a.name for a in plan.to_delete]
        assert "new.zip" in [a.name for a in plan.to_keep]

    def test_deletion_plan_space_reclaimed_mb(self):
        """DeletionPlan exposes space reclaimed in MB."""
        artifacts = [
            make_artifact("big.zip", 50, days_old=60, workflow_run_id="run-1"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        plan = generate_deletion_plan(artifacts, policy)
        assert plan.space_reclaimed_mb == 50.0


# === RED PHASE 8: Test dry-run mode ===

class TestDryRunMode:
    def test_dry_run_does_not_modify_plan(self):
        """Dry-run mode generates the same plan but marks it as simulation."""
        artifacts = [
            make_artifact("old.zip", 10, days_old=60, workflow_run_id="run-1"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        plan_dry = generate_deletion_plan(artifacts, policy, dry_run=True)
        plan_real = generate_deletion_plan(artifacts, policy, dry_run=False)
        # Both identify same artifacts to delete
        assert [a.name for a in plan_dry.to_delete] == [a.name for a in plan_real.to_delete]
        # Dry-run is flagged
        assert plan_dry.is_dry_run is True
        assert plan_real.is_dry_run is False

    def test_dry_run_summary_output(self):
        """Dry-run plan has a summary string indicating simulation mode."""
        artifacts = [
            make_artifact("old.zip", 10, days_old=60, workflow_run_id="run-1"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        plan = generate_deletion_plan(artifacts, policy, dry_run=True)
        summary = plan.summary()
        assert "DRY RUN" in summary
        assert "old.zip" in summary or "1" in summary

    def test_real_run_summary_output(self):
        """Real run plan summary does not mention dry-run."""
        artifacts = [
            make_artifact("old.zip", 10, days_old=60, workflow_run_id="run-1"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        plan = generate_deletion_plan(artifacts, policy, dry_run=False)
        summary = plan.summary()
        assert "DRY RUN" not in summary


# === RED PHASE 9: Test edge cases ===

class TestEdgeCases:
    def test_empty_artifact_list(self):
        """Empty artifact list produces empty deletion plan."""
        policy = RetentionPolicy(max_age_days=30)
        plan = generate_deletion_plan([], policy)
        assert plan.artifacts_deleted == 0
        assert plan.artifacts_retained == 0
        assert plan.space_reclaimed_bytes == 0

    def test_no_policies_set(self):
        """No policies set: no artifacts deleted."""
        artifacts = [
            make_artifact("any.zip", 10, days_old=100, workflow_run_id="run-1"),
        ]
        policy = RetentionPolicy()
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        assert len(to_delete) == 0
        assert len(to_keep) == 1

    def test_multiple_policies_union_of_deletions(self):
        """Artifact deleted if marked by any active policy."""
        artifacts = [
            make_artifact("size-violator.zip", 100, days_old=1, workflow_run_id="run-1"),
            make_artifact("age-violator.zip", 1, days_old=60, workflow_run_id="run-2"),
            make_artifact("clean.zip", 1, days_old=1, workflow_run_id="run-3"),
        ]
        # 102MB total, limit 50MB; max age 30 days
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=50 * 1024 * 1024,
        )
        to_delete, to_keep = apply_retention_policies(artifacts, policy)
        deleted_names = {a.name for a in to_delete}
        assert "age-violator.zip" in deleted_names
        assert "size-violator.zip" in deleted_names
        assert "clean.zip" in [a.name for a in to_keep]
