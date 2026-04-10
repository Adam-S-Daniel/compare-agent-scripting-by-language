# test_artifact_cleanup.py
#
# TDD approach: tests are written FIRST (RED), then the implementation is
# written to make them pass (GREEN), then refactored.
#
# Test coverage:
#   1. Artifact dataclass construction
#   2. max_age policy
#   3. keep_latest_n policy
#   4. max_total_size policy
#   5. Combined policies
#   6. Dry-run mode (no side effects)
#   7. Report formatting
#   8. CLI integration (JSON input/output)

import json
import pytest
from datetime import date, timedelta
from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    DeletionPlan,
    apply_policies,
    format_size,
    generate_report,
    load_artifacts_from_dict,
)

# ── Shared test date so tests are deterministic ──────────────────────────────
TODAY = date(2026, 4, 10)


def days_ago(n: int) -> date:
    return TODAY - timedelta(days=n)


# ── Fixture helpers ───────────────────────────────────────────────────────────

def make_artifact(name: str, size_mb: float, days_old: int, run_id: str = "run-001") -> Artifact:
    return Artifact(
        name=name,
        size_bytes=int(size_mb * 1024 * 1024),
        created_at=days_ago(days_old),
        workflow_run_id=run_id,
    )


# ─────────────────────────────────────────────────────────────────────────────
# RED 1 → Artifact dataclass exists and is constructable
# ─────────────────────────────────────────────────────────────────────────────

class TestArtifact:
    def test_artifact_construction(self):
        a = Artifact(
            name="my-artifact",
            size_bytes=1024,
            created_at=date(2026, 1, 1),
            workflow_run_id="run-42",
        )
        assert a.name == "my-artifact"
        assert a.size_bytes == 1024
        assert a.created_at == date(2026, 1, 1)
        assert a.workflow_run_id == "run-42"

    def test_artifact_from_dict(self):
        data = {
            "name": "artifact-x",
            "size_bytes": 2048,
            "created_at": "2026-03-15",
            "workflow_run_id": "run-99",
        }
        artifacts = load_artifacts_from_dict([data])
        assert len(artifacts) == 1
        assert artifacts[0].name == "artifact-x"
        assert artifacts[0].created_at == date(2026, 3, 15)


# ─────────────────────────────────────────────────────────────────────────────
# RED 2 → max_age policy: delete artifacts older than N days
# ─────────────────────────────────────────────────────────────────────────────

class TestMaxAgePolicy:
    def test_artifacts_within_max_age_are_retained(self):
        artifacts = [make_artifact("new", 10, days_old=5)]
        policy = RetentionPolicy(max_age_days=20)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert len(plan.to_retain) == 1
        assert len(plan.to_delete) == 0

    def test_artifacts_older_than_max_age_are_deleted(self):
        artifacts = [make_artifact("old", 10, days_old=30)]
        policy = RetentionPolicy(max_age_days=20)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert len(plan.to_delete) == 1
        assert plan.to_delete[0].name == "old"

    def test_artifact_exactly_at_max_age_boundary_is_retained(self):
        # An artifact that is exactly max_age_days old is NOT yet expired
        artifacts = [make_artifact("boundary", 10, days_old=20)]
        policy = RetentionPolicy(max_age_days=20)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert len(plan.to_retain) == 1

    def test_mixed_ages_correctly_partitioned(self):
        artifacts = [
            make_artifact("old-1", 10, days_old=40),
            make_artifact("old-2", 20, days_old=26),
            make_artifact("new-1", 30, days_old=9),
            make_artifact("new-2", 5, days_old=2),
        ]
        policy = RetentionPolicy(max_age_days=20)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert {a.name for a in plan.to_delete} == {"old-1", "old-2"}
        assert {a.name for a in plan.to_retain} == {"new-1", "new-2"}


# ─────────────────────────────────────────────────────────────────────────────
# RED 3 → keep_latest_n policy: per-workflow retention
# ─────────────────────────────────────────────────────────────────────────────

class TestKeepLatestNPolicy:
    def test_keep_one_per_workflow_deletes_older(self):
        artifacts = [
            make_artifact("v1", 10, days_old=10, run_id="wf-A"),
            make_artifact("v2", 10, days_old=5,  run_id="wf-A"),
            make_artifact("v3", 10, days_old=1,  run_id="wf-A"),
        ]
        policy = RetentionPolicy(keep_latest_n=1)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert {a.name for a in plan.to_delete} == {"v1", "v2"}
        assert {a.name for a in plan.to_retain} == {"v3"}

    def test_keep_two_per_workflow(self):
        artifacts = [
            make_artifact("v1", 10, days_old=10, run_id="wf-A"),
            make_artifact("v2", 10, days_old=5,  run_id="wf-A"),
            make_artifact("v3", 10, days_old=1,  run_id="wf-A"),
        ]
        policy = RetentionPolicy(keep_latest_n=2)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert {a.name for a in plan.to_delete} == {"v1"}
        assert {a.name for a in plan.to_retain} == {"v2", "v3"}

    def test_different_workflows_are_independent(self):
        artifacts = [
            make_artifact("wf-a-v1", 10, days_old=10, run_id="wf-A"),
            make_artifact("wf-a-v2", 10, days_old=3,  run_id="wf-A"),
            make_artifact("wf-b-v1", 10, days_old=8,  run_id="wf-B"),
            make_artifact("wf-b-v2", 10, days_old=2,  run_id="wf-B"),
        ]
        policy = RetentionPolicy(keep_latest_n=1)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert {a.name for a in plan.to_delete} == {"wf-a-v1", "wf-b-v1"}
        assert {a.name for a in plan.to_retain} == {"wf-a-v2", "wf-b-v2"}

    def test_fewer_artifacts_than_n_retains_all(self):
        artifacts = [make_artifact("only", 10, days_old=5, run_id="wf-A")]
        policy = RetentionPolicy(keep_latest_n=3)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert len(plan.to_retain) == 1
        assert len(plan.to_delete) == 0


# ─────────────────────────────────────────────────────────────────────────────
# RED 4 → max_total_size policy: delete oldest first until under limit
# ─────────────────────────────────────────────────────────────────────────────

class TestMaxTotalSizePolicy:
    def test_total_size_within_limit_retains_all(self):
        artifacts = [
            make_artifact("a", 10, days_old=5),
            make_artifact("b", 10, days_old=3),
        ]
        policy = RetentionPolicy(max_total_size_bytes=50 * 1024 * 1024)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert len(plan.to_retain) == 2
        assert len(plan.to_delete) == 0

    def test_total_size_over_limit_deletes_oldest_first(self):
        artifacts = [
            make_artifact("oldest", 30, days_old=20),
            make_artifact("middle", 20, days_old=10),
            make_artifact("newest", 10, days_old=1),
        ]
        # Total = 60MB, limit = 40MB → delete oldest (30MB) → 30MB remaining, under limit
        policy = RetentionPolicy(max_total_size_bytes=40 * 1024 * 1024)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert {a.name for a in plan.to_delete} == {"oldest"}
        assert {a.name for a in plan.to_retain} == {"middle", "newest"}

    def test_deletes_multiple_until_under_limit(self):
        artifacts = [
            make_artifact("v1", 20, days_old=30),
            make_artifact("v2", 20, days_old=20),
            make_artifact("v3", 20, days_old=10),
        ]
        # Total = 60MB, limit = 25MB → delete v1 (40MB left), delete v2 (20MB left), done
        policy = RetentionPolicy(max_total_size_bytes=25 * 1024 * 1024)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert {a.name for a in plan.to_delete} == {"v1", "v2"}
        assert {a.name for a in plan.to_retain} == {"v3"}


# ─────────────────────────────────────────────────────────────────────────────
# RED 5 → Combined policies
# ─────────────────────────────────────────────────────────────────────────────

class TestCombinedPolicies:
    def test_age_and_keep_latest_n_combined(self):
        # old-v1: 40 days old, wf-A  → expired by age
        # old-v2: 25 days old, wf-A  → expired by age
        # new-v1:  5 days old, wf-A  → retained
        # new-v2:  2 days old, wf-A  → retained
        # Both new ones from same workflow, keep_latest_n=1 → delete new-v1
        artifacts = [
            make_artifact("old-v1", 10, days_old=40, run_id="wf-A"),
            make_artifact("old-v2", 10, days_old=25, run_id="wf-A"),
            make_artifact("new-v1", 10, days_old=5,  run_id="wf-A"),
            make_artifact("new-v2", 10, days_old=2,  run_id="wf-A"),
        ]
        policy = RetentionPolicy(max_age_days=20, keep_latest_n=1)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert {a.name for a in plan.to_delete} == {"old-v1", "old-v2", "new-v1"}
        assert {a.name for a in plan.to_retain} == {"new-v2"}

    def test_no_policies_retains_all(self):
        artifacts = [
            make_artifact("a", 10, days_old=100),
            make_artifact("b", 10, days_old=200),
        ]
        policy = RetentionPolicy()
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert len(plan.to_retain) == 2
        assert len(plan.to_delete) == 0


# ─────────────────────────────────────────────────────────────────────────────
# RED 6 → DeletionPlan summary calculations
# ─────────────────────────────────────────────────────────────────────────────

class TestDeletionPlan:
    def test_space_reclaimed_is_sum_of_deleted_sizes(self):
        artifacts = [
            make_artifact("old", 30, days_old=40),
            make_artifact("new", 10, days_old=1),
        ]
        policy = RetentionPolicy(max_age_days=20)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert plan.space_reclaimed_bytes == 30 * 1024 * 1024

    def test_space_reclaimed_zero_when_nothing_deleted(self):
        artifacts = [make_artifact("new", 10, days_old=1)]
        policy = RetentionPolicy(max_age_days=20)
        plan = apply_policies(artifacts, policy, today=TODAY)
        assert plan.space_reclaimed_bytes == 0


# ─────────────────────────────────────────────────────────────────────────────
# RED 7 → format_size helper
# ─────────────────────────────────────────────────────────────────────────────

class TestFormatSize:
    def test_bytes(self):
        assert format_size(512) == "512 B"

    def test_kilobytes(self):
        assert format_size(2048) == "2.0 KB"

    def test_megabytes(self):
        assert format_size(10 * 1024 * 1024) == "10.0 MB"

    def test_gigabytes(self):
        assert format_size(2 * 1024 * 1024 * 1024) == "2.0 GB"


# ─────────────────────────────────────────────────────────────────────────────
# RED 8 → generate_report output format
# ─────────────────────────────────────────────────────────────────────────────

class TestGenerateReport:
    def _make_plan(self):
        artifacts = [
            make_artifact("old-logs", 10, days_old=40),
            make_artifact("new-build", 30, days_old=5),
        ]
        policy = RetentionPolicy(max_age_days=20)
        plan = apply_policies(artifacts, policy, today=TODAY)
        return plan, policy

    def test_report_contains_dry_run_mode(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "DRY RUN" in report

    def test_report_contains_execute_mode(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=False)
        assert "EXECUTE" in report

    def test_report_shows_deleted_count(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "Deleted: 1" in report

    def test_report_shows_retained_count(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "Retained: 1" in report

    def test_report_shows_space_reclaimed(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "Space reclaimed: 10.0 MB" in report

    def test_report_shows_total_artifacts(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "Total artifacts: 2" in report

    def test_report_shows_policy_info(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "max_age=20d" in report

    def test_report_lists_deleted_artifact_names(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "old-logs" in report

    def test_report_lists_retained_artifact_names(self):
        plan, policy = self._make_plan()
        report = generate_report(plan, policy, dry_run=True)
        assert "new-build" in report
