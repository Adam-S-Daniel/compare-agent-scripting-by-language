"""
TDD tests for CSV employee report generator.

Approach: We build up functionality incrementally using red/green/refactor:
1. Parse CSV data into employee records
2. Filter to active employees only
3. Compute per-department aggregates (avg salary, headcount)
4. Compute overall statistics
5. Format and write summary report to a text file
6. Handle error cases gracefully
"""

import unittest
import os
import tempfile
import csv

# Sample CSV content used across tests
SAMPLE_CSV = """name,department,salary,hire_date,status
Alice Johnson,Engineering,95000,2020-03-15,active
Bob Smith,Marketing,72000,2019-07-01,active
Carol White,Engineering,105000,2018-01-10,inactive
Dave Brown,Marketing,68000,2021-06-20,active
Eve Davis,HR,78000,2020-11-05,active
Frank Miller,HR,82000,2017-04-22,inactive
Grace Lee,Engineering,110000,2019-09-30,active
Hank Wilson,HR,75000,2022-02-14,active
Ivy Chen,Marketing,71000,2023-01-08,active
Jack Taylor,Engineering,98000,2021-08-17,active
"""


class TestParseCSV(unittest.TestCase):
    """RED/GREEN cycle 1: Parse CSV file into list of employee dicts."""

    def setUp(self):
        self.tmpfile = tempfile.NamedTemporaryFile(
            mode="w", suffix=".csv", delete=False
        )
        self.tmpfile.write(SAMPLE_CSV.strip())
        self.tmpfile.close()

    def tearDown(self):
        os.unlink(self.tmpfile.name)

    def test_parse_returns_list_of_dicts(self):
        from report import parse_csv

        employees = parse_csv(self.tmpfile.name)
        self.assertIsInstance(employees, list)
        self.assertEqual(len(employees), 10)

    def test_parse_fields_are_correct(self):
        from report import parse_csv

        employees = parse_csv(self.tmpfile.name)
        first = employees[0]
        self.assertEqual(first["name"], "Alice Johnson")
        self.assertEqual(first["department"], "Engineering")
        self.assertEqual(first["salary"], 95000.0)
        self.assertEqual(first["status"], "active")
        self.assertEqual(first["hire_date"], "2020-03-15")

    def test_parse_nonexistent_file_raises(self):
        from report import parse_csv

        with self.assertRaises(FileNotFoundError):
            parse_csv("/no/such/file.csv")

    def test_parse_empty_file_returns_empty_list(self):
        from report import parse_csv

        empty = tempfile.NamedTemporaryFile(
            mode="w", suffix=".csv", delete=False
        )
        empty.write("name,department,salary,hire_date,status\n")
        empty.close()
        try:
            self.assertEqual(parse_csv(empty.name), [])
        finally:
            os.unlink(empty.name)


class TestFilterActive(unittest.TestCase):
    """RED/GREEN cycle 2: Filter employees to active only."""

    def test_filter_active_employees(self):
        from report import filter_active

        employees = [
            {"name": "A", "status": "active"},
            {"name": "B", "status": "inactive"},
            {"name": "C", "status": "active"},
        ]
        result = filter_active(employees)
        self.assertEqual(len(result), 2)
        self.assertTrue(all(e["status"] == "active" for e in result))

    def test_filter_empty_list(self):
        from report import filter_active

        self.assertEqual(filter_active([]), [])

    def test_filter_no_active(self):
        from report import filter_active

        employees = [{"name": "A", "status": "inactive"}]
        self.assertEqual(filter_active(employees), [])


class TestDepartmentAggregates(unittest.TestCase):
    """RED/GREEN cycle 3: Compute per-department average salary and headcount."""

    def setUp(self):
        self.employees = [
            {"name": "A", "department": "Eng", "salary": 100000.0, "status": "active"},
            {"name": "B", "department": "Eng", "salary": 80000.0, "status": "active"},
            {"name": "C", "department": "HR", "salary": 70000.0, "status": "active"},
        ]

    def test_department_aggregates_keys(self):
        from report import department_aggregates

        aggs = department_aggregates(self.employees)
        self.assertIn("Eng", aggs)
        self.assertIn("HR", aggs)

    def test_department_headcount(self):
        from report import department_aggregates

        aggs = department_aggregates(self.employees)
        self.assertEqual(aggs["Eng"]["headcount"], 2)
        self.assertEqual(aggs["HR"]["headcount"], 1)

    def test_department_avg_salary(self):
        from report import department_aggregates

        aggs = department_aggregates(self.employees)
        self.assertAlmostEqual(aggs["Eng"]["avg_salary"], 90000.0)
        self.assertAlmostEqual(aggs["HR"]["avg_salary"], 70000.0)

    def test_empty_employees(self):
        from report import department_aggregates

        self.assertEqual(department_aggregates([]), {})


class TestOverallStatistics(unittest.TestCase):
    """RED/GREEN cycle 4: Compute overall statistics across all employees."""

    def setUp(self):
        self.employees = [
            {"name": "A", "department": "Eng", "salary": 100000.0, "status": "active"},
            {"name": "B", "department": "Eng", "salary": 80000.0, "status": "active"},
            {"name": "C", "department": "HR", "salary": 60000.0, "status": "active"},
        ]

    def test_overall_total_headcount(self):
        from report import overall_statistics

        stats = overall_statistics(self.employees)
        self.assertEqual(stats["total_headcount"], 3)

    def test_overall_avg_salary(self):
        from report import overall_statistics

        stats = overall_statistics(self.employees)
        self.assertAlmostEqual(stats["avg_salary"], 80000.0)

    def test_overall_min_max_salary(self):
        from report import overall_statistics

        stats = overall_statistics(self.employees)
        self.assertEqual(stats["min_salary"], 60000.0)
        self.assertEqual(stats["max_salary"], 100000.0)

    def test_overall_total_payroll(self):
        from report import overall_statistics

        stats = overall_statistics(self.employees)
        self.assertEqual(stats["total_payroll"], 240000.0)

    def test_empty_employees(self):
        from report import overall_statistics

        stats = overall_statistics([])
        self.assertEqual(stats["total_headcount"], 0)
        self.assertEqual(stats["avg_salary"], 0)
        self.assertEqual(stats["total_payroll"], 0)


class TestFormatReport(unittest.TestCase):
    """RED/GREEN cycle 5: Format aggregates into a readable text report."""

    def test_report_contains_department_sections(self):
        from report import format_report

        dept_aggs = {
            "Engineering": {"headcount": 3, "avg_salary": 95000.0},
            "HR": {"headcount": 2, "avg_salary": 76000.0},
        }
        overall = {
            "total_headcount": 5,
            "avg_salary": 87400.0,
            "min_salary": 68000.0,
            "max_salary": 110000.0,
            "total_payroll": 437000.0,
        }
        text = format_report(dept_aggs, overall)
        self.assertIn("Engineering", text)
        self.assertIn("HR", text)
        self.assertIn("95,000", text)  # formatted salary
        self.assertIn("Overall", text)

    def test_report_contains_overall_stats(self):
        from report import format_report

        dept_aggs = {"X": {"headcount": 1, "avg_salary": 50000.0}}
        overall = {
            "total_headcount": 1,
            "avg_salary": 50000.0,
            "min_salary": 50000.0,
            "max_salary": 50000.0,
            "total_payroll": 50000.0,
        }
        text = format_report(dept_aggs, overall)
        self.assertIn("Total Headcount", text)
        self.assertIn("Average Salary", text)
        self.assertIn("Total Payroll", text)


class TestWriteReport(unittest.TestCase):
    """RED/GREEN cycle 6: Write report text to an output file."""

    def test_write_report_creates_file(self):
        from report import write_report

        outpath = tempfile.mktemp(suffix=".txt")
        try:
            write_report("Hello report", outpath)
            self.assertTrue(os.path.exists(outpath))
            with open(outpath) as f:
                self.assertEqual(f.read(), "Hello report")
        finally:
            if os.path.exists(outpath):
                os.unlink(outpath)

    def test_write_report_bad_directory_raises(self):
        from report import write_report

        with self.assertRaises(OSError):
            write_report("data", "/no/such/dir/report.txt")


class TestEndToEnd(unittest.TestCase):
    """Integration test: full pipeline from CSV to report file."""

    def test_full_pipeline(self):
        from report import generate_report

        # Write sample CSV
        csv_path = tempfile.mktemp(suffix=".csv")
        out_path = tempfile.mktemp(suffix=".txt")
        try:
            with open(csv_path, "w") as f:
                f.write(SAMPLE_CSV.strip())

            generate_report(csv_path, out_path)

            self.assertTrue(os.path.exists(out_path))
            with open(out_path) as f:
                content = f.read()

            # Active employees: Alice, Bob, Dave, Eve, Grace, Hank, Ivy, Jack = 8
            self.assertIn("8", content)
            # Should mention all 3 departments
            self.assertIn("Engineering", content)
            self.assertIn("Marketing", content)
            self.assertIn("HR", content)
            # Inactive employees (Carol, Frank) should not inflate counts
            self.assertNotIn("Carol", content)
        finally:
            for p in [csv_path, out_path]:
                if os.path.exists(p):
                    os.unlink(p)


if __name__ == "__main__":
    unittest.main()
