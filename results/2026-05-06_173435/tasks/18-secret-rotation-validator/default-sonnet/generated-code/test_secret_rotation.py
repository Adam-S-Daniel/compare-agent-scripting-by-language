"""
Secret Rotation Validator — pytest unit + structure tests.
TDD: tests written first; all fail until implementation exists.
"""
import json
import os
import shutil
import subprocess
from datetime import date

import pytest

# RED: These imports fail until secret_rotation_validator.py is created.
from secret_rotation_validator import (
    Secret,
    generate_report,
    format_json,
    format_markdown,
    parse_secrets,
    load_config,
)

REFERENCE_DATE = date(2024, 3, 15)
WARNING_WINDOW = 14

# ---------------------------------------------------------------------------
# Secret dataclass tests
# ---------------------------------------------------------------------------

class TestSecret:
    def test_days_until_expiry_expired(self):
        # 2023-11-01 + 90 days = 2024-01-30; ref 2024-03-15 -> -45 days
        s = Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app"])
        assert s.days_until_expiry(REFERENCE_DATE) == -45

    def test_days_until_expiry_warning(self):
        # 2024-03-08 + 14 days = 2024-03-22; ref 2024-03-15 -> 7 days
        s = Secret("API_KEY", date(2024, 3, 8), 14, ["api-server"])
        assert s.days_until_expiry(REFERENCE_DATE) == 7

    def test_days_until_expiry_ok(self):
        # 2024-03-01 + 90 days = 2024-05-30; ref 2024-03-15 -> 76 days
        s = Secret("STRIPE_KEY", date(2024, 3, 1), 90, ["payment-service"])
        assert s.days_until_expiry(REFERENCE_DATE) == 76

    def test_status_expired(self):
        s = Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app"])
        assert s.status(REFERENCE_DATE, WARNING_WINDOW) == "expired"

    def test_status_warning(self):
        s = Secret("API_KEY", date(2024, 3, 8), 14, ["api-server"])
        assert s.status(REFERENCE_DATE, WARNING_WINDOW) == "warning"

    def test_status_ok(self):
        s = Secret("STRIPE_KEY", date(2024, 3, 1), 90, ["payment-service"])
        assert s.status(REFERENCE_DATE, WARNING_WINDOW) == "ok"

    def test_status_boundary_exactly_at_window_edge(self):
        # Expires exactly on reference date -> days=0 -> warning (not expired)
        s = Secret("EDGE_SECRET", date(2024, 3, 1), 14, [])
        assert s.status(REFERENCE_DATE, WARNING_WINDOW) == "warning"

    def test_status_expires_tomorrow(self):
        # 1 day left, window=14 -> warning
        s = Secret("SOON_SECRET", date(2024, 3, 1), 15, [])
        assert s.status(REFERENCE_DATE, WARNING_WINDOW) == "warning"

    def test_status_just_outside_window(self):
        # 15 days left, window=14 -> ok
        s = Secret("FAR_SECRET", date(2024, 3, 1), 29, [])
        assert s.status(REFERENCE_DATE, WARNING_WINDOW) == "ok"


# ---------------------------------------------------------------------------
# Report generation tests
# ---------------------------------------------------------------------------

class TestGenerateReport:
    def _mixed_secrets(self):
        return [
            Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app", "api-server"]),
            Secret("API_KEY", date(2024, 3, 8), 14, ["api-server"]),
            Secret("STRIPE_KEY", date(2024, 3, 1), 90, ["payment-service"]),
        ]

    def test_categorizes_expired_warning_ok(self):
        report = generate_report(self._mixed_secrets(), REFERENCE_DATE, WARNING_WINDOW)
        assert len(report.expired) == 1
        assert len(report.warning) == 1
        assert len(report.ok) == 1

    def test_expired_secret_name(self):
        report = generate_report(self._mixed_secrets(), REFERENCE_DATE, WARNING_WINDOW)
        assert report.expired[0]["name"] == "DB_PASSWORD"

    def test_warning_secret_name(self):
        report = generate_report(self._mixed_secrets(), REFERENCE_DATE, WARNING_WINDOW)
        assert report.warning[0]["name"] == "API_KEY"

    def test_ok_secret_name(self):
        report = generate_report(self._mixed_secrets(), REFERENCE_DATE, WARNING_WINDOW)
        assert report.ok[0]["name"] == "STRIPE_KEY"

    def test_empty_input(self):
        report = generate_report([], REFERENCE_DATE, WARNING_WINDOW)
        assert report.expired == []
        assert report.warning == []
        assert report.ok == []

    def test_entry_has_required_fields(self):
        secrets = [Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app"])]
        report = generate_report(secrets, REFERENCE_DATE, WARNING_WINDOW)
        entry = report.expired[0]
        for field in ("name", "last_rotated", "expires_on", "days_until_expiry", "required_by"):
            assert field in entry, f"Missing field: {field}"

    def test_days_until_expiry_value_in_entry(self):
        secrets = [Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app"])]
        report = generate_report(secrets, REFERENCE_DATE, WARNING_WINDOW)
        assert report.expired[0]["days_until_expiry"] == -45


# ---------------------------------------------------------------------------
# JSON output format tests
# ---------------------------------------------------------------------------

class TestFormatJson:
    def test_valid_json(self):
        report = generate_report([], REFERENCE_DATE, WARNING_WINDOW)
        output = format_json(report)
        data = json.loads(output)  # must not raise
        assert isinstance(data, dict)

    def test_summary_counts_correct(self):
        secrets = [Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app"])]
        report = generate_report(secrets, REFERENCE_DATE, WARNING_WINDOW)
        data = json.loads(format_json(report))
        assert data["summary"]["expired"] == 1
        assert data["summary"]["warning"] == 0
        assert data["summary"]["ok"] == 0

    def test_contains_reference_date(self):
        report = generate_report([], REFERENCE_DATE, WARNING_WINDOW)
        data = json.loads(format_json(report))
        assert data["reference_date"] == "2024-03-15"

    def test_expired_list_has_name(self):
        secrets = [Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app"])]
        report = generate_report(secrets, REFERENCE_DATE, WARNING_WINDOW)
        data = json.loads(format_json(report))
        assert data["expired"][0]["name"] == "DB_PASSWORD"


# ---------------------------------------------------------------------------
# Markdown output format tests
# ---------------------------------------------------------------------------

class TestFormatMarkdown:
    def test_contains_header(self):
        report = generate_report([], REFERENCE_DATE, WARNING_WINDOW)
        output = format_markdown(report)
        assert "# " in output

    def test_contains_summary_table(self):
        report = generate_report([], REFERENCE_DATE, WARNING_WINDOW)
        output = format_markdown(report)
        assert "| " in output  # at least one table row

    def test_expired_secret_appears_in_table(self):
        secrets = [Secret("DB_PASSWORD", date(2023, 11, 1), 90, ["web-app"])]
        report = generate_report(secrets, REFERENCE_DATE, WARNING_WINDOW)
        output = format_markdown(report)
        assert "DB_PASSWORD" in output

    def test_warning_secret_appears(self):
        secrets = [Secret("API_KEY", date(2024, 3, 8), 14, ["api-server"])]
        report = generate_report(secrets, REFERENCE_DATE, WARNING_WINDOW)
        output = format_markdown(report)
        assert "API_KEY" in output

    def test_ok_secret_appears(self):
        secrets = [Secret("STRIPE_KEY", date(2024, 3, 1), 90, ["payment-service"])]
        report = generate_report(secrets, REFERENCE_DATE, WARNING_WINDOW)
        output = format_markdown(report)
        assert "STRIPE_KEY" in output


# ---------------------------------------------------------------------------
# Config parsing tests
# ---------------------------------------------------------------------------

class TestParseSecrets:
    def test_parse_single_secret(self):
        config = {
            "secrets": [{
                "name": "DB_PASSWORD",
                "last_rotated": "2023-11-01",
                "rotation_policy_days": 90,
                "required_by": ["web-app"],
            }]
        }
        secrets = parse_secrets(config)
        assert len(secrets) == 1
        assert secrets[0].name == "DB_PASSWORD"
        assert secrets[0].last_rotated == date(2023, 11, 1)
        assert secrets[0].rotation_policy_days == 90
        assert secrets[0].required_by == ["web-app"]

    def test_parse_empty_secrets(self):
        assert parse_secrets({"secrets": []}) == []

    def test_parse_required_by_defaults_empty(self):
        config = {"secrets": [{"name": "X", "last_rotated": "2024-01-01", "rotation_policy_days": 30}]}
        secrets = parse_secrets(config)
        assert secrets[0].required_by == []


# ---------------------------------------------------------------------------
# Workflow structure tests (run both locally and in act container)
# ---------------------------------------------------------------------------

WORKFLOW_PATH = ".github/workflows/secret-rotation-validator.yml"


class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        assert os.path.exists(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"

    def test_workflow_yaml_parses(self):
        import yaml
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert wf is not None

    def test_workflow_has_push_trigger(self):
        import yaml
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        # PyYAML 1.1 parses bare `on` as boolean True; handle both forms.
        triggers = wf.get("on") or wf.get(True) or {}
        assert "push" in triggers

    def test_workflow_has_workflow_dispatch(self):
        import yaml
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        triggers = wf.get("on") or wf.get(True) or {}
        assert "workflow_dispatch" in triggers

    def test_workflow_has_validate_secrets_job(self):
        import yaml
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "validate-secrets" in wf.get("jobs", {})

    def test_workflow_references_script_exists(self):
        assert os.path.exists("secret_rotation_validator.py")

    @pytest.mark.skipif(
        shutil.which("actionlint") is None,
        reason="actionlint not installed",
    )
    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint errors:\n{result.stdout}\n{result.stderr}"
        )
