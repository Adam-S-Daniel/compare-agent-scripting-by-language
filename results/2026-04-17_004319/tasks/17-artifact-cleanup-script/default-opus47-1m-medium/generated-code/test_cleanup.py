"""Unit tests for cleanup.py - built via red/green TDD.

Each test was written first (red), then cleanup.py was written to make it
pass (green), then refactored. The final checked-in state of both files is
the result after all iterations.
"""
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from cleanup import (
    Artifact,
    build_plan,
    mark_by_keep_latest_n,
    mark_by_max_age,
    mark_by_max_total_size,
    parse_artifacts,
)

NOW = datetime(2026, 4, 17, 12, 0, 0, tzinfo=timezone.utc)


def _art(name, size, days_ago, wf):
    """Shorthand to build an Artifact created `days_ago` days before NOW."""
    dt = NOW.timestamp() - days_ago * 86400
    iso = datetime.fromtimestamp(dt, tz=timezone.utc).isoformat()
    return Artifact(name=name, size=size, created_at=iso, workflow_run_id=wf)


class ParseTests(unittest.TestCase):
    def test_parse_valid(self):
        got = parse_artifacts([{
            "name": "a", "size": 10,
            "created_at": "2026-04-01T00:00:00Z",
            "workflow_run_id": "123",
        }])
        self.assertEqual(len(got), 1)
        self.assertEqual(got[0].name, "a")
        self.assertEqual(got[0].workflow_run_id, "123")

    def test_parse_missing_field(self):
        with self.assertRaises(ValueError):
            parse_artifacts([{"name": "x", "size": 1, "created_at": "2026-01-01"}])

    def test_parse_negative_size(self):
        with self.assertRaises(ValueError):
            parse_artifacts([{
                "name": "x", "size": -1,
                "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "w",
            }])


class MaxAgeTests(unittest.TestCase):
    def test_marks_old_only(self):
        arts = [_art("old", 100, 40, "w1"), _art("new", 100, 5, "w1")]
        marked = mark_by_max_age(arts, 30, NOW)
        self.assertEqual(marked, {0})


class KeepLatestTests(unittest.TestCase):
    def test_keeps_newest_n_per_workflow(self):
        arts = [
            _art("w1-old", 10, 10, "w1"),
            _art("w1-mid", 10, 5, "w1"),
            _art("w1-new", 10, 1, "w1"),
            _art("w2-only", 10, 100, "w2"),
        ]
        marked = mark_by_keep_latest_n(arts, 1)
        # w1 keeps w1-new (idx 2), deletes idx 0,1; w2 keeps its only one.
        self.assertEqual(marked, {0, 1})


class MaxTotalSizeTests(unittest.TestCase):
    def test_deletes_oldest_beyond_quota(self):
        arts = [
            _art("a", 100, 10, "w1"),  # oldest, will be deleted
            _art("b", 100, 5, "w1"),
            _art("c", 100, 1, "w1"),
        ]
        marked = mark_by_max_total_size(arts, 200, set())
        self.assertEqual(marked, {0})


class BuildPlanTests(unittest.TestCase):
    def test_combined_policies_and_summary(self):
        arts = [
            _art("ancient", 500, 90, "w1"),      # old: deleted by max-age
            _art("w1-old", 200, 10, "w1"),       # deleted by keep-latest-1
            _art("w1-new", 200, 1, "w1"),        # kept
            _art("w2-big", 1000, 2, "w2"),       # kept but may be trimmed
            _art("w2-mid", 300, 3, "w2"),        # kept
        ]
        plan = build_plan(
            arts,
            max_age_days=30,
            keep_latest_n_per_workflow=1,
            now=NOW,
        )
        # keep-latest=1 per workflow deletes: ancient (w1), w1-old; w2-mid (older than w2-big).
        # max-age also flags ancient. So deletes = {ancient, w1-old, w2-mid}.
        deleted_names = {d["name"] for d in plan["deleted"]}
        self.assertEqual(deleted_names, {"ancient", "w1-old", "w2-mid"})
        self.assertEqual(plan["summary"]["deleted_count"], 3)
        self.assertEqual(plan["summary"]["retained_count"], 2)
        self.assertEqual(
            plan["summary"]["total_reclaimed_bytes"], 500 + 200 + 300
        )

    def test_max_total_size_enforced(self):
        arts = [
            _art("a", 100, 3, "w1"),
            _art("b", 100, 2, "w1"),
            _art("c", 100, 1, "w1"),
        ]
        plan = build_plan(arts, max_total_size=150, now=NOW)
        # Newest 'c' (100) fits; 'b' would push to 200 > 150, so deleted;
        # 'a' also deleted.
        names = {d["name"] for d in plan["deleted"]}
        self.assertEqual(names, {"a", "b"})
        self.assertEqual(plan["summary"]["total_reclaimed_bytes"], 200)

    def test_no_policies_deletes_nothing(self):
        arts = [_art("a", 10, 1, "w1")]
        plan = build_plan(arts, now=NOW)
        self.assertEqual(plan["summary"]["deleted_count"], 0)
        self.assertEqual(plan["summary"]["retained_count"], 1)


class CLITests(unittest.TestCase):
    """Smoke test of the CLI end-to-end with a temp fixture."""
    def test_cli_dry_run(self):
        fixture = [
            {"name": "old", "size": 999, "created_at": "2026-01-01T00:00:00Z",
             "workflow_run_id": "w1"},
            {"name": "new", "size": 1, "created_at": "2026-04-15T00:00:00Z",
             "workflow_run_id": "w1"},
        ]
        with tempfile.TemporaryDirectory() as d:
            fp = Path(d) / "in.json"
            fp.write_text(json.dumps(fixture))
            out = subprocess.run(
                [sys.executable, "cleanup.py",
                 "--input", str(fp),
                 "--max-age-days", "30",
                 "--now", "2026-04-17T12:00:00Z",
                 "--dry-run"],
                capture_output=True, text=True,
                cwd=Path(__file__).parent,
            )
            self.assertEqual(out.returncode, 0, out.stderr)
            plan = json.loads(out.stdout)
            self.assertEqual(plan["mode"], "DRY-RUN")
            self.assertEqual({d["name"] for d in plan["deleted"]}, {"old"})


if __name__ == "__main__":
    unittest.main()
