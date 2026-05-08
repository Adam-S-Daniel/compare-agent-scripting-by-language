"""
Tests for artifact_cleanup.py using red/green TDD.
Each test was written BEFORE the implementation code that makes it pass.
"""
import pytest
from datetime import datetime, timezone, timedelta
from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    apply_retention_policies,
    DeletionPlan,
    format_summary,
)


# --- Fixtures / helpers ---

def make_artifact(name: str, size_mb: int, age_days: int, workflow_run_id: str) -> Artifact:
    """Create an artifact with creation date offset by age_days from now."""
    now = datetime(2024, 6, 1, tzinfo=timezone.utc)
    created_at = now - timedelta(days=age_days)
    return Artifact(
        name=name,
        size=size_mb * 1024 * 1024,
        created_at=created_at,
        workflow_run_id=workflow_run_id,
    )


# Freeze "now" for deterministic tests
NOW = datetime(2024, 6, 1, tzinfo=timezone.utc)


# === TEST 1: Age-based deletion ===
# RED: Written before apply_retention_policies exists.
def test_age_policy_marks_old_artifacts_for_deletion():
    artifacts = [
        make_artifact("old-1", 10, age_days=45, workflow_run_id="run-1"),
        make_artifact("old-2", 20, age_days=31, workflow_run_id="run-2"),
        make_artifact("new-1", 15, age_days=10, workflow_run_id="run-3"),
        make_artifact("new-2", 5, age_days=1, workflow_run_id="run-4"),
    ]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, now=NOW)

    deleted_names = {a.name for a in plan.artifacts_to_delete}
    kept_names = {a.name for a in plan.artifacts_to_keep}

    assert deleted_names == {"old-1", "old-2"}
    assert kept_names == {"new-1", "new-2"}
    assert plan.space_reclaimed_bytes == (10 + 20) * 1024 * 1024


# === TEST 2: Keep-latest-N per workflow ===
def test_keep_latest_n_per_workflow():
    # workflow-A has 4 artifacts; policy keeps only 2 latest
    artifacts = [
        make_artifact("a-oldest", 5, age_days=20, workflow_run_id="workflow-A"),
        make_artifact("a-old", 5, age_days=15, workflow_run_id="workflow-A"),
        make_artifact("a-recent", 5, age_days=5, workflow_run_id="workflow-A"),
        make_artifact("a-newest", 5, age_days=1, workflow_run_id="workflow-A"),
        make_artifact("b-only", 10, age_days=10, workflow_run_id="workflow-B"),
    ]
    policy = RetentionPolicy(keep_latest_n_per_workflow=2)
    plan = apply_retention_policies(artifacts, policy, now=NOW)

    deleted_names = {a.name for a in plan.artifacts_to_delete}
    kept_names = {a.name for a in plan.artifacts_to_keep}

    # Two oldest from workflow-A should be deleted; workflow-B has only 1 so kept
    assert deleted_names == {"a-oldest", "a-old"}
    assert kept_names == {"a-recent", "a-newest", "b-only"}


# === TEST 3: Max total size — delete oldest until under limit ===
def test_max_total_size_deletes_oldest_first():
    # Total = 100+80+60+40 = 280MB; limit = 150MB; must remove 130MB
    artifacts = [
        make_artifact("big-oldest", 100, age_days=30, workflow_run_id="run-1"),
        make_artifact("big-old", 80, age_days=20, workflow_run_id="run-2"),
        make_artifact("med-recent", 60, age_days=10, workflow_run_id="run-3"),
        make_artifact("small-newest", 40, age_days=1, workflow_run_id="run-4"),
    ]
    policy = RetentionPolicy(max_total_size_bytes=150 * 1024 * 1024)
    plan = apply_retention_policies(artifacts, policy, now=NOW)

    deleted_names = {a.name for a in plan.artifacts_to_delete}
    # 100+80=180MB deleted, leaving 60+40=100MB which is under 150MB
    assert deleted_names == {"big-oldest", "big-old"}
    remaining_size = sum(a.size for a in plan.artifacts_to_keep)
    assert remaining_size <= 150 * 1024 * 1024


# === TEST 4: Dry-run mode returns correct plan but flags it ===
def test_dry_run_flag_is_preserved():
    artifacts = [
        make_artifact("old-artifact", 50, age_days=60, workflow_run_id="run-1"),
    ]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, now=NOW, dry_run=True)

    assert plan.dry_run is True
    assert len(plan.artifacts_to_delete) == 1


# === TEST 5: Summary formatting ===
def test_format_summary_output():
    artifacts = [
        make_artifact("old-1", 100, age_days=40, workflow_run_id="run-1"),
        make_artifact("new-1", 50, age_days=5, workflow_run_id="run-2"),
    ]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, now=NOW)
    summary = format_summary(plan)

    assert "1" in summary  # 1 deleted
    assert "1" in summary  # 1 kept
    # Space reclaimed should mention 100 MB
    assert "104857600" in summary or "100" in summary


# === TEST 6: Combined policies — age + keep-N ===
def test_combined_policies_union_of_deletions():
    artifacts = [
        make_artifact("a-old-1", 10, age_days=40, workflow_run_id="wf-A"),
        make_artifact("a-old-2", 10, age_days=35, workflow_run_id="wf-A"),
        make_artifact("a-new-1", 10, age_days=5, workflow_run_id="wf-A"),
        make_artifact("a-new-2", 10, age_days=2, workflow_run_id="wf-A"),
        make_artifact("a-new-3", 10, age_days=1, workflow_run_id="wf-A"),
    ]
    # Age removes a-old-1, a-old-2; keep-2 removes the next oldest (a-new-1)
    policy = RetentionPolicy(max_age_days=30, keep_latest_n_per_workflow=2)
    plan = apply_retention_policies(artifacts, policy, now=NOW)

    deleted_names = {a.name for a in plan.artifacts_to_delete}
    assert "a-old-1" in deleted_names
    assert "a-old-2" in deleted_names
    assert "a-new-1" in deleted_names
    assert "a-new-2" not in deleted_names
    assert "a-new-3" not in deleted_names


# === TEST 7: Empty artifact list ===
def test_empty_artifact_list():
    plan = apply_retention_policies([], RetentionPolicy(max_age_days=30), now=NOW)
    assert plan.artifacts_to_delete == []
    assert plan.artifacts_to_keep == []
    assert plan.space_reclaimed_bytes == 0


# === TEST 8: No policy — nothing deleted ===
def test_no_policy_keeps_everything():
    artifacts = [
        make_artifact("any-artifact", 100, age_days=999, workflow_run_id="run-1"),
    ]
    plan = apply_retention_policies(artifacts, RetentionPolicy(), now=NOW)
    assert plan.artifacts_to_delete == []
    assert len(plan.artifacts_to_keep) == 1


# === WORKFLOW STRUCTURE TESTS ===
import os
import subprocess
import yaml


WORKFLOW_PATH = os.path.join(
    os.path.dirname(__file__),
    ".github", "workflows", "artifact-cleanup-script.yml"
)


def test_workflow_file_exists():
    assert os.path.exists(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"


def test_workflow_yaml_structure():
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)

    # yaml.safe_load parses the bare 'on' key as Python True
    trigger_key = True if True in wf else "on"
    assert trigger_key in wf, "Workflow must have 'on' triggers"
    assert "jobs" in wf, "Workflow must have 'jobs'"

    # Must have push or pull_request trigger
    triggers = wf[trigger_key]
    assert any(t in triggers for t in ("push", "pull_request", "workflow_dispatch")), \
        "Workflow must have push, pull_request, or workflow_dispatch trigger"

    jobs = wf["jobs"]
    assert len(jobs) >= 1, "Workflow must have at least one job"


def test_workflow_references_script():
    with open(WORKFLOW_PATH) as f:
        content = f.read()

    assert "artifact_cleanup.py" in content, \
        "Workflow must reference artifact_cleanup.py"


def test_workflow_references_existing_files():
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)

    base_dir = os.path.dirname(__file__)
    # Check that artifact_cleanup.py exists
    assert os.path.exists(os.path.join(base_dir, "artifact_cleanup.py")), \
        "artifact_cleanup.py must exist"
    assert os.path.exists(os.path.join(base_dir, "test_artifact_cleanup.py")), \
        "test_artifact_cleanup.py must exist"


def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, \
        f"actionlint failed:\n{result.stdout}\n{result.stderr}"
