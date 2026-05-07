"""Unit tests for the artifact retention engine.

These exercise pure logic with hand-built fixtures. The
end-to-end CLI behaviour is verified separately via the
GitHub Actions workflow + act.
"""

from datetime import datetime, timedelta, timezone
import io
import json
import os
import sys
import unittest

# Make the project root importable when tests run from any cwd.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from retention import (  # noqa: E402
    Artifact,
    Policy,
    apply_policies,
    format_plan,
    load_artifacts,
    load_policy,
    main,
)


# Fixed "now" so age math is deterministic.
NOW = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)


def _at(days_ago: int) -> datetime:
    return NOW - timedelta(days=days_ago)


def _mk(name, size_mb, days_ago, wf):
    """Convenience constructor for tests."""
    return Artifact(
        name=name,
        size_bytes=size_mb * 1024 * 1024,
        created_at=_at(days_ago),
        workflow_run_id=wf,
    )


class MaxAgeTests(unittest.TestCase):
    def test_artifact_older_than_max_age_is_deleted(self):
        # Single artifact, 60 days old. Policy max_age=30 -> delete.
        a = _mk("old", 10, 60, "wf-1")
        plan = apply_policies([a], Policy(max_age_days=30), now=NOW)
        self.assertEqual(plan.deleted, [a])
        self.assertEqual(plan.retained, [])

    def test_artifact_younger_than_max_age_is_kept(self):
        a = _mk("fresh", 10, 5, "wf-1")
        plan = apply_policies([a], Policy(max_age_days=30), now=NOW)
        self.assertEqual(plan.deleted, [])
        self.assertEqual(plan.retained, [a])

    def test_no_max_age_keeps_everything(self):
        a = _mk("ancient", 10, 9999, "wf-1")
        plan = apply_policies([a], Policy(), now=NOW)
        self.assertEqual(plan.retained, [a])


class KeepLatestNTests(unittest.TestCase):
    def test_keeps_only_latest_n_per_workflow(self):
        # 3 artifacts on wf-1: keep latest 1 -> oldest 2 deleted.
        a1 = _mk("v1", 5, 10, "wf-1")
        a2 = _mk("v2", 5, 5, "wf-1")
        a3 = _mk("v3", 5, 1, "wf-1")
        plan = apply_policies(
            [a1, a2, a3], Policy(keep_latest_n_per_workflow=1), now=NOW
        )
        self.assertEqual(plan.retained, [a3])
        self.assertCountEqual(plan.deleted, [a1, a2])

    def test_separate_workflows_tracked_independently(self):
        # wf-1 has 2, wf-2 has 1. Keep latest 1 each -> delete oldest of wf-1.
        a1 = _mk("a", 5, 10, "wf-1")
        a2 = _mk("b", 5, 1, "wf-1")
        a3 = _mk("c", 5, 7, "wf-2")
        plan = apply_policies(
            [a1, a2, a3], Policy(keep_latest_n_per_workflow=1), now=NOW
        )
        self.assertCountEqual(plan.retained, [a2, a3])
        self.assertEqual(plan.deleted, [a1])

    def test_keep_latest_n_overrides_max_age(self):
        # Latest of wf-1 is also old, but keep_latest_n=1 protects it.
        a1 = _mk("ancient", 5, 200, "wf-1")
        a2 = _mk("less-ancient", 5, 100, "wf-1")
        plan = apply_policies(
            [a1, a2],
            Policy(max_age_days=30, keep_latest_n_per_workflow=1),
            now=NOW,
        )
        self.assertEqual(plan.retained, [a2])
        self.assertEqual(plan.deleted, [a1])


class MaxTotalSizeTests(unittest.TestCase):
    def test_oldest_deleted_first_until_within_budget(self):
        # 3 artifacts of 50MB each = 150MB. Budget 100MB -> delete oldest (one).
        a1 = _mk("a", 50, 30, "wf-1")
        a2 = _mk("b", 50, 20, "wf-2")
        a3 = _mk("c", 50, 10, "wf-3")
        plan = apply_policies(
            [a1, a2, a3],
            Policy(max_total_size_bytes=100 * 1024 * 1024),
            now=NOW,
        )
        self.assertEqual(plan.deleted, [a1])
        self.assertCountEqual(plan.retained, [a2, a3])

    def test_already_under_budget_keeps_everything(self):
        a1 = _mk("a", 10, 30, "wf-1")
        plan = apply_policies(
            [a1], Policy(max_total_size_bytes=100 * 1024 * 1024), now=NOW
        )
        self.assertEqual(plan.retained, [a1])

    def test_keep_latest_n_blocks_size_eviction(self):
        # 2 artifacts on wf-1, 100MB each. Budget 50MB BUT keep_latest=1.
        # Latest is protected -> only oldest is deleted, total stays > budget.
        a1 = _mk("old", 100, 30, "wf-1")
        a2 = _mk("new", 100, 1, "wf-1")
        plan = apply_policies(
            [a1, a2],
            Policy(
                max_total_size_bytes=50 * 1024 * 1024,
                keep_latest_n_per_workflow=1,
            ),
            now=NOW,
        )
        self.assertEqual(plan.retained, [a2])
        self.assertEqual(plan.deleted, [a1])


class ReclaimedSummaryTests(unittest.TestCase):
    def test_reclaimed_bytes_sums_deleted(self):
        a1 = _mk("a", 10, 60, "wf-1")  # deleted
        a2 = _mk("b", 20, 60, "wf-2")  # deleted
        a3 = _mk("c", 30, 1, "wf-3")  # retained
        plan = apply_policies(
            [a1, a2, a3], Policy(max_age_days=30), now=NOW
        )
        self.assertEqual(plan.reclaimed_bytes, (10 + 20) * 1024 * 1024)
        self.assertEqual(plan.retained_bytes, 30 * 1024 * 1024)


class FormatPlanTests(unittest.TestCase):
    def test_format_plan_includes_summary_lines(self):
        a1 = _mk("old-build", 10, 60, "wf-1")
        a2 = _mk("fresh-build", 5, 1, "wf-1")
        plan = apply_policies([a1, a2], Policy(max_age_days=30), now=NOW)
        out = format_plan(plan, dry_run=True)
        self.assertIn("Mode: dry-run", out)
        self.assertIn("Artifacts retained: 1", out)
        self.assertIn("Artifacts deleted: 1", out)
        self.assertIn("Space reclaimed: 10.00 MB", out)
        self.assertIn("old-build", out)
        self.assertIn("fresh-build", out)

    def test_format_plan_execute_mode_label(self):
        plan = apply_policies([], Policy(), now=NOW)
        self.assertIn("Mode: execute", format_plan(plan, dry_run=False))


class LoadFixturesTests(unittest.TestCase):
    def test_load_artifacts_parses_iso_dates(self):
        raw = [
            {
                "name": "x",
                "size_bytes": 1024,
                "created_at": "2026-05-01T00:00:00Z",
                "workflow_run_id": "wf-1",
            }
        ]
        arts = load_artifacts(raw)
        self.assertEqual(len(arts), 1)
        self.assertEqual(arts[0].name, "x")
        self.assertEqual(arts[0].size_bytes, 1024)
        self.assertEqual(arts[0].workflow_run_id, "wf-1")
        # Date is timezone-aware:
        self.assertIsNotNone(arts[0].created_at.tzinfo)

    def test_load_artifacts_rejects_missing_fields(self):
        with self.assertRaises(ValueError) as ctx:
            load_artifacts([{"name": "x"}])
        self.assertIn("missing", str(ctx.exception).lower())

    def test_load_policy_round_trips(self):
        p = load_policy(
            {
                "max_age_days": 30,
                "max_total_size_bytes": 1024,
                "keep_latest_n_per_workflow": 2,
            }
        )
        self.assertEqual(p.max_age_days, 30)
        self.assertEqual(p.max_total_size_bytes, 1024)
        self.assertEqual(p.keep_latest_n_per_workflow, 2)

    def test_load_policy_defaults_to_none(self):
        p = load_policy({})
        self.assertIsNone(p.max_age_days)
        self.assertIsNone(p.max_total_size_bytes)
        self.assertIsNone(p.keep_latest_n_per_workflow)


class CliTests(unittest.TestCase):
    def _write(self, tmpdir, name, payload):
        path = os.path.join(tmpdir, name)
        with open(path, "w") as f:
            json.dump(payload, f)
        return path

    def test_main_runs_against_fixture_files(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            arts_path = self._write(
                tmp,
                "arts.json",
                [
                    {
                        "name": "old",
                        "size_bytes": 10 * 1024 * 1024,
                        "created_at": "2026-01-01T00:00:00Z",
                        "workflow_run_id": "wf-1",
                    },
                    {
                        "name": "new",
                        "size_bytes": 5 * 1024 * 1024,
                        "created_at": "2026-05-06T00:00:00Z",
                        "workflow_run_id": "wf-1",
                    },
                ],
            )
            pol_path = self._write(tmp, "pol.json", {"max_age_days": 30})
            buf = io.StringIO()
            rc = main(
                ["--artifacts", arts_path, "--policy", pol_path, "--dry-run",
                 "--now", "2026-05-07T12:00:00Z"],
                stdout=buf,
            )
            self.assertEqual(rc, 0)
            text = buf.getvalue()
            self.assertIn("Artifacts deleted: 1", text)
            self.assertIn("old", text)

    def test_main_returns_nonzero_on_missing_file(self):
        buf = io.StringIO()
        rc = main(
            ["--artifacts", "/no/such/file.json",
             "--policy", "/no/such/policy.json"],
            stdout=buf,
            stderr=buf,
        )
        self.assertNotEqual(rc, 0)
        self.assertIn("Error", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
