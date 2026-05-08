# TDD test suite for the artifact cleanup script.
# Tests are written first, then implementation is added to satisfy them.

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from cleanup import (
    Artifact,
    apply_max_age_policy,
    apply_max_total_size_policy,
    apply_keep_latest_n_policy,
    build_deletion_plan,
    load_artifacts,
    main,
)


NOW = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)


def make_artifact(name, size, age_days, workflow_id, art_id=None):
    return Artifact(
        id=art_id or f"{name}-{workflow_id}-{age_days}",
        name=name,
        size_bytes=size,
        created_at=NOW - timedelta(days=age_days),
        workflow_run_id=workflow_id,
    )


# --- Test 1: max age policy ---
def test_max_age_policy_marks_old_artifacts_for_deletion():
    artifacts = [
        make_artifact("a", 100, age_days=5, workflow_id="wf1"),
        make_artifact("b", 100, age_days=40, workflow_id="wf1"),
        make_artifact("c", 100, age_days=100, workflow_id="wf2"),
    ]
    to_delete = apply_max_age_policy(artifacts, max_age_days=30, now=NOW)
    ids = {a.id for a in to_delete}
    assert ids == {artifacts[1].id, artifacts[2].id}


def test_max_age_policy_no_op_when_all_fresh():
    artifacts = [make_artifact("a", 100, age_days=1, workflow_id="wf1")]
    assert apply_max_age_policy(artifacts, max_age_days=30, now=NOW) == []


# --- Test 2: keep latest N per workflow ---
def test_keep_latest_n_per_workflow_keeps_n_newest():
    artifacts = [
        make_artifact("a", 100, age_days=1, workflow_id="wf1"),
        make_artifact("b", 100, age_days=2, workflow_id="wf1"),
        make_artifact("c", 100, age_days=3, workflow_id="wf1"),
        make_artifact("d", 100, age_days=4, workflow_id="wf1"),
        make_artifact("e", 100, age_days=1, workflow_id="wf2"),
    ]
    # Keep latest 2 per workflow -> wf1 deletes c,d; wf2 deletes none
    to_delete = apply_keep_latest_n_policy(artifacts, keep_n=2)
    ids = {a.id for a in to_delete}
    assert ids == {artifacts[2].id, artifacts[3].id}


def test_keep_latest_n_zero_deletes_all():
    artifacts = [make_artifact("a", 100, age_days=1, workflow_id="wf1")]
    assert len(apply_keep_latest_n_policy(artifacts, keep_n=0)) == 1


# --- Test 3: max total size policy ---
def test_max_total_size_evicts_oldest_until_under_budget():
    # Total = 600 bytes; budget = 250.
    # Sort by oldest first; delete from oldest until remaining <= 250.
    artifacts = [
        make_artifact("a", 100, age_days=1, workflow_id="wf1"),
        make_artifact("b", 200, age_days=2, workflow_id="wf1"),
        make_artifact("c", 300, age_days=3, workflow_id="wf2"),
    ]
    to_delete = apply_max_total_size_policy(artifacts, max_total_bytes=250)
    ids = {a.id for a in to_delete}
    # Delete c (300, oldest) -> remaining 300 still > 250, delete b (200) -> 100 OK
    assert ids == {artifacts[2].id, artifacts[1].id}


def test_max_total_size_no_op_when_under_budget():
    artifacts = [make_artifact("a", 100, age_days=1, workflow_id="wf1")]
    assert apply_max_total_size_policy(artifacts, max_total_bytes=1000) == []


# --- Test 4: build deletion plan combines policies and computes summary ---
def test_build_deletion_plan_combines_policies_and_summary():
    artifacts = [
        make_artifact("fresh", 100, age_days=1, workflow_id="wf1"),
        make_artifact("old", 200, age_days=60, workflow_id="wf1"),
        make_artifact("excess", 300, age_days=2, workflow_id="wf1"),
    ]
    plan = build_deletion_plan(
        artifacts,
        max_age_days=30,
        keep_latest_n=1,
        max_total_bytes=None,
        now=NOW,
    )
    deleted_ids = {a.id for a in plan["to_delete"]}
    # 'old' is deleted by age. 'excess' is the older fresh one (age 2 vs 1) so
    # keep_latest_n=1 in wf1 keeps 'fresh' and deletes 'excess'.
    assert deleted_ids == {artifacts[1].id, artifacts[2].id}
    assert plan["summary"]["bytes_reclaimed"] == 500
    assert plan["summary"]["deleted_count"] == 2
    assert plan["summary"]["retained_count"] == 1
    assert plan["summary"]["total_count"] == 3


def test_build_deletion_plan_empty_input():
    plan = build_deletion_plan([], max_age_days=30, keep_latest_n=5,
                               max_total_bytes=None, now=NOW)
    assert plan["to_delete"] == []
    assert plan["summary"]["total_count"] == 0
    assert plan["summary"]["bytes_reclaimed"] == 0


# --- Test 5: load_artifacts from JSON ---
def test_load_artifacts_parses_json(tmp_path: Path):
    data = [
        {
            "id": "x1",
            "name": "build",
            "size_bytes": 1234,
            "created_at": "2026-05-01T00:00:00Z",
            "workflow_run_id": "wf-100",
        }
    ]
    p = tmp_path / "artifacts.json"
    p.write_text(json.dumps(data))
    artifacts = load_artifacts(p)
    assert len(artifacts) == 1
    assert artifacts[0].id == "x1"
    assert artifacts[0].size_bytes == 1234
    assert artifacts[0].created_at == datetime(2026, 5, 1, tzinfo=timezone.utc)


def test_load_artifacts_missing_file_raises(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        load_artifacts(tmp_path / "nope.json")


def test_load_artifacts_invalid_json_raises(tmp_path: Path):
    p = tmp_path / "bad.json"
    p.write_text("{not json")
    with pytest.raises(ValueError, match="Invalid JSON"):
        load_artifacts(p)


def test_load_artifacts_missing_field_raises(tmp_path: Path):
    p = tmp_path / "bad.json"
    p.write_text(json.dumps([{"id": "x"}]))
    with pytest.raises(ValueError, match="missing field"):
        load_artifacts(p)


# --- Test 6: CLI main with dry-run ---
def test_main_dry_run_prints_plan_without_side_effects(tmp_path: Path, capsys):
    data = [
        {"id": "a", "name": "n1", "size_bytes": 100,
         "created_at": "2026-05-07T00:00:00Z", "workflow_run_id": "wf1"},
        {"id": "b", "name": "n2", "size_bytes": 500,
         "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "wf1"},
    ]
    p = tmp_path / "artifacts.json"
    p.write_text(json.dumps(data))

    rc = main([
        "--input", str(p),
        "--max-age-days", "30",
        "--keep-latest-n", "5",
        "--dry-run",
        "--now", "2026-05-08T12:00:00Z",
    ])
    assert rc == 0
    out = capsys.readouterr().out
    assert "DRY-RUN" in out
    assert "bytes_reclaimed" in out
    # 'b' is older than 30 days -> deleted
    assert '"id": "b"' in out


def test_main_non_dry_run_writes_plan_file(tmp_path: Path):
    data = [
        {"id": "a", "name": "n1", "size_bytes": 100,
         "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "wf1"},
    ]
    p = tmp_path / "artifacts.json"
    p.write_text(json.dumps(data))
    out_path = tmp_path / "plan.json"

    rc = main([
        "--input", str(p),
        "--max-age-days", "30",
        "--keep-latest-n", "5",
        "--output", str(out_path),
        "--now", "2026-05-08T12:00:00Z",
    ])
    assert rc == 0
    assert out_path.exists()
    plan = json.loads(out_path.read_text())
    assert plan["summary"]["deleted_count"] == 1


def test_main_returns_nonzero_on_missing_input():
    rc = main(["--input", "/no/such/file.json", "--max-age-days", "30",
               "--keep-latest-n", "5", "--dry-run"])
    assert rc != 0
