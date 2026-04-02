# Test suite for CSV report generator — built using red/green TDD methodology.
# Each test was written before its corresponding production code.

import os
import tempfile
import pytest
from report import parse_csv, filter_active, aggregate_by_department, overall_stats, format_report, generate_report

# ── Fixtures ──────────────────────────────────────────────────────────────────

SAMPLE_CSV = """\
name,department,salary,hire_date,status
Alice Johnson,Engineering,95000,2020-03-15,active
Bob Smith,Marketing,72000,2019-07-01,active
Carol White,Engineering,105000,2018-01-20,active
Dave Brown,Marketing,68000,2021-06-10,inactive
Eve Davis,HR,78000,2020-11-05,active
Frank Miller,Engineering,110000,2017-04-22,inactive
Grace Lee,HR,82000,2019-09-14,active
Hank Wilson,Sales,71000,2022-02-28,active
Ivy Chen,Sales,76000,2021-08-03,active
Jack Taylor,Engineering,98000,2020-05-17,active
"""

@pytest.fixture
def csv_file(tmp_path):
    """Write sample CSV to a temp file and return its path."""
    path = tmp_path / "employees.csv"
    path.write_text(SAMPLE_CSV)
    return str(path)


@pytest.fixture
def employees(csv_file):
    return parse_csv(csv_file)


@pytest.fixture
def active(employees):
    return filter_active(employees)


# ── Cycle 1: Parse CSV ───────────────────────────────────────────────────────

class TestParseCSV:
    def test_returns_list_of_dicts(self, employees):
        assert isinstance(employees, list)
        assert all(isinstance(e, dict) for e in employees)

    def test_correct_row_count(self, employees):
        assert len(employees) == 10

    def test_fields_present(self, employees):
        expected_keys = {"name", "department", "salary", "hire_date", "status"}
        for emp in employees:
            assert set(emp.keys()) == expected_keys

    def test_salary_is_numeric(self, employees):
        for emp in employees:
            assert isinstance(emp["salary"], (int, float))

    def test_first_record(self, employees):
        assert employees[0]["name"] == "Alice Johnson"
        assert employees[0]["department"] == "Engineering"
        assert employees[0]["salary"] == 95000

    def test_missing_file_raises(self):
        with pytest.raises(FileNotFoundError):
            parse_csv("/nonexistent/path.csv")

    def test_empty_csv_raises(self, tmp_path):
        path = tmp_path / "empty.csv"
        path.write_text("")
        with pytest.raises(ValueError, match="empty or missing header"):
            parse_csv(str(path))

    def test_header_only_csv(self, tmp_path):
        path = tmp_path / "header_only.csv"
        path.write_text("name,department,salary,hire_date,status\n")
        result = parse_csv(str(path))
        assert result == []


# ── Cycle 2: Filter active employees ─────────────────────────────────────────

class TestFilterActive:
    def test_excludes_inactive(self, active):
        assert all(e["status"] == "active" for e in active)

    def test_correct_count(self, active):
        # 10 total, 2 inactive → 8 active
        assert len(active) == 8

    def test_inactive_names_excluded(self, active):
        names = {e["name"] for e in active}
        assert "Dave Brown" not in names
        assert "Frank Miller" not in names

    def test_empty_list(self):
        assert filter_active([]) == []


# ── Cycle 3: Aggregate by department ──────────────────────────────────────────

class TestAggregateByDepartment:
    def test_departments_present(self, active):
        agg = aggregate_by_department(active)
        assert set(agg.keys()) == {"Engineering", "Marketing", "HR", "Sales"}

    def test_headcount(self, active):
        agg = aggregate_by_department(active)
        assert agg["Engineering"]["headcount"] == 3
        assert agg["Marketing"]["headcount"] == 1
        assert agg["HR"]["headcount"] == 2
        assert agg["Sales"]["headcount"] == 2

    def test_average_salary(self, active):
        agg = aggregate_by_department(active)
        # Engineering active: Alice 95k, Carol 105k, Jack 98k → avg 99333.33
        assert agg["Engineering"]["avg_salary"] == pytest.approx(99333.33, rel=1e-2)
        # Marketing active: Bob 72k → avg 72000
        assert agg["Marketing"]["avg_salary"] == pytest.approx(72000)
        # HR active: Eve 78k, Grace 82k → avg 80000
        assert agg["HR"]["avg_salary"] == pytest.approx(80000)

    def test_total_salary(self, active):
        agg = aggregate_by_department(active)
        assert agg["Engineering"]["total_salary"] == 298000

    def test_empty_list(self):
        assert aggregate_by_department([]) == {}


# ── Cycle 4: Overall statistics ───────────────────────────────────────────────

class TestOverallStats:
    def test_total_headcount(self, active):
        stats = overall_stats(active)
        assert stats["total_headcount"] == 8

    def test_overall_avg_salary(self, active):
        stats = overall_stats(active)
        # Sum of active salaries: 95k+72k+105k+78k+82k+71k+76k+98k = 677000
        assert stats["avg_salary"] == pytest.approx(677000 / 8)

    def test_min_max_salary(self, active):
        stats = overall_stats(active)
        assert stats["min_salary"] == 71000
        assert stats["max_salary"] == 105000

    def test_empty_list(self):
        stats = overall_stats([])
        assert stats["total_headcount"] == 0


# ── Cycle 5: Format report ───────────────────────────────────────────────────

class TestFormatReport:
    def test_contains_department_sections(self, active):
        report = format_report(active)
        assert "Engineering" in report
        assert "Marketing" in report
        assert "HR" in report
        assert "Sales" in report

    def test_contains_overall_section(self, active):
        report = format_report(active)
        assert "Overall" in report

    def test_contains_headcount(self, active):
        report = format_report(active)
        assert "Headcount" in report or "headcount" in report

    def test_is_string(self, active):
        report = format_report(active)
        assert isinstance(report, str)


# ── Cycle 6: End-to-end generate_report writes to file ───────────────────────

class TestGenerateReport:
    def test_creates_output_file(self, csv_file, tmp_path):
        out = str(tmp_path / "report.txt")
        generate_report(csv_file, out)
        assert os.path.exists(out)

    def test_output_not_empty(self, csv_file, tmp_path):
        out = str(tmp_path / "report.txt")
        generate_report(csv_file, out)
        content = open(out).read()
        assert len(content) > 0

    def test_output_contains_departments(self, csv_file, tmp_path):
        out = str(tmp_path / "report.txt")
        generate_report(csv_file, out)
        content = open(out).read()
        assert "Engineering" in content
        assert "Overall" in content

    def test_bad_input_file(self, tmp_path):
        out = str(tmp_path / "report.txt")
        with pytest.raises(FileNotFoundError):
            generate_report("/nonexistent.csv", out)
