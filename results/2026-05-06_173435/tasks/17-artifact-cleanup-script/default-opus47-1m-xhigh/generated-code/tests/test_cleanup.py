"""TDD test suite for the artifact cleanup script.

Each test exercises a single retention rule or behaviour. Fixtures use a
fixed reference date (REF_NOW) so tests are deterministic regardless of
when they run. Sizes are in bytes.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import pytest

from cleanup import (
    Artifact,
    CleanupConfig,
    CleanupError,
    build_plan,
    load_artifacts,
    render_summary,
)

# Reference "now" used by every test. Pick a date well in the future of
# any fixture to keep age math simple.
REF_NOW = datetime(2026, 6, 1, 12, 0, 0, tzinfo=timezone.utc)


def _art(
    artifact_id: str,
    name: str,
    size: int,
    days_old: int,
    workflow_run_id: int,
) -> Artifact:
    """Helper to build an Artifact whose creation date is N days before REF_NOW."""
    created = REF_NOW.replace(hour=0) - __import__("datetime").timedelta(days=days_old)
    return Artifact(
        id=artifact_id,
        name=name,
        size_bytes=size,
        created_at=created,
        workflow_run_id=workflow_run_id,
    )


# --------------------------------------------------------------------------
# 1. Empty input — the simplest possible failing case.
# --------------------------------------------------------------------------
def test_empty_artifact_list_yields_empty_plan():
    plan = build_plan([], CleanupConfig(), now=REF_NOW)
    assert plan.deletions == []
    assert plan.retained == []
    assert plan.summary["deleted_count"] == 0
    assert plan.summary["retained_count"] == 0
    assert plan.summary["space_reclaimed_bytes"] == 0


# --------------------------------------------------------------------------
# 2. With no policies configured, everything is retained.
# --------------------------------------------------------------------------
def test_no_policies_retains_all():
    artifacts = [
        _art("a", "build", 100, days_old=400, workflow_run_id=1),
        _art("b", "test", 200, days_old=10, workflow_run_id=2),
    ]
    plan = build_plan(artifacts, CleanupConfig(), now=REF_NOW)
    assert {d.id for d in plan.deletions} == set()
    assert {r.id for r in plan.retained} == {"a", "b"}


# --------------------------------------------------------------------------
# 3. max_age_days deletes anything older than the cutoff.
# --------------------------------------------------------------------------
def test_max_age_days_deletes_old_artifacts():
    artifacts = [
        _art("old1", "build", 100, days_old=120, workflow_run_id=1),
        _art("old2", "build", 100, days_old=91, workflow_run_id=2),
        _art("fresh", "build", 100, days_old=89, workflow_run_id=3),
        _art("today", "build", 100, days_old=0, workflow_run_id=4),
    ]
    cfg = CleanupConfig(max_age_days=90)
    plan = build_plan(artifacts, cfg, now=REF_NOW)

    deleted_ids = {d.id for d in plan.deletions}
    retained_ids = {r.id for r in plan.retained}
    assert deleted_ids == {"old1", "old2"}
    assert retained_ids == {"fresh", "today"}
    assert all(d.reason == "max_age_days" for d in plan.deletions)


# --------------------------------------------------------------------------
# 4. max_total_size_bytes evicts oldest first until under the cap.
# --------------------------------------------------------------------------
def test_max_total_size_evicts_oldest_first():
    artifacts = [
        _art("a", "build", 500, days_old=30, workflow_run_id=1),
        _art("b", "build", 500, days_old=20, workflow_run_id=2),
        _art("c", "build", 500, days_old=10, workflow_run_id=3),
        _art("d", "build", 500, days_old=5, workflow_run_id=4),
    ]
    # Total 2000 bytes. Cap at 1000 -> need to drop 1000 bytes -> oldest two go.
    cfg = CleanupConfig(max_total_size_bytes=1000)
    plan = build_plan(artifacts, cfg, now=REF_NOW)
    assert {d.id for d in plan.deletions} == {"a", "b"}
    assert {r.id for r in plan.retained} == {"c", "d"}
    assert all(d.reason == "max_total_size_bytes" for d in plan.deletions)


def test_max_total_size_no_eviction_when_under_cap():
    artifacts = [_art("a", "build", 100, days_old=1, workflow_run_id=1)]
    cfg = CleanupConfig(max_total_size_bytes=1000)
    plan = build_plan(artifacts, cfg, now=REF_NOW)
    assert plan.deletions == []
    assert len(plan.retained) == 1


# --------------------------------------------------------------------------
# 5. keep_latest_n_per_workflow groups by name, keeps newest N.
# --------------------------------------------------------------------------
def test_keep_latest_n_per_workflow():
    artifacts = [
        _art("b1", "build", 100, days_old=30, workflow_run_id=1),
        _art("b2", "build", 100, days_old=20, workflow_run_id=2),
        _art("b3", "build", 100, days_old=10, workflow_run_id=3),
        _art("b4", "build", 100, days_old=5, workflow_run_id=4),
        _art("t1", "test", 100, days_old=20, workflow_run_id=5),
        _art("t2", "test", 100, days_old=10, workflow_run_id=6),
    ]
    cfg = CleanupConfig(keep_latest_n_per_workflow=2)
    plan = build_plan(artifacts, cfg, now=REF_NOW)
    # Per-name newest two: build -> b3, b4; test -> t1, t2 (only two exist).
    assert {d.id for d in plan.deletions} == {"b1", "b2"}
    assert {r.id for r in plan.retained} == {"b3", "b4", "t1", "t2"}
    assert all(d.reason == "keep_latest_n_per_workflow" for d in plan.deletions)


# --------------------------------------------------------------------------
# 6. Policies compose. An artifact deleted by any policy is deleted overall.
# --------------------------------------------------------------------------
def test_combined_policies_union_of_deletions():
    artifacts = [
        _art("ancient", "build", 100, days_old=400, workflow_run_id=1),  # max_age
        _art("medium", "build", 100, days_old=200, workflow_run_id=2),   # max_age + keep_latest
        _art("recent1", "build", 100, days_old=20, workflow_run_id=3),
        _art("recent2", "build", 100, days_old=10, workflow_run_id=4),
        _art("newest", "build", 100, days_old=1, workflow_run_id=5),
    ]
    cfg = CleanupConfig(max_age_days=90, keep_latest_n_per_workflow=2)
    plan = build_plan(artifacts, cfg, now=REF_NOW)
    # max_age removes ancient + medium (both >90d). keep_latest_n=2 of remaining
    # by name "build": newest, recent2 are kept; recent1 is dropped.
    deleted_ids = {d.id for d in plan.deletions}
    assert deleted_ids == {"ancient", "medium", "recent1"}
    # The first reason that matched should be reported for each deletion.
    reason_by_id = {d.id: d.reason for d in plan.deletions}
    assert reason_by_id["ancient"] == "max_age_days"
    assert reason_by_id["medium"] == "max_age_days"
    assert reason_by_id["recent1"] == "keep_latest_n_per_workflow"


# --------------------------------------------------------------------------
# 7. Summary numbers are correct.
# --------------------------------------------------------------------------
def test_summary_counts_and_reclaim():
    artifacts = [
        _art("a", "build", 1000, days_old=400, workflow_run_id=1),
        _art("b", "build", 2000, days_old=10, workflow_run_id=2),
    ]
    cfg = CleanupConfig(max_age_days=90)
    plan = build_plan(artifacts, cfg, now=REF_NOW)
    s = plan.summary
    assert s["total_artifacts"] == 2
    assert s["deleted_count"] == 1
    assert s["retained_count"] == 1
    assert s["space_reclaimed_bytes"] == 1000
    assert s["space_retained_bytes"] == 2000


# --------------------------------------------------------------------------
# 8. Dry-run flag is reflected in output but doesn't change which deletions
#    appear in the plan (the plan is the same; the executor would skip).
# --------------------------------------------------------------------------
def test_dry_run_marker_in_summary():
    artifacts = [_art("a", "build", 100, days_old=400, workflow_run_id=1)]
    cfg = CleanupConfig(max_age_days=90, dry_run=True)
    plan = build_plan(artifacts, cfg, now=REF_NOW)
    assert plan.summary["dry_run"] is True
    assert {d.id for d in plan.deletions} == {"a"}


def test_dry_run_default_false():
    plan = build_plan([], CleanupConfig(), now=REF_NOW)
    assert plan.summary["dry_run"] is False


# --------------------------------------------------------------------------
# 9. JSON loader parses the documented shape.
# --------------------------------------------------------------------------
def test_load_artifacts_from_json(tmp_path: Path):
    data = [
        {
            "id": "x",
            "name": "build",
            "size_bytes": 123,
            "created_at": "2026-04-01T00:00:00Z",
            "workflow_run_id": 7,
        }
    ]
    p = tmp_path / "a.json"
    p.write_text(json.dumps(data))
    arts = load_artifacts(p)
    assert len(arts) == 1
    assert arts[0].id == "x"
    assert arts[0].size_bytes == 123
    assert arts[0].workflow_run_id == 7
    assert arts[0].created_at.tzinfo is not None


# --------------------------------------------------------------------------
# 10. Bad JSON shapes raise CleanupError with a useful message.
# --------------------------------------------------------------------------
def test_load_artifacts_missing_field(tmp_path: Path):
    p = tmp_path / "a.json"
    p.write_text(json.dumps([{"id": "x", "name": "build"}]))  # missing size etc.
    with pytest.raises(CleanupError) as exc:
        load_artifacts(p)
    assert "size_bytes" in str(exc.value) or "missing" in str(exc.value).lower()


def test_load_artifacts_bad_json(tmp_path: Path):
    p = tmp_path / "a.json"
    p.write_text("not json {{{")
    with pytest.raises(CleanupError):
        load_artifacts(p)


def test_load_artifacts_not_a_list(tmp_path: Path):
    p = tmp_path / "a.json"
    p.write_text(json.dumps({"oops": "object instead of list"}))
    with pytest.raises(CleanupError):
        load_artifacts(p)


# --------------------------------------------------------------------------
# 11. Human-readable summary renderer.
# --------------------------------------------------------------------------
def test_render_summary_contains_key_numbers():
    artifacts = [
        _art("a", "build", 1000, days_old=400, workflow_run_id=1),
        _art("b", "build", 2000, days_old=10, workflow_run_id=2),
    ]
    plan = build_plan(artifacts, CleanupConfig(max_age_days=90), now=REF_NOW)
    text = render_summary(plan)
    assert "1 deleted" in text
    assert "1 retained" in text
    assert "1000" in text  # reclaimed bytes
    assert "DRY RUN" not in text  # dry_run flag was False


def test_render_summary_dry_run_label():
    plan = build_plan([], CleanupConfig(dry_run=True), now=REF_NOW)
    assert "DRY RUN" in render_summary(plan)
