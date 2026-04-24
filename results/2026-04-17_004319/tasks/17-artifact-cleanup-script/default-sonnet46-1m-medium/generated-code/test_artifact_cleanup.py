"""
Artifact cleanup tests — written FIRST (TDD red phase).
Each test targets one unit of behavior; the module did not exist when these
were written, so they all fail until artifact_cleanup.py is created.
"""
import pytest
from datetime import datetime, timezone, timedelta
from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    DeletionPlan,
    apply_retention_policies,
    generate_deletion_plan,
    format_bytes,
)

# Fixed reference point so age-based tests are deterministic.
NOW = datetime(2026, 4, 20, 0, 0, 0, tzinfo=timezone.utc)

# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------

def make_artifact(name, size_mb, days_ago, workflow_run_id="run-001"):
    """Create an Artifact whose created_at is `days_ago` days before NOW."""
    created = NOW - timedelta(days=days_ago)
    return Artifact(
        name=name,
        size_bytes=size_mb * 1024 * 1024,
        created_at=created,
        workflow_run_id=workflow_run_id,
    )


# ---------------------------------------------------------------------------
# TDD iteration 1 — Artifact dataclass
# ---------------------------------------------------------------------------

class TestArtifactDataclass:
    def test_artifact_fields(self):
        a = Artifact(
            name="build-output",
            size_bytes=1024,
            created_at=NOW,
            workflow_run_id="run-42",
        )
        assert a.name == "build-output"
        assert a.size_bytes == 1024
        assert a.created_at == NOW
        assert a.workflow_run_id == "run-42"


# ---------------------------------------------------------------------------
# TDD iteration 2 — format_bytes helper
# ---------------------------------------------------------------------------

class TestFormatBytes:
    def test_bytes(self):
        assert format_bytes(512) == "512.0 B"

    def test_kilobytes(self):
        assert format_bytes(2048) == "2.0 KB"

    def test_megabytes(self):
        assert format_bytes(150 * 1024 * 1024) == "150.0 MB"

    def test_gigabytes(self):
        assert format_bytes(2 * 1024 * 1024 * 1024) == "2.0 GB"


# ---------------------------------------------------------------------------
# TDD iteration 3 — age-based retention policy
# ---------------------------------------------------------------------------

class TestAgPolicy:
    """Artifacts older than max_age_days should be marked for deletion."""

    def setup_method(self):
        self.artifacts = [
            make_artifact("old-1",  50, days_ago=109),  # created 2026-01-01
            make_artifact("old-2", 100, days_ago=64),   # created 2026-02-15
            make_artifact("new-1",  20, days_ago=10),   # created 2026-04-10
            make_artifact("new-2",  30, days_ago=2),    # created 2026-04-18
        ]
        self.policy = RetentionPolicy(max_age_days=30)

    def test_delete_count(self):
        _, to_delete = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert len(to_delete) == 2

    def test_retain_count(self):
        to_retain, _ = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert len(to_retain) == 2

    def test_correct_artifacts_deleted(self):
        _, to_delete = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        deleted_names = {a.name for a in to_delete}
        assert deleted_names == {"old-1", "old-2"}

    def test_space_reclaimed(self):
        plan = generate_deletion_plan(self.artifacts, self.policy, now=NOW)
        assert plan.space_reclaimed_bytes == (50 + 100) * 1024 * 1024


# ---------------------------------------------------------------------------
# TDD iteration 4 — size-based retention policy
# ---------------------------------------------------------------------------

class TestSizePolicy:
    """Delete oldest artifacts until total size is at or below max_total_size_bytes."""

    def setup_method(self):
        # Total: 180 MB, limit: 100 MB → delete oldest two (60+80 MB)
        self.artifacts = [
            make_artifact("artifact-1", 60, days_ago=19),  # oldest
            make_artifact("artifact-2", 80, days_ago=15),
            make_artifact("artifact-3", 40, days_ago=5),   # newest
        ]
        self.policy = RetentionPolicy(max_total_size_bytes=100 * 1024 * 1024)

    def test_delete_count(self):
        _, to_delete = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert len(to_delete) == 2

    def test_retain_count(self):
        to_retain, _ = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert len(to_retain) == 1

    def test_newest_retained(self):
        to_retain, _ = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert to_retain[0].name == "artifact-3"

    def test_space_reclaimed(self):
        plan = generate_deletion_plan(self.artifacts, self.policy, now=NOW)
        assert plan.space_reclaimed_bytes == (60 + 80) * 1024 * 1024


# ---------------------------------------------------------------------------
# TDD iteration 5 — keep-latest-N per workflow policy
# ---------------------------------------------------------------------------

class TestKeepLatestNPolicy:
    """Keep only the N newest artifacts per workflow_run_id."""

    def setup_method(self):
        # ci-build has 3 artifacts; keep 2 → delete oldest
        # integration-test has 2; keep 2 → delete none
        self.artifacts = [
            make_artifact("ci-build-a1", 10, days_ago=50, workflow_run_id="ci-build"),
            make_artifact("ci-build-a2", 20, days_ago=36, workflow_run_id="ci-build"),
            make_artifact("ci-build-a3", 30, days_ago=19, workflow_run_id="ci-build"),
            make_artifact("int-b1", 15, days_ago=41, workflow_run_id="integration-test"),
            make_artifact("int-b2", 25, days_ago=15, workflow_run_id="integration-test"),
        ]
        self.policy = RetentionPolicy(keep_latest_n=2)

    def test_delete_count(self):
        _, to_delete = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert len(to_delete) == 1

    def test_retain_count(self):
        to_retain, _ = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert len(to_retain) == 4

    def test_oldest_per_workflow_deleted(self):
        _, to_delete = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert to_delete[0].name == "ci-build-a1"

    def test_space_reclaimed(self):
        plan = generate_deletion_plan(self.artifacts, self.policy, now=NOW)
        assert plan.space_reclaimed_bytes == 10 * 1024 * 1024


# ---------------------------------------------------------------------------
# TDD iteration 6 — combined policies
# ---------------------------------------------------------------------------

class TestCombinedPolicies:
    """Age and keep-latest-N applied together; union of all deletions."""

    def setup_method(self):
        self.artifacts = [
            # These two are old → deleted by age policy
            make_artifact("old-ci-1", 20, days_ago=140, workflow_run_id="ci-build"),
            make_artifact("old-ci-2", 30, days_ago=95,  workflow_run_id="ci-build"),
            # Recent ci-build artifacts; keep_latest_n=2 → delete oldest of these
            make_artifact("new-ci-1", 15, days_ago=10, workflow_run_id="ci-build"),
            make_artifact("new-ci-2", 25, days_ago=5,  workflow_run_id="ci-build"),
            make_artifact("new-ci-3", 10, days_ago=2,  workflow_run_id="ci-build"),
            # Deploy artifacts; keep_latest_n=2 → delete oldest
            make_artifact("new-dep-1", 50, days_ago=8, workflow_run_id="deploy"),
            make_artifact("new-dep-2", 60, days_ago=3, workflow_run_id="deploy"),
            make_artifact("new-dep-3", 70, days_ago=1, workflow_run_id="deploy"),
        ]
        self.policy = RetentionPolicy(max_age_days=30, keep_latest_n=2)

    def test_delete_count(self):
        _, to_delete = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        # old-ci-1, old-ci-2 (age), new-ci-1 (keep-n ci-build), new-dep-1 (keep-n deploy)
        assert len(to_delete) == 4

    def test_retain_count(self):
        to_retain, _ = apply_retention_policies(self.artifacts, self.policy, now=NOW)
        assert len(to_retain) == 4

    def test_space_reclaimed(self):
        plan = generate_deletion_plan(self.artifacts, self.policy, now=NOW)
        expected_bytes = (20 + 30 + 15 + 50) * 1024 * 1024
        assert plan.space_reclaimed_bytes == expected_bytes


# ---------------------------------------------------------------------------
# TDD iteration 7 — dry-run mode
# ---------------------------------------------------------------------------

class TestDryRunMode:
    """dry_run flag is recorded in the plan and does not affect what is deleted."""

    def setup_method(self):
        self.artifacts = [
            make_artifact("old-1", 50, days_ago=109),
            make_artifact("new-1", 20, days_ago=10),
        ]
        self.policy = RetentionPolicy(max_age_days=30)

    def test_dry_run_plan_records_flag(self):
        plan = generate_deletion_plan(self.artifacts, self.policy, dry_run=True, now=NOW)
        assert plan.dry_run is True

    def test_non_dry_run_plan_records_flag(self):
        plan = generate_deletion_plan(self.artifacts, self.policy, dry_run=False, now=NOW)
        assert plan.dry_run is False

    def test_dry_run_same_deletions_as_live(self):
        dry_plan  = generate_deletion_plan(self.artifacts, self.policy, dry_run=True,  now=NOW)
        live_plan = generate_deletion_plan(self.artifacts, self.policy, dry_run=False, now=NOW)
        assert dry_plan.deleted_count  == live_plan.deleted_count
        assert dry_plan.retained_count == live_plan.retained_count
        assert dry_plan.space_reclaimed_bytes == live_plan.space_reclaimed_bytes


# ---------------------------------------------------------------------------
# TDD iteration 8 — no artifacts / empty policy
# ---------------------------------------------------------------------------

class TestEdgeCases:
    def test_empty_artifact_list(self):
        plan = generate_deletion_plan([], RetentionPolicy(max_age_days=30), now=NOW)
        assert plan.deleted_count == 0
        assert plan.retained_count == 0
        assert plan.space_reclaimed_bytes == 0

    def test_no_policy_retains_all(self):
        artifacts = [make_artifact("a", 10, days_ago=5)]
        plan = generate_deletion_plan(artifacts, RetentionPolicy(), now=NOW)
        assert plan.deleted_count == 0
        assert plan.retained_count == 1

    def test_all_artifacts_qualify_for_deletion_by_age(self):
        artifacts = [
            make_artifact("a", 10, days_ago=100),
            make_artifact("b", 20, days_ago=200),
        ]
        plan = generate_deletion_plan(artifacts, RetentionPolicy(max_age_days=30), now=NOW)
        assert plan.deleted_count == 2
        assert plan.retained_count == 0
