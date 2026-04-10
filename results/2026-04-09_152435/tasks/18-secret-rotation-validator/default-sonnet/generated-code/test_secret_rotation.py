"""
Tests for the secret rotation validator.
TDD approach: tests written before implementation, run to confirm failure, then implement.

Reference date for all tests: 2026-04-10 (fixed, so results are deterministic)
"""
import json
import os
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

import pytest
import yaml

# The module under test — will fail to import until implemented
from secret_rotation import (
    Secret,
    SecretStatus,
    categorize_secret,
    validate_secrets,
    format_markdown,
    format_json,
    generate_report,
)

# Fixed reference date for all tests — avoids time-dependent flakiness
REF_DATE = date(2026, 4, 10)
WARNING_WINDOW = 7  # days


# ---------------------------------------------------------------------------
# Fixtures: define test secrets relative to REF_DATE so intent is obvious
# ---------------------------------------------------------------------------

def make_expired_secret():
    """Returns a secret that expired 20 days before REF_DATE."""
    return Secret(
        name="DB_PASSWORD",
        last_rotated=REF_DATE - timedelta(days=110),  # 110 days ago
        rotation_policy_days=90,                       # expires after 90 days -> 20 days overdue
        required_by=["api-server", "worker"],
    )


def make_warning_secret():
    """Returns a secret that expires 4 days after REF_DATE (within warning window)."""
    return Secret(
        name="API_KEY",
        last_rotated=REF_DATE - timedelta(days=21),   # 21 days ago
        rotation_policy_days=25,                       # expires after 25 days -> 4 days left
        required_by=["frontend"],
    )


def make_ok_secret():
    """Returns a secret that expires 80 days after REF_DATE (well within policy)."""
    return Secret(
        name="JWT_SECRET",
        last_rotated=REF_DATE - timedelta(days=10),   # 10 days ago
        rotation_policy_days=90,                       # expires after 90 days -> 80 days left
        required_by=["auth-service"],
    )


# ---------------------------------------------------------------------------
# RED 1: Can we import and construct a Secret?
# ---------------------------------------------------------------------------

class TestSecretConstruction:
    def test_secret_fields(self):
        """Secret dataclass holds all required fields."""
        s = Secret(
            name="MY_SECRET",
            last_rotated=date(2026, 1, 1),
            rotation_policy_days=30,
            required_by=["svc-a", "svc-b"],
        )
        assert s.name == "MY_SECRET"
        assert s.last_rotated == date(2026, 1, 1)
        assert s.rotation_policy_days == 30
        assert s.required_by == ["svc-a", "svc-b"]


# ---------------------------------------------------------------------------
# RED 2: days_until_expiry computation
# ---------------------------------------------------------------------------

class TestCategorizeSecret:
    def test_expired_secret_has_negative_days(self):
        """An overdue secret has negative days_until_expiry."""
        s = make_expired_secret()
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert status.days_until_expiry < 0

    def test_expired_urgency(self):
        """An overdue secret is categorized as 'expired'."""
        s = make_expired_secret()
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert status.urgency == "expired"

    def test_warning_secret_days_in_window(self):
        """A soon-expiring secret has days_until_expiry in [0, warning_window]."""
        s = make_warning_secret()
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert 0 <= status.days_until_expiry <= WARNING_WINDOW

    def test_warning_urgency(self):
        """A soon-expiring secret is categorized as 'warning'."""
        s = make_warning_secret()
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert status.urgency == "warning"

    def test_ok_secret_days_beyond_window(self):
        """A healthy secret has days_until_expiry > warning_window."""
        s = make_ok_secret()
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert status.days_until_expiry > WARNING_WINDOW

    def test_ok_urgency(self):
        """A healthy secret is categorized as 'ok'."""
        s = make_ok_secret()
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert status.urgency == "ok"

    def test_expires_exactly_today_is_expired(self):
        """A secret that expires exactly today is 'expired' (0 days left = expired)."""
        s = Secret("EDGE", REF_DATE - timedelta(days=30), 30, ["svc"])
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert status.urgency == "expired"
        assert status.days_until_expiry == 0

    def test_expires_in_warning_window_boundary(self):
        """A secret expiring exactly at the warning window edge is 'warning'."""
        s = Secret("EDGE2", REF_DATE - timedelta(days=83), 90, ["svc"])
        status = categorize_secret(s, REF_DATE, WARNING_WINDOW)
        assert status.urgency == "warning"


# ---------------------------------------------------------------------------
# RED 3: validate_secrets — processes a config dict
# ---------------------------------------------------------------------------

class TestValidateSecrets:
    def _make_config(self):
        return {
            "warning_window_days": WARNING_WINDOW,
            "reference_date": REF_DATE.isoformat(),
            "secrets": [
                {
                    "name": "DB_PASSWORD",
                    "last_rotated": (REF_DATE - timedelta(days=110)).isoformat(),
                    "rotation_policy_days": 90,
                    "required_by": ["api-server"],
                },
                {
                    "name": "API_KEY",
                    "last_rotated": (REF_DATE - timedelta(days=21)).isoformat(),
                    "rotation_policy_days": 25,
                    "required_by": ["frontend"],
                },
                {
                    "name": "JWT_SECRET",
                    "last_rotated": (REF_DATE - timedelta(days=10)).isoformat(),
                    "rotation_policy_days": 90,
                    "required_by": ["auth-service"],
                },
            ],
        }

    def test_returns_list_of_statuses(self):
        """validate_secrets returns one SecretStatus per secret."""
        config = self._make_config()
        statuses = validate_secrets(config)
        assert len(statuses) == 3

    def test_all_urgency_levels_present(self):
        """The three test secrets cover all urgency levels."""
        config = self._make_config()
        statuses = validate_secrets(config)
        urgencies = {s.urgency for s in statuses}
        assert urgencies == {"expired", "warning", "ok"}

    def test_expired_secret_identified(self):
        """DB_PASSWORD is identified as expired."""
        config = self._make_config()
        statuses = validate_secrets(config)
        db = next(s for s in statuses if s.secret.name == "DB_PASSWORD")
        assert db.urgency == "expired"

    def test_warning_secret_identified(self):
        """API_KEY is identified as warning."""
        config = self._make_config()
        statuses = validate_secrets(config)
        api = next(s for s in statuses if s.secret.name == "API_KEY")
        assert api.urgency == "warning"

    def test_ok_secret_identified(self):
        """JWT_SECRET is identified as ok."""
        config = self._make_config()
        statuses = validate_secrets(config)
        jwt = next(s for s in statuses if s.secret.name == "JWT_SECRET")
        assert jwt.urgency == "ok"

    def test_missing_warning_window_defaults(self):
        """warning_window_days is optional in config; defaults to 7."""
        config = self._make_config()
        del config["warning_window_days"]
        # Should not raise; uses default
        statuses = validate_secrets(config)
        assert len(statuses) == 3

    def test_error_on_invalid_date(self):
        """validate_secrets raises ValueError for unparseable date strings."""
        config = self._make_config()
        config["secrets"][0]["last_rotated"] = "not-a-date"
        with pytest.raises(ValueError, match="last_rotated"):
            validate_secrets(config)

    def test_error_on_missing_name(self):
        """validate_secrets raises ValueError when 'name' field is absent."""
        config = self._make_config()
        del config["secrets"][0]["name"]
        with pytest.raises(ValueError, match="name"):
            validate_secrets(config)


# ---------------------------------------------------------------------------
# RED 4: Markdown table format
# ---------------------------------------------------------------------------

class TestFormatMarkdown:
    def _get_statuses(self):
        s1 = categorize_secret(make_expired_secret(), REF_DATE, WARNING_WINDOW)
        s2 = categorize_secret(make_warning_secret(), REF_DATE, WARNING_WINDOW)
        s3 = categorize_secret(make_ok_secret(), REF_DATE, WARNING_WINDOW)
        return [s1, s2, s3]

    def test_markdown_contains_header(self):
        """Markdown output has a table header row."""
        md = format_markdown(self._get_statuses())
        assert "| Name |" in md or "|Name|" in md.replace(" ", "")

    def test_markdown_contains_secret_names(self):
        """All secret names appear in the markdown output."""
        md = format_markdown(self._get_statuses())
        assert "DB_PASSWORD" in md
        assert "API_KEY" in md
        assert "JWT_SECRET" in md

    def test_markdown_contains_urgency_labels(self):
        """Urgency labels appear in the markdown output."""
        md = format_markdown(self._get_statuses())
        assert "EXPIRED" in md.upper() or "expired" in md
        assert "WARNING" in md.upper() or "warning" in md
        assert "OK" in md.upper() or "ok" in md

    def test_markdown_contains_services(self):
        """Required-by services appear in the output."""
        md = format_markdown(self._get_statuses())
        assert "api-server" in md
        assert "frontend" in md

    def test_markdown_grouped_by_urgency(self):
        """Expired secrets appear before warning, which appear before ok."""
        md = format_markdown(self._get_statuses())
        pos_expired = md.find("DB_PASSWORD")
        pos_warning = md.find("API_KEY")
        pos_ok = md.find("JWT_SECRET")
        assert pos_expired < pos_warning < pos_ok


# ---------------------------------------------------------------------------
# RED 5: JSON format
# ---------------------------------------------------------------------------

class TestFormatJson:
    def _get_statuses(self):
        s1 = categorize_secret(make_expired_secret(), REF_DATE, WARNING_WINDOW)
        s2 = categorize_secret(make_warning_secret(), REF_DATE, WARNING_WINDOW)
        s3 = categorize_secret(make_ok_secret(), REF_DATE, WARNING_WINDOW)
        return [s1, s2, s3]

    def test_json_is_valid(self):
        """format_json returns valid JSON."""
        result = format_json(self._get_statuses())
        data = json.loads(result)
        assert isinstance(data, dict)

    def test_json_has_summary_counts(self):
        """JSON output includes counts per urgency level."""
        result = format_json(self._get_statuses())
        data = json.loads(result)
        assert data["summary"]["expired"] == 1
        assert data["summary"]["warning"] == 1
        assert data["summary"]["ok"] == 1

    def test_json_has_grouped_secrets(self):
        """JSON output groups secrets by urgency."""
        result = format_json(self._get_statuses())
        data = json.loads(result)
        assert "expired" in data["groups"]
        assert "warning" in data["groups"]
        assert "ok" in data["groups"]
        assert data["groups"]["expired"][0]["name"] == "DB_PASSWORD"
        assert data["groups"]["warning"][0]["name"] == "API_KEY"
        assert data["groups"]["ok"][0]["name"] == "JWT_SECRET"

    def test_json_secrets_include_days_until_expiry(self):
        """Each secret entry in JSON includes days_until_expiry."""
        result = format_json(self._get_statuses())
        data = json.loads(result)
        expired = data["groups"]["expired"][0]
        assert "days_until_expiry" in expired
        assert expired["days_until_expiry"] < 0

    def test_json_secrets_include_required_by(self):
        """Each secret entry in JSON includes required_by list."""
        result = format_json(self._get_statuses())
        data = json.loads(result)
        expired = data["groups"]["expired"][0]
        assert "required_by" in expired
        assert "api-server" in expired["required_by"]


# ---------------------------------------------------------------------------
# RED 6: generate_report dispatcher
# ---------------------------------------------------------------------------

class TestGenerateReport:
    def _get_statuses(self):
        s1 = categorize_secret(make_expired_secret(), REF_DATE, WARNING_WINDOW)
        s2 = categorize_secret(make_warning_secret(), REF_DATE, WARNING_WINDOW)
        s3 = categorize_secret(make_ok_secret(), REF_DATE, WARNING_WINDOW)
        return [s1, s2, s3]

    def test_generate_report_markdown(self):
        """generate_report with format='markdown' returns markdown content."""
        report = generate_report(self._get_statuses(), fmt="markdown")
        assert "DB_PASSWORD" in report
        assert "|" in report  # table markers

    def test_generate_report_json(self):
        """generate_report with format='json' returns valid JSON."""
        report = generate_report(self._get_statuses(), fmt="json")
        data = json.loads(report)
        assert "summary" in data

    def test_generate_report_invalid_format(self):
        """generate_report raises ValueError for unknown format."""
        with pytest.raises(ValueError, match="format"):
            generate_report(self._get_statuses(), fmt="xml")


# ---------------------------------------------------------------------------
# RED 7: Workflow structure tests (no act yet — just YAML parsing)
# ---------------------------------------------------------------------------

WORKFLOW_PATH = Path(__file__).parent / ".github" / "workflows" / "secret-rotation-validator.yml"
SCRIPT_PATH = Path(__file__).parent / "secret_rotation.py"


class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        """The workflow YAML file is present."""
        assert WORKFLOW_PATH.exists(), f"Workflow not found: {WORKFLOW_PATH}"

    def test_script_file_exists(self):
        """The main script file is present."""
        assert SCRIPT_PATH.exists(), f"Script not found: {SCRIPT_PATH}"

    def test_workflow_has_valid_yaml(self):
        """The workflow file is valid YAML."""
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        assert data is not None

    def test_workflow_has_push_trigger(self):
        """Workflow triggers on push.

        Note: PyYAML parses the YAML key 'on' as Python True (a YAML boolean),
        so we check both data["on"] and data[True].
        """
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        # 'on' in YAML is parsed as True by PyYAML
        triggers = data.get("on") or data.get(True) or {}
        assert "push" in triggers

    def test_workflow_has_workflow_dispatch(self):
        """Workflow supports manual dispatch."""
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        triggers = data.get("on") or data.get(True) or {}
        assert "workflow_dispatch" in triggers

    def test_workflow_has_jobs(self):
        """Workflow defines at least one job."""
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        assert data.get("jobs"), "No jobs defined"

    def test_workflow_has_checkout_step(self):
        """At least one job uses actions/checkout."""
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        found = False
        for job in data["jobs"].values():
            for step in job.get("steps", []):
                if "actions/checkout" in str(step.get("uses", "")):
                    found = True
        assert found, "No actions/checkout step found"

    def test_workflow_references_script(self):
        """Workflow YAML references the main script file."""
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        assert "secret_rotation.py" in content

    def test_actionlint_passes(self):
        """actionlint reports no errors on the workflow file."""
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
        )
