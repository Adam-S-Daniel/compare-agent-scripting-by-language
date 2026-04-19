"""
Red/Green TDD tests for artifact cleanup script.
Start with the simplest test, make it pass, then add more.
"""
import pytest
from datetime import datetime, timedelta
from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    ArtifactCleaner,
    DeletionPlan,
)


class TestArtifactCreation:
    """Test basic artifact data structure."""

    def test_create_artifact_with_metadata(self):
        """RED: Artifact class doesn't exist yet."""
        artifact = Artifact(
            name="build-log.txt",
            size_bytes=1024,
            created_at=datetime(2026, 4, 1),
            workflow_run_id="run-123",
        )
        assert artifact.name == "build-log.txt"
        assert artifact.size_bytes == 1024
        assert artifact.workflow_run_id == "run-123"


class TestRetentionPolicy:
    """Test retention policy configuration."""

    def test_create_retention_policy(self):
        """Retention policy with max age, max size, and keep-latest-n."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=1_000_000,
            keep_latest_n_per_workflow=5,
        )
        assert policy.max_age_days == 30
        assert policy.max_total_size_bytes == 1_000_000
        assert policy.keep_latest_n_per_workflow == 5


class TestDeletionLogic:
    """Test artifact deletion decisions."""

    def test_delete_artifact_exceeding_max_age(self):
        """Delete artifacts older than max_age_days."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=10_000_000,
            keep_latest_n_per_workflow=10,
        )
        cleaner = ArtifactCleaner(policy)

        # Create an artifact from 31 days ago
        old_date = datetime.now() - timedelta(days=31)
        artifact = Artifact(
            name="old-build.zip",
            size_bytes=1000,
            created_at=old_date,
            workflow_run_id="run-old",
        )
        artifacts = [artifact]
        plan = cleaner.plan_deletions(artifacts)
        assert len(plan.to_delete) == 1
        assert plan.to_delete[0].name == "old-build.zip"

    def test_keep_artifact_within_max_age(self):
        """Keep artifacts younger than max_age_days."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=10_000_000,
            keep_latest_n_per_workflow=10,
        )
        cleaner = ArtifactCleaner(policy)

        # Create an artifact from 15 days ago
        recent_date = datetime.now() - timedelta(days=15)
        artifact = Artifact(
            name="recent-build.zip",
            size_bytes=1000,
            created_at=recent_date,
            workflow_run_id="run-recent",
        )
        artifacts = [artifact]
        plan = cleaner.plan_deletions(artifacts)
        assert len(plan.to_delete) == 0
        assert len(plan.to_keep) == 1


class TestMaxTotalSize:
    """Test max total size policy."""

    def test_delete_when_exceeding_max_total_size(self):
        """Delete older artifacts when total size exceeds limit."""
        policy = RetentionPolicy(
            max_age_days=365,  # Don't delete by age
            max_total_size_bytes=5000,  # 5KB limit
            keep_latest_n_per_workflow=10,
        )
        cleaner = ArtifactCleaner(policy)

        now = datetime.now()
        artifacts = [
            Artifact(
                name="old-build.zip",
                size_bytes=2000,
                created_at=now - timedelta(days=10),
                workflow_run_id="run-1",
            ),
            Artifact(
                name="recent-build.zip",
                size_bytes=2000,
                created_at=now - timedelta(days=5),
                workflow_run_id="run-1",
            ),
            Artifact(
                name="newest-build.zip",
                size_bytes=2000,
                created_at=now,
                workflow_run_id="run-1",
            ),
        ]
        plan = cleaner.plan_deletions(artifacts)
        # Total is 6000 bytes, need to delete oldest until <= 5000
        assert len(plan.to_delete) >= 1
        assert len(plan.to_keep) >= 1


class TestKeepLatestN:
    """Test keep-latest-N per workflow."""

    def test_keep_latest_n_per_workflow(self):
        """Keep only latest N artifacts per workflow."""
        policy = RetentionPolicy(
            max_age_days=365,
            max_total_size_bytes=1_000_000,
            keep_latest_n_per_workflow=2,
        )
        cleaner = ArtifactCleaner(policy)

        now = datetime.now()
        artifacts = [
            Artifact(
                name="build-1.zip",
                size_bytes=100,
                created_at=now - timedelta(days=3),
                workflow_run_id="run-1",
            ),
            Artifact(
                name="build-2.zip",
                size_bytes=100,
                created_at=now - timedelta(days=2),
                workflow_run_id="run-1",
            ),
            Artifact(
                name="build-3.zip",
                size_bytes=100,
                created_at=now - timedelta(days=1),
                workflow_run_id="run-1",
            ),
            Artifact(
                name="build-4.zip",
                size_bytes=100,
                created_at=now,
                workflow_run_id="run-1",
            ),
        ]
        plan = cleaner.plan_deletions(artifacts)
        # Keep only latest 2, so delete the first 2
        assert len(plan.to_delete) == 2
        assert len(plan.to_keep) == 2
        assert "build-1.zip" in [a.name for a in plan.to_delete]
        assert "build-2.zip" in [a.name for a in plan.to_delete]


class TestDeletionPlanSummary:
    """Test deletion plan summary generation."""

    def test_deletion_plan_summary(self):
        """Generate summary with space reclaimed and retention stats."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=10_000_000,
            keep_latest_n_per_workflow=5,
        )
        cleaner = ArtifactCleaner(policy)

        now = datetime.now()
        artifacts = [
            Artifact(
                name="old.zip",
                size_bytes=1000,
                created_at=now - timedelta(days=31),
                workflow_run_id="run-1",
            ),
            Artifact(
                name="recent.zip",
                size_bytes=2000,
                created_at=now - timedelta(days=1),
                workflow_run_id="run-1",
            ),
        ]
        plan = cleaner.plan_deletions(artifacts)
        summary = plan.summary()

        assert summary["artifacts_to_delete"] == 1
        assert summary["artifacts_to_keep"] == 1
        assert summary["space_reclaimed_bytes"] == 1000


class TestDryRunMode:
    """Test dry-run mode doesn't actually delete."""

    def test_dry_run_returns_plan_without_deletion(self):
        """Dry-run mode should return plan but not delete."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=10_000_000,
            keep_latest_n_per_workflow=5,
        )
        cleaner = ArtifactCleaner(policy)

        now = datetime.now()
        artifacts = [
            Artifact(
                name="old.zip",
                size_bytes=1000,
                created_at=now - timedelta(days=31),
                workflow_run_id="run-1",
            ),
        ]
        plan = cleaner.plan_deletions(artifacts, dry_run=True)

        assert plan.dry_run is True
        assert len(plan.to_delete) == 1
        # In dry-run, nothing should actually be deleted


class TestMultipleWorkflows:
    """Test handling multiple workflows independently."""

    def test_keep_latest_n_per_workflow_separately(self):
        """Each workflow gets its own keep-latest-N count."""
        policy = RetentionPolicy(
            max_age_days=365,
            max_total_size_bytes=1_000_000,
            keep_latest_n_per_workflow=2,
        )
        cleaner = ArtifactCleaner(policy)

        now = datetime.now()
        artifacts = [
            # Workflow 1: 4 artifacts
            Artifact(
                name="wf1-build-1.zip",
                size_bytes=100,
                created_at=now - timedelta(days=4),
                workflow_run_id="workflow-1",
            ),
            Artifact(
                name="wf1-build-2.zip",
                size_bytes=100,
                created_at=now - timedelta(days=3),
                workflow_run_id="workflow-1",
            ),
            Artifact(
                name="wf1-build-3.zip",
                size_bytes=100,
                created_at=now - timedelta(days=2),
                workflow_run_id="workflow-1",
            ),
            Artifact(
                name="wf1-build-4.zip",
                size_bytes=100,
                created_at=now - timedelta(days=1),
                workflow_run_id="workflow-1",
            ),
            # Workflow 2: 3 artifacts
            Artifact(
                name="wf2-build-1.zip",
                size_bytes=100,
                created_at=now - timedelta(days=3),
                workflow_run_id="workflow-2",
            ),
            Artifact(
                name="wf2-build-2.zip",
                size_bytes=100,
                created_at=now - timedelta(days=2),
                workflow_run_id="workflow-2",
            ),
            Artifact(
                name="wf2-build-3.zip",
                size_bytes=100,
                created_at=now - timedelta(days=1),
                workflow_run_id="workflow-2",
            ),
        ]
        plan = cleaner.plan_deletions(artifacts)

        # Should delete 2 from workflow-1 and 1 from workflow-2
        assert len(plan.to_delete) == 3
        assert len(plan.to_keep) == 4


class TestEmptyAndEdgeCases:
    """Test edge cases."""

    def test_empty_artifact_list(self):
        """Handle empty artifact list gracefully."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=10_000_000,
            keep_latest_n_per_workflow=5,
        )
        cleaner = ArtifactCleaner(policy)
        plan = cleaner.plan_deletions([])

        assert len(plan.to_delete) == 0
        assert len(plan.to_keep) == 0

    def test_all_artifacts_too_old(self):
        """Delete all artifacts if they exceed max age."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=10_000_000,
            keep_latest_n_per_workflow=5,
        )
        cleaner = ArtifactCleaner(policy)

        now = datetime.now()
        artifacts = [
            Artifact(
                name="old1.zip",
                size_bytes=1000,
                created_at=now - timedelta(days=100),
                workflow_run_id="run-1",
            ),
            Artifact(
                name="old2.zip",
                size_bytes=1000,
                created_at=now - timedelta(days=200),
                workflow_run_id="run-1",
            ),
        ]
        plan = cleaner.plan_deletions(artifacts)

        assert len(plan.to_delete) == 2
        assert len(plan.to_keep) == 0
