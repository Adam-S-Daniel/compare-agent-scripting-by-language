"""
Tests for the artifact cleanup script.

Developed red/green TDD: each test below was written before the corresponding
code in cleanup.py. Tests use fixed timestamps via an injected `now` parameter
so assertions remain deterministic.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from cleanup import (  # noqa: E402
    Artifact,
    RetentionPolicy,
    build_plan,
    format_summary,
    load_artifacts,
    load_policy,
)

# A single fixed reference point so tests don't depend on wall-clock time.
NOW = datetime(2026, 4, 19, 12, 0, 0, tzinfo=timezone.utc)


def _art(name: str, size: int, age_days: float, run_id: str, workflow: str = "ci") -> Artifact:
    created = NOW - timedelta(days=age_days)
    return Artifact(
        name=name,
        size_bytes=size,
        created_at=created,
        workflow_run_id=run_id,
        workflow_name=workflow,
    )


# --- RED 1: age-based retention ---
def test_max_age_marks_old_artifacts_for_deletion():
    artifacts = [
        _art("a", 100, age_days=60, run_id="r1"),
        _art("b", 200, age_days=5, run_id="r2"),
    ]
    policy = RetentionPolicy(max_age_days=30)
    plan = build_plan(artifacts, policy, now=NOW)
    deleted_names = {a.name for a in plan.deleted}
    assert deleted_names == {"a"}
    assert {a.name for a in plan.retained} == {"b"}


def test_max_age_none_keeps_everything_by_age():
    artifacts = [_art("old", 100, age_days=365, run_id="r1")]
    policy = RetentionPolicy(max_age_days=None)
    plan = build_plan(artifacts, policy, now=NOW)
    assert plan.deleted == []
    assert len(plan.retained) == 1


# --- RED 2: keep-latest-N per workflow ---
def test_keep_latest_n_per_workflow():
    artifacts = [
        _art("a1", 10, age_days=10, run_id="r1", workflow="build"),
        _art("a2", 10, age_days=5, run_id="r2", workflow="build"),
        _art("a3", 10, age_days=1, run_id="r3", workflow="build"),
        _art("b1", 10, age_days=7, run_id="r4", workflow="test"),
        _art("b2", 10, age_days=2, run_id="r5", workflow="test"),
    ]
    policy = RetentionPolicy(keep_latest_n_per_workflow=2)
    plan = build_plan(artifacts, policy, now=NOW)
    # Oldest in "build" is "a1"; "test" has only 2 so both kept.
    assert {a.name for a in plan.deleted} == {"a1"}
    assert {a.name for a in plan.retained} == {"a2", "a3", "b1", "b2"}


# --- RED 3: max total size ---
def test_max_total_size_trims_oldest_first():
    artifacts = [
        _art("oldest", 100, age_days=10, run_id="r1"),
        _art("middle", 100, age_days=5, run_id="r2"),
        _art("newest", 100, age_days=1, run_id="r3"),
    ]
    policy = RetentionPolicy(max_total_size_bytes=200)
    plan = build_plan(artifacts, policy, now=NOW)
    assert {a.name for a in plan.deleted} == {"oldest"}
    retained_size = sum(a.size_bytes for a in plan.retained)
    assert retained_size <= 200


def test_max_total_size_not_exceeded_means_no_deletion():
    artifacts = [_art("a", 50, age_days=1, run_id="r1")]
    policy = RetentionPolicy(max_total_size_bytes=1000)
    plan = build_plan(artifacts, policy, now=NOW)
    assert plan.deleted == []


# --- RED 4: combined policies ---
def test_combined_policies_union_of_deletions():
    artifacts = [
        _art("expired", 100, age_days=60, run_id="r1", workflow="build"),
        _art("surplus", 100, age_days=20, run_id="r2", workflow="build"),
        _art("keep-1", 100, age_days=10, run_id="r3", workflow="build"),
        _art("keep-2", 100, age_days=1, run_id="r4", workflow="build"),
    ]
    policy = RetentionPolicy(max_age_days=30, keep_latest_n_per_workflow=2)
    plan = build_plan(artifacts, policy, now=NOW)
    assert {a.name for a in plan.deleted} == {"expired", "surplus"}
    assert {a.name for a in plan.retained} == {"keep-1", "keep-2"}


# --- RED 5: summary formatting ---
def test_summary_reports_counts_and_reclaimed_bytes():
    artifacts = [
        _art("a", 1024, age_days=100, run_id="r1"),
        _art("b", 2048, age_days=1, run_id="r2"),
    ]
    policy = RetentionPolicy(max_age_days=30)
    plan = build_plan(artifacts, policy, now=NOW)
    summary = format_summary(plan, dry_run=True)
    assert "deleted: 1" in summary.lower()
    assert "retained: 1" in summary.lower()
    assert "1024" in summary
    assert "DRY RUN" in summary


def test_summary_non_dry_run_does_not_say_dry_run():
    plan = build_plan([], RetentionPolicy(), now=NOW)
    summary = format_summary(plan, dry_run=False)
    assert "DRY RUN" not in summary


# --- RED 6: JSON loading ---
def test_load_artifacts_from_json(tmp_path: Path):
    p = tmp_path / "arts.json"
    p.write_text(json.dumps([
        {
            "name": "a",
            "size_bytes": 100,
            "created_at": "2026-03-01T00:00:00Z",
            "workflow_run_id": "r1",
            "workflow_name": "build",
        }
    ]))
    artifacts = load_artifacts(p)
    assert len(artifacts) == 1
    assert artifacts[0].name == "a"
    assert artifacts[0].size_bytes == 100


def test_load_artifacts_missing_file_raises(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        load_artifacts(tmp_path / "missing.json")


def test_load_artifacts_rejects_malformed(tmp_path: Path):
    p = tmp_path / "bad.json"
    p.write_text('[{"name": "x"}]')  # missing required fields
    with pytest.raises(ValueError):
        load_artifacts(p)


def test_load_policy_from_json(tmp_path: Path):
    p = tmp_path / "pol.json"
    p.write_text(json.dumps({"max_age_days": 30, "keep_latest_n_per_workflow": 5}))
    policy = load_policy(p)
    assert policy.max_age_days == 30
    assert policy.keep_latest_n_per_workflow == 5
    assert policy.max_total_size_bytes is None


# --- RED 7: CLI end-to-end ---
def _run_cli(*args: str) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    return subprocess.run(
        [sys.executable, str(ROOT / "cleanup.py"), *args],
        capture_output=True,
        text=True,
        env=env,
    )


def test_cli_dry_run_outputs_plan(tmp_path: Path):
    arts_path = tmp_path / "arts.json"
    pol_path = tmp_path / "pol.json"
    plan_path = tmp_path / "plan.json"
    arts_path.write_text(json.dumps([
        {
            "name": "old",
            "size_bytes": 500,
            "created_at": "2025-01-01T00:00:00Z",
            "workflow_run_id": "r1",
            "workflow_name": "build",
        }
    ]))
    pol_path.write_text(json.dumps({"max_age_days": 30}))
    result = _run_cli(
        "--artifacts", str(arts_path),
        "--policy", str(pol_path),
        "--output", str(plan_path),
        "--now", "2026-04-19T12:00:00Z",
        "--dry-run",
    )
    assert result.returncode == 0, result.stderr
    assert "DRY RUN" in result.stdout
    plan_doc = json.loads(plan_path.read_text())
    assert plan_doc["summary"]["deleted_count"] == 1
    assert plan_doc["summary"]["reclaimed_bytes"] == 500


def test_cli_exits_nonzero_on_bad_input(tmp_path: Path):
    result = _run_cli(
        "--artifacts", str(tmp_path / "nope.json"),
        "--policy", str(tmp_path / "also-nope.json"),
    )
    assert result.returncode != 0
    assert result.stderr.strip() != ""
