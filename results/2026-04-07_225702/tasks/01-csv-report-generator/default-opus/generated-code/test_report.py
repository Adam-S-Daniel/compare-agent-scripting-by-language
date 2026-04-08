"""Tests for CSV report generator using red/green TDD methodology.

Each test class represents one TDD cycle. Tests are written first (red),
then the minimum implementation is added to make them pass (green).
"""

import os
import tempfile
import unittest

# --- Test fixture data ---

SAMPLE_CSV = """\
name,department,salary,hire_date,status
Alice Johnson,Engineering,95000,2020-03-15,active
Bob Smith,Marketing,72000,2019-07-01,active
Carol White,Engineering,105000,2018-01-20,active
Dave Brown,Marketing,68000,2021-06-10,inactive
Eve Davis,HR,78000,2020-11-05,active
Frank Miller,Engineering,88000,2022-02-28,active
Grace Lee,HR,82000,2017-09-12,inactive
Henry Wilson,Marketing,75000,2023-01-15,active
Ivy Chen,Engineering,112000,2016-05-30,active
Jack Taylor,HR,71000,2021-08-22,active
"""

# Edge case: CSV with all inactive employees
ALL_INACTIVE_CSV = """\
name,department,salary,hire_date,status
Dave Brown,Marketing,68000,2021-06-10,inactive
Grace Lee,HR,82000,2017-09-12,inactive
"""

# Edge case: CSV with only a header
EMPTY_CSV = """\
name,department,salary,hire_date,status
"""


class TempCSVMixin:
    """Mixin providing helpers to create temporary CSV files for testing."""

    def _write_csv(self, content):
        """Write CSV content to a temp file, return path. Caller cleans up."""
        fd, path = tempfile.mkstemp(suffix=".csv")
        with os.fdopen(fd, "w") as f:
            f.write(content)
        self._temp_files.append(path)
        return path

    def setUp(self):
        self._temp_files = []

    def tearDown(self):
        for path in self._temp_files:
            if os.path.exists(path):
                os.unlink(path)


# ============================================================
# TDD Round 1: Parse CSV into list of employee dicts
# ============================================================

class TestParseCSV(TempCSVMixin, unittest.TestCase):
    """RED: These tests fail because report.parse_csv doesn't exist yet."""

    def test_parse_returns_all_rows(self):
        from report import parse_csv
        path = self._write_csv(SAMPLE_CSV)
        employees = parse_csv(path)
        self.assertEqual(len(employees), 10)

    def test_parse_converts_salary_to_float(self):
        from report import parse_csv
        path = self._write_csv(SAMPLE_CSV)
        employees = parse_csv(path)
        self.assertIsInstance(employees[0]["salary"], float)
        self.assertEqual(employees[0]["salary"], 95000.0)

    def test_parse_preserves_string_fields(self):
        from report import parse_csv
        path = self._write_csv(SAMPLE_CSV)
        employees = parse_csv(path)
        emp = employees[0]
        self.assertEqual(emp["name"], "Alice Johnson")
        self.assertEqual(emp["department"], "Engineering")
        self.assertEqual(emp["hire_date"], "2020-03-15")
        self.assertEqual(emp["status"], "active")

    def test_parse_empty_csv_returns_empty_list(self):
        from report import parse_csv
        path = self._write_csv(EMPTY_CSV)
        employees = parse_csv(path)
        self.assertEqual(employees, [])

    def test_parse_nonexistent_file_raises(self):
        from report import parse_csv
        with self.assertRaises(FileNotFoundError):
            parse_csv("/no/such/file.csv")


# ============================================================
# TDD Round 2: Filter to active employees only
# ============================================================

class TestFilterActive(TempCSVMixin, unittest.TestCase):
    """RED: These tests fail because report.filter_active doesn't exist yet."""

    def test_filter_removes_inactive(self):
        from report import filter_active
        employees = [
            {"name": "A", "status": "active"},
            {"name": "B", "status": "inactive"},
            {"name": "C", "status": "active"},
        ]
        result = filter_active(employees)
        self.assertEqual(len(result), 2)
        self.assertTrue(all(e["status"] == "active" for e in result))

    def test_filter_all_inactive_returns_empty(self):
        from report import filter_active
        employees = [
            {"name": "A", "status": "inactive"},
            {"name": "B", "status": "inactive"},
        ]
        self.assertEqual(filter_active(employees), [])

    def test_filter_empty_input(self):
        from report import filter_active
        self.assertEqual(filter_active([]), [])


# ============================================================
# TDD Round 3: Compute department aggregates
# ============================================================

class TestDepartmentAggregates(unittest.TestCase):
    """RED: These tests fail because report.compute_department_stats doesn't exist yet."""

    def setUp(self):
        self.employees = [
            {"name": "A", "department": "Engineering", "salary": 100000.0, "status": "active"},
            {"name": "B", "department": "Engineering", "salary": 80000.0, "status": "active"},
            {"name": "C", "department": "HR", "salary": 70000.0, "status": "active"},
        ]

    def test_headcount_by_department(self):
        from report import compute_department_stats
        stats = compute_department_stats(self.employees)
        self.assertEqual(stats["Engineering"]["headcount"], 2)
        self.assertEqual(stats["HR"]["headcount"], 1)

    def test_average_salary_by_department(self):
        from report import compute_department_stats
        stats = compute_department_stats(self.employees)
        self.assertAlmostEqual(stats["Engineering"]["avg_salary"], 90000.0)
        self.assertAlmostEqual(stats["HR"]["avg_salary"], 70000.0)

    def test_total_salary_by_department(self):
        from report import compute_department_stats
        stats = compute_department_stats(self.employees)
        self.assertAlmostEqual(stats["Engineering"]["total_salary"], 180000.0)
        self.assertAlmostEqual(stats["HR"]["total_salary"], 70000.0)

    def test_empty_employees_returns_empty_dict(self):
        from report import compute_department_stats
        self.assertEqual(compute_department_stats([]), {})


# ============================================================
# TDD Round 4: Compute overall statistics
# ============================================================

class TestOverallStats(unittest.TestCase):
    """RED: These tests fail because report.compute_overall_stats doesn't exist yet."""

    def setUp(self):
        self.employees = [
            {"name": "A", "department": "Eng", "salary": 100000.0, "status": "active"},
            {"name": "B", "department": "Eng", "salary": 80000.0, "status": "active"},
            {"name": "C", "department": "HR", "salary": 60000.0, "status": "active"},
        ]

    def test_total_headcount(self):
        from report import compute_overall_stats
        stats = compute_overall_stats(self.employees)
        self.assertEqual(stats["total_employees"], 3)

    def test_overall_average_salary(self):
        from report import compute_overall_stats
        stats = compute_overall_stats(self.employees)
        self.assertAlmostEqual(stats["avg_salary"], 80000.0)

    def test_min_max_salary(self):
        from report import compute_overall_stats
        stats = compute_overall_stats(self.employees)
        self.assertEqual(stats["min_salary"], 60000.0)
        self.assertEqual(stats["max_salary"], 100000.0)

    def test_total_payroll(self):
        from report import compute_overall_stats
        stats = compute_overall_stats(self.employees)
        self.assertAlmostEqual(stats["total_payroll"], 240000.0)

    def test_empty_employees(self):
        from report import compute_overall_stats
        stats = compute_overall_stats([])
        self.assertEqual(stats["total_employees"], 0)
        self.assertEqual(stats["total_payroll"], 0.0)


# ============================================================
# TDD Round 5: Format and write the report
# ============================================================

class TestFormatReport(unittest.TestCase):
    """RED: These tests fail because report.format_report doesn't exist yet."""

    def test_report_contains_department_section(self):
        from report import format_report
        dept_stats = {
            "Engineering": {"headcount": 2, "avg_salary": 90000.0, "total_salary": 180000.0},
        }
        overall = {"total_employees": 2, "avg_salary": 90000.0,
                    "min_salary": 80000.0, "max_salary": 100000.0, "total_payroll": 180000.0}
        text = format_report(dept_stats, overall)
        self.assertIn("Engineering", text)
        self.assertIn("Headcount", text)

    def test_report_contains_overall_section(self):
        from report import format_report
        dept_stats = {}
        overall = {"total_employees": 0, "avg_salary": 0, "min_salary": 0,
                    "max_salary": 0, "total_payroll": 0}
        text = format_report(dept_stats, overall)
        self.assertIn("Overall", text)


class TestWriteReport(TempCSVMixin, unittest.TestCase):
    """RED: These tests fail because report.write_report doesn't exist yet."""

    def test_write_report_creates_file(self):
        from report import write_report
        fd, path = tempfile.mkstemp(suffix=".txt")
        os.close(fd)
        os.unlink(path)  # start with no file
        self._temp_files.append(path)
        write_report("Hello report", path)
        self.assertTrue(os.path.exists(path))

    def test_write_report_content_matches(self):
        from report import write_report
        fd, path = tempfile.mkstemp(suffix=".txt")
        os.close(fd)
        self._temp_files.append(path)
        write_report("Test content", path)
        with open(path) as f:
            self.assertEqual(f.read(), "Test content")


# ============================================================
# TDD Round 6: End-to-end integration
# ============================================================

class TestEndToEnd(TempCSVMixin, unittest.TestCase):
    """Integration test: run the full pipeline and verify the output report."""

    def test_full_pipeline(self):
        from report import generate_report
        csv_path = self._write_csv(SAMPLE_CSV)
        fd, out_path = tempfile.mkstemp(suffix=".txt")
        os.close(fd)
        self._temp_files.append(out_path)

        generate_report(csv_path, out_path)

        with open(out_path) as f:
            report = f.read()

        # The report should reference departments and overall stats
        self.assertIn("Engineering", report)
        self.assertIn("Marketing", report)
        self.assertIn("HR", report)
        self.assertIn("Overall", report)
        # Inactive employees (Dave, Grace) are excluded, so 8 active
        self.assertIn("8", report)

    def test_all_inactive_produces_empty_report(self):
        from report import generate_report
        csv_path = self._write_csv(ALL_INACTIVE_CSV)
        fd, out_path = tempfile.mkstemp(suffix=".txt")
        os.close(fd)
        self._temp_files.append(out_path)

        generate_report(csv_path, out_path)

        with open(out_path) as f:
            report = f.read()
        # Should still produce a valid report, just with 0 employees
        self.assertIn("0", report)

    def test_missing_csv_raises(self):
        from report import generate_report
        with self.assertRaises(FileNotFoundError):
            generate_report("/no/such/file.csv", "/tmp/out.txt")


if __name__ == "__main__":
    unittest.main()
