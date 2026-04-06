#!/usr/bin/env python3
"""Standalone test runner using unittest (no pytest required)."""
import sys
import os
import json
import tempfile
import unittest
from datetime import datetime

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from log_analyzer import (
    parse_syslog_line,
    parse_json_line,
    parse_log_file,
    extract_errors_warnings,
    build_frequency_table,
    format_table,
    write_json_report,
)

SYSLOG_LINES = [
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


class TestParseSyslogLine(unittest.TestCase):
    def test_parses_error_line(self):
        r = parse_syslog_line("Jan 15 10:23:45 webhost nginx[1234]: ERROR Connection refused")
        self.assertIsNotNone(r)
        self.assertEqual(r["level"], "ERROR")
        self.assertEqual(r["service"], "nginx")
        self.assertEqual(r["message"], "Connection refused")
        self.assertIsInstance(r["timestamp"], datetime)

    def test_parses_warning_line(self):
        r = parse_syslog_line("Jan 15 10:23:46 webhost nginx[1234]: WARNING Slow response: 2.1s")
        self.assertIsNotNone(r)
        self.assertEqual(r["level"], "WARNING")
        self.assertEqual(r["message"], "Slow response: 2.1s")

    def test_parses_info_line(self):
        r = parse_syslog_line("Jan 15 10:23:47 webhost nginx[1234]: INFO Request completed")
        self.assertIsNotNone(r)
        self.assertEqual(r["level"], "INFO")

    def test_returns_none_for_non_syslog(self):
        r = parse_syslog_line('{"timestamp": "2024-01-15T10:23:45Z", "level": "ERROR"}')
        self.assertIsNone(r)

    def test_returns_none_for_blank_line(self):
        self.assertIsNone(parse_syslog_line(""))

    def test_timestamp_uses_current_year(self):
        r = parse_syslog_line("Jan 15 10:23:45 webhost sshd[999]: ERROR Auth failure")
        self.assertEqual(r["timestamp"].year, datetime.now().year)


class TestParseJsonLine(unittest.TestCase):
    def test_parses_error_json(self):
        line = '{"timestamp": "2024-01-15T10:23:45Z", "level": "ERROR", "service": "api", "message": "Database timeout", "error_type": "DatabaseError"}'
        r = parse_json_line(line)
        self.assertIsNotNone(r)
        self.assertEqual(r["level"], "ERROR")
        self.assertEqual(r["service"], "api")
        self.assertEqual(r["message"], "Database timeout")
        self.assertEqual(r["error_type"], "DatabaseError")
        self.assertIsInstance(r["timestamp"], datetime)

    def test_parses_warning_json(self):
        line = '{"timestamp": "2024-01-15T10:23:50Z", "level": "WARNING", "service": "api", "message": "Cache miss", "error_type": "CacheWarning"}'
        r = parse_json_line(line)
        self.assertIsNotNone(r)
        self.assertEqual(r["level"], "WARNING")

    def test_returns_none_for_non_json(self):
        r = parse_json_line("Jan 15 10:23:45 webhost nginx[1234]: ERROR foo")
        self.assertIsNone(r)

    def test_returns_none_for_invalid_json(self):
        r = parse_json_line("{not valid json}")
        self.assertIsNone(r)

    def test_handles_null_error_type(self):
        line = '{"timestamp": "2024-01-15T10:24:00Z", "level": "INFO", "service": "api", "message": "ok", "error_type": null}'
        r = parse_json_line(line)
        self.assertIsNotNone(r)
        self.assertIsNone(r["error_type"])


class TestParseLogFile(unittest.TestCase):
    def test_parses_mixed_file(self):
        mixed = "\n".join([
            SYSLOG_LINES[0], JSON_LINES[0], SYSLOG_LINES[1], JSON_LINES[1],
            SYSLOG_LINES[2], JSON_LINES[2], SYSLOG_LINES[3],
            JSON_LINES[3].replace("None", "null"), SYSLOG_LINES[4],
        ])
        with tempfile.NamedTemporaryFile(mode="w", suffix=".log", delete=False) as f:
            f.write(mixed)
            fname = f.name
        try:
            entries = parse_log_file(fname)
            self.assertEqual(len(entries), 9)
        finally:
            os.unlink(fname)

    def test_raises_on_missing_file(self):
        with self.assertRaises(FileNotFoundError):
            parse_log_file("/nonexistent/path/to/log.txt")

    def test_skips_blank_lines(self):
        content = "\n".join(SYSLOG_LINES) + "\n\n"
        with tempfile.NamedTemporaryFile(mode="w", suffix=".log", delete=False) as f:
            f.write(content)
            fname = f.name
        try:
            entries = parse_log_file(fname)
            self.assertEqual(len(entries), len(SYSLOG_LINES))
        finally:
            os.unlink(fname)


class TestExtractErrorsWarnings(unittest.TestCase):
    def test_filters_info_out(self):
        entries = [
            {"level": "ERROR", "message": "boom"},
            {"level": "WARNING", "message": "watch out"},
            {"level": "INFO", "message": "all good"},
            {"level": "DEBUG", "message": "verbose"},
        ]
        result = extract_errors_warnings(entries)
        self.assertEqual(len(result), 2)
        for e in result:
            self.assertIn(e["level"], ("ERROR", "WARNING"))

    def test_returns_empty_for_empty_input(self):
        self.assertEqual(extract_errors_warnings([]), [])

    def test_preserves_all_fields(self):
        entry = {"level": "ERROR", "message": "boom", "service": "svc", "timestamp": datetime.now()}
        result = extract_errors_warnings([entry])
        self.assertEqual(result[0], entry)


def _make_entry(level, message, error_type=None, ts=None):
    return {
        "level": level,
        "message": message,
        "error_type": error_type,
        "timestamp": ts or datetime(2024, 1, 15, 10, 0, 0),
        "service": "test",
    }


class TestBuildFrequencyTable(unittest.TestCase):
    def test_counts_identical_errors(self):
        entries = [
            _make_entry("ERROR", "DB timeout", "DatabaseError", datetime(2024, 1, 15, 10, 0)),
            _make_entry("ERROR", "DB timeout", "DatabaseError", datetime(2024, 1, 15, 11, 0)),
            _make_entry("ERROR", "DB timeout", "DatabaseError", datetime(2024, 1, 15, 12, 0)),
        ]
        table = build_frequency_table(entries)
        self.assertEqual(len(table), 1)
        self.assertEqual(table[0]["count"], 3)

    def test_tracks_first_and_last_seen(self):
        t1, t2, t3 = datetime(2024,1,15,10), datetime(2024,1,15,11), datetime(2024,1,15,12)
        entries = [
            _make_entry("ERROR", "DB timeout", "DatabaseError", t2),
            _make_entry("ERROR", "DB timeout", "DatabaseError", t1),
            _make_entry("ERROR", "DB timeout", "DatabaseError", t3),
        ]
        table = build_frequency_table(entries)
        self.assertEqual(table[0]["first_seen"], t1)
        self.assertEqual(table[0]["last_seen"], t3)

    def test_separates_different_error_types(self):
        entries = [
            _make_entry("ERROR", "DB timeout", "DatabaseError"),
            _make_entry("ERROR", "Auth fail", "AuthError"),
        ]
        self.assertEqual(len(build_frequency_table(entries)), 2)

    def test_sorted_by_count_descending(self):
        entries = [
            _make_entry("ERROR", "DB timeout", "DatabaseError"),
            _make_entry("WARNING", "Cache miss", "CacheWarning"),
            _make_entry("WARNING", "Cache miss", "CacheWarning"),
            _make_entry("WARNING", "Cache miss", "CacheWarning"),
        ]
        table = build_frequency_table(entries)
        self.assertEqual(table[0]["count"], 3)
        self.assertEqual(table[1]["count"], 1)

    def test_uses_message_when_no_error_type(self):
        entries = [
            _make_entry("ERROR", "Connection refused to upstream"),
            _make_entry("ERROR", "Connection refused to upstream"),
        ]
        table = build_frequency_table(entries)
        self.assertEqual(len(table), 1)
        self.assertEqual(table[0]["count"], 2)
        self.assertIn("Connection refused", table[0]["error_key"])

    def test_separates_error_and_warning_same_key(self):
        entries = [
            _make_entry("ERROR", "Disk space low", "DiskWarning"),
            _make_entry("WARNING", "Disk space low", "DiskWarning"),
        ]
        self.assertEqual(len(build_frequency_table(entries)), 2)


class TestFormatTable(unittest.TestCase):
    def _make_row(self, key, level, count, first, last):
        return {"error_key": key, "level": level, "count": count,
                "first_seen": first, "last_seen": last}

    def test_output_contains_headers(self):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024,1,15,10,0), datetime(2024,1,15,12,0))]
        output = format_table(rows)
        self.assertIn("Error Key", output)
        self.assertIn("Level", output)
        self.assertIn("Count", output)
        self.assertIn("First Seen", output)
        self.assertIn("Last Seen", output)

    def test_output_contains_row_data(self):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024,1,15,10,0), datetime(2024,1,15,12,0))]
        output = format_table(rows)
        self.assertIn("DatabaseError", output)
        self.assertIn("ERROR", output)
        self.assertIn("3", output)

    def test_empty_table_returns_no_entries_message(self):
        output = format_table([])
        self.assertTrue("no entries" in output.lower() or output.strip() == "")


class TestWriteJsonReport(unittest.TestCase):
    def _make_row(self, key, level, count, first, last):
        return {"error_key": key, "level": level, "count": count,
                "first_seen": first, "last_seen": last}

    def test_creates_json_file(self):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024,1,15,10,0), datetime(2024,1,15,12,0))]
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            fname = f.name
        try:
            write_json_report(rows, fname)
            self.assertTrue(os.path.exists(fname))
        finally:
            os.unlink(fname)

    def test_json_is_valid(self):
        rows = [self._make_row("DatabaseError", "ERROR", 3,
                               datetime(2024,1,15,10,0), datetime(2024,1,15,12,0))]
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            fname = f.name
        try:
            write_json_report(rows, fname)
            with open(fname) as f:
                data = json.load(f)
            self.assertIsInstance(data, dict)
        finally:
            os.unlink(fname)

    def test_json_contains_entries(self):
        rows = [
            self._make_row("DatabaseError", "ERROR", 3, datetime(2024,1,15,10,0), datetime(2024,1,15,12,0)),
            self._make_row("CacheWarning", "WARNING", 1, datetime(2024,1,15,10,30), datetime(2024,1,15,10,30)),
        ]
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            fname = f.name
        try:
            write_json_report(rows, fname)
            with open(fname) as f:
                data = json.load(f)
            self.assertIn("entries", data)
            self.assertEqual(len(data["entries"]), 2)
        finally:
            os.unlink(fname)

    def test_json_timestamps_are_strings(self):
        rows = [self._make_row("DatabaseError", "ERROR", 1,
                               datetime(2024,1,15,10,0), datetime(2024,1,15,10,0))]
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            fname = f.name
        try:
            write_json_report(rows, fname)
            with open(fname) as f:
                data = json.load(f)
            entry = data["entries"][0]
            self.assertIsInstance(entry["first_seen"], str)
            self.assertIsInstance(entry["last_seen"], str)
        finally:
            os.unlink(fname)

    def test_json_contains_metadata(self):
        rows = [self._make_row("DatabaseError", "ERROR", 2,
                               datetime(2024,1,15,10,0), datetime(2024,1,15,11,0))]
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            fname = f.name
        try:
            write_json_report(rows, fname)
            with open(fname) as f:
                data = json.load(f)
            self.assertIn("generated_at", data)
            self.assertIn("total_entries", data)
            self.assertEqual(data["total_entries"], 1)
        finally:
            os.unlink(fname)

    def test_raises_on_unwritable_path(self):
        with self.assertRaises((OSError, FileNotFoundError, PermissionError)):
            write_json_report([], "/nonexistent_dir/report.json")


if __name__ == "__main__":
    # Also demonstrate the full pipeline using the sample fixture
    print("=" * 60)
    print("RUNNING UNIT TESTS")
    print("=" * 60)
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    for cls in [TestParseSyslogLine, TestParseJsonLine, TestParseLogFile,
                TestExtractErrorsWarnings, TestBuildFrequencyTable,
                TestFormatTable, TestWriteJsonReport]:
        suite.addTests(loader.loadTestsFromTestCase(cls))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    print()
    print("=" * 60)
    print("RUNNING PIPELINE ON SAMPLE FIXTURE")
    print("=" * 60)
    fixture = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "sample.log")
    if os.path.exists(fixture):
        entries = parse_log_file(fixture)
        filtered = extract_errors_warnings(entries)
        table = build_frequency_table(filtered)
        print(f"Parsed {len(entries)} lines, found {len(filtered)} errors/warnings\n")
        print(format_table(table))
        out_json = os.path.join(os.path.dirname(os.path.abspath(__file__)), "log_report.json")
        write_json_report(table, out_json)
        print(f"\nJSON report written to: {out_json}")
    else:
        print(f"Fixture not found at {fixture}")

    sys.exit(0 if result.wasSuccessful() else 1)
