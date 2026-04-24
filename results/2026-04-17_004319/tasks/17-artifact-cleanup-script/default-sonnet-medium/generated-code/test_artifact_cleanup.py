"""
Test suite for artifact_cleanup.py following red/green TDD methodology.

Each test was written BEFORE its implementation. Tests are ordered by the
feature they verify, matching the order features were developed.

Fixtures are designed up front for determinism:
- Reference date: 2026-04-19 (fixed so age calculations are reproducible)
- Size values chosen so exact MB arithmetic works out cleanly
"""
import os
import subprocess
import pytest
import yaml
from datetime import datetime, timedelta, timezone

# Import the module under test (fails until artifact_cleanup.py is written)
from artifact_cleanup import (
    Artifact,
    RetentionPolicy,
    apply_retention_policies,
    generate_summary,
    format_size,
)

# Fixed reference date for all age-based calculations
REF_DATE = datetime(2026, 4, 19, tzinfo=timezone.utc)


def make_artifact(name, size_mb, days_ago, workflow="build", run_id=None):
    """Helper: create an Artifact with size in MB and age in days from REF_DATE."""
    created = REF_DATE - timedelta(days=days_ago)
    return Artifact(
        name=name,
        size_bytes=size_mb * 1024 * 1024,
        created_at=created,
        workflow_run_id=run_id or f"run-{name}",
        workflow=workflow,
    )


# ─── RED #1: max-age policy ────────────────────────────────────────────────

def test_max_age_deletes_old_artifact():
    # 60 days old exceeds max_age_days=30, should be deleted
    artifacts = [
        make_artifact("old-artifact", 100, days_ago=60),
        make_artifact("recent-artifact", 50, days_ago=10),
    ]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    delete_names = {d.artifact.name for d in plan.to_delete}
    retain_names = {d.artifact.name for d in plan.to_retain}

    assert "old-artifact" in delete_names
    assert "recent-artifact" in retain_names


def test_max_age_retains_artifact_exactly_at_limit():
    # Exactly 30 days old is NOT older-than-30, so it should be retained
    artifacts = [make_artifact("border-artifact", 100, days_ago=30)]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    assert len(plan.to_retain) == 1
    assert len(plan.to_delete) == 0


# ─── RED #2: keep-latest-N policy ─────────────────────────────────────────

def test_keep_latest_1_per_workflow():
    # Only most recent artifact per workflow should be retained
    artifacts = [
        make_artifact("build-1", 100, days_ago=60, workflow="build"),
        make_artifact("build-2", 100, days_ago=30, workflow="build"),
        make_artifact("build-3", 100, days_ago=5, workflow="build"),
        make_artifact("test-1", 50, days_ago=20, workflow="test"),
        make_artifact("test-2", 50, days_ago=3, workflow="test"),
    ]
    policy = RetentionPolicy(keep_latest_n=1)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    delete_names = {d.artifact.name for d in plan.to_delete}
    retain_names = {d.artifact.name for d in plan.to_retain}

    assert "build-3" in retain_names
    assert "test-2" in retain_names
    assert "build-1" in delete_names
    assert "build-2" in delete_names
    assert "test-1" in delete_names
    assert len(plan.to_delete) == 3
    assert len(plan.to_retain) == 2


def test_keep_latest_2_per_workflow():
    artifacts = [
        make_artifact("build-1", 100, days_ago=90, workflow="build"),
        make_artifact("build-2", 100, days_ago=60, workflow="build"),
        make_artifact("build-3", 100, days_ago=30, workflow="build"),
        make_artifact("build-4", 100, days_ago=5, workflow="build"),
    ]
    policy = RetentionPolicy(keep_latest_n=2)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    delete_names = {d.artifact.name for d in plan.to_delete}
    retain_names = {d.artifact.name for d in plan.to_retain}

    assert "build-4" in retain_names
    assert "build-3" in retain_names
    assert "build-1" in delete_names
    assert "build-2" in delete_names


# ─── RED #3: max-total-size policy ────────────────────────────────────────

def test_max_total_size_deletes_oldest_to_reach_limit():
    # Total 600 MB, limit 300 MB — delete oldest until under limit
    artifacts = [
        make_artifact("oldest", 200, days_ago=90, workflow="build"),  # 200 MB
        make_artifact("middle", 250, days_ago=60, workflow="build"),  # 250 MB
        make_artifact("newest", 150, days_ago=10, workflow="build"),  # 150 MB
    ]
    policy = RetentionPolicy(max_total_size_bytes=300 * 1024 * 1024)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    delete_names = {d.artifact.name for d in plan.to_delete}
    retain_names = {d.artifact.name for d in plan.to_retain}

    # Remove oldest (200 MB): 400 MB still over limit
    # Remove middle (250 MB): 150 MB under limit — stop
    assert "oldest" in delete_names
    assert "middle" in delete_names
    assert "newest" in retain_names
    assert plan.space_reclaimed_bytes == (200 + 250) * 1024 * 1024


def test_max_total_size_no_deletion_when_under_limit():
    artifacts = [make_artifact("small", 50, days_ago=5, workflow="build")]
    policy = RetentionPolicy(max_total_size_bytes=500 * 1024 * 1024)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    assert len(plan.to_delete) == 0


# ─── RED #4: combined policies ─────────────────────────────────────────────

def test_combined_max_age_and_keep_latest_n():
    artifacts = [
        make_artifact("very-old", 100, days_ago=120, workflow="build"),
        make_artifact("old", 100, days_ago=45, workflow="build"),
        make_artifact("medium", 100, days_ago=20, workflow="build"),
        make_artifact("new", 100, days_ago=5, workflow="build"),
    ]
    # max_age=30 marks very-old and old; keep_latest_n=2 keeps medium and new
    policy = RetentionPolicy(max_age_days=30, keep_latest_n=2)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    delete_names = {d.artifact.name for d in plan.to_delete}
    retain_names = {d.artifact.name for d in plan.to_retain}

    assert "very-old" in delete_names
    assert "old" in delete_names
    assert "medium" in retain_names
    assert "new" in retain_names


# ─── RED #5: edge cases ────────────────────────────────────────────────────

def test_empty_artifact_list():
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies([], policy, reference_date=REF_DATE)

    assert len(plan.to_delete) == 0
    assert len(plan.to_retain) == 0
    assert plan.space_reclaimed_bytes == 0


def test_no_policies_retains_all():
    artifacts = [
        make_artifact("a1", 100, days_ago=200),
        make_artifact("a2", 50, days_ago=100),
    ]
    plan = apply_retention_policies(artifacts, RetentionPolicy(), reference_date=REF_DATE)

    assert len(plan.to_delete) == 0
    assert len(plan.to_retain) == 2


# ─── RED #6: format_size utility ──────────────────────────────────────────

def test_format_size_bytes():
    assert format_size(512) == "512 B"


def test_format_size_kb():
    assert format_size(2048) == "2.0 KB"


def test_format_size_mb():
    assert format_size(5 * 1024 * 1024) == "5.0 MB"


def test_format_size_gb():
    assert format_size(2 * 1024 * 1024 * 1024) == "2.0 GB"


# ─── RED #7: summary generation ───────────────────────────────────────────

def test_summary_dry_run_mode():
    artifacts = [
        make_artifact("old-build", 100, days_ago=60, workflow="build"),
        make_artifact("new-build", 50, days_ago=5, workflow="build"),
    ]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)
    summary = generate_summary(plan, policy, dry_run=True)

    assert "DRY RUN" in summary
    assert "Deleted: 1" in summary
    assert "Retained: 1" in summary
    assert "Space reclaimed: 100.0 MB" in summary
    assert "old-build" in summary


def test_summary_live_mode():
    artifacts = [make_artifact("test", 50, days_ago=5)]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)
    summary = generate_summary(plan, policy, dry_run=False)

    assert "LIVE" in summary


def test_summary_includes_policy_details():
    artifacts = [make_artifact("a", 10, days_ago=5)]
    policy = RetentionPolicy(max_age_days=30, keep_latest_n=2, max_total_size_bytes=1024 * 1024 * 1024)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)
    summary = generate_summary(plan, policy, dry_run=True)

    assert "30 days" in summary
    assert "keep-latest" in summary.lower() or "Keep Latest" in summary
    assert "1.0 GB" in summary


# ─── RED #8: delete reasons ────────────────────────────────────────────────

def test_deletion_includes_reason():
    artifacts = [make_artifact("old", 100, days_ago=60)]
    policy = RetentionPolicy(max_age_days=30)
    plan = apply_retention_policies(artifacts, policy, reference_date=REF_DATE)

    assert len(plan.to_delete) == 1
    decision = plan.to_delete[0]
    assert len(decision.reasons) > 0
    assert "age" in decision.reasons[0].lower() or "days" in decision.reasons[0].lower()


# ─── RED #9: workflow structure tests ─────────────────────────────────────
# These tests verify the GitHub Actions workflow is correctly structured.

WORKFLOW_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    ".github", "workflows", "artifact-cleanup-script.yml"
)
SCRIPT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "artifact_cleanup.py")


def test_workflow_file_exists():
    assert os.path.exists(WORKFLOW_PATH), f"Workflow file missing: {WORKFLOW_PATH}"


def test_workflow_has_required_triggers():
    with open(WORKFLOW_PATH) as f:
        workflow = yaml.safe_load(f)

    # PyYAML 1.1 parses bare `on` as True; look under both keys
    on_block = workflow.get("on") or workflow.get(True) or {}
    triggers = list(on_block.keys()) if isinstance(on_block, dict) else list(on_block)
    assert "push" in triggers or "workflow_dispatch" in triggers


def test_workflow_has_jobs():
    with open(WORKFLOW_PATH) as f:
        workflow = yaml.safe_load(f)

    assert "jobs" in workflow
    assert len(workflow["jobs"]) >= 1


def test_workflow_references_existing_script():
    with open(WORKFLOW_PATH) as f:
        content = f.read()

    assert "artifact_cleanup.py" in content, "Workflow must reference artifact_cleanup.py"
    assert os.path.exists(SCRIPT_PATH), f"Script not found: {SCRIPT_PATH}"


def test_actionlint_passes():
    """actionlint must exit 0 — installed as a workflow step before pytest runs."""
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    )
