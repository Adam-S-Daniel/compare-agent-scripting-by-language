"""Tests for secret rotation validator — TDD approach.

Written test-first: each test was written before the corresponding implementation.
Tests cover classification logic, report generation, output formatting, and error handling.
"""

import json
import os
import subprocess
import sys
from datetime import date

import pytest
import yaml

from secret_rotation_validator import (
    classify_secret,
    generate_json_report,
    generate_markdown_report,
    load_config,
    validate_config,
    validate_secrets,
)

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")
REFERENCE_DATE = date(2026, 5, 7)
WARNING_WINDOW = 14


# --- Classification tests ---

class TestClassifySecret:
    """Red/green cycle 1: classify individual secrets by urgency."""

    def test_expired_secret(self):
        secret = {
            "name": "DB_PASSWORD",
            "last_rotated": "2025-12-01",
            "rotation_policy_days": 90,
            "required_by": ["api-service", "worker-service"],
        }
        result = classify_secret(secret, REFERENCE_DATE, WARNING_WINDOW)
        assert result["status"] == "expired"
        assert result["days_since_rotation"] == 157
        assert result["days_until_expiry"] == -67

    def test_warning_secret(self):
        secret = {
            "name": "TLS_CERT",
            "last_rotated": "2026-03-15",
            "rotation_policy_days": 60,
            "required_by": ["gateway", "cdn"],
        }
        result = classify_secret(secret, REFERENCE_DATE, WARNING_WINDOW)
        assert result["status"] == "warning"
        assert result["days_since_rotation"] == 53
        assert result["days_until_expiry"] == 7

    def test_ok_secret(self):
        secret = {
            "name": "API_KEY",
            "last_rotated": "2026-04-25",
            "rotation_policy_days": 30,
            "required_by": ["frontend"],
        }
        result = classify_secret(secret, REFERENCE_DATE, WARNING_WINDOW)
        assert result["status"] == "ok"
        assert result["days_since_rotation"] == 12
        assert result["days_until_expiry"] == 18

    def test_exactly_on_expiry_boundary(self):
        """Secret that expires today (days_until_expiry == 0) is expired."""
        secret = {
            "name": "BOUNDARY",
            "last_rotated": "2026-02-06",
            "rotation_policy_days": 90,
            "required_by": ["svc"],
        }
        result = classify_secret(secret, REFERENCE_DATE, WARNING_WINDOW)
        assert result["status"] == "expired"
        assert result["days_until_expiry"] == 0

    def test_exactly_on_warning_boundary(self):
        """Secret with days_until_expiry == warning_window is in warning."""
        secret = {
            "name": "EDGE",
            "last_rotated": "2026-03-10",
            "rotation_policy_days": 72,
            "required_by": ["svc"],
        }
        # days_since = (2026-05-07 - 2026-03-10) = 58, days_until = 72 - 58 = 14
        result = classify_secret(secret, REFERENCE_DATE, WARNING_WINDOW)
        assert result["status"] == "warning"
        assert result["days_until_expiry"] == 14

    def test_just_outside_warning_window(self):
        """Secret with days_until_expiry == warning_window + 1 is ok."""
        secret = {
            "name": "SAFE",
            "last_rotated": "2026-03-11",
            "rotation_policy_days": 72,
            "required_by": ["svc"],
        }
        # days_since = (2026-05-07 - 2026-03-11) = 57, days_until = 72 - 57 = 15
        result = classify_secret(secret, REFERENCE_DATE, WARNING_WINDOW)
        assert result["status"] == "ok"
        assert result["days_until_expiry"] == 15

    def test_preserves_original_fields(self):
        secret = {
            "name": "TEST",
            "last_rotated": "2026-05-01",
            "rotation_policy_days": 365,
            "required_by": ["deploy-bot"],
        }
        result = classify_secret(secret, REFERENCE_DATE, WARNING_WINDOW)
        assert result["name"] == "TEST"
        assert result["last_rotated"] == "2026-05-01"
        assert result["rotation_policy_days"] == 365
        assert result["required_by"] == ["deploy-bot"]


# --- Validation tests ---

class TestValidation:
    """Red/green cycle 2: config and secret validation."""

    def test_validate_config_valid(self):
        config = {
            "warning_window_days": 14,
            "secrets": [
                {
                    "name": "X",
                    "last_rotated": "2026-01-01",
                    "rotation_policy_days": 90,
                    "required_by": ["svc"],
                }
            ],
        }
        errors = validate_config(config)
        assert errors == []

    def test_validate_config_missing_secrets(self):
        config = {"warning_window_days": 14}
        errors = validate_config(config)
        assert any("secrets" in e for e in errors)

    def test_validate_config_empty_secrets(self):
        config = {"warning_window_days": 14, "secrets": []}
        errors = validate_config(config)
        assert any("empty" in e.lower() or "secrets" in e.lower() for e in errors)

    def test_validate_config_negative_warning_window(self):
        config = {
            "warning_window_days": -1,
            "secrets": [
                {
                    "name": "X",
                    "last_rotated": "2026-01-01",
                    "rotation_policy_days": 90,
                    "required_by": ["svc"],
                }
            ],
        }
        errors = validate_config(config)
        assert any("warning_window" in e.lower() for e in errors)

    def test_validate_secret_missing_name(self):
        secrets = [
            {
                "last_rotated": "2026-01-01",
                "rotation_policy_days": 90,
                "required_by": ["svc"],
            }
        ]
        errors = validate_secrets(secrets)
        assert any("name" in e.lower() for e in errors)

    def test_validate_secret_invalid_date(self):
        secrets = [
            {
                "name": "X",
                "last_rotated": "not-a-date",
                "rotation_policy_days": 90,
                "required_by": ["svc"],
            }
        ]
        errors = validate_secrets(secrets)
        assert any("date" in e.lower() for e in errors)

    def test_validate_secret_negative_policy(self):
        secrets = [
            {
                "name": "X",
                "last_rotated": "2026-01-01",
                "rotation_policy_days": -10,
                "required_by": ["svc"],
            }
        ]
        errors = validate_secrets(secrets)
        assert any("policy" in e.lower() for e in errors)


# --- Report generation tests ---

class TestGenerateReport:
    """Red/green cycle 3: grouping and report generation."""

    def _load_mixed_config(self):
        with open(os.path.join(FIXTURES_DIR, "mixed_config.json")) as f:
            return json.load(f)

    def test_json_report_summary_counts(self):
        config = self._load_mixed_config()
        report = generate_json_report(config, REFERENCE_DATE)
        assert report["summary"]["total"] == 5
        assert report["summary"]["expired"] == 2
        assert report["summary"]["warning"] == 1
        assert report["summary"]["ok"] == 2

    def test_json_report_expired_secrets(self):
        config = self._load_mixed_config()
        report = generate_json_report(config, REFERENCE_DATE)
        expired_names = [s["name"] for s in report["secrets"]["expired"]]
        assert expired_names == ["DB_PASSWORD", "OAUTH_SECRET"]

    def test_json_report_warning_secrets(self):
        config = self._load_mixed_config()
        report = generate_json_report(config, REFERENCE_DATE)
        warning_names = [s["name"] for s in report["secrets"]["warning"]]
        assert warning_names == ["TLS_CERT"]

    def test_json_report_ok_secrets(self):
        config = self._load_mixed_config()
        report = generate_json_report(config, REFERENCE_DATE)
        ok_names = [s["name"] for s in report["secrets"]["ok"]]
        assert ok_names == ["API_KEY", "SSH_KEY"]

    def test_json_report_sorted_by_urgency(self):
        """Expired sorted by most overdue first, warning/ok by soonest expiry."""
        config = self._load_mixed_config()
        report = generate_json_report(config, REFERENCE_DATE)
        expired_days = [s["days_until_expiry"] for s in report["secrets"]["expired"]]
        assert expired_days == sorted(expired_days)
        ok_days = [s["days_until_expiry"] for s in report["secrets"]["ok"]]
        assert ok_days == sorted(ok_days)

    def test_json_report_reference_date(self):
        config = self._load_mixed_config()
        report = generate_json_report(config, REFERENCE_DATE)
        assert report["reference_date"] == "2026-05-07"
        assert report["warning_window_days"] == 14

    def test_markdown_report_contains_headers(self):
        config = self._load_mixed_config()
        md = generate_markdown_report(config, REFERENCE_DATE)
        assert "# Secret Rotation Report" in md
        assert "## Summary" in md
        assert "## Expired Secrets" in md
        assert "## Warning Secrets" in md
        assert "## OK Secrets" in md

    def test_markdown_report_contains_secret_names(self):
        config = self._load_mixed_config()
        md = generate_markdown_report(config, REFERENCE_DATE)
        assert "DB_PASSWORD" in md
        assert "TLS_CERT" in md
        assert "API_KEY" in md

    def test_markdown_report_summary_counts(self):
        config = self._load_mixed_config()
        md = generate_markdown_report(config, REFERENCE_DATE)
        assert "| Expired | 2 |" in md
        assert "| Warning | 1 |" in md
        assert "| OK | 2 |" in md
        assert "| **Total** | **5** |" in md

    def test_markdown_report_expired_days_overdue(self):
        config = self._load_mixed_config()
        md = generate_markdown_report(config, REFERENCE_DATE)
        assert "| DB_PASSWORD | 2025-12-01 | 90 | 67 | api-service, worker-service |" in md
        assert "| OAUTH_SECRET | 2026-02-01 | 90 | 5 | auth-service |" in md

    def test_markdown_report_warning_days_until(self):
        config = self._load_mixed_config()
        md = generate_markdown_report(config, REFERENCE_DATE)
        assert "| TLS_CERT | 2026-03-15 | 60 | 7 | gateway, cdn |" in md

    def test_markdown_report_ok_days_until(self):
        config = self._load_mixed_config()
        md = generate_markdown_report(config, REFERENCE_DATE)
        assert "| API_KEY | 2026-04-25 | 30 | 18 | frontend |" in md
        assert "| SSH_KEY | 2026-05-01 | 365 | 359 | deploy-bot |" in md


# --- Config loading tests ---

class TestLoadConfig:
    """Red/green cycle 4: loading config from file."""

    def test_load_valid_config(self):
        path = os.path.join(FIXTURES_DIR, "mixed_config.json")
        config = load_config(path)
        assert "secrets" in config
        assert len(config["secrets"]) == 5

    def test_load_nonexistent_file(self):
        with pytest.raises(FileNotFoundError):
            load_config("/nonexistent/path.json")

    def test_load_invalid_json(self, tmp_path):
        bad_file = tmp_path / "bad.json"
        bad_file.write_text("not valid json{{{")
        with pytest.raises(json.JSONDecodeError):
            load_config(str(bad_file))


# --- CLI integration tests ---

class TestCLI:
    """Red/green cycle 5: CLI argument handling."""

    def test_cli_json_output(self):
        config_path = os.path.join(FIXTURES_DIR, "mixed_config.json")
        result = subprocess.run(
            [
                sys.executable,
                "secret_rotation_validator.py",
                "--config",
                config_path,
                "--format",
                "json",
                "--reference-date",
                "2026-05-07",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert data["summary"]["expired"] == 2

    def test_cli_markdown_output(self):
        config_path = os.path.join(FIXTURES_DIR, "mixed_config.json")
        result = subprocess.run(
            [
                sys.executable,
                "secret_rotation_validator.py",
                "--config",
                config_path,
                "--format",
                "markdown",
                "--reference-date",
                "2026-05-07",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "# Secret Rotation Report" in result.stdout

    def test_cli_invalid_config_exits_nonzero(self, tmp_path):
        bad_config = tmp_path / "bad.json"
        bad_config.write_text('{"warning_window_days": 14}')
        result = subprocess.run(
            [
                sys.executable,
                "secret_rotation_validator.py",
                "--config",
                str(bad_config),
                "--format",
                "json",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0

    def test_cli_warning_window_override(self):
        config_path = os.path.join(FIXTURES_DIR, "mixed_config.json")
        result = subprocess.run(
            [
                sys.executable,
                "secret_rotation_validator.py",
                "--config",
                config_path,
                "--format",
                "json",
                "--reference-date",
                "2026-05-07",
                "--warning-window",
                "20",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        data = json.loads(result.stdout)
        # With 20-day window, API_KEY (18 days until expiry) becomes warning
        assert data["summary"]["warning"] == 2
        assert data["summary"]["ok"] == 1

    def test_cli_all_expired_config(self):
        config_path = os.path.join(FIXTURES_DIR, "all_expired_config.json")
        result = subprocess.run(
            [
                sys.executable,
                "secret_rotation_validator.py",
                "--config",
                config_path,
                "--format",
                "json",
                "--reference-date",
                "2026-05-07",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert data["summary"]["expired"] == 3
        assert data["summary"]["warning"] == 0
        assert data["summary"]["ok"] == 0


# --- Workflow structure tests ---

class TestWorkflowStructure:
    """Verify the GitHub Actions workflow YAML has correct structure."""

    WORKFLOW_PATH = os.path.join(
        os.path.dirname(__file__),
        ".github",
        "workflows",
        "secret-rotation-validator.yml",
    )

    def test_workflow_file_exists(self):
        assert os.path.isfile(self.WORKFLOW_PATH)

    def test_workflow_valid_yaml(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert wf is not None

    def test_workflow_has_triggers(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert True in wf or "on" in wf

    def test_workflow_has_push_trigger(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        triggers = wf.get(True) or wf.get("on")
        assert "push" in triggers

    def test_workflow_has_jobs(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "jobs" in wf
        assert len(wf["jobs"]) > 0

    def test_workflow_has_validate_job(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "validate" in wf["jobs"]

    def test_workflow_has_checkout_step(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        job = wf["jobs"]["validate"]
        step_uses = [s.get("uses", "") for s in job["steps"]]
        assert any("actions/checkout" in u for u in step_uses)

    def test_workflow_references_script(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        job = wf["jobs"]["validate"]
        step_runs = " ".join(s.get("run", "") for s in job["steps"])
        assert "secret_rotation_validator.py" in step_runs

    def test_workflow_references_existing_files(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        job = wf["jobs"]["validate"]
        step_runs = " ".join(s.get("run", "") for s in job["steps"])
        assert "secret_rotation_validator.py" in step_runs
        assert os.path.isfile(
            os.path.join(os.path.dirname(__file__), "secret_rotation_validator.py")
        )

    def test_actionlint_passes(self):
        try:
            result = subprocess.run(
                ["actionlint", self.WORKFLOW_PATH],
                capture_output=True,
                text=True,
            )
        except FileNotFoundError:
            pytest.skip("actionlint not installed in this environment")
        assert result.returncode == 0, f"actionlint errors:\n{result.stdout}\n{result.stderr}"
