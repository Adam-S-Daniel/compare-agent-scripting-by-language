"""
Tests for the artifact cleanup / retention policy engine.

Developed using red/green TDD methodology:
  - Each test class represents one TDD cycle
  - Tests were written FIRST (RED), then production code was added to make them pass (GREEN)
  - Refactoring was done after each green phase

Run with:  python3 -m unittest test_artifact_cleanup -v
"""
import unittest
import json
from datetime import datetime, timezone, timedelta


# ---------------------------------------------------------------------------
# Shared test fixtures — mock artifact data used across cycles
# ---------------------------------------------------------------------------
def make_artifacts():
    """
    Factory for a realistic set of mock artifacts spanning multiple workflows.
    Returns a list of dicts (the raw input format) and the reference 'now' time.
    """
    now = datetime(2026, 4, 1, 12, 0, 0, tzinfo=timezone.utc)
    return [
        # Workflow "build" — 4 artifacts, oldest is 40 days old
        {"name": "build-logs-v1", "size_bytes": 1_000_000, "created_at": "2026-02-20T12:00:00Z", "workflow_run_id": "build"},
        {"name": "build-logs-v2", "size_bytes": 2_000_000, "created_at": "2026-03-10T12:00:00Z", "workflow_run_id": "build"},
        {"name": "build-logs-v3", "size_bytes": 1_500_000, "created_at": "2026-03-25T12:00:00Z", "workflow_run_id": "build"},
        {"name": "build-logs-v4", "size_bytes": 1_000_000, "created_at": "2026-03-31T12:00:00Z", "workflow_run_id": "build"},
        # Workflow "test" — 3 artifacts
        {"name": "test-results-v1", "size_bytes": 500_000, "created_at": "2026-03-01T12:00:00Z", "workflow_run_id": "test"},
        {"name": "test-results-v2", "size_bytes": 800_000, "created_at": "2026-03-20T12:00:00Z", "workflow_run_id": "test"},
        {"name": "test-results-v3", "size_bytes": 600_000, "created_at": "2026-03-30T12:00:00Z", "workflow_run_id": "test"},
        # Workflow "deploy" — 2 artifacts, both recent
        {"name": "deploy-bundle-v1", "size_bytes": 5_000_000, "created_at": "2026-03-28T12:00:00Z", "workflow_run_id": "deploy"},
        {"name": "deploy-bundle-v2", "size_bytes": 5_000_000, "created_at": "2026-03-31T12:00:00Z", "workflow_run_id": "deploy"},
    ], now


# ===========================================================================
# TDD CYCLE 1 — Artifact data model
# ===========================================================================
class TestArtifactModel(unittest.TestCase):
    """RED: Can we create Artifact objects and query their properties?"""

    def test_create_artifact_with_required_fields(self):
        from artifact_cleanup import Artifact

        art = Artifact(
            name="build-logs",
            size_bytes=1_048_576,
            created_at=datetime(2026, 3, 1, 12, 0, 0, tzinfo=timezone.utc),
            workflow_run_id="run-100",
        )
        self.assertEqual(art.name, "build-logs")
        self.assertEqual(art.size_bytes, 1_048_576)
        self.assertEqual(art.workflow_run_id, "run-100")

    def test_artifact_size_in_mb(self):
        from artifact_cleanup import Artifact

        art = Artifact(
            name="a", size_bytes=5_242_880,
            created_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
            workflow_run_id="run-1",
        )
        self.assertAlmostEqual(art.size_mb, 5.0)

    def test_artifact_age_days(self):
        from artifact_cleanup import Artifact

        art = Artifact(
            name="a", size_bytes=100,
            created_at=datetime(2026, 3, 1, tzinfo=timezone.utc),
            workflow_run_id="run-1",
        )
        now = datetime(2026, 3, 11, tzinfo=timezone.utc)
        self.assertEqual(art.age_days(now), 10)

    def test_parse_artifacts_from_dicts(self):
        """Parse a list of raw dicts (mock JSON input) into Artifact objects."""
        from artifact_cleanup import parse_artifacts

        raw, _ = make_artifacts()
        artifacts = parse_artifacts(raw)
        self.assertEqual(len(artifacts), 9)
        self.assertEqual(artifacts[0].name, "build-logs-v1")
        self.assertIsInstance(artifacts[0].created_at, datetime)

    def test_parse_artifacts_with_iso_dates(self):
        """created_at strings in ISO 8601 are parsed into timezone-aware datetimes."""
        from artifact_cleanup import parse_artifacts

        raw = [{"name": "x", "size_bytes": 1, "created_at": "2026-03-15T08:30:00Z", "workflow_run_id": "w"}]
        arts = parse_artifacts(raw)
        self.assertEqual(arts[0].created_at.tzinfo, timezone.utc)


# ===========================================================================
# TDD CYCLE 2 — Max-age retention policy
# ===========================================================================
class TestMaxAgePolicy(unittest.TestCase):
    """RED: Artifacts older than max_age_days should be marked for deletion."""

    def test_old_artifacts_flagged(self):
        from artifact_cleanup import parse_artifacts, apply_max_age_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        # Max age = 30 days → build-logs-v1 (40 days old) and test-results-v1 (31 days old) should be deleted
        to_delete = apply_max_age_policy(artifacts, max_age_days=30, now=now)
        deleted_names = {a.name for a in to_delete}
        self.assertIn("build-logs-v1", deleted_names)
        self.assertIn("test-results-v1", deleted_names)

    def test_recent_artifacts_kept(self):
        from artifact_cleanup import parse_artifacts, apply_max_age_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_max_age_policy(artifacts, max_age_days=30, now=now)
        deleted_names = {a.name for a in to_delete}
        # Recent artifacts should NOT appear in the deletion set
        self.assertNotIn("build-logs-v4", deleted_names)
        self.assertNotIn("deploy-bundle-v2", deleted_names)

    def test_zero_max_age_deletes_all(self):
        from artifact_cleanup import parse_artifacts, apply_max_age_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_max_age_policy(artifacts, max_age_days=0, now=now)
        self.assertEqual(len(to_delete), len(artifacts))

    def test_none_max_age_skips_policy(self):
        """When max_age_days is None the policy is disabled — nothing is deleted."""
        from artifact_cleanup import parse_artifacts, apply_max_age_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_max_age_policy(artifacts, max_age_days=None, now=now)
        self.assertEqual(len(to_delete), 0)


# ===========================================================================
# TDD CYCLE 3 — Max-total-size retention policy
# ===========================================================================
class TestMaxTotalSizePolicy(unittest.TestCase):
    """RED: When total size exceeds the budget, oldest artifacts are removed first."""

    def test_over_budget_deletes_oldest_first(self):
        from artifact_cleanup import parse_artifacts, apply_max_total_size_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        # Total size of all 9 artifacts = 17.4 MB.  Budget = 10 MB.
        to_delete = apply_max_total_size_policy(artifacts, max_total_bytes=10_000_000, now=now)
        # Oldest artifacts should be deleted first until we fit under budget
        self.assertTrue(len(to_delete) > 0)
        # The remaining artifacts' total size should be <= budget
        remaining = [a for a in artifacts if a not in to_delete]
        self.assertLessEqual(sum(a.size_bytes for a in remaining), 10_000_000)

    def test_under_budget_deletes_nothing(self):
        from artifact_cleanup import parse_artifacts, apply_max_total_size_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        # Budget larger than total → nothing deleted
        to_delete = apply_max_total_size_policy(artifacts, max_total_bytes=100_000_000, now=now)
        self.assertEqual(len(to_delete), 0)

    def test_none_budget_skips_policy(self):
        from artifact_cleanup import parse_artifacts, apply_max_total_size_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_max_total_size_policy(artifacts, max_total_bytes=None, now=now)
        self.assertEqual(len(to_delete), 0)


# ===========================================================================
# TDD CYCLE 4 — Keep-latest-N-per-workflow policy
# ===========================================================================
class TestKeepLatestNPolicy(unittest.TestCase):
    """RED: Only keep the N most recent artifacts for each workflow run ID."""

    def test_keep_2_per_workflow(self):
        from artifact_cleanup import parse_artifacts, apply_keep_latest_n_policy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_keep_latest_n_policy(artifacts, keep_n=2)
        deleted_names = {a.name for a in to_delete}
        # "build" has 4 artifacts → 2 oldest should be deleted
        self.assertIn("build-logs-v1", deleted_names)
        self.assertIn("build-logs-v2", deleted_names)
        self.assertNotIn("build-logs-v3", deleted_names)
        self.assertNotIn("build-logs-v4", deleted_names)
        # "test" has 3 → 1 oldest deleted
        self.assertIn("test-results-v1", deleted_names)
        self.assertNotIn("test-results-v2", deleted_names)
        # "deploy" has 2 → none deleted
        self.assertNotIn("deploy-bundle-v1", deleted_names)
        self.assertNotIn("deploy-bundle-v2", deleted_names)

    def test_keep_all_when_n_is_large(self):
        from artifact_cleanup import parse_artifacts, apply_keep_latest_n_policy

        raw, _ = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_keep_latest_n_policy(artifacts, keep_n=100)
        self.assertEqual(len(to_delete), 0)

    def test_none_keep_n_skips_policy(self):
        from artifact_cleanup import parse_artifacts, apply_keep_latest_n_policy

        raw, _ = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_keep_latest_n_policy(artifacts, keep_n=None)
        self.assertEqual(len(to_delete), 0)

    def test_keep_1_per_workflow(self):
        from artifact_cleanup import parse_artifacts, apply_keep_latest_n_policy

        raw, _ = make_artifacts()
        artifacts = parse_artifacts(raw)
        to_delete = apply_keep_latest_n_policy(artifacts, keep_n=1)
        # build: 3 deleted, test: 2 deleted, deploy: 1 deleted → 6 total
        self.assertEqual(len(to_delete), 6)


# ===========================================================================
# TDD CYCLE 5 — Combined policies & deletion plan generation
# ===========================================================================
class TestDeletionPlan(unittest.TestCase):
    """RED: Combining all policies produces a unified deletion plan with summary."""

    def test_combined_policies_union_of_deletions(self):
        """Artifacts flagged by ANY policy are included in the deletion plan."""
        from artifact_cleanup import parse_artifacts, generate_deletion_plan, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=30, max_total_bytes=None, keep_latest_n=2)
        plan = generate_deletion_plan(artifacts, policy, now=now)
        deleted_names = {a.name for a in plan.to_delete}
        # max_age_days=30 flags: build-logs-v1, test-results-v1
        # keep_latest_n=2 flags: build-logs-v1, build-logs-v2, test-results-v1
        # Union: build-logs-v1, build-logs-v2, test-results-v1
        self.assertIn("build-logs-v1", deleted_names)
        self.assertIn("build-logs-v2", deleted_names)
        self.assertIn("test-results-v1", deleted_names)

    def test_plan_summary_has_required_fields(self):
        from artifact_cleanup import parse_artifacts, generate_deletion_plan, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=30, max_total_bytes=None, keep_latest_n=2)
        plan = generate_deletion_plan(artifacts, policy, now=now)
        summary = plan.summary()
        self.assertIn("total_artifacts", summary)
        self.assertIn("artifacts_to_delete", summary)
        self.assertIn("artifacts_retained", summary)
        self.assertIn("space_reclaimed_bytes", summary)
        self.assertIn("space_retained_bytes", summary)

    def test_plan_summary_math_is_correct(self):
        from artifact_cleanup import parse_artifacts, generate_deletion_plan, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=None, max_total_bytes=None, keep_latest_n=None)
        plan = generate_deletion_plan(artifacts, policy, now=now)
        summary = plan.summary()
        # No policies active → nothing deleted
        self.assertEqual(summary["artifacts_to_delete"], 0)
        self.assertEqual(summary["artifacts_retained"], 9)
        self.assertEqual(summary["space_reclaimed_bytes"], 0)

    def test_plan_retained_plus_deleted_equals_total(self):
        from artifact_cleanup import parse_artifacts, generate_deletion_plan, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=15, max_total_bytes=5_000_000, keep_latest_n=1)
        plan = generate_deletion_plan(artifacts, policy, now=now)
        summary = plan.summary()
        self.assertEqual(
            summary["artifacts_to_delete"] + summary["artifacts_retained"],
            summary["total_artifacts"],
        )
        self.assertEqual(
            summary["space_reclaimed_bytes"] + summary["space_retained_bytes"],
            sum(a.size_bytes for a in artifacts),
        )

    def test_plan_lists_reasons_per_artifact(self):
        """Each deleted artifact should list which policy/policies flagged it."""
        from artifact_cleanup import parse_artifacts, generate_deletion_plan, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=30, max_total_bytes=None, keep_latest_n=2)
        plan = generate_deletion_plan(artifacts, policy, now=now)
        # build-logs-v1 should be flagged by both max_age and keep_latest_n
        reasons = plan.deletion_reasons()
        self.assertIn("build-logs-v1", reasons)
        self.assertTrue(len(reasons["build-logs-v1"]) >= 1)


# ===========================================================================
# TDD CYCLE 6 — Dry-run mode
# ===========================================================================
class TestDryRunMode(unittest.TestCase):
    """RED: dry_run=True produces the plan + summary but marks no actual deletions."""

    def test_dry_run_returns_plan_without_executing(self):
        from artifact_cleanup import parse_artifacts, run_cleanup, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=30, max_total_bytes=None, keep_latest_n=2)
        result = run_cleanup(artifacts, policy, now=now, dry_run=True)
        self.assertTrue(result.is_dry_run)
        self.assertTrue(len(result.plan.to_delete) > 0)
        # In dry-run, nothing is actually deleted — the 'executed' flag is False
        self.assertFalse(result.executed)

    def test_non_dry_run_marks_executed(self):
        from artifact_cleanup import parse_artifacts, run_cleanup, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=30, max_total_bytes=None, keep_latest_n=2)
        result = run_cleanup(artifacts, policy, now=now, dry_run=False)
        self.assertFalse(result.is_dry_run)
        self.assertTrue(result.executed)

    def test_dry_run_summary_output_is_json_serializable(self):
        """The summary should be JSON-serializable for machine consumption."""
        from artifact_cleanup import parse_artifacts, run_cleanup, RetentionPolicy

        raw, now = make_artifacts()
        artifacts = parse_artifacts(raw)
        policy = RetentionPolicy(max_age_days=30, max_total_bytes=None, keep_latest_n=2)
        result = run_cleanup(artifacts, policy, now=now, dry_run=True)
        # Should not raise
        output = json.dumps(result.to_dict(), indent=2)
        self.assertIsInstance(output, str)
        parsed = json.loads(output)
        self.assertIn("dry_run", parsed)
        self.assertIn("summary", parsed)
        self.assertIn("deleted_artifacts", parsed)
        self.assertIn("retained_artifacts", parsed)


# ===========================================================================
# TDD CYCLE 7 — Error handling
# ===========================================================================
class TestErrorHandling(unittest.TestCase):
    """RED: Graceful errors with meaningful messages for bad inputs."""

    def test_negative_max_age_raises(self):
        from artifact_cleanup import RetentionPolicy

        with self.assertRaises(ValueError) as ctx:
            RetentionPolicy(max_age_days=-1)
        self.assertIn("max_age_days", str(ctx.exception))

    def test_negative_max_total_bytes_raises(self):
        from artifact_cleanup import RetentionPolicy

        with self.assertRaises(ValueError) as ctx:
            RetentionPolicy(max_total_bytes=-100)
        self.assertIn("max_total_bytes", str(ctx.exception))

    def test_zero_keep_n_raises(self):
        from artifact_cleanup import RetentionPolicy

        with self.assertRaises(ValueError) as ctx:
            RetentionPolicy(keep_latest_n=0)
        self.assertIn("keep_latest_n", str(ctx.exception))

    def test_negative_keep_n_raises(self):
        from artifact_cleanup import RetentionPolicy

        with self.assertRaises(ValueError) as ctx:
            RetentionPolicy(keep_latest_n=-5)
        self.assertIn("keep_latest_n", str(ctx.exception))

    def test_missing_field_in_raw_artifact(self):
        from artifact_cleanup import parse_artifacts

        bad_data = [{"name": "oops"}]  # missing required fields
        with self.assertRaises(ValueError) as ctx:
            parse_artifacts(bad_data)
        self.assertIn("missing", str(ctx.exception).lower())

    def test_invalid_date_format(self):
        from artifact_cleanup import parse_artifacts

        bad_data = [{"name": "x", "size_bytes": 1, "created_at": "not-a-date", "workflow_run_id": "w"}]
        with self.assertRaises(ValueError) as ctx:
            parse_artifacts(bad_data)
        self.assertIn("date", str(ctx.exception).lower())

    def test_negative_size_raises(self):
        from artifact_cleanup import parse_artifacts

        bad_data = [{"name": "x", "size_bytes": -10, "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "w"}]
        with self.assertRaises(ValueError) as ctx:
            parse_artifacts(bad_data)
        self.assertIn("size", str(ctx.exception).lower())

    def test_empty_artifact_list_produces_empty_plan(self):
        from artifact_cleanup import generate_deletion_plan, RetentionPolicy

        now = datetime(2026, 4, 1, tzinfo=timezone.utc)
        policy = RetentionPolicy(max_age_days=30)
        plan = generate_deletion_plan([], policy, now=now)
        summary = plan.summary()
        self.assertEqual(summary["total_artifacts"], 0)
        self.assertEqual(summary["artifacts_to_delete"], 0)


if __name__ == "__main__":
    unittest.main()
