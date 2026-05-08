# Unit tests for secret_rotation module.
#
# These tests were authored using red/green TDD: each `def test_*` block was
# written to fail first, the production code in src/secret_rotation.py was
# then written to make it pass, then refactored. They are run inside the
# GitHub Actions workflow (see .github/workflows/secret-rotation-validator.yml)
# so all assertions execute "through act" as the benchmark requires.

import json
import sys
import textwrap
from datetime import date
from pathlib import Path

import pytest

# Make `src/` importable without packaging.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))

from secret_rotation import (  # noqa: E402  (sys.path edit must precede import)
    InvalidConfigError,
    Secret,
    categorize_secret,
    format_json,
    format_markdown,
    generate_report,
    load_config,
    main,
)


# ---------- Test fixtures (helpers) ----------

REF_DATE = date(2026, 5, 7)
WARNING_DAYS = 14


def _secret(name="API_KEY", last="2026-05-01", days=30, services=("api",)):
    return Secret(
        name=name,
        last_rotated=date.fromisoformat(last),
        rotation_days=days,
        services=list(services),
    )


# ---------- categorize_secret() ----------

class TestCategorize:
    """`categorize_secret` returns 'expired' / 'warning' / 'ok'."""

    def test_expired_when_due_date_in_the_past(self):
        # Last rotated 2026-01-01 + 30 day policy => due 2026-01-31, well past 2026-05-07.
        s = _secret(last="2026-01-01", days=30)
        assert categorize_secret(s, REF_DATE, WARNING_DAYS) == "expired"

    def test_warning_when_due_within_window(self):
        # Last rotated 2026-04-15 + 30 days => due 2026-05-15 (8 days from REF_DATE).
        s = _secret(last="2026-04-15", days=30)
        assert categorize_secret(s, REF_DATE, WARNING_DAYS) == "warning"

    def test_ok_when_due_outside_window(self):
        # Last rotated 2026-05-01 + 90 days => due 2026-07-30 (84 days from REF_DATE).
        s = _secret(last="2026-05-01", days=90)
        assert categorize_secret(s, REF_DATE, WARNING_DAYS) == "ok"

    def test_due_today_counts_as_expired(self):
        # If today equals due date, treat as expired (must rotate now).
        s = _secret(last="2026-04-07", days=30)  # due 2026-05-07
        assert categorize_secret(s, REF_DATE, WARNING_DAYS) == "expired"

    def test_warning_window_boundary_inclusive(self):
        # Due exactly `warning_days` from now is still a warning.
        s = _secret(last="2026-04-23", days=28)  # due 2026-05-21 == REF_DATE + 14
        assert categorize_secret(s, REF_DATE, WARNING_DAYS) == "warning"


# ---------- generate_report() ----------

class TestGenerateReport:
    """`generate_report` groups secrets by urgency and computes summary."""

    def test_groups_secrets_by_urgency(self):
        secrets = [
            _secret(name="A", last="2026-01-01", days=30),  # expired
            _secret(name="B", last="2026-04-15", days=30),  # warning
            _secret(name="C", last="2026-05-01", days=90),  # ok
        ]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        assert [s["name"] for s in rep["expired"]] == ["A"]
        assert [s["name"] for s in rep["warning"]] == ["B"]
        assert [s["name"] for s in rep["ok"]] == ["C"]

    def test_summary_totals_match_groups(self):
        secrets = [
            _secret(name="A", last="2026-01-01", days=30),
            _secret(name="B", last="2026-04-15", days=30),
            _secret(name="C", last="2026-05-01", days=90),
        ]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        assert rep["summary"] == {"total": 3, "expired": 1, "warning": 1, "ok": 1}

    def test_expired_sorted_most_overdue_first(self):
        # Most-overdue secret should come first so the urgent items lead the report.
        secrets = [
            _secret(name="LESS", last="2026-04-01", days=30),  # 6d overdue
            _secret(name="MORE", last="2026-01-01", days=30),  # 96d overdue
        ]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        assert [s["name"] for s in rep["expired"]] == ["MORE", "LESS"]

    def test_warning_sorted_soonest_due_first(self):
        secrets = [
            _secret(name="LATER", last="2026-04-23", days=28),  # due in 14
            _secret(name="SOONER", last="2026-04-15", days=30),  # due in 8
        ]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        assert [s["name"] for s in rep["warning"]] == ["SOONER", "LATER"]

    def test_includes_metadata_in_each_secret_entry(self):
        secrets = [_secret(name="X", last="2026-01-01", days=30, services=("a", "b"))]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        entry = rep["expired"][0]
        assert entry == {
            "name": "X",
            "last_rotated": "2026-01-01",
            "due_date": "2026-01-31",
            "days_overdue": 96,
            "days_until_due": -96,
            "rotation_days": 30,
            "services": ["a", "b"],
        }


# ---------- format_markdown() ----------

class TestMarkdownFormat:
    """`format_markdown` produces a human-readable grouped report."""

    def _sample_report(self):
        secrets = [
            _secret(name="DATABASE_PASSWORD", last="2026-01-01", days=30,
                    services=("api", "worker")),
            _secret(name="API_KEY", last="2026-04-15", days=30,
                    services=("public-api",)),
            _secret(name="JWT_SECRET", last="2026-05-01", days=90,
                    services=("auth",)),
        ]
        return generate_report(secrets, REF_DATE, WARNING_DAYS)

    def test_header_contains_summary_line(self):
        out = format_markdown(self._sample_report())
        assert "# Secret Rotation Report" in out
        assert "Generated: 2026-05-07" in out
        assert "Warning window: 14 days" in out
        assert "Total secrets: 3 (1 expired, 1 warning, 1 ok)" in out

    def test_each_group_has_its_own_section(self):
        out = format_markdown(self._sample_report())
        assert "## Expired (1)" in out
        assert "## Warning (1)" in out
        assert "## OK (1)" in out

    def test_expired_table_shows_days_overdue(self):
        out = format_markdown(self._sample_report())
        # Markdown table row for the expired secret.
        assert "| DATABASE_PASSWORD | 2026-01-01 | 2026-01-31 | 96 | api, worker |" in out

    def test_warning_table_shows_days_until_due(self):
        out = format_markdown(self._sample_report())
        assert "| API_KEY | 2026-04-15 | 2026-05-15 | 8 | public-api |" in out

    def test_empty_groups_render_no_secrets_message(self):
        # A report with no expired/warning secrets should still render those
        # sections so consumers can see "everything is fine".
        secrets = [_secret(name="JWT_SECRET", last="2026-05-01", days=90)]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        out = format_markdown(rep)
        assert "## Expired (0)" in out
        assert "_No secrets in this group._" in out


# ---------- format_json() ----------

class TestJsonFormat:
    """`format_json` produces a parseable, schema-stable JSON document."""

    def test_round_trips_through_json_loads(self):
        secrets = [_secret(name="X", last="2026-01-01", days=30)]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        text = format_json(rep)
        parsed = json.loads(text)
        assert parsed["summary"]["expired"] == 1
        assert parsed["expired"][0]["name"] == "X"

    def test_includes_top_level_metadata(self):
        secrets = [_secret(name="X", last="2026-01-01", days=30)]
        rep = generate_report(secrets, REF_DATE, WARNING_DAYS)
        parsed = json.loads(format_json(rep))
        assert parsed["generated"] == "2026-05-07"
        assert parsed["warning_days"] == 14


# ---------- load_config() ----------

class TestLoadConfig:
    """`load_config` parses a JSON file of secrets and validates fields."""

    def test_loads_well_formed_file(self, tmp_path):
        cfg = {
            "secrets": [
                {"name": "A", "last_rotated": "2026-01-01",
                 "rotation_days": 30, "services": ["api"]}
            ]
        }
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps(cfg))
        secrets = load_config(p)
        assert len(secrets) == 1
        assert secrets[0].name == "A"
        assert secrets[0].last_rotated == date(2026, 1, 1)

    def test_missing_file_raises_invalid_config(self, tmp_path):
        with pytest.raises(InvalidConfigError, match="not found"):
            load_config(tmp_path / "nope.json")

    def test_malformed_json_raises_invalid_config(self, tmp_path):
        p = tmp_path / "secrets.json"
        p.write_text("{ this isn't json")
        with pytest.raises(InvalidConfigError, match="invalid JSON"):
            load_config(p)

    def test_missing_required_field_raises_invalid_config(self, tmp_path):
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps({"secrets": [{"name": "A"}]}))
        with pytest.raises(InvalidConfigError, match="missing field"):
            load_config(p)

    def test_invalid_date_raises_invalid_config(self, tmp_path):
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps({"secrets": [
            {"name": "A", "last_rotated": "not-a-date",
             "rotation_days": 30, "services": []}
        ]}))
        with pytest.raises(InvalidConfigError, match="invalid date"):
            load_config(p)

    def test_non_positive_rotation_days_raises_invalid_config(self, tmp_path):
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps({"secrets": [
            {"name": "A", "last_rotated": "2026-01-01",
             "rotation_days": 0, "services": []}
        ]}))
        with pytest.raises(InvalidConfigError, match="rotation_days"):
            load_config(p)


# ---------- main() / CLI ----------

class TestCliMain:
    """`main(argv)` is the CLI entry point used by the GHA workflow."""

    def _write_fixture(self, tmp_path):
        cfg = {"secrets": [
            {"name": "DATABASE_PASSWORD", "last_rotated": "2026-01-01",
             "rotation_days": 30, "services": ["api", "worker"]},
            {"name": "API_KEY", "last_rotated": "2026-04-15",
             "rotation_days": 30, "services": ["public-api"]},
            {"name": "JWT_SECRET", "last_rotated": "2026-05-01",
             "rotation_days": 90, "services": ["auth"]},
        ]}
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps(cfg))
        return p

    def test_markdown_default(self, tmp_path, capsys):
        cfg = self._write_fixture(tmp_path)
        rc = main(["--config", str(cfg), "--reference-date", "2026-05-07",
                   "--warning-days", "14"])
        out = capsys.readouterr().out
        assert rc == 0
        assert "Total secrets: 3 (1 expired, 1 warning, 1 ok)" in out

    def test_json_format(self, tmp_path, capsys):
        cfg = self._write_fixture(tmp_path)
        rc = main(["--config", str(cfg), "--format", "json",
                   "--reference-date", "2026-05-07", "--warning-days", "14"])
        out = capsys.readouterr().out
        assert rc == 0
        parsed = json.loads(out)
        assert parsed["summary"] == {"total": 3, "expired": 1, "warning": 1, "ok": 1}

    def test_exit_code_2_when_secrets_expired(self, tmp_path):
        # Non-zero exit lets CI fail when an expired secret is detected.
        cfg = self._write_fixture(tmp_path)
        rc = main(["--config", str(cfg), "--reference-date", "2026-05-07",
                   "--warning-days", "14", "--strict"])
        assert rc == 2

    def test_exit_code_0_when_all_ok(self, tmp_path, capsys):
        cfg_data = {"secrets": [
            {"name": "S", "last_rotated": "2026-05-01",
             "rotation_days": 90, "services": ["s"]},
        ]}
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps(cfg_data))
        rc = main(["--config", str(p), "--reference-date", "2026-05-07",
                   "--warning-days", "14", "--strict"])
        assert rc == 0

    def test_invalid_config_returns_non_zero_with_message(self, tmp_path, capsys):
        rc = main(["--config", str(tmp_path / "missing.json"),
                   "--reference-date", "2026-05-07"])
        err = capsys.readouterr().err
        assert rc == 1
        assert "Error" in err
