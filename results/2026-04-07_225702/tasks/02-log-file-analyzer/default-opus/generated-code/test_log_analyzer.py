"""Tests for log file analyzer — written using red/green TDD methodology."""

import json
import os
import pytest
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent / "fixtures"


# ── TDD Round 1: Parse syslog-style lines ──────────────────────────────────

class TestParseSyslog:
    """First piece of functionality: extract level and message from syslog lines."""

    def test_parse_error_line(self):
        from log_analyzer import parse_syslog_line

        line = 'Mar 15 10:22:01 webserver01 nginx[1234]: ERROR: connection refused to upstream backend 10.0.1.5:8080'
        result = parse_syslog_line(line)
        assert result is not None
        assert result["level"] == "ERROR"
        assert result["message"] == "connection refused to upstream backend 10.0.1.5:8080"
        assert result["timestamp"] == "Mar 15 10:22:01"

    def test_parse_warning_line(self):
        from log_analyzer import parse_syslog_line

        line = 'Mar 15 10:22:05 webserver01 nginx[1234]: WARNING: upstream response time exceeded threshold (3.2s)'
        result = parse_syslog_line(line)
        assert result is not None
        assert result["level"] == "WARNING"
        assert result["message"] == "upstream response time exceeded threshold (3.2s)"

    def test_parse_info_line(self):
        from log_analyzer import parse_syslog_line

        line = 'Mar 15 10:26:00 webserver01 nginx[1234]: INFO: health check passed'
        result = parse_syslog_line(line)
        assert result is not None
        assert result["level"] == "INFO"

    def test_returns_none_for_non_syslog(self):
        from log_analyzer import parse_syslog_line

        line = '{"timestamp": "2026-03-15T10:24:00Z", "level": "ERROR"}'
        result = parse_syslog_line(line)
        assert result is None


# ── TDD Round 2: Parse JSON-structured lines ────────────────────────────────

class TestParseJsonLine:
    """Parse JSON log entries and extract level/message/timestamp."""

    def test_parse_json_error(self):
        from log_analyzer import parse_json_line

        line = '{"timestamp": "2026-03-15T10:24:00Z", "level": "ERROR", "service": "auth-api", "message": "connection refused"}'
        result = parse_json_line(line)
        assert result is not None
        assert result["level"] == "ERROR"
        assert result["message"] == "connection refused"
        assert result["timestamp"] == "2026-03-15T10:24:00Z"

    def test_parse_json_warning(self):
        from log_analyzer import parse_json_line

        line = '{"timestamp": "2026-03-15T10:27:00Z", "level": "WARNING", "service": "payment-svc", "message": "slow query"}'
        result = parse_json_line(line)
        assert result["level"] == "WARNING"

    def test_returns_none_for_syslog(self):
        from log_analyzer import parse_json_line

        line = 'Mar 15 10:22:01 webserver01 nginx[1234]: ERROR: something'
        result = parse_json_line(line)
        assert result is None

    def test_returns_none_for_missing_fields(self):
        from log_analyzer import parse_json_line

        line = '{"timestamp": "2026-03-15T10:24:00Z"}'
        result = parse_json_line(line)
        assert result is None


# ── TDD Round 3: Unified parser + file reader with error/warning filter ──────

class TestParseLogFile:
    """Parse a full log file and return only error/warning entries."""

    def test_parse_line_tries_both_formats(self):
        from log_analyzer import parse_line

        syslog = 'Mar 15 10:22:01 webserver01 nginx[1234]: ERROR: fail'
        assert parse_line(syslog)["level"] == "ERROR"

        jsonl = '{"timestamp": "2026-03-15T10:24:00Z", "level": "WARNING", "service": "x", "message": "slow"}'
        assert parse_line(jsonl)["level"] == "WARNING"

        assert parse_line("random garbage line") is None

    def test_parse_log_file_filters_errors_and_warnings(self):
        from log_analyzer import parse_log_file

        # The fixture has 12 lines total: 2 INFO lines should be excluded
        entries = parse_log_file(FIXTURES_DIR / "sample.log")
        levels = {e["level"] for e in entries}
        assert levels == {"ERROR", "WARNING"}
        # Fixture has 7 ERROR + 3 WARNING = 10 error/warning entries
        assert len(entries) == 10

    def test_parse_log_file_nonexistent(self):
        from log_analyzer import parse_log_file

        with pytest.raises(FileNotFoundError):
            parse_log_file(Path("/nonexistent/path.log"))

    def test_parse_log_file_empty(self, tmp_path):
        from log_analyzer import parse_log_file

        empty = tmp_path / "empty.log"
        empty.write_text("")
        assert parse_log_file(empty) == []


# ── TDD Round 4: Frequency table with first/last timestamps ─────────────────

class TestBuildFrequencyTable:
    """Build a frequency table keyed by error message, tracking count + timestamps."""

    def test_basic_frequency_table(self):
        from log_analyzer import build_frequency_table

        entries = [
            {"level": "ERROR", "message": "connection refused", "timestamp": "T1"},
            {"level": "ERROR", "message": "connection refused", "timestamp": "T3"},
            {"level": "WARNING", "message": "slow query", "timestamp": "T2"},
        ]
        table = build_frequency_table(entries)
        assert len(table) == 2
        assert table["connection refused"]["count"] == 2
        assert table["connection refused"]["level"] == "ERROR"
        assert table["connection refused"]["first_seen"] == "T1"
        assert table["connection refused"]["last_seen"] == "T3"
        assert table["slow query"]["count"] == 1
        assert table["slow query"]["first_seen"] == "T2"
        assert table["slow query"]["last_seen"] == "T2"

    def test_empty_entries(self):
        from log_analyzer import build_frequency_table

        assert build_frequency_table([]) == {}

    def test_fixture_file_frequency(self):
        """Integration test: frequency table from the sample fixture."""
        from log_analyzer import parse_log_file, build_frequency_table

        entries = parse_log_file(FIXTURES_DIR / "sample.log")
        table = build_frequency_table(entries)
        # "connection refused to upstream backend 10.0.1.5:8080" appears 3 times
        conn_err = table["connection refused to upstream backend 10.0.1.5:8080"]
        assert conn_err["count"] == 3
        assert conn_err["level"] == "ERROR"
        # "timeout waiting for database connection" appears 2 times
        assert table["timeout waiting for database connection"]["count"] == 2


# ── TDD Round 5: Output formatting — table string and JSON export ────────────

class TestOutputFormatting:
    """Format the frequency table as a human-readable string and write JSON."""

    def test_format_table_string(self):
        from log_analyzer import format_table

        table = {
            "connection refused": {
                "level": "ERROR", "count": 3,
                "first_seen": "T1", "last_seen": "T5",
            },
            "slow query": {
                "level": "WARNING", "count": 1,
                "first_seen": "T2", "last_seen": "T2",
            },
        }
        output = format_table(table)
        # Should contain header and both rows
        assert "connection refused" in output
        assert "slow query" in output
        assert "ERROR" in output
        assert "WARNING" in output
        # Count should appear
        assert "3" in output
        assert "1" in output

    def test_format_table_sorted_by_count_desc(self):
        from log_analyzer import format_table

        table = {
            "rare error": {"level": "ERROR", "count": 1, "first_seen": "T1", "last_seen": "T1"},
            "common error": {"level": "ERROR", "count": 10, "first_seen": "T1", "last_seen": "T9"},
        }
        output = format_table(table)
        # "common error" (count=10) should appear before "rare error" (count=1)
        assert output.index("common error") < output.index("rare error")

    def test_write_json_report(self, tmp_path):
        from log_analyzer import write_json_report

        table = {
            "err1": {"level": "ERROR", "count": 2, "first_seen": "T1", "last_seen": "T2"},
        }
        out_path = tmp_path / "report.json"
        write_json_report(table, out_path)
        data = json.loads(out_path.read_text())
        assert len(data["errors"]) == 1
        assert data["errors"][0]["message"] == "err1"
        assert data["errors"][0]["count"] == 2
        assert "total_entries" in data["summary"]


# ── TDD Round 6: CLI end-to-end integration ──────────────────────────────────

class TestCLI:
    """Test the main() CLI entry point end-to-end."""

    def test_analyze_fixture_produces_both_outputs(self, tmp_path, capsys):
        from log_analyzer import analyze

        json_out = tmp_path / "report.json"
        analyze(FIXTURES_DIR / "sample.log", json_out)

        # Human-readable table was printed to stdout
        captured = capsys.readouterr().out
        assert "connection refused" in captured
        assert "ERROR" in captured

        # JSON report was written
        assert json_out.exists()
        data = json.loads(json_out.read_text())
        assert data["summary"]["total_entries"] == 10
        assert data["summary"]["unique_messages"] == 5

    def test_cli_missing_file(self, capsys):
        """Graceful error message for missing files instead of a traceback."""
        from log_analyzer import analyze

        with pytest.raises(SystemExit):
            analyze(Path("/does/not/exist.log"), Path("/tmp/out.json"))

    def test_cli_empty_file(self, tmp_path, capsys):
        from log_analyzer import analyze

        empty = tmp_path / "empty.log"
        empty.write_text("")
        json_out = tmp_path / "report.json"
        analyze(empty, json_out)

        captured = capsys.readouterr().out
        assert "No errors or warnings found" in captured
