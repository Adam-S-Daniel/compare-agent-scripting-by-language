"""
TDD tests for artifact cleanup script.

Red/green cycles, documented in order of authorship:

1. test_load_artifacts_from_json — load mock artifact list from file
2. test_parse_created_at — ISO-8601 parsing, reject bad input
3. test_apply_max_age_policy — old artifacts marked delete
4. test_keep_latest_n_per_workflow — oldest within a workflow marked delete
5. test_max_total_size_policy — trim biggest-first until under budget
6. test_combined_policies_union — any policy flagging -> delete
7. test_build_deletion_plan_summary — totals + counts are correct
8. test_dry_run_returns_plan_without_side_effects — dry-run is pure
9. test_cli_reads_fixture_and_emits_json — end-to-end CLI smoke test
10. test_invalid_artifact_raises — graceful error on malformed input
"""

from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import cleanup  # noqa: E402


NOW = datetime(2026, 4, 20, 12, 0, 0, tzinfo=timezone.utc)


def _art(name, size, age_days, run_id, workflow="ci"):
    """Helper: build an artifact dict relative to NOW."""
    return {
        "name": name,
        "size_bytes": size,
        "created_at": (NOW - timedelta(days=age_days)).isoformat(),
        "workflow_run_id": run_id,
        "workflow_name": workflow,
    }


def test_load_artifacts_from_json(tmp_path):
    data = [_art("a.zip", 100, 1, 1)]
    f = tmp_path / "arts.json"
    f.write_text(json.dumps(data))
    loaded = cleanup.load_artifacts(f)
    assert len(loaded) == 1
    assert loaded[0]["name"] == "a.zip"


def test_parse_created_at_accepts_iso():
    dt = cleanup.parse_created_at("2026-04-20T12:00:00+00:00")
    assert dt.tzinfo is not None


def test_parse_created_at_rejects_garbage():
    with pytest.raises(ValueError):
        cleanup.parse_created_at("not-a-date")


def test_apply_max_age_policy_flags_old_artifacts():
    arts = [_art("old", 10, 40, 1), _art("fresh", 10, 3, 2)]
    flagged = cleanup.apply_max_age(arts, max_age_days=30, now=NOW)
    names = {a["name"] for a in flagged}
    assert names == {"old"}


def test_keep_latest_n_per_workflow_keeps_newest():
    arts = [
        _art("ci-1", 10, 5, 1, "ci"),
        _art("ci-2", 10, 3, 2, "ci"),
        _art("ci-3", 10, 1, 3, "ci"),
        _art("rel-1", 10, 2, 4, "release"),
    ]
    flagged = cleanup.apply_keep_latest_n(arts, n=1)
    flagged_names = {a["name"] for a in flagged}
    # keep newest of each workflow -> ci-3 and rel-1 kept; ci-1 & ci-2 deleted
    assert flagged_names == {"ci-1", "ci-2"}


def test_max_total_size_policy_trims_largest_first():
    # total = 600, budget = 250 -> must delete until <= 250
    arts = [
        _art("big", 400, 1, 1),
        _art("med", 150, 2, 2),
        _art("small", 50, 3, 3),
    ]
    flagged = cleanup.apply_max_total_size(arts, max_total_bytes=250)
    # dropping "big" alone leaves 200 <= 250, so only "big" flagged.
    assert {a["name"] for a in flagged} == {"big"}


def test_combined_policies_union():
    arts = [
        _art("old-and-big", 500, 100, 1),
        _art("old-only", 10, 100, 2),
        _art("big-only", 500, 1, 3),
        _art("safe", 10, 1, 4),
    ]
    plan = cleanup.build_plan(
        arts,
        max_age_days=30,
        max_total_bytes=600,
        keep_latest_n=None,
        now=NOW,
    )
    to_delete = {a["name"] for a in plan["delete"]}
    # age flags both old-* ; size (after age trim, total = 500 + 10 = 510) fine.
    assert to_delete == {"old-and-big", "old-only"}
    assert {a["name"] for a in plan["keep"]} == {"big-only", "safe"}


def test_build_deletion_plan_summary_totals():
    arts = [_art("a", 100, 40, 1), _art("b", 200, 1, 2)]
    plan = cleanup.build_plan(arts, max_age_days=30, now=NOW)
    s = plan["summary"]
    assert s["retained_count"] == 1
    assert s["deleted_count"] == 1
    assert s["space_reclaimed_bytes"] == 100
    assert s["total_size_before_bytes"] == 300
    assert s["total_size_after_bytes"] == 200


def test_dry_run_does_not_mutate_input():
    arts = [_art("a", 100, 40, 1)]
    snapshot = json.dumps(arts, sort_keys=True)
    cleanup.build_plan(arts, max_age_days=30, now=NOW, dry_run=True)
    assert json.dumps(arts, sort_keys=True) == snapshot


def test_cli_end_to_end(tmp_path):
    arts = [
        _art("old", 500, 60, 1),
        _art("new", 100, 1, 2),
    ]
    f = tmp_path / "arts.json"
    f.write_text(json.dumps(arts))
    out = tmp_path / "plan.json"
    result = subprocess.run(
        [
            sys.executable,
            str(ROOT / "cleanup.py"),
            "--input", str(f),
            "--output", str(out),
            "--max-age-days", "30",
            "--now", NOW.isoformat(),
            "--dry-run",
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    plan = json.loads(out.read_text())
    assert plan["summary"]["deleted_count"] == 1
    assert plan["summary"]["space_reclaimed_bytes"] == 500
    assert plan["summary"]["dry_run"] is True


def test_invalid_artifact_raises():
    with pytest.raises(cleanup.ArtifactError):
        cleanup.build_plan([{"name": "bad"}], max_age_days=1, now=NOW)
