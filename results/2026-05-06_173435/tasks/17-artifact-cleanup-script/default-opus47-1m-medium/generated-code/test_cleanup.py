"""Tests for artifact cleanup script.

Built incrementally with TDD: each test was written before the
corresponding implementation, run to confirm failure, then made green.
"""
from datetime import datetime, timedelta, timezone
import json
import subprocess
import sys
from pathlib import Path

import pytest

from cleanup import (
    Artifact,
    RetentionPolicy,
    plan_cleanup,
    format_summary,
    load_artifacts,
    main,
)


NOW = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)


def art(name, size, age_days, run_id):
    """Helper: build an Artifact whose creation date is `age_days` ago."""
    return Artifact(
        name=name,
        size_bytes=size,
        created_at=NOW - timedelta(days=age_days),
        workflow_run_id=run_id,
    )


# --- 1: max-age policy ---------------------------------------------------

def test_max_age_marks_old_artifacts_for_deletion():
    artifacts = [art("a", 100, 10, "r1"), art("b", 200, 1, "r2")]
    policy = RetentionPolicy(max_age_days=5, now=NOW)
    plan = plan_cleanup(artifacts, policy)
    assert [a.name for a in plan.to_delete] == ["a"]
    assert [a.name for a in plan.to_retain] == ["b"]


# --- 2: keep-latest-N per workflow --------------------------------------

def test_keep_latest_n_per_workflow():
    # Same workflow run "r1" with three artifacts of different ages.
    artifacts = [
        art("old", 100, 10, "r1"),
        art("mid", 100, 5, "r1"),
        art("new", 100, 1, "r1"),
        art("only", 100, 1, "r2"),
    ]
    policy = RetentionPolicy(keep_latest_per_workflow=2, now=NOW)
    plan = plan_cleanup(artifacts, policy)
    assert sorted(a.name for a in plan.to_delete) == ["old"]
    assert sorted(a.name for a in plan.to_retain) == ["mid", "new", "only"]


# --- 3: max-total-size policy -------------------------------------------

def test_max_total_size_deletes_oldest_until_under_budget():
    # Total = 600. Budget = 350. Must delete oldest until <= 350.
    artifacts = [
        art("oldest", 200, 10, "r1"),
        art("middle", 200, 5, "r2"),
        art("newest", 200, 1, "r3"),
    ]
    policy = RetentionPolicy(max_total_size_bytes=350, now=NOW)
    plan = plan_cleanup(artifacts, policy)
    # Delete oldest two -> 200 retained which is <= 350.
    assert sorted(a.name for a in plan.to_delete) == ["middle", "oldest"]
    assert [a.name for a in plan.to_retain] == ["newest"]


# --- 4: combined policies (union of deletions) --------------------------

def test_combined_policies_union():
    artifacts = [
        art("ancient", 100, 30, "r1"),  # killed by age
        art("recent_r1_old", 100, 2, "r1"),  # killed by keep-latest=1
        art("recent_r1_new", 100, 1, "r1"),  # kept
        art("solo", 100, 2, "r2"),  # kept
    ]
    policy = RetentionPolicy(
        max_age_days=10, keep_latest_per_workflow=1, now=NOW
    )
    plan = plan_cleanup(artifacts, policy)
    assert sorted(a.name for a in plan.to_delete) == ["ancient", "recent_r1_old"]
    assert sorted(a.name for a in plan.to_retain) == ["recent_r1_new", "solo"]


# --- 5: summary numbers --------------------------------------------------

def test_summary_reports_totals():
    artifacts = [art("a", 100, 10, "r1"), art("b", 200, 1, "r2")]
    policy = RetentionPolicy(max_age_days=5, now=NOW)
    plan = plan_cleanup(artifacts, policy)
    assert plan.bytes_reclaimed == 100
    assert plan.retained_count == 1
    assert plan.deleted_count == 1


# --- 6: format_summary text ---------------------------------------------

def test_format_summary_includes_key_numbers():
    artifacts = [art("a", 100, 10, "r1"), art("b", 200, 1, "r2")]
    plan = plan_cleanup(artifacts, RetentionPolicy(max_age_days=5, now=NOW))
    text = format_summary(plan, dry_run=True)
    assert "DRY-RUN" in text
    assert "Deleted: 1" in text
    assert "Retained: 1" in text
    assert "Reclaimed: 100" in text
    assert "a" in text


def test_format_summary_marks_apply_mode():
    plan = plan_cleanup(
        [art("a", 100, 10, "r1")], RetentionPolicy(max_age_days=5, now=NOW)
    )
    assert "APPLY" in format_summary(plan, dry_run=False)


# --- 7: load_artifacts from JSON ----------------------------------------

def test_load_artifacts_from_json(tmp_path):
    fixture = tmp_path / "f.json"
    fixture.write_text(json.dumps([
        {
            "name": "a",
            "size_bytes": 100,
            "created_at": "2026-05-01T00:00:00Z",
            "workflow_run_id": "r1",
        }
    ]))
    artifacts = load_artifacts(fixture)
    assert len(artifacts) == 1
    assert artifacts[0].name == "a"
    assert artifacts[0].size_bytes == 100
    assert artifacts[0].workflow_run_id == "r1"


def test_load_artifacts_missing_file_raises_clear_error(tmp_path):
    with pytest.raises(FileNotFoundError, match="not found"):
        load_artifacts(tmp_path / "missing.json")


def test_load_artifacts_bad_json_raises_clear_error(tmp_path):
    f = tmp_path / "bad.json"
    f.write_text("{not json")
    with pytest.raises(ValueError, match="Invalid JSON"):
        load_artifacts(f)


# --- 8: CLI / main ------------------------------------------------------

def test_cli_dry_run_prints_summary_and_exits_zero(tmp_path, capsys):
    fixture = tmp_path / "in.json"
    fixture.write_text(json.dumps([
        {"name": "old", "size_bytes": 100,
         "created_at": "2026-04-01T00:00:00Z", "workflow_run_id": "r1"},
        {"name": "new", "size_bytes": 200,
         "created_at": "2026-05-06T00:00:00Z", "workflow_run_id": "r2"},
    ]))
    rc = main([
        "--input", str(fixture),
        "--max-age-days", "5",
        "--dry-run",
        "--now", "2026-05-07T12:00:00Z",
    ])
    out = capsys.readouterr().out
    assert rc == 0
    assert "DRY-RUN" in out
    assert "Deleted: 1" in out
    assert "Retained: 1" in out


def test_cli_apply_mode(tmp_path, capsys):
    fixture = tmp_path / "in.json"
    fixture.write_text(json.dumps([
        {"name": "x", "size_bytes": 50,
         "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "r1"},
    ]))
    rc = main([
        "--input", str(fixture),
        "--max-age-days", "10",
        "--now", "2026-05-07T12:00:00Z",
    ])
    out = capsys.readouterr().out
    assert rc == 0
    assert "APPLY" in out


def test_cli_missing_input_returns_nonzero(tmp_path, capsys):
    rc = main(["--input", str(tmp_path / "nope.json"), "--max-age-days", "5"])
    err = capsys.readouterr().err
    assert rc != 0
    assert "not found" in err.lower()
