"""
Tests for the secret rotation validator.

TDD progression:
  RED  — wrote each test class before the corresponding implementation existed.
  GREEN — wrote minimum code in secret_rotation.py to make each group pass.
  REFACTOR — cleaned up duplication and added helpers.
"""

import json
import subprocess
import sys
from datetime import date
from pathlib import Path

import pytest
import yaml

# This import is the first "red" moment: fails until secret_rotation.py exists.
from secret_rotation import (
    Secret,
    SecretStatus,
    evaluate_secrets,
    format_json,
    format_markdown,
    load_secrets,
)

REFERENCE_DATE = date(2026, 4, 20)
WARNING_WINDOW = 30
PROJECT_ROOT = Path(__file__).parent.parent


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_secret(name, last_rotated_str, policy_days, required_by=None):
    return Secret(
        name=name,
        last_rotated=date.fromisoformat(last_rotated_str),
        rotation_policy_days=policy_days,
        required_by=required_by or [],
    )


# ---------------------------------------------------------------------------
# RED 1: evaluate_secrets — basic urgency classification
# ---------------------------------------------------------------------------

class TestSecretEvaluation:
    def test_expired_secret(self):
        """Secret past its rotation deadline → EXPIRED."""
        s = make_secret("OLD_KEY", "2025-10-01", 90, ["svc-a"])
        result = evaluate_secrets([s], REFERENCE_DATE, WARNING_WINDOW)
        assert result[0].urgency == "expired"
        assert result[0].days_until_expiry < 0

    def test_warning_secret(self):
        """Secret expiring within warning window → WARNING."""
        s = make_secret("SOON_KEY", "2026-04-05", 30, ["svc-b"])
        result = evaluate_secrets([s], REFERENCE_DATE, WARNING_WINDOW)
        assert result[0].urgency == "warning"
        assert 0 < result[0].days_until_expiry <= WARNING_WINDOW

    def test_ok_secret(self):
        """Secret with plenty of time remaining → OK."""
        s = make_secret("FRESH_KEY", "2026-04-15", 90, ["svc-c"])
        result = evaluate_secrets([s], REFERENCE_DATE, WARNING_WINDOW)
        assert result[0].urgency == "ok"
        assert result[0].days_until_expiry > WARNING_WINDOW

    def test_expiry_date_calculation(self):
        """expires_on == last_rotated + rotation_policy_days."""
        s = make_secret("KEY", "2026-01-01", 90)
        result = evaluate_secrets([s], REFERENCE_DATE, WARNING_WINDOW)
        assert result[0].expires_on == date(2026, 4, 1)

    def test_exactly_on_expiry_date_is_expired(self):
        """Secret expiring exactly today (days_until_expiry == 0) → EXPIRED."""
        # 2026-03-21 + 30 days = 2026-04-20 == REFERENCE_DATE
        s = make_secret("DUE_KEY", "2026-03-21", 30)
        result = evaluate_secrets([s], REFERENCE_DATE, WARNING_WINDOW)
        assert result[0].urgency == "expired"
        assert result[0].days_until_expiry == 0

    def test_ordering_expired_before_warning_before_ok(self):
        """Results sorted: expired → warning → ok."""
        secrets = [
            make_secret("OK_KEY", "2026-04-15", 90),
            make_secret("WARN_KEY", "2026-04-05", 30),
            make_secret("EXP_KEY", "2025-10-01", 90),
        ]
        result = evaluate_secrets(secrets, REFERENCE_DATE, WARNING_WINDOW)
        assert [r.urgency for r in result] == ["expired", "warning", "ok"]

    def test_custom_warning_window_narrow(self):
        """With a 10-day window, a secret 15 days out is OK, not WARNING."""
        s = make_secret("KEY", "2026-04-05", 30)  # expires 2026-05-05, 15 days away
        result = evaluate_secrets([s], REFERENCE_DATE, 10)
        assert result[0].urgency == "ok"

    def test_custom_warning_window_wide(self):
        """With a 20-day window, a secret 15 days out is WARNING."""
        s = make_secret("KEY", "2026-04-05", 30)  # expires 2026-05-05, 15 days away
        result = evaluate_secrets([s], REFERENCE_DATE, 20)
        assert result[0].urgency == "warning"

    def test_multiple_required_by_services(self):
        """required_by list is preserved in SecretStatus."""
        s = make_secret("DB_PASS", "2025-10-01", 90, ["api", "worker", "admin"])
        result = evaluate_secrets([s], REFERENCE_DATE, WARNING_WINDOW)
        assert result[0].secret.required_by == ["api", "worker", "admin"]

    def test_empty_secrets_list(self):
        """Empty input returns empty output."""
        assert evaluate_secrets([], REFERENCE_DATE, WARNING_WINDOW) == []


# ---------------------------------------------------------------------------
# RED 2: format_markdown — report structure
# ---------------------------------------------------------------------------

class TestMarkdownFormat:
    def _statuses(self):
        secrets = [
            make_secret("DB_PASSWORD", "2025-10-01", 90, ["api-service", "worker-service"]),
            make_secret("API_KEY", "2026-04-05", 30, ["frontend-service"]),
            make_secret("JWT_SECRET", "2026-03-01", 60, ["auth-service"]),
            make_secret("SMTP_PASSWORD", "2026-04-15", 90, ["notification-service"]),
        ]
        return evaluate_secrets(secrets, REFERENCE_DATE, WARNING_WINDOW)

    def test_has_expired_section(self):
        md = format_markdown(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        assert "## EXPIRED (1)" in md

    def test_has_warning_section(self):
        md = format_markdown(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        assert "## WARNING (2)" in md

    def test_has_ok_section(self):
        md = format_markdown(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        assert "## OK (1)" in md

    def test_expired_secret_in_expired_section(self):
        md = format_markdown(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        assert "DB_PASSWORD" in md

    def test_reference_date_in_output(self):
        md = format_markdown(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        assert "2026-04-20" in md

    def test_markdown_table_header(self):
        md = format_markdown(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        assert "| Name |" in md

    def test_empty_section_shows_none(self):
        """A group with no secrets shows a placeholder."""
        s = make_secret("ONLY_EXPIRED", "2020-01-01", 30)
        statuses = evaluate_secrets([s], REFERENCE_DATE, WARNING_WINDOW)
        md = format_markdown(statuses, REFERENCE_DATE, WARNING_WINDOW)
        assert "_None_" in md


# ---------------------------------------------------------------------------
# RED 3: format_json — structured output
# ---------------------------------------------------------------------------

class TestJsonFormat:
    def _statuses(self):
        secrets = [
            make_secret("DB_PASSWORD", "2025-10-01", 90, ["api-service", "worker-service"]),
            make_secret("API_KEY", "2026-04-05", 30, ["frontend-service"]),
            make_secret("JWT_SECRET", "2026-03-01", 60, ["auth-service"]),
            make_secret("SMTP_PASSWORD", "2026-04-15", 90, ["notification-service"]),
        ]
        return evaluate_secrets(secrets, REFERENCE_DATE, WARNING_WINDOW)

    def test_valid_json(self):
        output = format_json(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        parsed = json.loads(output)
        assert isinstance(parsed, dict)

    def test_summary_counts(self):
        output = format_json(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        parsed = json.loads(output)
        assert parsed["summary"]["expired"] == 1
        assert parsed["summary"]["warning"] == 2
        assert parsed["summary"]["ok"] == 1
        assert parsed["summary"]["total"] == 4

    def test_groups_structure(self):
        output = format_json(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        parsed = json.loads(output)
        assert "expired" in parsed["groups"]
        assert "warning" in parsed["groups"]
        assert "ok" in parsed["groups"]

    def test_expired_group_contains_db_password(self):
        output = format_json(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        parsed = json.loads(output)
        names = [s["name"] for s in parsed["groups"]["expired"]]
        assert "DB_PASSWORD" in names

    def test_reference_date_in_json(self):
        output = format_json(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        parsed = json.loads(output)
        assert parsed["reference_date"] == "2026-04-20"

    def test_days_until_expiry_negative_for_expired(self):
        output = format_json(self._statuses(), REFERENCE_DATE, WARNING_WINDOW)
        parsed = json.loads(output)
        for item in parsed["groups"]["expired"]:
            assert item["days_until_expiry"] <= 0


# ---------------------------------------------------------------------------
# RED 4: load_secrets — JSON config file parsing
# ---------------------------------------------------------------------------

class TestLoadSecrets:
    def test_load_standard_fixture(self):
        """Load the standard test fixture successfully."""
        fixture = PROJECT_ROOT / "fixtures" / "test_secrets.json"
        secrets = load_secrets(str(fixture))
        assert len(secrets) == 4
        assert secrets[0].name == "DB_PASSWORD"

    def test_load_parses_dates(self):
        fixture = PROJECT_ROOT / "fixtures" / "test_secrets.json"
        secrets = load_secrets(str(fixture))
        assert secrets[0].last_rotated == date(2025, 10, 1)

    def test_load_parses_required_by(self):
        fixture = PROJECT_ROOT / "fixtures" / "test_secrets.json"
        secrets = load_secrets(str(fixture))
        assert "api-service" in secrets[0].required_by

    def test_missing_file_raises_error(self):
        with pytest.raises(FileNotFoundError):
            load_secrets("/nonexistent/path/secrets.json")

    def test_invalid_json_raises_error(self, tmp_path):
        bad = tmp_path / "bad.json"
        bad.write_text("not valid json {{{")
        with pytest.raises(ValueError, match="Invalid JSON"):
            load_secrets(str(bad))

    def test_missing_secrets_key_raises_error(self, tmp_path):
        bad = tmp_path / "bad.json"
        bad.write_text('{"other_key": []}')
        with pytest.raises(ValueError, match="'secrets'"):
            load_secrets(str(bad))

    def test_invalid_date_format_raises_error(self, tmp_path):
        bad = tmp_path / "bad.json"
        bad.write_text(json.dumps({
            "secrets": [{"name": "X", "last_rotated": "not-a-date",
                         "rotation_policy_days": 30, "required_by": []}]
        }))
        with pytest.raises(ValueError):
            load_secrets(str(bad))

    def test_load_custom_fixture(self, tmp_path):
        config = tmp_path / "secrets.json"
        config.write_text(json.dumps({
            "secrets": [
                {"name": "MY_KEY", "last_rotated": "2026-01-01",
                 "rotation_policy_days": 60, "required_by": ["svc"]}
            ]
        }))
        secrets = load_secrets(str(config))
        assert len(secrets) == 1
        assert secrets[0].name == "MY_KEY"


# ---------------------------------------------------------------------------
# RED 5: Workflow structure tests
# ---------------------------------------------------------------------------

WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "secret-rotation-validator.yml"


class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        assert WORKFLOW_PATH.exists(), f"Workflow not found: {WORKFLOW_PATH}"

    def test_workflow_triggers(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        # PyYAML parses the 'on:' key as the boolean True
        on = wf.get("on") or wf.get(True, {})
        assert "push" in on, "Missing 'push' trigger"
        assert "pull_request" in on, "Missing 'pull_request' trigger"
        assert "schedule" in on, "Missing 'schedule' trigger"
        assert "workflow_dispatch" in on, "Missing 'workflow_dispatch' trigger"

    def test_workflow_has_validate_job(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "validate" in wf.get("jobs", {}), "Missing 'validate' job"

    def test_workflow_has_checkout_step(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        steps = wf["jobs"]["validate"]["steps"]
        uses_values = [s.get("uses", "") for s in steps]
        assert any("actions/checkout" in u for u in uses_values), "Missing checkout step"

    def test_workflow_references_script(self):
        script = PROJECT_ROOT / "secret_rotation.py"
        assert script.exists(), f"Script not found: {script}"

    def test_workflow_references_fixture(self):
        fixture = PROJECT_ROOT / "fixtures" / "test_secrets.json"
        assert fixture.exists(), f"Fixture not found: {fixture}"

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
        )
