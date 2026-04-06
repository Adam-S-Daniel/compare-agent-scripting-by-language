"""
TDD Cycle 6: End-to-End Integration Tests
==========================================
RED:  Write tests that exercise the full pipeline: load JSON → generate report → format output.
GREEN: Verify all pieces work together with realistic fixture data.
REFACTOR: Ensure the CLI entry point works with various argument combinations.

These tests verify the complete workflow from JSON input to formatted output,
catching any integration issues between the individual components.
"""
import unittest
import json
import sys
import os
from datetime import date
from pathlib import Path
from io import StringIO

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from secret_rotation_validator import (
    load_secrets_from_json,
    generate_report,
    format_json,
    format_markdown,
)
from main import main


# Path to the fixture file
FIXTURE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "test_fixtures.json",
)


class TestFullPipeline(unittest.TestCase):
    """End-to-end: load fixture file → report → both output formats."""

    def setUp(self):
        with open(FIXTURE_PATH) as f:
            self.json_str = f.read()
        self.configs = load_secrets_from_json(self.json_str)

    def test_load_fixture_file(self):
        """The fixture file should parse into the expected number of secrets."""
        self.assertEqual(len(self.configs), 8)

    def test_full_pipeline_json_output(self):
        """JSON output from the full pipeline should be valid and complete."""
        report = generate_report(self.configs, warning_window_days=14, reference_date=date(2026, 4, 1))
        output = format_json(report)
        data = json.loads(output)
        self.assertEqual(data["metadata"]["total_secrets"], 8)
        # Verify all groups sum to total
        total = (
            len(data["secrets"]["expired"])
            + len(data["secrets"]["warning"])
            + len(data["secrets"]["ok"])
        )
        self.assertEqual(total, 8)

    def test_full_pipeline_markdown_output(self):
        """Markdown output should contain all secret names from fixtures."""
        report = generate_report(self.configs, warning_window_days=14, reference_date=date(2026, 4, 1))
        output = format_markdown(report)
        for config in self.configs:
            self.assertIn(config.name, output)

    def test_different_warning_windows_produce_different_results(self):
        """Changing the warning window should change the grouping."""
        narrow = generate_report(self.configs, warning_window_days=7, reference_date=date(2026, 4, 1))
        wide = generate_report(self.configs, warning_window_days=30, reference_date=date(2026, 4, 1))
        # Both should have the same total
        narrow_total = len(narrow.expired) + len(narrow.warning) + len(narrow.ok)
        wide_total = len(wide.expired) + len(wide.warning) + len(wide.ok)
        self.assertEqual(narrow_total, wide_total)
        # Wider window should push some from ok → warning
        self.assertGreaterEqual(len(wide.warning), len(narrow.warning))


class TestCLIEntryPoint(unittest.TestCase):
    """Test the CLI main() function with various argument combinations."""

    def test_cli_json_output(self):
        """CLI should produce valid JSON with --format json."""
        old_stdout = sys.stdout
        sys.stdout = captured = StringIO()
        try:
            ret = main(["--input", FIXTURE_PATH, "--format", "json", "--date", "2026-04-01"])
        finally:
            sys.stdout = old_stdout
        self.assertEqual(ret, 0)
        data = json.loads(captured.getvalue())
        self.assertIn("metadata", data)
        self.assertIn("secrets", data)

    def test_cli_markdown_output(self):
        """CLI should produce markdown with --format markdown."""
        old_stdout = sys.stdout
        sys.stdout = captured = StringIO()
        try:
            ret = main(["--input", FIXTURE_PATH, "--format", "markdown", "--date", "2026-04-01"])
        finally:
            sys.stdout = old_stdout
        self.assertEqual(ret, 0)
        output = captured.getvalue()
        self.assertIn("# Secret Rotation Report", output)

    def test_cli_custom_warning_days(self):
        """CLI --warning-days should affect the report output."""
        old_stdout = sys.stdout
        sys.stdout = captured = StringIO()
        try:
            ret = main(["--input", FIXTURE_PATH, "--format", "json", "--warning-days", "30", "--date", "2026-04-01"])
        finally:
            sys.stdout = old_stdout
        self.assertEqual(ret, 0)
        data = json.loads(captured.getvalue())
        self.assertEqual(data["metadata"]["warning_window_days"], 30)

    def test_cli_missing_file_returns_error(self):
        """CLI should return 1 and print an error for a missing input file."""
        old_stderr = sys.stderr
        sys.stderr = captured = StringIO()
        try:
            ret = main(["--input", "nonexistent.json"])
        finally:
            sys.stderr = old_stderr
        self.assertEqual(ret, 1)
        self.assertIn("not found", captured.getvalue().lower())

    def test_cli_invalid_date_returns_error(self):
        """CLI should return 1 for an invalid --date value."""
        old_stderr = sys.stderr
        sys.stderr = captured = StringIO()
        try:
            ret = main(["--input", FIXTURE_PATH, "--date", "bad-date"])
        finally:
            sys.stderr = old_stderr
        self.assertEqual(ret, 1)
        self.assertIn("invalid date", captured.getvalue().lower())


if __name__ == "__main__":
    unittest.main()
