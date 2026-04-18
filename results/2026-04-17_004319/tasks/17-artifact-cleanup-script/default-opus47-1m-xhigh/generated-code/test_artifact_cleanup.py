"""
Tests for artifact_cleanup module.

Uses red/green TDD: each test was written before the corresponding implementation.
Test names track the increments made to artifact_cleanup.py.
"""
from datetime import datetime, timedelta, timezone
import json
import subprocess
import sys
from pathlib import Path

import pytest

import artifact_cleanup as ac


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


NOW = datetime(2026, 4, 17, 12, 0, 0, tzinfo=timezone.utc)


_next_id = [1000]


def make_artifact(name, size_bytes, age_days, workflow_run_id, artifact_id=None):
    """Build a single artifact dict with creation date computed from age.

    Uses an auto-incrementing id so no two artifacts collide on identity.
    """
    if artifact_id is None:
        artifact_id = _next_id[0]
        _next_id[0] += 1
    return {
        "id": artifact_id,
        "name": name,
        "size_bytes": size_bytes,
        "created_at": (NOW - timedelta(days=age_days)).isoformat(),
        "workflow_run_id": workflow_run_id,
    }


@pytest.fixture
def sample_artifacts():
    """A small mixed fixture used across tests."""
    return [
        make_artifact("build-logs", 1_000_000, age_days=1, workflow_run_id=100),
        make_artifact("build-logs", 2_000_000, age_days=10, workflow_run_id=101),
        make_artifact("build-logs", 3_000_000, age_days=40, workflow_run_id=102),
        make_artifact("coverage", 500_000, age_days=5, workflow_run_id=200),
        make_artifact("coverage", 600_000, age_days=15, workflow_run_id=201),
    ]


# ---------------------------------------------------------------------------
# 1. Policy parsing / defaults
# ---------------------------------------------------------------------------


def test_default_policy_has_no_limits():
    """A freshly-built default policy keeps all artifacts."""
    policy = ac.RetentionPolicy()
    assert policy.max_age_days is None
    assert policy.max_total_size_bytes is None
    assert policy.keep_latest_n_per_workflow is None


# ---------------------------------------------------------------------------
# 2. Max-age rule
# ---------------------------------------------------------------------------


def test_max_age_marks_old_artifacts_for_deletion(sample_artifacts):
    """Anything older than max_age_days should land in `to_delete`."""
    policy = ac.RetentionPolicy(max_age_days=30)
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    deleted_names = {(a["name"], a["workflow_run_id"]) for a in plan.to_delete}
    assert deleted_names == {("build-logs", 102)}


def test_max_age_zero_deletes_everything(sample_artifacts):
    """A zero-day policy means nothing is fresh enough."""
    policy = ac.RetentionPolicy(max_age_days=0)
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    assert len(plan.to_delete) == len(sample_artifacts)
    assert plan.to_retain == []


# ---------------------------------------------------------------------------
# 3. Keep-latest-N-per-workflow rule
# ---------------------------------------------------------------------------


def test_keep_latest_n_per_workflow_groups_by_name(sample_artifacts):
    """With keep=1, the newest artifact per `name` survives."""
    policy = ac.RetentionPolicy(keep_latest_n_per_workflow=1)
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    retained = {(a["name"], a["workflow_run_id"]) for a in plan.to_retain}
    assert retained == {("build-logs", 100), ("coverage", 200)}


# ---------------------------------------------------------------------------
# 4. Max-total-size rule
# ---------------------------------------------------------------------------


def test_max_total_size_evicts_oldest_first(sample_artifacts):
    """When the corpus exceeds max size, oldest artifacts are evicted first."""
    # Total size is 7.1MB. Cap at 4MB — oldest should be evicted until under cap.
    policy = ac.RetentionPolicy(max_total_size_bytes=4_000_000)
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    total_retained_size = sum(a["size_bytes"] for a in plan.to_retain)
    assert total_retained_size <= 4_000_000
    # The 40-day-old build-logs is the oldest — definitely deleted.
    deleted_ids = {a["workflow_run_id"] for a in plan.to_delete}
    assert 102 in deleted_ids


# ---------------------------------------------------------------------------
# 5. Combined policies
# ---------------------------------------------------------------------------


def test_combined_policies_union_of_deletions(sample_artifacts):
    """
    A deletion by any rule wins. An artifact kept by keep-latest but old
    enough to fail max_age must still be deleted.
    """
    policy = ac.RetentionPolicy(
        max_age_days=20,
        keep_latest_n_per_workflow=5,  # wouldn't delete anything on its own
    )
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    deleted_ids = {a["workflow_run_id"] for a in plan.to_delete}
    assert deleted_ids == {102}  # the 40-day-old build-logs


# ---------------------------------------------------------------------------
# 6. Summary / reclaimed bytes
# ---------------------------------------------------------------------------


def test_summary_reports_counts_and_reclaimed_bytes(sample_artifacts):
    policy = ac.RetentionPolicy(max_age_days=30)
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    summary = plan.summary()
    assert summary["artifacts_total"] == 5
    assert summary["artifacts_retained"] == 4
    assert summary["artifacts_deleted"] == 1
    assert summary["bytes_reclaimed"] == 3_000_000
    assert summary["bytes_retained"] == 1_000_000 + 2_000_000 + 500_000 + 600_000


# ---------------------------------------------------------------------------
# 7. Dry-run mode: plan.apply() should not touch anything when dry-run
# ---------------------------------------------------------------------------


def test_dry_run_does_not_call_deleter(sample_artifacts):
    """In dry-run, no deletion callback is invoked."""
    policy = ac.RetentionPolicy(max_age_days=30)
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    called_with = []
    plan.apply(deleter=lambda a: called_with.append(a), dry_run=True)
    assert called_with == []


def test_non_dry_run_invokes_deleter_per_artifact(sample_artifacts):
    policy = ac.RetentionPolicy(max_age_days=30)
    plan = ac.build_deletion_plan(sample_artifacts, policy, now=NOW)
    called_with = []
    plan.apply(deleter=lambda a: called_with.append(a["id"]), dry_run=False)
    assert len(called_with) == 1


# ---------------------------------------------------------------------------
# 8. Error handling
# ---------------------------------------------------------------------------


def test_invalid_artifact_raises_clear_error():
    """Missing required fields should surface a helpful ValueError."""
    bad = [{"name": "oops"}]  # missing size_bytes, created_at, workflow_run_id
    with pytest.raises(ValueError, match="missing required field"):
        ac.build_deletion_plan(bad, ac.RetentionPolicy())


def test_negative_max_age_rejected():
    with pytest.raises(ValueError, match="max_age_days"):
        ac.RetentionPolicy(max_age_days=-1)


# ---------------------------------------------------------------------------
# 9. CLI entrypoint — reads JSON, writes JSON
# ---------------------------------------------------------------------------


def test_cli_produces_deletion_plan_json(tmp_path, sample_artifacts):
    """End-to-end: feed the CLI a JSON file and parse its structured output."""
    script = Path(__file__).parent / "artifact_cleanup.py"
    fixture = tmp_path / "artifacts.json"
    fixture.write_text(json.dumps(sample_artifacts))

    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "--input",
            str(fixture),
            "--max-age-days",
            "30",
            "--dry-run",
            "--now",
            NOW.isoformat(),
            "--json",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    payload = json.loads(result.stdout)
    assert payload["summary"]["artifacts_deleted"] == 1
    assert payload["summary"]["bytes_reclaimed"] == 3_000_000
    assert payload["dry_run"] is True
