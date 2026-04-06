"""
TDD tests for CSV Report Generator.

Red/Green TDD approach:
1. Write a failing test
2. Write minimum code to pass
3. Refactor
4. Repeat
"""

import unittest
import os
import csv
import tempfile
from pathlib import Path


# ─────────────────────────────────────────────
# RED: Test 1 — Can we parse a CSV file at all?
# ─────────────────────────────────────────────
class TestCsvParsing(unittest.TestCase):
    def setUp(self):
        # Create a minimal in-memory CSV for this test group
        self.sample_rows = [
            {"name": "Alice", "department": "Engineering", "salary": "90000", "hire_date": "2020-01-15", "status": "active"},
            {"name": "Bob",   "department": "Marketing",   "salary": "75000", "hire_date": "2019-03-22", "status": "inactive"},
            {"name": "Carol", "department": "Engineering", "salary": "95000", "hire_date": "2021-07-01", "status": "active"},
        ]

    def test_parse_csv_returns_list_of_dicts(self):
        """Parsing a CSV file should return a list of dicts with the correct keys."""
        from csv_report import parse_csv

        with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False, newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["name", "department", "salary", "hire_date", "status"])
            writer.writeheader()
            writer.writerows(self.sample_rows)
            tmp_path = f.name

        try:
            records = parse_csv(tmp_path)
            self.assertEqual(len(records), 3)
            self.assertEqual(records[0]["name"], "Alice")
            self.assertIn("department", records[0])
            self.assertIn("salary", records[0])
            self.assertIn("hire_date", records[0])
            self.assertIn("status", records[0])
        finally:
            os.unlink(tmp_path)

    def test_parse_csv_raises_on_missing_file(self):
        """Parsing a non-existent file should raise FileNotFoundError with a clear message."""
        from csv_report import parse_csv

        with self.assertRaises(FileNotFoundError) as ctx:
            parse_csv("/nonexistent/path/employees.csv")
        self.assertIn("employees.csv", str(ctx.exception))


# ─────────────────────────────────────────────────────────
# RED: Test 2 — Can we filter to only active employees?
# ─────────────────────────────────────────────────────────
class TestFilterActive(unittest.TestCase):
    def setUp(self):
        self.records = [
            {"name": "Alice", "department": "Engineering", "salary": "90000", "hire_date": "2020-01-15", "status": "active"},
            {"name": "Bob",   "department": "Marketing",   "salary": "75000", "hire_date": "2019-03-22", "status": "inactive"},
            {"name": "Carol", "department": "Engineering", "salary": "95000", "hire_date": "2021-07-01", "status": "active"},
            {"name": "Dave",  "department": "HR",          "salary": "65000", "hire_date": "2018-11-05", "status": "ACTIVE"},  # case variation
        ]

    def test_filter_active_keeps_only_active(self):
        """filter_active should return only employees with status == 'active' (case-insensitive)."""
        from csv_report import filter_active

        active = filter_active(self.records)
        self.assertEqual(len(active), 3)
        names = {r["name"] for r in active}
        self.assertIn("Alice", names)
        self.assertIn("Carol", names)
        self.assertIn("Dave", names)   # ACTIVE should match
        self.assertNotIn("Bob", names)

    def test_filter_active_empty_input(self):
        """filter_active with empty list returns empty list."""
        from csv_report import filter_active

        self.assertEqual(filter_active([]), [])


# ─────────────────────────────────────────────────────────────────────
# RED: Test 3 — Can we compute average salary and headcount per dept?
# ─────────────────────────────────────────────────────────────────────
class TestDepartmentStats(unittest.TestCase):
    def setUp(self):
        # Salary stored as strings (as read from CSV); implementation must convert
        self.active_records = [
            {"name": "Alice", "department": "Engineering", "salary": "90000", "hire_date": "2020-01-15", "status": "active"},
            {"name": "Carol", "department": "Engineering", "salary": "95000", "hire_date": "2021-07-01", "status": "active"},
            {"name": "Dave",  "department": "HR",          "salary": "65000", "hire_date": "2018-11-05", "status": "active"},
        ]

    def test_department_stats_headcount(self):
        """compute_department_stats should count employees per department."""
        from csv_report import compute_department_stats

        stats = compute_department_stats(self.active_records)
        self.assertEqual(stats["Engineering"]["headcount"], 2)
        self.assertEqual(stats["HR"]["headcount"], 1)

    def test_department_stats_average_salary(self):
        """compute_department_stats should compute average salary per department."""
        from csv_report import compute_department_stats

        stats = compute_department_stats(self.active_records)
        self.assertAlmostEqual(stats["Engineering"]["avg_salary"], 92500.0)
        self.assertAlmostEqual(stats["HR"]["avg_salary"], 65000.0)

    def test_department_stats_empty(self):
        """compute_department_stats with empty list returns empty dict."""
        from csv_report import compute_department_stats

        self.assertEqual(compute_department_stats([]), {})


# ─────────────────────────────────────────────────────────
# RED: Test 4 — Can we compute overall statistics?
# ─────────────────────────────────────────────────────────
class TestOverallStats(unittest.TestCase):
    def setUp(self):
        self.active_records = [
            {"name": "Alice", "department": "Engineering", "salary": "90000", "hire_date": "2020-01-15", "status": "active"},
            {"name": "Carol", "department": "Engineering", "salary": "95000", "hire_date": "2021-07-01", "status": "active"},
            {"name": "Dave",  "department": "HR",          "salary": "65000", "hire_date": "2018-11-05", "status": "active"},
        ]

    def test_overall_stats_total_headcount(self):
        from csv_report import compute_overall_stats

        stats = compute_overall_stats(self.active_records)
        self.assertEqual(stats["total_employees"], 3)

    def test_overall_stats_average_salary(self):
        from csv_report import compute_overall_stats

        stats = compute_overall_stats(self.active_records)
        expected_avg = (90000 + 95000 + 65000) / 3
        self.assertAlmostEqual(stats["avg_salary"], expected_avg)

    def test_overall_stats_min_max_salary(self):
        from csv_report import compute_overall_stats

        stats = compute_overall_stats(self.active_records)
        self.assertEqual(stats["min_salary"], 65000.0)
        self.assertEqual(stats["max_salary"], 95000.0)

    def test_overall_stats_department_count(self):
        from csv_report import compute_overall_stats

        stats = compute_overall_stats(self.active_records)
        self.assertEqual(stats["department_count"], 2)

    def test_overall_stats_empty(self):
        from csv_report import compute_overall_stats

        stats = compute_overall_stats([])
        self.assertEqual(stats["total_employees"], 0)


# ─────────────────────────────────────────────────────────────────────
# RED: Test 5 — Can we write a formatted summary report to a file?
# ─────────────────────────────────────────────────────────────────────
class TestReportOutput(unittest.TestCase):
    def setUp(self):
        self.dept_stats = {
            "Engineering": {"headcount": 2, "avg_salary": 92500.0},
            "HR":          {"headcount": 1, "avg_salary": 65000.0},
        }
        self.overall_stats = {
            "total_employees": 3,
            "avg_salary": 83333.33,
            "min_salary": 65000.0,
            "max_salary": 95000.0,
            "department_count": 2,
        }

    def test_report_file_is_created(self):
        """generate_report should create the output file."""
        from csv_report import generate_report

        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as f:
            out_path = f.name

        try:
            generate_report(self.dept_stats, self.overall_stats, out_path)
            self.assertTrue(os.path.exists(out_path))
        finally:
            os.unlink(out_path)

    def test_report_contains_department_names(self):
        """The report should mention each department."""
        from csv_report import generate_report

        with tempfile.NamedTemporaryFile(mode="r", suffix=".txt", delete=False) as f:
            out_path = f.name

        try:
            generate_report(self.dept_stats, self.overall_stats, out_path)
            content = Path(out_path).read_text()
            self.assertIn("Engineering", content)
            self.assertIn("HR", content)
        finally:
            os.unlink(out_path)

    def test_report_contains_salary_figures(self):
        """The report should include salary numbers."""
        from csv_report import generate_report

        with tempfile.NamedTemporaryFile(mode="r", suffix=".txt", delete=False) as f:
            out_path = f.name

        try:
            generate_report(self.dept_stats, self.overall_stats, out_path)
            content = Path(out_path).read_text()
            self.assertIn("92,500", content)   # formatted number
            self.assertIn("65,000", content)
        finally:
            os.unlink(out_path)

    def test_report_contains_overall_section(self):
        """The report should have an overall / summary section."""
        from csv_report import generate_report

        with tempfile.NamedTemporaryFile(mode="r", suffix=".txt", delete=False) as f:
            out_path = f.name

        try:
            generate_report(self.dept_stats, self.overall_stats, out_path)
            content = Path(out_path).read_text().lower()
            self.assertIn("overall", content)
        finally:
            os.unlink(out_path)


# ──────────────────────────────────────────────────────────────────────
# RED: Test 6 — Integration test using the fixture CSV file
# ──────────────────────────────────────────────────────────────────────
class TestIntegration(unittest.TestCase):
    """End-to-end test using the real fixture file (fixtures/employees.csv)."""

    FIXTURE_PATH = os.path.join(os.path.dirname(__file__), "fixtures", "employees.csv")

    def test_fixture_file_exists(self):
        """The fixture CSV file must exist."""
        self.assertTrue(os.path.exists(self.FIXTURE_PATH), f"Fixture not found: {self.FIXTURE_PATH}")

    def test_full_pipeline(self):
        """Running the full pipeline on the fixture produces a non-empty report."""
        from csv_report import parse_csv, filter_active, compute_department_stats, compute_overall_stats, generate_report

        records = parse_csv(self.FIXTURE_PATH)
        active  = filter_active(records)
        dept_stats    = compute_department_stats(active)
        overall_stats = compute_overall_stats(active)

        with tempfile.NamedTemporaryFile(mode="r", suffix=".txt", delete=False) as f:
            out_path = f.name

        try:
            generate_report(dept_stats, overall_stats, out_path)
            content = Path(out_path).read_text()
            self.assertGreater(len(content), 100)           # non-trivial output
            self.assertGreater(overall_stats["total_employees"], 0)
        finally:
            os.unlink(out_path)


if __name__ == "__main__":
    unittest.main()
