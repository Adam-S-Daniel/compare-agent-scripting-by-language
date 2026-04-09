"""
Artifact Cleanup Policy Tests — TDD Red/Green/Refactor

Cycle order:
  1. Age-based retention          → apply_age_policy
  2. Size-based retention         → apply_size_policy
  3. Keep-latest-N per workflow   → apply_keep_latest_n_policy
  4. Combined policy application  → apply_retention_policies
  5. Deletion plan generation     → generate_deletion_plan / format_plan

Each test was written *before* its corresponding implementation (RED phase).
The implementation was then added to make it pass (GREEN phase).
"""

import pytest
from datetime import datetime, timezone

# RED: these imports fail until artifact_cleanup.py is created
from artifact_cleanup import (
    apply_age_policy,
    apply_size_policy,
    apply_keep_latest_n_policy,
    apply_retention_policies,
    generate_deletion_plan,
    format_plan,
)

# Fixed reference date so tests are deterministic regardless of when they run.
REF_DATE = datetime(2026, 4, 9, 0, 0, 0, tzinfo=timezone.utc)


# ─────────────────────────────────────────────────────────────
# CYCLE 1 — Age-based retention
# RED: test written first; artifact_cleanup.py didn't exist yet.
# GREEN: implemented parse_date + apply_age_policy.
# REFACTOR: extracted parse_date as a module-level helper.
# ─────────────────────────────────────────────────────────────

class TestAgePolicy:
    def _artifact(self, name, created_at, size=100, run_id="r0", wf="CI"):
        return {
            "name": name,
            "size": size,
            "created_at": created_at,
            "workflow_run_id": run_id,
            "workflow_name": wf,
        }

    def test_old_artifact_is_marked_for_deletion(self):
        """Artifact older than max_age_days must appear in the deletion set."""
        artifacts = [self._artifact("old", "2025-01-01T00:00:00+00:00")]
        result = apply_age_policy(artifacts, max_age_days=30, reference_date=REF_DATE)
        assert "old" in result

    def test_recent_artifact_is_retained(self):
        """Artifact younger than max_age_days must NOT appear in the deletion set."""
        artifacts = [self._artifact("new", "2026-04-07T00:00:00+00:00")]
        result = apply_age_policy(artifacts, max_age_days=30, reference_date=REF_DATE)
        assert "new" not in result

    def test_artifact_exactly_at_age_limit_is_retained(self):
        """Artifact created exactly max_age_days ago should be retained (boundary)."""
        # REF_DATE − 30 days = 2026-03-10
        artifacts = [self._artifact("boundary", "2026-03-10T00:00:00+00:00")]
        result = apply_age_policy(artifacts, max_age_days=30, reference_date=REF_DATE)
        assert "boundary" not in result

    def test_mixed_ages_only_old_ones_deleted(self):
        """Only artifacts that exceed max_age_days are returned."""
        artifacts = [
            self._artifact("too-old",  "2025-12-01T00:00:00+00:00"),
            self._artifact("just-fine", "2026-04-01T00:00:00+00:00"),
        ]
        result = apply_age_policy(artifacts, max_age_days=30, reference_date=REF_DATE)
        assert "too-old" in result
        assert "just-fine" not in result

    def test_empty_list_returns_empty_set(self):
        result = apply_age_policy([], max_age_days=30, reference_date=REF_DATE)
        assert result == set()


# ─────────────────────────────────────────────────────────────
# CYCLE 2 — Size-based retention
# RED: tests written; apply_size_policy not yet implemented.
# GREEN: implemented apply_size_policy (sort-oldest-first, pop until under limit).
# REFACTOR: unified sort key via parse_date.
# ─────────────────────────────────────────────────────────────

class TestSizePolicy:
    def _artifact(self, name, size, created_at):
        return {
            "name": name,
            "size": size,
            "created_at": created_at,
            "workflow_run_id": f"r-{name}",
            "workflow_name": "CI",
        }

    def test_under_limit_nothing_deleted(self):
        artifacts = [
            self._artifact("a", 100, "2026-04-01T00:00:00+00:00"),
            self._artifact("b", 100, "2026-04-02T00:00:00+00:00"),
        ]
        result = apply_size_policy(artifacts, max_total_size_bytes=500)
        assert len(result) == 0

    def test_exactly_at_limit_nothing_deleted(self):
        artifacts = [self._artifact("a", 100, "2026-04-01T00:00:00+00:00")]
        result = apply_size_policy(artifacts, max_total_size_bytes=100)
        assert len(result) == 0

    def test_over_limit_deletes_oldest_first(self):
        """Total 300 bytes, limit 150 → delete oldest two."""
        artifacts = [
            self._artifact("newest", 100, "2026-04-05T00:00:00+00:00"),
            self._artifact("middle", 100, "2026-04-03T00:00:00+00:00"),
            self._artifact("oldest", 100, "2026-04-01T00:00:00+00:00"),
        ]
        result = apply_size_policy(artifacts, max_total_size_bytes=150)
        assert "oldest" in result
        assert "middle" in result
        assert "newest" not in result

    def test_deletes_minimum_required(self):
        """Stops as soon as total drops below limit (doesn't over-delete)."""
        artifacts = [
            self._artifact("big-new",  80, "2026-04-05T00:00:00+00:00"),
            self._artifact("big-old",  80, "2026-04-03T00:00:00+00:00"),
            self._artifact("tiny-old", 10, "2026-04-01T00:00:00+00:00"),
        ]
        # Total = 170, limit = 90. Delete tiny-old (10): 160 > 90.
        # Delete big-old (80): 80 ≤ 90. Stop. big-new retained.
        result = apply_size_policy(artifacts, max_total_size_bytes=90)
        assert "tiny-old" in result
        assert "big-old" in result
        assert "big-new" not in result


# ─────────────────────────────────────────────────────────────
# CYCLE 3 — Keep-latest-N per workflow
# RED: tests written; apply_keep_latest_n_policy not yet implemented.
# GREEN: implemented grouping by workflow_name + run_id, sort by latest
#        artifact date in the run, keep top-N runs.
# REFACTOR: extracted run_date helper inside the function.
# ─────────────────────────────────────────────────────────────

class TestKeepLatestNPolicy:
    def _artifact(self, name, run_id, wf, created_at, size=100):
        return {
            "name": name,
            "size": size,
            "created_at": created_at,
            "workflow_run_id": run_id,
            "workflow_name": wf,
        }

    def test_within_limit_nothing_deleted(self):
        artifacts = [
            self._artifact("a1", "run-1", "CI", "2026-04-01T00:00:00+00:00"),
            self._artifact("a2", "run-2", "CI", "2026-04-05T00:00:00+00:00"),
        ]
        result = apply_keep_latest_n_policy(artifacts, keep_latest_n=3)
        assert len(result) == 0

    def test_over_limit_deletes_oldest_runs(self):
        """4 runs, keep=2 → delete artifacts from 2 oldest runs."""
        artifacts = [
            self._artifact("r1-art", "run-1", "CI", "2026-04-01T00:00:00+00:00"),
            self._artifact("r2-art", "run-2", "CI", "2026-04-03T00:00:00+00:00"),
            self._artifact("r3-art", "run-3", "CI", "2026-04-05T00:00:00+00:00"),
            self._artifact("r4-art", "run-4", "CI", "2026-04-07T00:00:00+00:00"),
        ]
        result = apply_keep_latest_n_policy(artifacts, keep_latest_n=2)
        assert "r1-art" in result
        assert "r2-art" in result
        assert "r3-art" not in result
        assert "r4-art" not in result

    def test_multiple_workflows_counted_independently(self):
        """Keep-N applies per workflow, not globally."""
        artifacts = [
            self._artifact("ci-old",     "ci-1",     "CI",     "2026-04-01T00:00:00+00:00"),
            self._artifact("ci-new",     "ci-2",     "CI",     "2026-04-07T00:00:00+00:00"),
            self._artifact("dep-old",    "dep-1",    "Deploy", "2026-04-01T00:00:00+00:00"),
            self._artifact("dep-new",    "dep-2",    "Deploy", "2026-04-07T00:00:00+00:00"),
        ]
        result = apply_keep_latest_n_policy(artifacts, keep_latest_n=1)
        assert "ci-old"  in result
        assert "ci-new"  not in result
        assert "dep-old" in result
        assert "dep-new" not in result

    def test_multiple_artifacts_per_run_deleted_together(self):
        """All artifacts belonging to a deleted run are removed."""
        artifacts = [
            self._artifact("r1-a1", "run-1", "CI", "2026-04-01T00:00:00+00:00"),
            self._artifact("r1-a2", "run-1", "CI", "2026-04-01T06:00:00+00:00", size=200),
            self._artifact("r2-a1", "run-2", "CI", "2026-04-05T00:00:00+00:00"),
        ]
        result = apply_keep_latest_n_policy(artifacts, keep_latest_n=1)
        assert "r1-a1" in result
        assert "r1-a2" in result
        assert "r2-a1" not in result


# ─────────────────────────────────────────────────────────────
# CYCLE 4 — Combined policy application
# RED: tests written; apply_retention_policies not yet implemented.
# GREEN: implemented sequential application (age → size → keep-N).
# REFACTOR: simplified by reusing the individual policy functions.
# ─────────────────────────────────────────────────────────────

class TestCombinedPolicies:
    def _a(self, name, size, created_at, run_id, wf="CI"):
        return {
            "name": name,
            "size": size,
            "created_at": created_at,
            "workflow_run_id": run_id,
            "workflow_name": wf,
        }

    def test_age_and_size_combined(self):
        """Age policy fires first; size policy then applies to remaining."""
        artifacts = [
            self._a("very-old",         100, "2025-01-01T00:00:00+00:00", "r1"),
            self._a("oldest-remaining",  50, "2026-04-01T00:00:00+00:00", "r2"),
            self._a("newest-remaining",  50, "2026-04-07T00:00:00+00:00", "r3"),
        ]
        # After age: delete very-old. Remaining = 100 bytes (50+50).
        # Size limit 60: 100 > 60 → delete oldest-remaining (50): 50 ≤ 60.
        result = apply_retention_policies(
            artifacts,
            {"max_age_days": 30, "max_total_size_bytes": 60},
            reference_date=REF_DATE,
        )
        assert len(result["to_delete"]) == 2
        assert len(result["to_retain"]) == 1
        assert result["to_retain"][0]["name"] == "newest-remaining"

    def test_all_three_policies_combined(self):
        """Verifies the exact combined fixture data expectations."""
        artifacts = [
            self._a("ancient",    1000, "2025-01-01T00:00:00+00:00", "r1", "Deploy"),
            self._a("big-new",     500, "2026-04-08T00:00:00+00:00", "r2", "Deploy"),
            self._a("big-old",     500, "2026-04-02T00:00:00+00:00", "r3", "Deploy"),
            self._a("extra-run",   100, "2026-04-04T00:00:00+00:00", "r4", "CI"),
            self._a("latest-run",  100, "2026-04-08T00:00:00+00:00", "r5", "CI"),
        ]
        # Age: delete ancient (>30 days)
        # Size limit 1300: remaining = 1200 ≤ 1300, nothing extra
        # Keep N=1: Deploy keeps r2 (big-new), deletes r3 (big-old)
        #            CI     keeps r5 (latest-run), deletes r4 (extra-run)
        result = apply_retention_policies(
            artifacts,
            {"max_age_days": 30, "max_total_size_bytes": 1300, "keep_latest_n_per_workflow": 1},
            reference_date=REF_DATE,
        )
        deleted = {a["name"] for a in result["to_delete"]}
        retained = {a["name"] for a in result["to_retain"]}
        assert deleted   == {"ancient", "big-old", "extra-run"}
        assert retained  == {"big-new", "latest-run"}

    def test_empty_artifacts_returns_empty_plan(self):
        result = apply_retention_policies([], {"max_age_days": 30}, reference_date=REF_DATE)
        assert result["to_delete"] == []
        assert result["to_retain"] == []

    def test_no_policies_retains_everything(self):
        artifacts = [
            self._a("a", 100, "2025-01-01T00:00:00+00:00", "r1"),
        ]
        result = apply_retention_policies(artifacts, {}, reference_date=REF_DATE)
        assert result["to_delete"] == []
        assert len(result["to_retain"]) == 1


# ─────────────────────────────────────────────────────────────
# CYCLE 5 — Deletion plan generation & formatting
# RED: tests written; generate_deletion_plan / format_plan not yet implemented.
# GREEN: implemented summary calculation and human-readable formatter.
# REFACTOR: added SUMMARY_LINE marker for machine-readable harness parsing.
# ─────────────────────────────────────────────────────────────

class TestDeletionPlan:
    def _old_artifact(self, name="old", size=1048576):
        return {
            "name": name,
            "size": size,
            "created_at": "2025-01-01T00:00:00+00:00",
            "workflow_run_id": "r1",
            "workflow_name": "CI",
        }

    def _new_artifact(self, name="new", size=2097152):
        return {
            "name": name,
            "size": size,
            "created_at": "2026-04-08T00:00:00+00:00",
            "workflow_run_id": "r2",
            "workflow_name": "CI",
        }

    def test_summary_counts_are_correct(self):
        artifacts = [self._old_artifact(), self._new_artifact()]
        result = apply_retention_policies(artifacts, {"max_age_days": 30}, REF_DATE)
        plan = generate_deletion_plan(result)
        s = plan["summary"]
        assert s["total_artifacts"]      == 2
        assert s["artifacts_to_delete"]  == 1
        assert s["artifacts_to_retain"]  == 1
        assert s["space_reclaimed_bytes"] == 1048576
        assert s["space_reclaimed_mb"]   == 1.0

    def test_dry_run_flag_propagates_to_plan(self):
        result = apply_retention_policies([], {}, REF_DATE)
        plan = generate_deletion_plan(result, dry_run=True)
        assert plan["dry_run"] is True

    def test_plan_includes_deletion_reasons(self):
        result = apply_retention_policies(
            [self._old_artifact()], {"max_age_days": 30}, REF_DATE
        )
        plan = generate_deletion_plan(result)
        assert len(plan["to_delete"]) == 1
        assert len(plan["to_delete"][0]["reasons"]) > 0

    def test_format_plan_shows_dry_run_header(self):
        result = apply_retention_policies([], {}, REF_DATE)
        plan = generate_deletion_plan(result, dry_run=True)
        formatted = format_plan(plan)
        assert "DRY RUN" in formatted

    def test_format_plan_shows_space_reclaimed_in_mb(self):
        result = apply_retention_policies(
            [self._old_artifact(size=1048576)], {"max_age_days": 30}, REF_DATE
        )
        plan = generate_deletion_plan(result)
        formatted = format_plan(plan)
        assert "1.0 MB" in formatted

    def test_format_plan_contains_machine_readable_summary_line(self):
        """The ARTIFACT_CLEANUP_SUMMARY line lets the harness assert exact values."""
        result = apply_retention_policies(
            [self._old_artifact(), self._new_artifact()], {"max_age_days": 30}, REF_DATE
        )
        plan = generate_deletion_plan(result, dry_run=False)
        formatted = format_plan(plan)
        assert "ARTIFACT_CLEANUP_SUMMARY:" in formatted
        # Harness checks for specific key=value pairs on this line
        assert "deleted=1" in formatted
        assert "retained=1" in formatted
        assert "space_bytes=1048576" in formatted
        assert "dry_run=false" in formatted
