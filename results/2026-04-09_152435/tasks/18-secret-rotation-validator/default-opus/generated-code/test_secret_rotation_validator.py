"""
Unit tests for Secret Rotation Validator — developed using red/green TDD.

Each test was written BEFORE the corresponding production code.
The test names document the TDD cycle they belong to.
"""

import json
import os
import tempfile
import pytest
from datetime import datetime

from secret_rotation_validator import (
    parse_config,
    classify_secret,
    generate_report,
    validate_secrets,
)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SAMPLE_SECRET = {
    "name": "DB_PASSWORD",
    "last_rotated": "2025-12-01",
    "rotation_policy_days": 90,
    "required_by": ["api-service", "worker"],
}

REF_DATE = datetime(2026, 4, 10)


def _write_config(tmp_dir, config_dict):
    """Helper: write a config dict to a temp JSON file and return its path."""
    path = os.path.join(tmp_dir, "secrets.json")
    with open(path, "w") as f:
        json.dump(config_dict, f)
    return path


# ---------------------------------------------------------------------------
# TDD Cycle 1: parse_config
# ---------------------------------------------------------------------------

class TestParseConfig:
    """RED: wrote these tests first, then implemented parse_config."""

    def test_parse_valid_config(self, tmp_path):
        config = {"secrets": [SAMPLE_SECRET]}
        path = _write_config(str(tmp_path), config)
        result = parse_config(path)
        assert "secrets" in result
        assert len(result["secrets"]) == 1
        assert result["secrets"][0]["name"] == "DB_PASSWORD"

    def test_parse_file_not_found(self):
        with pytest.raises(ValueError, match="not found"):
            parse_config("/nonexistent/path.json")

    def test_parse_invalid_json(self, tmp_path):
        bad_file = os.path.join(str(tmp_path), "bad.json")
        with open(bad_file, "w") as f:
            f.write("{not valid json")
        with pytest.raises(ValueError, match="Invalid JSON"):
            parse_config(bad_file)

    def test_parse_missing_secrets_key(self, tmp_path):
        path = _write_config(str(tmp_path), {"other": []})
        with pytest.raises(ValueError, match="'secrets' key"):
            parse_config(path)

    def test_parse_secrets_not_list(self, tmp_path):
        path = _write_config(str(tmp_path), {"secrets": "oops"})
        with pytest.raises(ValueError, match="must be a list"):
            parse_config(path)


# ---------------------------------------------------------------------------
# TDD Cycle 2: classify_secret
# ---------------------------------------------------------------------------

class TestClassifySecret:
    """RED: wrote failing tests for each urgency level, then implemented."""

    def test_classify_expired(self):
        # DB_PASSWORD: rotated 2025-12-01, policy 90d, ref 2026-04-10
        # days_since=130, days_until=-40 -> expired
        result = classify_secret(SAMPLE_SECRET, REF_DATE, warning_window_days=14)
        assert result["status"] == "expired"
        assert result["days_since_rotation"] == 130
        assert result["days_until_expiry"] == -40

    def test_classify_warning(self):
        secret = {
            "name": "API_KEY",
            "last_rotated": "2026-03-15",
            "rotation_policy_days": 30,
            "required_by": ["gateway"],
        }
        # days_since=26, days_until=4 -> warning (4 <= 14)
        result = classify_secret(secret, REF_DATE, warning_window_days=14)
        assert result["status"] == "warning"
        assert result["days_since_rotation"] == 26
        assert result["days_until_expiry"] == 4

    def test_classify_ok(self):
        secret = {
            "name": "TLS_CERT",
            "last_rotated": "2026-04-01",
            "rotation_policy_days": 365,
            "required_by": ["nginx", "cdn"],
        }
        # days_since=9, days_until=356 -> ok (356 > 14)
        result = classify_secret(secret, REF_DATE, warning_window_days=14)
        assert result["status"] == "ok"
        assert result["days_since_rotation"] == 9
        assert result["days_until_expiry"] == 356

    def test_classify_missing_field(self):
        bad_secret = {"name": "INCOMPLETE"}
        with pytest.raises(ValueError, match="missing required field"):
            classify_secret(bad_secret, REF_DATE, warning_window_days=14)

    def test_classify_invalid_date(self):
        bad_secret = {
            "name": "BAD_DATE",
            "last_rotated": "not-a-date",
            "rotation_policy_days": 30,
            "required_by": [],
        }
        with pytest.raises(ValueError, match="Invalid date format"):
            classify_secret(bad_secret, REF_DATE, warning_window_days=14)

    def test_classify_exact_expiry_boundary(self):
        # Exactly at the policy boundary (days_until=0) should be 'warning'
        secret = {
            "name": "BOUNDARY",
            "last_rotated": "2026-01-10",
            "rotation_policy_days": 90,
            "required_by": ["svc"],
        }
        # 2026-01-10 to 2026-04-10 = 90 days, days_until = 0
        result = classify_secret(secret, REF_DATE, warning_window_days=14)
        assert result["status"] == "warning"
        assert result["days_until_expiry"] == 0

    def test_classify_custom_warning_window(self):
        secret = {
            "name": "NARROW_WINDOW",
            "last_rotated": "2026-03-15",
            "rotation_policy_days": 30,
            "required_by": ["svc"],
        }
        # days_until=4, warning_window=3 -> 4 > 3 -> ok
        result = classify_secret(secret, REF_DATE, warning_window_days=3)
        assert result["status"] == "ok"


# ---------------------------------------------------------------------------
# TDD Cycle 3: generate_report
# ---------------------------------------------------------------------------

class TestGenerateReport:
    """RED: wrote tests for JSON and markdown output, then implemented."""

    def _make_classified(self):
        return [
            {
                "name": "DB_PASSWORD", "status": "expired",
                "last_rotated": "2025-12-01", "rotation_policy_days": 90,
                "required_by": ["api-service", "worker"],
                "days_since_rotation": 130, "days_until_expiry": -40,
            },
            {
                "name": "API_KEY", "status": "warning",
                "last_rotated": "2026-03-15", "rotation_policy_days": 30,
                "required_by": ["gateway"],
                "days_since_rotation": 26, "days_until_expiry": 4,
            },
            {
                "name": "TLS_CERT", "status": "ok",
                "last_rotated": "2026-04-01", "rotation_policy_days": 365,
                "required_by": ["nginx", "cdn"],
                "days_since_rotation": 9, "days_until_expiry": 356,
            },
        ]

    def test_report_json_summary(self):
        report = generate_report(self._make_classified(), "json")
        data = json.loads(report)
        assert data["summary"]["expired"] == 1
        assert data["summary"]["warning"] == 1
        assert data["summary"]["ok"] == 1
        assert data["summary"]["total"] == 3

    def test_report_json_grouping(self):
        report = generate_report(self._make_classified(), "json")
        data = json.loads(report)
        assert len(data["secrets"]["expired"]) == 1
        assert data["secrets"]["expired"][0]["name"] == "DB_PASSWORD"
        assert len(data["secrets"]["warning"]) == 1
        assert data["secrets"]["warning"][0]["name"] == "API_KEY"
        assert len(data["secrets"]["ok"]) == 1
        assert data["secrets"]["ok"][0]["name"] == "TLS_CERT"

    def test_report_markdown_header(self):
        report = generate_report(self._make_classified(), "markdown")
        assert "# Secret Rotation Report" in report
        assert "**Expired:** 1" in report
        assert "**Warning:** 1" in report
        assert "**OK:** 1" in report

    def test_report_markdown_table_rows(self):
        report = generate_report(self._make_classified(), "markdown")
        assert "| DB_PASSWORD | EXPIRED |" in report
        assert "| API_KEY | WARNING |" in report
        assert "| TLS_CERT | OK |" in report

    def test_report_invalid_format(self):
        with pytest.raises(ValueError, match="Unsupported output format"):
            generate_report([], "xml")


# ---------------------------------------------------------------------------
# TDD Cycle 4: validate_secrets (integration)
# ---------------------------------------------------------------------------

class TestValidateSecrets:
    """RED: wrote end-to-end test, then wired validate_secrets together."""

    def test_full_pipeline_json(self, tmp_path):
        config = {
            "secrets": [
                {
                    "name": "DB_PASSWORD",
                    "last_rotated": "2025-12-01",
                    "rotation_policy_days": 90,
                    "required_by": ["api-service", "worker"],
                },
                {
                    "name": "API_KEY",
                    "last_rotated": "2026-03-15",
                    "rotation_policy_days": 30,
                    "required_by": ["gateway"],
                },
                {
                    "name": "TLS_CERT",
                    "last_rotated": "2026-04-01",
                    "rotation_policy_days": 365,
                    "required_by": ["nginx", "cdn"],
                },
            ],
            "warning_window_days": 14,
        }
        path = _write_config(str(tmp_path), config)
        output = validate_secrets(path, reference_date="2026-04-10",
                                  output_format="json")
        data = json.loads(output)
        assert data["summary"]["expired"] == 1
        assert data["summary"]["warning"] == 1
        assert data["summary"]["ok"] == 1

    def test_full_pipeline_markdown(self, tmp_path):
        config = {
            "secrets": [
                {
                    "name": "SECRET_A",
                    "last_rotated": "2025-01-01",
                    "rotation_policy_days": 30,
                    "required_by": ["service-a"],
                },
                {
                    "name": "SECRET_B",
                    "last_rotated": "2025-06-01",
                    "rotation_policy_days": 60,
                    "required_by": ["service-b", "service-c"],
                },
            ],
            "warning_window_days": 7,
        }
        path = _write_config(str(tmp_path), config)
        output = validate_secrets(path, reference_date="2026-04-10",
                                  output_format="markdown")
        assert "**Expired:** 2" in output
        assert "**Warning:** 0" in output
        assert "**OK:** 0" in output

    def test_config_warning_window_override(self, tmp_path):
        """Config-level warning_window_days overrides CLI default."""
        config = {
            "secrets": [
                {
                    "name": "NARROW",
                    "last_rotated": "2026-03-15",
                    "rotation_policy_days": 30,
                    "required_by": ["svc"],
                },
            ],
            "warning_window_days": 3,
        }
        path = _write_config(str(tmp_path), config)
        # days_until=4, config says warning_window=3, so 4>3 -> ok
        output = validate_secrets(path, reference_date="2026-04-10",
                                  output_format="json")
        data = json.loads(output)
        assert data["summary"]["ok"] == 1
        assert data["summary"]["warning"] == 0
