"""
Employee Report Generator - Test Suite
=======================================

TDD approach (red/green cycles):

  Cycle 1 — CSV loading      : load_employees()
  Cycle 2 — Active filtering : filter_active()
  Cycle 3 — Dept aggregates  : dept_aggregates()
  Cycle 4 — Overall stats    : overall_stats()
  Cycle 5 — Report output    : generate_report()

Each class represents one cycle. Tests were written RED first (before any
implementation existed), then the minimum green code was added to pass them.
"""

import os
import pytest
import tempfile

# Module under test — import fails until report.py is created (first RED state).
from report import load_employees, filter_active, dept_aggregates, overall_stats, generate_report

# ---------------------------------------------------------------------------
# Shared in-memory fixtures (no file I/O needed for pure-logic tests)
# ---------------------------------------------------------------------------

FIXTURE_CSV = os.path.join(os.path.dirname(__file__), "fixtures", "employees.csv")

# A small, deterministic dataset used across multiple test classes.
SAMPLE_EMPLOYEES = [
    {"name": "Alice Johnson", "department": "Engineering", "salary": 95000.0, "hire_date": "2020-03-15", "status": "active"},
    {"name": "Bob Smith",     "department": "Marketing",   "salary": 72000.0, "hire_date": "2019-07-22", "status": "inactive"},
    {"name": "Carol White",   "department": "Engineering", "salary": 88000.0, "hire_date": "2021-01-10", "status": "active"},
    {"name": "David Brown",   "department": "HR",          "salary": 65000.0, "hire_date": "2018-05-30", "status": "active"},
    {"name": "Eve Davis",     "department": "Marketing",   "salary": 78000.0, "hire_date": "2022-11-05", "status": "active"},
]

# Pre-filtered view used by aggregate/stats tests.
ACTIVE_EMPLOYEES = [e for e in SAMPLE_EMPLOYEES if e["status"] == "active"]
# Active: Alice(Eng,95k), Carol(Eng,88k), David(HR,65k), Eve(Marketing,78k)


# ===========================================================================
# CYCLE 1: CSV LOADING
# RED  → import fails / AttributeError
# GREEN → implement load_employees()
# ===========================================================================

class TestLoadEmployees:
    """Verify that the CSV reader produces well-formed employee records."""

    def test_returns_a_list(self):
        """load_employees must return a list (not a generator or dict)."""
        result = load_employees(FIXTURE_CSV)
        assert isinstance(result, list)

    def test_list_is_non_empty(self):
        """Fixture CSV has 16 data rows; result must not be empty."""
        result = load_employees(FIXTURE_CSV)
        assert len(result) > 0

    def test_record_has_required_fields(self):
        """Every record must expose: name, department, salary, hire_date, status."""
        required = {"name", "department", "salary", "hire_date", "status"}
        for emp in load_employees(FIXTURE_CSV):
            assert required.issubset(emp.keys()), f"Missing fields in: {emp}"

    def test_salary_parsed_as_float(self):
        """Salary must be numeric (float) so arithmetic works downstream."""
        for emp in load_employees(FIXTURE_CSV):
            assert isinstance(emp["salary"], float), (
                f"Expected float, got {type(emp['salary'])} for {emp['name']}"
            )

    def test_status_is_lowercase(self):
        """Status values are normalised to lowercase for consistent filtering."""
        for emp in load_employees(FIXTURE_CSV):
            assert emp["status"] == emp["status"].lower()

    def test_missing_file_raises_file_not_found(self):
        """A clear FileNotFoundError (with the path) beats a cryptic traceback."""
        with pytest.raises(FileNotFoundError, match="not found"):
            load_employees("/no/such/file/employees.csv")

    def test_bad_columns_raise_value_error(self):
        """If required columns are absent the caller gets a descriptive ValueError."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False) as f:
            f.write("wrong_col,another_col\nfoo,bar\n")
            bad_path = f.name
        try:
            with pytest.raises(ValueError, match="missing required columns"):
                load_employees(bad_path)
        finally:
            os.unlink(bad_path)

    def test_all_fixture_rows_loaded(self):
        """Fixture has 16 data rows (header excluded)."""
        assert len(load_employees(FIXTURE_CSV)) == 16


# ===========================================================================
# CYCLE 2: ACTIVE EMPLOYEE FILTERING
# RED  → AttributeError (filter_active not yet defined)
# GREEN → implement filter_active()
# ===========================================================================

class TestFilterActive:
    """Verify that only employees with status == 'active' are retained."""

    def test_excludes_inactive_employees(self):
        result = filter_active(SAMPLE_EMPLOYEES)
        assert all(e["status"] == "active" for e in result)

    def test_correct_count_returned(self):
        expected = sum(1 for e in SAMPLE_EMPLOYEES if e["status"] == "active")
        assert len(filter_active(SAMPLE_EMPLOYEES)) == expected

    def test_empty_input_returns_empty_list(self):
        assert filter_active([]) == []

    def test_all_inactive_returns_empty_list(self):
        all_inactive = [
            {"name": "X", "department": "A", "salary": 50000.0,
             "hire_date": "2020-01-01", "status": "inactive"}
        ]
        assert filter_active(all_inactive) == []

    def test_all_active_returns_all(self):
        all_active = [e for e in SAMPLE_EMPLOYEES if e["status"] == "active"]
        assert filter_active(all_active) == all_active

    def test_fixture_csv_active_count(self):
        """Fixture CSV has 12 active employees (rows marked 'active')."""
        employees = load_employees(FIXTURE_CSV)
        active = filter_active(employees)
        assert len(active) == 12


# ===========================================================================
# CYCLE 3: DEPARTMENT AGGREGATES
# RED  → AttributeError (dept_aggregates not yet defined)
# GREEN → implement dept_aggregates()
# ===========================================================================

class TestDeptAggregates:
    """Verify per-department headcount and average salary computations."""

    def test_returns_dict(self):
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        assert isinstance(result, dict)

    def test_engineering_headcount(self):
        # Active Engineering: Alice, Carol → 2
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        assert result["Engineering"]["headcount"] == 2

    def test_hr_headcount(self):
        # Active HR: David → 1
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        assert result["HR"]["headcount"] == 1

    def test_marketing_headcount(self):
        # Active Marketing: Eve → 1
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        assert result["Marketing"]["headcount"] == 1

    def test_engineering_avg_salary(self):
        # (95000 + 88000) / 2 = 91500
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        assert result["Engineering"]["avg_salary"] == pytest.approx(91500.0)

    def test_hr_avg_salary(self):
        # 65000 / 1 = 65000
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        assert result["HR"]["avg_salary"] == pytest.approx(65000.0)

    def test_marketing_avg_salary(self):
        # 78000 / 1 = 78000
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        assert result["Marketing"]["avg_salary"] == pytest.approx(78000.0)

    def test_single_employee_department(self):
        """Edge case: a department with one employee should still compute correctly."""
        solo = [{"name": "Solo", "department": "Finance", "salary": 80000.0,
                 "hire_date": "2020-01-01", "status": "active"}]
        result = dept_aggregates(solo)
        assert result["Finance"]["headcount"] == 1
        assert result["Finance"]["avg_salary"] == pytest.approx(80000.0)

    def test_all_departments_present(self):
        """Result must contain exactly the departments found in the input."""
        result = dept_aggregates(ACTIVE_EMPLOYEES)
        expected_depts = {e["department"] for e in ACTIVE_EMPLOYEES}
        assert set(result.keys()) == expected_depts


# ===========================================================================
# CYCLE 4: OVERALL STATISTICS
# RED  → AttributeError (overall_stats not yet defined)
# GREEN → implement overall_stats()
# ===========================================================================

class TestOverallStats:
    """Verify aggregate statistics computed across all active employees."""

    def test_total_employees(self):
        result = overall_stats(ACTIVE_EMPLOYEES)
        assert result["total_employees"] == len(ACTIVE_EMPLOYEES)

    def test_avg_salary(self):
        expected = sum(e["salary"] for e in ACTIVE_EMPLOYEES) / len(ACTIVE_EMPLOYEES)
        result = overall_stats(ACTIVE_EMPLOYEES)
        assert result["avg_salary"] == pytest.approx(expected)

    def test_min_salary(self):
        expected_min = min(e["salary"] for e in ACTIVE_EMPLOYEES)
        result = overall_stats(ACTIVE_EMPLOYEES)
        assert result["min_salary"] == pytest.approx(expected_min)

    def test_max_salary(self):
        expected_max = max(e["salary"] for e in ACTIVE_EMPLOYEES)
        result = overall_stats(ACTIVE_EMPLOYEES)
        assert result["max_salary"] == pytest.approx(expected_max)

    def test_num_departments(self):
        expected = len({e["department"] for e in ACTIVE_EMPLOYEES})
        result = overall_stats(ACTIVE_EMPLOYEES)
        assert result["num_departments"] == expected

    def test_empty_input_returns_zero_stats(self):
        """Empty list must not raise; return zeroed-out stats instead."""
        result = overall_stats([])
        assert result["total_employees"] == 0
        assert result["avg_salary"] == 0.0
        assert result["min_salary"] == 0.0
        assert result["max_salary"] == 0.0
        assert result["num_departments"] == 0


# ===========================================================================
# CYCLE 5: REPORT GENERATION
# RED  → AttributeError (generate_report not yet defined)
# GREEN → implement generate_report()
# ===========================================================================

class TestGenerateReport:
    """Verify that a human-readable report file is written correctly."""

    def test_creates_output_file(self, tmp_path):
        output = str(tmp_path / "report.txt")
        generate_report(ACTIVE_EMPLOYEES, output)
        assert os.path.exists(output)

    def test_returns_report_as_string(self, tmp_path):
        output = str(tmp_path / "report.txt")
        result = generate_report(ACTIVE_EMPLOYEES, output)
        assert isinstance(result, str) and len(result) > 0

    def test_report_contains_department_names(self, tmp_path):
        output = str(tmp_path / "report.txt")
        generate_report(ACTIVE_EMPLOYEES, output)
        content = open(output).read()
        assert "Engineering" in content
        assert "HR" in content
        assert "Marketing" in content

    def test_report_contains_overall_stats_header(self, tmp_path):
        output = str(tmp_path / "report.txt")
        generate_report(ACTIVE_EMPLOYEES, output)
        content = open(output).read().upper()
        # Accept either word appearing in the report header.
        assert "OVERALL" in content or "STATISTICS" in content

    def test_report_contains_total_headcount(self, tmp_path):
        """Active employee count must appear somewhere in the report."""
        output = str(tmp_path / "report.txt")
        generate_report(ACTIVE_EMPLOYEES, output)
        content = open(output).read()
        assert str(len(ACTIVE_EMPLOYEES)) in content

    def test_report_contains_salary_figures(self, tmp_path):
        """At least one salary value must appear in the report."""
        output = str(tmp_path / "report.txt")
        generate_report(ACTIVE_EMPLOYEES, output)
        content = open(output).read()
        # Every salary in ACTIVE_EMPLOYEES should appear somewhere (formatted).
        salaries_found = any(
            str(int(e["salary"])) in content.replace(",", "")
            for e in ACTIVE_EMPLOYEES
        )
        assert salaries_found

    def test_empty_list_raises_value_error(self, tmp_path):
        """No active employees → ValueError with a meaningful message."""
        output = str(tmp_path / "report.txt")
        with pytest.raises(ValueError, match="no active employees"):
            generate_report([], output)

    def test_file_content_matches_return_value(self, tmp_path):
        """The string returned and the file contents must be identical."""
        output = str(tmp_path / "report.txt")
        returned = generate_report(ACTIVE_EMPLOYEES, output)
        on_disk = open(output).read()
        assert returned == on_disk

    def test_full_pipeline_with_fixture_csv(self, tmp_path):
        """End-to-end: load → filter → report. Smoke test using the real fixture."""
        employees = load_employees(FIXTURE_CSV)
        active = filter_active(employees)
        output = str(tmp_path / "full_report.txt")
        result = generate_report(active, output)
        assert os.path.exists(output)
        assert len(result) > 100  # non-trivial content
