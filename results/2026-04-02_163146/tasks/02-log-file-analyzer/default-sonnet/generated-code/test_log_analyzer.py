# Test suite for log_analyzer.py using red/green TDD.
# We write each test before the implementation exists, run it to confirm it
# fails (RED), then implement the minimum code to make it pass (GREEN).

import json
import os
import tempfile
from datetime import datetime

import pytest

# The module under test — does not exist yet when we write the first test.
from log_analyzer import (
    parse_syslog_line,
    parse_json_line,
    parse_log_file,
    extract_errors_warnings,
    build_frequency_table,
    format_table,
    write_json_report,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SYSLOG_LINES = [
    # Standard syslog format: Mon DD HH:MM:SS host service[pid]: LEVEL message
    "Jan 15 10:23:45 webhost nginx[1234]: ERROR Connection refused to upstream",
    "Jan 15 10:23:46 webhost nginx[1234]: WARNING Slow response: 2.1s",
    "Jan 15 10:23:47 webhost nginx[1234]: INFO Request completed in 0.1s",
    "Jan 15 10:24:00 webhost nginx[1235]: ERROR Connection refused to upstream",
    "Jan 15 10:25:00 webhost sshd[999]: ERROR Authentication failure for user root",
]

JSON_LINES = [
    '{"timestamp": "2024-01-15T10:23:45Z", "level": "ERROR", "service": "api", "message": "Database timeout", "error_type": "DatabaseError"}',
    '{"timestamp": "2024-01-15T10:23:50Z", "level": "WARNING", "service": "api", "message": "Cache miss rate high", "error_type": "CacheWarning"}',
    '{"timestamp": "2024-01-15T10:24:00Z", "level": "INFO", "service": "api", "message": "Request processed", "error_type": null}',
    '{"timestamp": "2024-01-15T10:25:00Z", "level": "ERROR", "service": "api", "message": "Database timeout", "error_type": "DatabaseError"}',
]

MIXED_LOG = "\n".join([
    SYSLOG_LINES[0],
    JSON_LINES[0],
    SYSLOG_LINES[1],
    JSON_LINES[1],
    SYSLOG_LINES[2],  # INFO — should be excluded
    JSON_LINES[2],    # INFO — should be excluded
    SYSLOG_LINES[3],
    JSON_LINES[3],
    SYSLOG_LINES[4],
])


# ===========================================================================
# RED/GREEN CYCLE 1 — Syslog line parser
# ===========================================================================

class TestParseSyslogLine:
    """parse_syslog_line(line) -> dict | None
    Returns a dict with keys: timestamp, level, service, message, raw.
    Returns None for lines that don't match the syslog pattern.
    """

    def test_parses_error_line(self):
        result = parse_syslog_line(
            "Jan 15 10:23:45 webhost nginx[1234]: ERROR Connection refused"
        )
        assert result is not None
        assert result["level"] == "ERROR"
        assert result["service"] == "nginx"
        assert result["message"] == "Connection refused"
        assert isinstance(result["timestamp"], datetime)

    def test_parses_warning_line(self):
        result = parse_syslog_line(
            "Jan 15 10:23:46 webhost nginx[1234]: WARNING Slow response: 2.1s"
        )
        assert result is not None
        assert result["level"] == "WARNING"
        assert result["message"] == "Slow response: 2.1s"

    def test_parses_info_line(self):
        result = parse_syslog_line(
            "Jan 15 10:23:47 webhost nginx[1234]: INFO Request completed"
        )
        assert result is not None
        assert result["level"] == "INFO"

    def test_returns_none_for_non_syslog(self):
        # JSON lines should not match the syslog pattern
        result = parse_syslog_line(
            '{"timestamp": "2024-01-15T10:23:45Z", "level": "ERROR"}'
        )
        assert result is None

    def test_returns_none_for_blank_line(self):
        assert parse_syslog_line("") is None

    def test_timestamp_uses_current_year(self):
        # Syslog omits the year; we default to the current year
        result = parse_syslog_line(
            "Jan 15 10:23:45 webhost sshd[999]: ERROR Auth failure"
        )
        assert result["timestamp"].year == datetime.now().year


# ===========================================================================
# RED/GREEN CYCLE 2 — JSON line parser
# ===========================================================================

class TestParseJsonLine:
    """parse_json_line(line) -> dict | None
    Returns a normalised dict (same shape as syslog result) or None.
    """

    def test_parses_error_json(self):
        line = '{"timestamp": "2024-01-15T10:23:45Z", "level": "ERROR", "service": "api", "message": "Database timeout", "error_type": "DatabaseError"}'
        result = parse_json_line(line)
        assert result is not None
        assert result["level"] == "ERROR"
        assert result["service"] == "api"
        assert result["message"] == "Database timeout"
        assert result["error_type"] == "DatabaseError"
        assert isinstance(result["timestamp"], datetime)

    def test_parses_warning_json(self):
        line = '{"timestamp": "2024-01-15T10:23:50Z", "level": "WARNING", "service": "api", "message": "Cache miss", "error_type": "CacheWarning"}'
        result = parse_json_line(line)
        assert result is not None
        assert result["level"] == "WARNING"

    def test_returns_none_for_non_json(self):
        result = parse_json_line("Jan 15 10:23:45 webhost nginx[1234]: ERROR foo")
        assert result is None

    def test_returns_none_for_invalid_json(self):
        result = parse_json_line("{not valid json}")
        assert result is None

    def test_handles_null_error_type(self):
        line = '{"timestamp": "2024-01-15T10:24:00Z", "level": "INFO", "service": "api", "message": "ok", "error_type": null}'
        result = parse_json_line(line)
        assert result is not None
        assert result["error_type"] is None


# ===========================================================================
# RED/GREEN CYCLE 3 — Mixed-format log file parser
# ===========================================================================

class TestParseLogFile:
    """parse_log_file(path) -> list[dict]
    Reads a file, tries each line as JSON then syslog, skips unparseable lines.
    """

    def test_parses_mixed_file(self, tmp_path):
        log_file = tmp_path / "test.log"
        log_file.write_text(MIXED_LOG)
        entries = parse_log_file(str(log_file))
        # MIXED_LOG has 9 lines, all parseable
        assert len(entries) == 9

    def test_raises_on_missing_file(self):
        with pytest.raises(FileNotFoundError):
            parse_log_file("/nonexistent/path/to/log.txt")

    def test_skips_blank_lines(self, tmp_path):
        log_file = tmp_path / "test.log"
        log_file.write_text("\n".join(SYSLOG_LINES) + "\n\n")
        entries = parse_log_file(str(log_file))
        assert len(entries) == len(SYSLOG_LINES)


# ===========================================================================
# RED/GREEN CYCLE 4 — Error/warning extraction
# ===========================================================================

class TestExtractErrorsWarnings:
    """extract_errors_warnings(entries) -> list[dict]
    Returns only entries where level is ERROR or WARNING.
    """

    def test_filters_info_out(self):
        entries = [
            {"level": "ERROR", "message": "boom"},
            {"level": "WARNING", "message": "watch out"},
            {"level": "INFO", "message": "all good"},
            {"level": "DEBUG", "message": "verbose"},
        ]
        result = extract_errors_warnings(entries)
        assert len(result) == 2
        assert all(e["level"] in ("ERROR", "WARNING") for e in result)

    def test_returns_empty_for_empty_input(self):
        assert extract_errors_warnings([]) == []

    def test_preserves_all_fields(self):
        entry = {"level": "ERROR", "message": "boom", "service": "svc", "timestamp": datetime.now()}
        result = extract_errors_warnings([entry])
        assert result[0] == entry


# ===========================================================================
# RED/GREEN CYCLE 5 — Frequency table builder
# ===========================================================================

class TestBuildFrequencyTable:
    """build_frequency_table(entries) -> list[dict]
    Groups by (level, error_key) where error_key is:
      - error_type field if present and non-null
      - otherwise the first ~60 chars of the message
    Returns list of dicts with: error_key, level, count, first_seen, last_seen.
    Sorted by count descending.
    """

    def _make_entry(self, level, message, error_type=None, ts=None):
        return {
            "level": level,
            "message": message,
            "error_type": error_type,
            "timestamp": ts or datetime(2024, 1, 15, 10, 0, 0),
            "service": "test",
        }

    def test_counts_identical_errors(self):
        entries = [
            self._make_entry("ERROR", "DB timeout", "DatabaseError", datetime(2024, 1, 15, 10, 0)),
            self._make_entry("ERROR", "DB timeout", "DatabaseError", datetime(2024, 1, 15, 11, 0)),
            self._make_entry("ERROR", "DB timeout", "DatabaseError", datetime(2024, 1, 15, 12, 0)),
        ]
        table = build_frequency_table(entries)
        assert len(table) == 1
        assert table[0]["count"] == 3

    def test_tracks_first_and_last_seen(self):
        t1 = datetime(2024, 1, 15, 10, 0)
        t2 = datetime(2024, 1, 15, 11, 0)
        t3 = datetime(2024, 1, 15, 12, 0)
        entries = [
            self._make_entry("ERROR", "DB timeout", "DatabaseError", t2),
            self._make_entry("ERROR", "DB timeout", "DatabaseError", t1),
            self._make_entry("ERROR", "DB timeout", "DatabaseError", t3),
        ]
        table = build_frequency_table(entries)
        assert table[0]["first_seen"] == t1
        assert table[0]["last_seen"] == t3

    def test_separates_different_error_types(self):
        entries = [
            self._make_entry("ERROR", "DB timeout", "DatabaseError"),
            self._make_entry("ERROR", "Auth fail", "AuthError"),
        ]
        table = build_frequency_table(entries)
        assert len(table) == 2

    def test_sorted_by_count_descending(self):
        entries = [
            self._make_entry("ERROR", "DB timeout", "DatabaseError"),
            self._make_entry("WARNING", "Cache miss", "CacheWarning"),
            self._make_entry("WARNING", "Cache miss", "CacheWarning"),
            self._make_entry("WARNING", "Cache miss", "CacheWarning"),
        ]
        table = build_frequency_table(entries)
        assert table[0]["count"] == 3  # CacheWarning first
        assert table[1]["count"] == 1

    def test_uses_message_when_no_error_type(self):
        entries = [
            self._make_entry("ERROR", "Connection refused to upstream"),
            self._make_entry("ERROR", "Connection refused to upstream"),
        ]
        table = build_frequency_table(entries)
        assert len(table) == 1
        assert table[0]["count"] == 2
        assert "Connection refused" in table[0]["error_key"]

    def test_separates_error_and_warning_same_key(self):
        """Same error_type but different level → separate rows."""
        entries = [
            self._make_entry("ERROR", "Disk space low", "DiskWarning"),
            self._make_entry("WARNING", "Disk space low", "DiskWarning"),
        ]
        table = build_frequency_table(entries)
        assert len(table) == 2


# ===========================================================================
# RED/GREEN CYCLE 6 — Human-readable table formatter
# ===========================================================================

class TestFormatTable:
    """format_table(table_rows) -> str
    Returns a plain-text table with columns:
    Error Key | Level | Count | First Seen | Last Seen
    """

    def _make_row(self, key, level, count, first, last):
        return {
            "error_key": key,
            "level": level,
            "count": count,
            "first_seen": first,
            "last_seen": last,
        }

    def test_output_contains_headers(self):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024, 1, 15, 10, 0),
                               datetime(2024, 1, 15, 12, 0))]
        output = format_table(rows)
        assert "Error Key" in output
        assert "Level" in output
        assert "Count" in output
        assert "First Seen" in output
        assert "Last Seen" in output

    def test_output_contains_row_data(self):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024, 1, 15, 10, 0),
                               datetime(2024, 1, 15, 12, 0))]
        output = format_table(rows)
        assert "DatabaseError" in output
        assert "ERROR" in output
        assert "3" in output

    def test_empty_table_returns_no_entries_message(self):
        output = format_table([])
        assert "no entries" in output.lower() or output.strip() == ""


# ===========================================================================
# RED/GREEN CYCLE 7 — JSON report writer
# ===========================================================================

class TestWriteJsonReport:
    """write_json_report(table_rows, path) -> None
    Writes a JSON file with analysis results including metadata.
    """

    def _make_row(self, key, level, count, first, last):
        return {
            "error_key": key,
            "level": level,
            "count": count,
            "first_seen": first,
            "last_seen": last,
        }

    def test_creates_json_file(self, tmp_path):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024, 1, 15, 10, 0),
                               datetime(2024, 1, 15, 12, 0))]
        out_path = str(tmp_path / "report.json")
        write_json_report(rows, out_path)
        assert os.path.exists(out_path)

    def test_json_is_valid(self, tmp_path):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024, 1, 15, 10, 0),
                               datetime(2024, 1, 15, 12, 0))]
        out_path = str(tmp_path / "report.json")
        write_json_report(rows, out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert isinstance(data, dict)

    def test_json_contains_entries(self, tmp_path):
        rows = [
            self._make_row("DatabaseError", "ERROR", 3,
                           datetime(2024, 1, 15, 10, 0),
                           datetime(2024, 1, 15, 12, 0)),
            self._make_row("CacheWarning", "WARNING", 1,
                           datetime(2024, 1, 15, 10, 30),
                           datetime(2024, 1, 15, 10, 30)),
        ]
        out_path = str(tmp_path / "report.json")
        write_json_report(rows, out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert "entries" in data
        assert len(data["entries"]) == 2

    def test_json_timestamps_are_strings(self, tmp_path):
        """datetime objects must be serialised as ISO strings."""
        rows = [self._make_row("DatabaseError", "ERROR", 1,
                               datetime(2024, 1, 15, 10, 0),
                               datetime(2024, 1, 15, 10, 0))]
        out_path = str(tmp_path / "report.json")
        write_json_report(rows, out_path)
        with open(out_path) as f:
            data = json.load(f)
        entry = data["entries"][0]
        assert isinstance(entry["first_seen"], str)
        assert isinstance(entry["last_seen"], str)

    def test_json_contains_metadata(self, tmp_path):
        """Report should include a generated_at timestamp and total_entries."""
        rows = [self._make_row("DatabaseError", "ERROR", 2,
                               datetime(2024, 1, 15, 10, 0),
                               datetime(2024, 1, 15, 11, 0))]
        out_path = str(tmp_path / "report.json")
        write_json_report(rows, out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert "generated_at" in data
        assert "total_entries" in data
        assert data["total_entries"] == 1

    def test_raises_on_unwritable_path(self):
        with pytest.raises((OSError, FileNotFoundError, PermissionError)):
            write_json_report([], "/nonexistent_dir/report.json")
