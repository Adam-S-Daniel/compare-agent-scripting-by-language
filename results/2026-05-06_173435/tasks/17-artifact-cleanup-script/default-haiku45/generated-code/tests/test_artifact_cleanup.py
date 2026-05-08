"""
Tests for artifact cleanup script using red/green TDD methodology.
Each test case is paired with minimal implementation code.
"""
import unittest
from datetime import datetime, timedelta
from artifact_cleanup import (
    Artifact, RetentionPolicy, ArtifactCleanup, DeletionPlan
)


class TestArtifactModel(unittest.TestCase):
    """Test the Artifact data model."""

    def test_artifact_creation(self):
        """FAILING TEST: Artifact should store name, size, creation date, and run ID."""
        created = datetime(2026, 5, 1, 12, 0, 0)
        artifact = Artifact(
            name="build-output.zip",
            size_bytes=1024 * 1024,  # 1 MB
            created_at=created,
            workflow_run_id="run-123"
        )
        self.assertEqual(artifact.name, "build-output.zip")
        self.assertEqual(artifact.size_bytes, 1024 * 1024)
        self.assertEqual(artifact.created_at, created)
        self.assertEqual(artifact.workflow_run_id, "run-123")


class TestRetentionPolicy(unittest.TestCase):
    """Test retention policy application."""

    def test_policy_creation(self):
        """FAILING TEST: RetentionPolicy should accept max_age_days, max_total_size_bytes, and keep_latest_n."""
        policy = RetentionPolicy(
            max_age_days=30,
            max_total_size_bytes=1024 * 1024 * 1024,  # 1 GB
            keep_latest_n=5
        )
        self.assertEqual(policy.max_age_days, 30)
        self.assertEqual(policy.max_total_size_bytes, 1024 * 1024 * 1024)
        self.assertEqual(policy.keep_latest_n, 5)


class TestArtifactCleanup(unittest.TestCase):
    """Test artifact cleanup logic."""

    def setUp(self):
        """Set up test fixtures."""
        now = datetime.now()
        self.now = now
        # Create artifacts with varied dates, sizes, and run IDs
        self.artifacts = [
            Artifact("app-run-1.tar", 500 * 1024, now - timedelta(days=10), "run-1"),
            Artifact("app-run-2.tar", 600 * 1024, now - timedelta(days=5), "run-1"),
            Artifact("app-run-3.tar", 700 * 1024, now - timedelta(days=2), "run-1"),
            Artifact("db-run-1.sql", 800 * 1024, now - timedelta(days=45), "run-2"),
            Artifact("db-run-2.sql", 900 * 1024, now - timedelta(days=40), "run-2"),
            Artifact("db-run-3.sql", 1000 * 1024, now, "run-2"),
        ]

    def test_cleanup_initialization(self):
        """FAILING TEST: ArtifactCleanup should initialize with artifacts and policy."""
        policy = RetentionPolicy(max_age_days=30, max_total_size_bytes=5 * 1024 * 1024, keep_latest_n=2)
        cleanup = ArtifactCleanup(self.artifacts, policy)
        self.assertEqual(len(cleanup.artifacts), 6)
        self.assertEqual(cleanup.policy.max_age_days, 30)

    def test_delete_by_age(self):
        """FAILING TEST: ArtifactCleanup should delete artifacts older than max_age_days."""
        policy = RetentionPolicy(max_age_days=30, max_total_size_bytes=float('inf'), keep_latest_n=float('inf'))
        cleanup = ArtifactCleanup(self.artifacts, policy)
        plan = cleanup.generate_plan()
        # db-run-1.sql is 45 days old, should be deleted
        deleted_names = [a.name for a in plan.artifacts_to_delete]
        self.assertIn("db-run-1.sql", deleted_names)
        # app-run-3.tar is 2 days old, should not be deleted
        retained_names = [a.name for a in plan.artifacts_to_retain]
        self.assertIn("app-run-3.tar", retained_names)

    def test_keep_latest_n_per_workflow(self):
        """FAILING TEST: Should keep only the latest N artifacts per workflow run ID."""
        policy = RetentionPolicy(max_age_days=float('inf'), max_total_size_bytes=float('inf'), keep_latest_n=2)
        cleanup = ArtifactCleanup(self.artifacts, policy)
        plan = cleanup.generate_plan()

        # For run-1: should keep 2 latest (run-2.tar, run-3.tar), delete run-1.tar
        deleted_names = [a.name for a in plan.artifacts_to_delete]
        self.assertIn("app-run-1.tar", deleted_names)

        retained_names = [a.name for a in plan.artifacts_to_retain]
        self.assertIn("app-run-2.tar", retained_names)
        self.assertIn("app-run-3.tar", retained_names)

    def test_max_total_size_enforcement(self):
        """FAILING TEST: Should delete oldest artifacts until total size is under limit."""
        # Set limit to 3 MB (less than total)
        policy = RetentionPolicy(max_age_days=float('inf'), max_total_size_bytes=3 * 1024 * 1024, keep_latest_n=float('inf'))
        cleanup = ArtifactCleanup(self.artifacts, policy)
        plan = cleanup.generate_plan()

        # Total retained size should be <= 3 MB
        total_size = sum(a.size_bytes for a in plan.artifacts_to_retain)
        self.assertLessEqual(total_size, 3 * 1024 * 1024)

    def test_deletion_plan_summary(self):
        """FAILING TEST: DeletionPlan should provide summary metrics."""
        policy = RetentionPolicy(max_age_days=30, max_total_size_bytes=5 * 1024 * 1024, keep_latest_n=2)
        cleanup = ArtifactCleanup(self.artifacts, policy)
        plan = cleanup.generate_plan()

        # Check summary exists and has expected fields
        self.assertIsNotNone(plan.summary)
        self.assertGreater(plan.summary['space_reclaimed_bytes'], 0)
        self.assertEqual(plan.summary['total_artifacts'], 6)
        self.assertEqual(
            plan.summary['artifacts_to_delete'] + plan.summary['artifacts_to_retain'],
            6
        )


class TestDryRunMode(unittest.TestCase):
    """Test dry-run mode functionality."""

    def test_dry_run_generates_plan_without_deleting(self):
        """FAILING TEST: Dry-run should generate a plan but not actually delete files."""
        now = datetime.now()
        artifacts = [
            Artifact("file1.tar", 1024 * 1024, now - timedelta(days=50), "run-1"),
            Artifact("file2.tar", 2048 * 1024, now - timedelta(days=5), "run-1"),
        ]
        policy = RetentionPolicy(max_age_days=30, max_total_size_bytes=float('inf'), keep_latest_n=float('inf'))
        cleanup = ArtifactCleanup(artifacts, policy, dry_run=True)
        plan = cleanup.generate_plan()

        # Should have deletion plan
        self.assertEqual(len(plan.artifacts_to_delete), 1)
        self.assertEqual(plan.artifacts_to_delete[0].name, "file1.tar")
        # Dry run flag should be set
        self.assertTrue(plan.dry_run)


class TestErrorHandling(unittest.TestCase):
    """Test error handling."""

    def test_invalid_policy_raises_error(self):
        """FAILING TEST: Should raise error for invalid policy values."""
        with self.assertRaises(ValueError):
            RetentionPolicy(max_age_days=-1, max_total_size_bytes=1024, keep_latest_n=5)

    def test_empty_artifact_list(self):
        """FAILING TEST: Should handle empty artifact list gracefully."""
        policy = RetentionPolicy(max_age_days=30, max_total_size_bytes=1024 * 1024, keep_latest_n=2)
        cleanup = ArtifactCleanup([], policy)
        plan = cleanup.generate_plan()

        self.assertEqual(len(plan.artifacts_to_delete), 0)
        self.assertEqual(len(plan.artifacts_to_retain), 0)
        self.assertEqual(plan.summary['space_reclaimed_bytes'], 0)


if __name__ == '__main__':
    unittest.main()
