"""Tests for artifact cleanup / retention policy engine. TDD: red-green-refactor."""

import pytest
from datetime import datetime, timedelta
from artifact_cleanup import (
    apply_retention_policies,
    RetentionPolicy,
    generate_summary,
    run_cleanup,
)

# --- Fixtures ---

NOW = datetime(2026, 4, 8, 12, 0, 0)


def _make_artifact(name, size_mb, age_days, workflow_run_id):
    """Helper to build an artifact dict with a creation date relative to NOW."""
    return {
        "name": name,
        "size_bytes": size_mb * 1024 * 1024,
        "created_at": NOW - timedelta(days=age_days),
        "workflow_run_id": workflow_run_id,
    }


# ---- Cycle 1: max-age policy ----

class TestMaxAgePolicy:
    """Artifacts older than max_age_days should be marked for deletion."""

    def test_old_artifacts_are_deleted(self):
        artifacts = [
            _make_artifact("old-log", 10, age_days=31, workflow_run_id="run-1"),
            _make_artifact("new-log", 5, age_days=2, workflow_run_id="run-2"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        result = apply_retention_policies(artifacts, policy, now=NOW)

        assert "old-log" in [a["name"] for a in result.to_delete]
        assert "new-log" in [a["name"] for a in result.to_retain]

    def test_no_max_age_keeps_everything(self):
        artifacts = [
            _make_artifact("ancient", 1, age_days=9999, workflow_run_id="run-1"),
        ]
        policy = RetentionPolicy()  # no max_age_days
        result = apply_retention_policies(artifacts, policy, now=NOW)

        assert len(result.to_delete) == 0
        assert len(result.to_retain) == 1


# ---- Cycle 2: keep-latest-N per workflow ----

class TestKeepLatestNPerWorkflow:
    """Only the N most recent artifacts per workflow_run_id are kept."""

    def test_keeps_latest_2_per_workflow(self):
        artifacts = [
            _make_artifact("build-1", 10, age_days=5, workflow_run_id="deploy"),
            _make_artifact("build-2", 10, age_days=3, workflow_run_id="deploy"),
            _make_artifact("build-3", 10, age_days=1, workflow_run_id="deploy"),
            _make_artifact("test-1", 5, age_days=4, workflow_run_id="test"),
        ]
        policy = RetentionPolicy(keep_latest_n_per_workflow=2)
        result = apply_retention_policies(artifacts, policy, now=NOW)

        deleted_names = {a["name"] for a in result.to_delete}
        retained_names = {a["name"] for a in result.to_retain}
        # oldest deploy artifact should be deleted; newest 2 kept
        assert "build-1" in deleted_names
        assert "build-2" in retained_names
        assert "build-3" in retained_names
        # test workflow has only 1 artifact — kept
        assert "test-1" in retained_names

    def test_no_keep_latest_n_keeps_all(self):
        artifacts = [
            _make_artifact("a", 1, age_days=i, workflow_run_id="w")
            for i in range(10)
        ]
        policy = RetentionPolicy()  # no keep_latest_n
        result = apply_retention_policies(artifacts, policy, now=NOW)
        assert len(result.to_retain) == 10


# ---- Cycle 3: max total size ----

MB = 1024 * 1024


class TestMaxTotalSize:
    """When retained artifacts exceed max_total_size_bytes, oldest are dropped first."""

    def test_drops_oldest_to_fit_size_budget(self):
        artifacts = [
            _make_artifact("big-old", 100, age_days=10, workflow_run_id="run-1"),
            _make_artifact("big-mid", 100, age_days=5, workflow_run_id="run-2"),
            _make_artifact("small-new", 10, age_days=1, workflow_run_id="run-3"),
        ]
        # Budget: 150 MB — can keep big-mid (100) + small-new (10) = 110 MB
        policy = RetentionPolicy(max_total_size_bytes=150 * MB)
        result = apply_retention_policies(artifacts, policy, now=NOW)

        deleted_names = {a["name"] for a in result.to_delete}
        retained_names = {a["name"] for a in result.to_retain}
        assert "big-old" in deleted_names
        assert "big-mid" in retained_names
        assert "small-new" in retained_names

    def test_no_max_size_keeps_all(self):
        artifacts = [_make_artifact("huge", 9999, age_days=1, workflow_run_id="r")]
        policy = RetentionPolicy()
        result = apply_retention_policies(artifacts, policy, now=NOW)
        assert len(result.to_retain) == 1


# ---- Cycle 4: combined policies ----

class TestCombinedPolicies:
    """Multiple policies compose: age first, then keep-latest-N, then size cap."""

    def test_all_policies_together(self):
        artifacts = [
            # Too old — removed by max_age
            _make_artifact("ancient", 50, age_days=100, workflow_run_id="deploy"),
            # deploy workflow: 3 artifacts, keep latest 2
            _make_artifact("deploy-old", 40, age_days=10, workflow_run_id="deploy"),
            _make_artifact("deploy-mid", 40, age_days=5, workflow_run_id="deploy"),
            _make_artifact("deploy-new", 40, age_days=1, workflow_run_id="deploy"),
            # test workflow: small, recent
            _make_artifact("test-1", 10, age_days=2, workflow_run_id="test"),
        ]
        policy = RetentionPolicy(
            max_age_days=30,
            keep_latest_n_per_workflow=2,
            max_total_size_bytes=100 * MB,  # 100 MB budget
        )
        result = apply_retention_policies(artifacts, policy, now=NOW)

        deleted_names = {a["name"] for a in result.to_delete}
        retained_names = {a["name"] for a in result.to_retain}

        # "ancient" removed by age policy
        assert "ancient" in deleted_names
        # "deploy-old" removed by keep-latest-2 policy
        assert "deploy-old" in deleted_names
        # After age + keep-latest-N: deploy-mid(40), deploy-new(40), test-1(10) = 90 MB
        # 90 MB < 100 MB budget, so all three survive the size cap
        assert "deploy-new" in retained_names
        assert "deploy-mid" in retained_names
        assert "test-1" in retained_names

    def test_empty_artifacts_list(self):
        policy = RetentionPolicy(max_age_days=7)
        result = apply_retention_policies([], policy, now=NOW)
        assert result.to_delete == []
        assert result.to_retain == []


# ---- Cycle 5: summary generation ----

class TestSummary:
    """generate_summary produces a human-readable deletion plan."""

    def test_summary_contains_key_metrics(self):
        artifacts = [
            _make_artifact("keep-me", 50, age_days=1, workflow_run_id="run-1"),
            _make_artifact("delete-me", 30, age_days=60, workflow_run_id="run-2"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        result = apply_retention_policies(artifacts, policy, now=NOW)
        summary = generate_summary(result)

        assert "1 artifact(s) to delete" in summary
        assert "1 artifact(s) to retain" in summary
        # 30 MB reclaimed
        assert "30.00 MB" in summary
        assert "delete-me" in summary

    def test_summary_empty_deletion(self):
        artifacts = [_make_artifact("safe", 10, age_days=1, workflow_run_id="r")]
        policy = RetentionPolicy(max_age_days=30)
        result = apply_retention_policies(artifacts, policy, now=NOW)
        summary = generate_summary(result)

        assert "0 artifact(s) to delete" in summary
        assert "0.00 MB" in summary


# ---- Cycle 6: dry-run mode and run_cleanup orchestrator ----

class TestDryRun:
    """run_cleanup orchestrates policy application + optional deletion callback."""

    def test_dry_run_does_not_call_delete(self):
        """In dry-run mode, the delete callback is never invoked."""
        deleted = []

        def fake_delete(artifact):
            deleted.append(artifact["name"])

        artifacts = [
            _make_artifact("old", 10, age_days=60, workflow_run_id="r"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        summary = run_cleanup(artifacts, policy, delete_fn=fake_delete, dry_run=True, now=NOW)

        assert deleted == []  # nothing actually deleted
        assert "DRY RUN" in summary

    def test_live_run_calls_delete(self):
        """When dry_run=False, the delete callback is invoked for each artifact."""
        deleted = []

        def fake_delete(artifact):
            deleted.append(artifact["name"])

        artifacts = [
            _make_artifact("old", 10, age_days=60, workflow_run_id="r"),
            _make_artifact("new", 10, age_days=1, workflow_run_id="r"),
        ]
        policy = RetentionPolicy(max_age_days=30)
        summary = run_cleanup(artifacts, policy, delete_fn=fake_delete, dry_run=False, now=NOW)

        assert deleted == ["old"]
        assert "DRY RUN" not in summary


# ---- Cycle 7: error handling ----

class TestErrorHandling:
    """Graceful handling of bad inputs."""

    def test_invalid_policy_values(self):
        with pytest.raises(ValueError, match="max_age_days must be positive"):
            RetentionPolicy(max_age_days=-1).validate()

    def test_invalid_max_total_size(self):
        with pytest.raises(ValueError, match="max_total_size_bytes must be positive"):
            RetentionPolicy(max_total_size_bytes=0).validate()

    def test_invalid_keep_latest_n(self):
        with pytest.raises(ValueError, match="keep_latest_n_per_workflow must be positive"):
            RetentionPolicy(keep_latest_n_per_workflow=-5).validate()

    def test_missing_artifact_fields(self):
        bad_artifact = {"name": "oops"}  # missing required fields
        policy = RetentionPolicy(max_age_days=7)
        with pytest.raises(ValueError, match="missing required fields"):
            apply_retention_policies([bad_artifact], policy, now=NOW)

    def test_delete_fn_error_is_reported(self):
        """If the delete callback raises, run_cleanup reports the failure gracefully."""
        def failing_delete(artifact):
            raise RuntimeError("API timeout")

        artifacts = [_make_artifact("x", 1, age_days=60, workflow_run_id="r")]
        policy = RetentionPolicy(max_age_days=30)
        summary = run_cleanup(artifacts, policy, delete_fn=failing_delete, dry_run=False, now=NOW)

        # Should report the error, not crash
        assert "FAILED" in summary
        assert "API timeout" in summary
