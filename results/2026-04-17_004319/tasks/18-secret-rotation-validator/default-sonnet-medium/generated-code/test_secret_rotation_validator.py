"""
Tests for secret_rotation_validator.py - written FIRST (TDD red phase).

We test:
1. check_secret() - classifies a single secret as expired/warning/ok
2. load_config() - parses JSON config from file
3. generate_report() - outputs JSON and markdown formats
4. Workflow structure - YAML has expected triggers/jobs/steps
5. actionlint - workflow passes linting
"""

import json
import os
import subprocess
import sys
from datetime import date
from pathlib import Path

import pytest
import yaml

# The module under test -- will fail to import until we write it
from secret_rotation_validator import (
    Secret,
    SecretStatus,
    check_secret,
    generate_report,
    load_config,
)

REFERENCE_DATE = date(2026, 4, 19)
WORKFLOW_FILE = Path(__file__).parent / ".github" / "workflows" / "secret-rotation-validator.yml"

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def secret_expired():
    """A secret whose expiry date is 10 days in the past (as of 2026-04-19)."""
    # last_rotated=2026-01-09, policy=90 -> expiry=2026-04-09, 10 days overdue
    return Secret(
        name="DB_PASSWORD",
        last_rotated=date(2026, 1, 9),
        rotation_policy_days=90,
        required_by=["web-app", "api-service"],
    )

@pytest.fixture
def secret_warning():
    """A secret expiring in 7 days (within the 14-day warning window)."""
    # last_rotated=2026-04-06, policy=20 -> expiry=2026-04-26, 7 days left
    return Secret(
        name="API_KEY",
        last_rotated=date(2026, 4, 6),
        rotation_policy_days=20,
        required_by=["payment-service"],
    )

@pytest.fixture
def secret_ok():
    """A secret with plenty of time left before rotation."""
    # last_rotated=2026-04-09, policy=365 -> expiry=2027-04-09, 355 days left
    return Secret(
        name="TLS_CERT",
        last_rotated=date(2026, 4, 9),
        rotation_policy_days=365,
        required_by=["load-balancer"],
    )

@pytest.fixture
def mixed_statuses(secret_expired, secret_warning, secret_ok):
    """All three statuses plus a second warning secret."""
    # OAUTH_SECRET: last_rotated=2026-04-01, policy=30 -> expiry=2026-05-01, 12 days left
    oauth = Secret(
        name="OAUTH_SECRET",
        last_rotated=date(2026, 4, 1),
        rotation_policy_days=30,
        required_by=["auth-service"],
    )
    return [secret_expired, secret_warning, secret_ok, oauth]

# ---------------------------------------------------------------------------
# TDD: check_secret() — single secret classification
# ---------------------------------------------------------------------------

def test_expired_secret(secret_expired):
    """An overdue secret is classified as 'expired' with correct days_overdue."""
    status = check_secret(secret_expired, REFERENCE_DATE)
    assert status.status == "expired"
    assert status.days_overdue == 10
    assert status.days_remaining is None

def test_warning_secret(secret_warning):
    """A secret expiring within the warning window is classified as 'warning'."""
    status = check_secret(secret_warning, REFERENCE_DATE, warning_window=14)
    assert status.status == "warning"
    assert status.days_remaining == 7
    assert status.days_overdue is None

def test_ok_secret(secret_ok):
    """A secret with ample time left is classified as 'ok'."""
    status = check_secret(secret_ok, REFERENCE_DATE)
    assert status.status == "ok"
    assert status.days_remaining == 355
    assert status.days_overdue is None

def test_exactly_at_boundary_warning():
    """A secret expiring exactly at the warning boundary is 'warning', not 'ok'."""
    # Expires exactly 14 days from reference date
    s = Secret("EDGE_SECRET", date(2026, 3, 26), 24, [])  # 2026-03-26 + 24 = 2026-04-19 + 14 - wait
    # last_rotated=2026-3-26, policy=24 -> expiry = 2026-4-19 + (24 - days from mar26 to apr19)
    # Actually let me compute: reference=2026-04-19, want expiry = 2026-05-03 (14 days away)
    # 2026-05-03 - ? days = policy days starting from last_rotated
    # Choose last_rotated=2026-04-09, policy=24: expiry=2026-04-09+24=2026-05-03, 14 days away
    s = Secret("EDGE_SECRET", date(2026, 4, 9), 24, [])
    status = check_secret(s, REFERENCE_DATE, warning_window=14)
    assert status.status == "warning"
    assert status.days_remaining == 14

def test_one_day_past_boundary_is_ok():
    """A secret expiring 15 days out is 'ok' with 14-day warning window."""
    # last_rotated=2026-04-10, policy=24: expiry=2026-05-04, 15 days from 2026-04-19
    s = Secret("FINE_SECRET", date(2026, 4, 10), 24, [])
    status = check_secret(s, REFERENCE_DATE, warning_window=14)
    assert status.status == "ok"
    assert status.days_remaining == 15

def test_expired_zero_days():
    """A secret expiring exactly today is classified as 'expired' (0 days overdue)."""
    # last_rotated=2026-01-19, policy=90: expiry=2026-04-19 = reference_date
    s = Secret("TODAY_SECRET", date(2026, 1, 19), 90, [])
    status = check_secret(s, REFERENCE_DATE)
    assert status.status == "expired"
    assert status.days_overdue == 0

def test_custom_warning_window(secret_warning):
    """A custom warning window changes classification boundaries."""
    # secret_warning expires in 7 days — with 5-day window it should be 'ok'
    status = check_secret(secret_warning, REFERENCE_DATE, warning_window=5)
    assert status.status == "ok"

# ---------------------------------------------------------------------------
# TDD: load_config() — parse JSON config file
# ---------------------------------------------------------------------------

def test_load_config(tmp_path):
    """load_config reads a JSON file and returns a list of Secret objects."""
    config = {
        "secrets": [
            {
                "name": "MY_SECRET",
                "last_rotated": "2026-01-01",
                "rotation_policy_days": 90,
                "required_by": ["svc-a"],
            }
        ]
    }
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(config))
    secrets = load_config(str(config_file))
    assert len(secrets) == 1
    assert secrets[0].name == "MY_SECRET"
    assert secrets[0].last_rotated == date(2026, 1, 1)
    assert secrets[0].rotation_policy_days == 90
    assert secrets[0].required_by == ["svc-a"]

def test_load_config_missing_file():
    """load_config raises FileNotFoundError for non-existent files."""
    with pytest.raises(FileNotFoundError):
        load_config("/nonexistent/path/config.json")

def test_load_config_invalid_json(tmp_path):
    """load_config raises ValueError for malformed JSON."""
    bad = tmp_path / "bad.json"
    bad.write_text("not valid json {{{")
    with pytest.raises(ValueError, match="Invalid JSON"):
        load_config(str(bad))

def test_load_config_missing_required_field(tmp_path):
    """load_config raises ValueError when a required field is missing."""
    config = {"secrets": [{"name": "X"}]}  # missing last_rotated etc.
    f = tmp_path / "config.json"
    f.write_text(json.dumps(config))
    with pytest.raises(ValueError, match="missing required field"):
        load_config(str(f))

# ---------------------------------------------------------------------------
# TDD: generate_report() — output formats
# ---------------------------------------------------------------------------

def test_generate_report_json(mixed_statuses):
    """generate_report produces valid JSON with expired/warning/ok groups."""
    statuses = [check_secret(s, REFERENCE_DATE) for s in mixed_statuses]
    output = generate_report(statuses, fmt="json")
    data = json.loads(output)  # must be valid JSON
    assert "expired" in data
    assert "warning" in data
    assert "ok" in data
    # DB_PASSWORD is expired
    assert any(e["name"] == "DB_PASSWORD" for e in data["expired"])
    # API_KEY and OAUTH_SECRET are warnings
    warning_names = [w["name"] for w in data["warning"]]
    assert "API_KEY" in warning_names
    assert "OAUTH_SECRET" in warning_names
    # TLS_CERT is ok
    assert any(o["name"] == "TLS_CERT" for o in data["ok"])

def test_generate_report_json_expired_has_days_overdue(secret_expired):
    """Expired entries in JSON include 'days_overdue' field."""
    status = check_secret(secret_expired, REFERENCE_DATE)
    output = generate_report([status], fmt="json")
    data = json.loads(output)
    entry = data["expired"][0]
    assert entry["days_overdue"] == 10
    assert "days_remaining" not in entry

def test_generate_report_json_warning_has_days_remaining(secret_warning):
    """Warning entries in JSON include 'days_remaining' field."""
    status = check_secret(secret_warning, REFERENCE_DATE)
    output = generate_report([status], fmt="json")
    data = json.loads(output)
    entry = data["warning"][0]
    assert entry["days_remaining"] == 7
    assert "days_overdue" not in entry

def test_generate_report_json_includes_required_by(secret_expired):
    """JSON output includes the required_by list for each secret."""
    status = check_secret(secret_expired, REFERENCE_DATE)
    output = generate_report([status], fmt="json")
    data = json.loads(output)
    entry = data["expired"][0]
    assert entry["required_by"] == ["web-app", "api-service"]

def test_generate_report_markdown(mixed_statuses):
    """generate_report in markdown mode produces a table with all secrets."""
    statuses = [check_secret(s, REFERENCE_DATE) for s in mixed_statuses]
    output = generate_report(statuses, fmt="markdown")
    assert "# Secret Rotation Report" in output
    assert "DB_PASSWORD" in output
    assert "API_KEY" in output
    assert "TLS_CERT" in output
    assert "OAUTH_SECRET" in output
    # Must contain markdown table characters
    assert "|" in output

def test_generate_report_markdown_urgency_sections(mixed_statuses):
    """Markdown report has distinct EXPIRED/WARNING/OK sections."""
    statuses = [check_secret(s, REFERENCE_DATE) for s in mixed_statuses]
    output = generate_report(statuses, fmt="markdown")
    assert "## EXPIRED" in output
    assert "## WARNING" in output
    assert "## OK" in output

def test_generate_report_invalid_format(secret_ok):
    """generate_report raises ValueError for unsupported format."""
    status = check_secret(secret_ok, REFERENCE_DATE)
    with pytest.raises(ValueError, match="Unknown format"):
        generate_report([status], fmt="xml")

def test_generate_report_empty_list():
    """generate_report handles empty list gracefully."""
    output = generate_report([], fmt="json")
    data = json.loads(output)
    assert data["expired"] == []
    assert data["warning"] == []
    assert data["ok"] == []

# ---------------------------------------------------------------------------
# Workflow structure tests
# ---------------------------------------------------------------------------

def test_workflow_file_exists():
    """The GitHub Actions workflow file must exist."""
    assert WORKFLOW_FILE.exists(), f"Workflow file not found: {WORKFLOW_FILE}"

def test_workflow_has_expected_triggers():
    """Workflow must have push, pull_request, schedule, and workflow_dispatch triggers."""
    with open(WORKFLOW_FILE) as f:
        wf = yaml.safe_load(f)
    # PyYAML parses "on" as boolean True in YAML 1.1 — handle both forms
    on = wf.get("on") or wf.get(True, {})
    assert "push" in on, "Missing 'push' trigger"
    assert "pull_request" in on, "Missing 'pull_request' trigger"
    assert "schedule" in on, "Missing 'schedule' trigger"
    assert "workflow_dispatch" in on, "Missing 'workflow_dispatch' trigger"

def test_workflow_has_validate_job():
    """Workflow must have a 'validate-secrets' job."""
    with open(WORKFLOW_FILE) as f:
        wf = yaml.safe_load(f)
    jobs = wf.get("jobs", {})
    assert "validate-secrets" in jobs, f"Expected 'validate-secrets' job, got: {list(jobs.keys())}"

def test_workflow_references_script():
    """Workflow must reference secret_rotation_validator.py in a step."""
    with open(WORKFLOW_FILE) as f:
        content = f.read()
    assert "secret_rotation_validator.py" in content

def test_workflow_uses_checkout():
    """Workflow must use actions/checkout@v4."""
    with open(WORKFLOW_FILE) as f:
        content = f.read()
    assert "actions/checkout@v4" in content

def test_actionlint_passes():
    """Workflow must pass actionlint validation with exit code 0."""
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_FILE)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )

def test_script_file_exists():
    """The main script must exist at the path the workflow references."""
    script = Path(__file__).parent / "secret_rotation_validator.py"
    assert script.exists(), "secret_rotation_validator.py not found"

def test_default_fixture_exists():
    """The default fixture config must exist for the workflow to run."""
    fixture = Path(__file__).parent / "fixtures" / "default_config.json"
    assert fixture.exists(), "fixtures/default_config.json not found"
