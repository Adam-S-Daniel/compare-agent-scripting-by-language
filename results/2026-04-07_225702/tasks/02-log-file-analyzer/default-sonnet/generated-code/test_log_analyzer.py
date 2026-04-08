# Log File Analyzer - Test Suite (TDD)
#
# Approach: Red-green TDD cycles.
# Each test group covers one piece of functionality.
# Tests are written first (failing), then the minimum implementation
# is added to make them pass.
#
# Log formats supported:
#   Syslog: "Jan 15 10:23:45 hostname process[pid]: LEVEL: message"
#   JSON:   {"timestamp": "...", "level": "...", "type": "...", "message": "..."}

import json
import os
import pytest
from log_analyzer import (
    parse_syslog_line,
    parse_json_line,
    parse_log_file,
    filter_errors_and_warnings,
    build_frequency_table,
    format_table,
    write_json_report,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SYSLOG_ERROR = "Jan 15 10:23:45 myhost myapp[1234]: ERROR: DBConnectionError: could not connect to database"
SYSLOG_WARNING = "Feb  3 08:01:12 myhost nginx[5678]: WARNING: slow response time 5.2s"
SYSLOG_INFO = "Mar 20 14:55:00 myhost myapp[9999]: INFO: server started on port 8080"

JSON_ERROR = '{"timestamp": "2024-01-15T10:23:45", "level": "ERROR", "type": "DBConnectionError", "message": "could not connect"}'
JSON_WARNING = '{"timestamp": "2024-02-03T08:01:12", "level": "WARNING", "type": "SlowResponse", "message": "response took 5.2s"}'
JSON_INFO = '{"timestamp": "2024-03-20T14:55:00", "level": "INFO", "type": "ServerStart", "message": "server started"}'
MALFORMED_LINE = "this is not a valid log line at all"


# ===========================================================================
# CYCLE 1: parse_syslog_line
# ===========================================================================

class TestParseSyslogLine:
    """RED: these tests fail until parse_syslog_line is implemented."""

    def test_parses_error_level(self):
        result = parse_syslog_line(SYSLOG_ERROR)
        assert result is not None
        assert result["level"] == "ERROR"

    def test_parses_warning_level(self):
        result = parse_syslog_line(SYSLOG_WARNING)
        assert result is not None
        assert result["level"] == "WARNING"

    def test_parses_info_level(self):
        result = parse_syslog_line(SYSLOG_INFO)
        assert result is not None
        assert result["level"] == "INFO"

    def test_parses_error_type(self):
        # For syslog, the error type is the first word after "LEVEL: "
        result = parse_syslog_line(SYSLOG_ERROR)
        assert result["type"] == "DBConnectionError"

    def test_parses_timestamp(self):
        result = parse_syslog_line(SYSLOG_ERROR)
        # Timestamp should contain the date portion
        assert "Jan" in result["timestamp"] or "2024" in result["timestamp"]

    def test_parses_message(self):
        result = parse_syslog_line(SYSLOG_ERROR)
        assert "could not connect" in result["message"]

    def test_returns_none_for_malformed_line(self):
        result = parse_syslog_line(MALFORMED_LINE)
        assert result is None

    def test_returns_none_for_empty_line(self):
        assert parse_syslog_line("") is None
        assert parse_syslog_line("   ") is None


# ===========================================================================
# CYCLE 2: parse_json_line
# ===========================================================================

class TestParseJsonLine:
    """RED: these tests fail until parse_json_line is implemented."""

    def test_parses_error_level(self):
        result = parse_json_line(JSON_ERROR)
        assert result is not None
        assert result["level"] == "ERROR"

    def test_parses_warning_level(self):
        result = parse_json_line(JSON_WARNING)
        assert result is not None
        assert result["level"] == "WARNING"

    def test_parses_type(self):
        result = parse_json_line(JSON_ERROR)
        assert result["type"] == "DBConnectionError"

    def test_parses_timestamp(self):
        result = parse_json_line(JSON_ERROR)
        assert result["timestamp"] == "2024-01-15T10:23:45"

    def test_parses_message(self):
        result = parse_json_line(JSON_ERROR)
        assert "could not connect" in result["message"]

    def test_returns_none_for_non_json(self):
        result = parse_json_line(MALFORMED_LINE)
        assert result is None

    def test_returns_none_for_json_missing_level(self):
        # JSON line without a "level" key is not a valid log entry
        result = parse_json_line('{"message": "hello"}')
        assert result is None


# ===========================================================================
# CYCLE 3: parse_log_file — handles mixed format lines
# ===========================================================================

class TestParseLogFile:
    """RED: these tests fail until parse_log_file is implemented."""

    def test_parses_mixed_content(self, tmp_path):
        log_file = tmp_path / "mixed.log"
        log_file.write_text(
            "\n".join([SYSLOG_ERROR, JSON_WARNING, SYSLOG_INFO, MALFORMED_LINE, ""])
        )
        entries = parse_log_file(str(log_file))
        assert len(entries) == 3  # malformed and empty lines skipped

    def test_raises_on_missing_file(self):
        with pytest.raises(FileNotFoundError):
            parse_log_file("/nonexistent/path/to/file.log")

    def test_all_entries_have_required_keys(self, tmp_path):
        log_file = tmp_path / "test.log"
        log_file.write_text("\n".join([SYSLOG_ERROR, JSON_ERROR]))
        entries = parse_log_file(str(log_file))
        for entry in entries:
            assert "level" in entry
            assert "type" in entry
            assert "timestamp" in entry
            assert "message" in entry


# ===========================================================================
# CYCLE 4: filter_errors_and_warnings
# ===========================================================================

class TestFilterErrorsAndWarnings:
    """RED: these tests fail until filter_errors_and_warnings is implemented."""

    def _make_entries(self):
        return [
            {"level": "ERROR",   "type": "DBError",     "timestamp": "T1", "message": "m1"},
            {"level": "WARNING", "type": "SlowResp",    "timestamp": "T2", "message": "m2"},
            {"level": "INFO",    "type": "ServerStart", "timestamp": "T3", "message": "m3"},
            {"level": "DEBUG",   "type": "QueryTrace",  "timestamp": "T4", "message": "m4"},
            {"level": "ERROR",   "type": "DBError",     "timestamp": "T5", "message": "m5"},
        ]

    def test_keeps_errors(self):
        result = filter_errors_and_warnings(self._make_entries())
        levels = [e["level"] for e in result]
        assert "ERROR" in levels

    def test_keeps_warnings(self):
        result = filter_errors_and_warnings(self._make_entries())
        levels = [e["level"] for e in result]
        assert "WARNING" in levels

    def test_drops_info(self):
        result = filter_errors_and_warnings(self._make_entries())
        levels = [e["level"] for e in result]
        assert "INFO" not in levels

    def test_drops_debug(self):
        result = filter_errors_and_warnings(self._make_entries())
        levels = [e["level"] for e in result]
        assert "DEBUG" not in levels

    def test_count(self):
        result = filter_errors_and_warnings(self._make_entries())
        assert len(result) == 3  # 2 ERRORs + 1 WARNING

    def test_empty_input(self):
        assert filter_errors_and_warnings([]) == []


# ===========================================================================
# CYCLE 5: build_frequency_table
# ===========================================================================

class TestBuildFrequencyTable:
    """RED: these tests fail until build_frequency_table is implemented."""

    def _make_entries(self):
        return [
            {"level": "ERROR",   "type": "DBError",   "timestamp": "2024-01-01T00:00:00", "message": "a"},
            {"level": "WARNING", "type": "SlowResp",  "timestamp": "2024-01-02T00:00:00", "message": "b"},
            {"level": "ERROR",   "type": "DBError",   "timestamp": "2024-01-03T00:00:00", "message": "c"},
            {"level": "ERROR",   "type": "DBError",   "timestamp": "2024-01-04T00:00:00", "message": "d"},
        ]

    def test_returns_list(self):
        table = build_frequency_table(self._make_entries())
        assert isinstance(table, list)

    def test_correct_number_of_unique_types(self):
        table = build_frequency_table(self._make_entries())
        # DBError and SlowResp
        assert len(table) == 2

    def test_dbError_count(self):
        table = build_frequency_table(self._make_entries())
        db_row = next(r for r in table if r["type"] == "DBError")
        assert db_row["count"] == 3

    def test_first_occurrence(self):
        table = build_frequency_table(self._make_entries())
        db_row = next(r for r in table if r["type"] == "DBError")
        assert db_row["first_seen"] == "2024-01-01T00:00:00"

    def test_last_occurrence(self):
        table = build_frequency_table(self._make_entries())
        db_row = next(r for r in table if r["type"] == "DBError")
        assert db_row["last_seen"] == "2024-01-04T00:00:00"

    def test_level_recorded(self):
        table = build_frequency_table(self._make_entries())
        db_row = next(r for r in table if r["type"] == "DBError")
        assert db_row["level"] == "ERROR"

    def test_sorted_by_count_descending(self):
        table = build_frequency_table(self._make_entries())
        counts = [r["count"] for r in table]
        assert counts == sorted(counts, reverse=True)

    def test_empty_input(self):
        assert build_frequency_table([]) == []


# ===========================================================================
# CYCLE 6: format_table (human-readable output)
# ===========================================================================

class TestFormatTable:
    """RED: these tests fail until format_table is implemented."""

    def _make_table(self):
        return [
            {"type": "DBError",  "level": "ERROR",   "count": 3,
             "first_seen": "2024-01-01T00:00:00", "last_seen": "2024-01-04T00:00:00"},
            {"type": "SlowResp", "level": "WARNING", "count": 1,
             "first_seen": "2024-01-02T00:00:00", "last_seen": "2024-01-02T00:00:00"},
        ]

    def test_returns_string(self):
        output = format_table(self._make_table())
        assert isinstance(output, str)

    def test_contains_header(self):
        output = format_table(self._make_table())
        # Header should label the columns
        assert "Type" in output or "type" in output.lower()
        assert "Count" in output or "count" in output.lower()

    def test_contains_error_type(self):
        output = format_table(self._make_table())
        assert "DBError" in output

    def test_contains_count(self):
        output = format_table(self._make_table())
        assert "3" in output

    def test_contains_timestamps(self):
        output = format_table(self._make_table())
        assert "2024-01-01" in output

    def test_empty_table(self):
        output = format_table([])
        assert isinstance(output, str)
        # Should still produce some output (e.g. header + "no entries" message)
        assert len(output) > 0


# ===========================================================================
# CYCLE 7: write_json_report
# ===========================================================================

class TestWriteJsonReport:
    """RED: these tests fail until write_json_report is implemented."""

    def _make_table(self):
        return [
            {"type": "DBError",  "level": "ERROR",   "count": 3,
             "first_seen": "2024-01-01T00:00:00", "last_seen": "2024-01-04T00:00:00"},
        ]

    def test_creates_file(self, tmp_path):
        out_path = str(tmp_path / "report.json")
        write_json_report(self._make_table(), out_path)
        assert os.path.exists(out_path)

    def test_valid_json(self, tmp_path):
        out_path = str(tmp_path / "report.json")
        write_json_report(self._make_table(), out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert isinstance(data, list)

    def test_json_preserves_count(self, tmp_path):
        out_path = str(tmp_path / "report.json")
        write_json_report(self._make_table(), out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert data[0]["count"] == 3

    def test_json_preserves_type(self, tmp_path):
        out_path = str(tmp_path / "report.json")
        write_json_report(self._make_table(), out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert data[0]["type"] == "DBError"

    def test_raises_on_unwritable_path(self):
        with pytest.raises(Exception):
            write_json_report(self._make_table(), "/nonexistent_dir/report.json")


# ===========================================================================
# CYCLE 8: End-to-end integration test using the sample fixture
# ===========================================================================

class TestEndToEnd:
    """Integration tests that run the full pipeline against fixtures/sample.log."""

    FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "sample.log")

    def test_fixture_file_exists(self):
        assert os.path.exists(self.FIXTURE), f"Fixture missing: {self.FIXTURE}"

    def test_parses_without_error(self):
        entries = parse_log_file(self.FIXTURE)
        assert len(entries) > 0

    def test_malformed_lines_skipped(self):
        # The fixture has comment lines, a plain malformed line, and JSON missing "level"
        # All valid entries should be parsed; junk lines silently dropped
        entries = parse_log_file(self.FIXTURE)
        for e in entries:
            assert "level" in e

    def test_errors_and_warnings_found(self):
        entries = parse_log_file(self.FIXTURE)
        filtered = filter_errors_and_warnings(entries)
        assert len(filtered) > 0

    def test_dbconnection_error_appears_multiple_times(self):
        entries = parse_log_file(self.FIXTURE)
        filtered = filter_errors_and_warnings(entries)
        table = build_frequency_table(filtered)
        db_rows = [r for r in table if r["type"] == "DBConnectionError"]
        assert len(db_rows) == 1
        assert db_rows[0]["count"] >= 5  # fixture has several DBConnectionError lines

    def test_table_sorted_by_count(self):
        entries = parse_log_file(self.FIXTURE)
        filtered = filter_errors_and_warnings(entries)
        table = build_frequency_table(filtered)
        counts = [r["count"] for r in table]
        assert counts == sorted(counts, reverse=True)

    def test_full_pipeline_json_output(self, tmp_path):
        entries = parse_log_file(self.FIXTURE)
        filtered = filter_errors_and_warnings(entries)
        table = build_frequency_table(filtered)
        out_path = str(tmp_path / "report.json")
        write_json_report(table, out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert isinstance(data, list)
        assert len(data) > 0
        # Every row must have the required keys
        for row in data:
            assert "type" in row
            assert "count" in row
            assert "first_seen" in row
            assert "last_seen" in row

    def test_full_pipeline_human_readable(self):
        entries = parse_log_file(self.FIXTURE)
        filtered = filter_errors_and_warnings(entries)
        table = build_frequency_table(filtered)
        output = format_table(table)
        assert "DBConnectionError" in output
        assert "Type" in output
