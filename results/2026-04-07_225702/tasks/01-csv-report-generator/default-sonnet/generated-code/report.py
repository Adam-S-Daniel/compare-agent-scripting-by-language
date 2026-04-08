"""
Employee Report Generator
=========================

Core module implementing all CSV report generation logic.

Design decisions:
- Pure functions with no global state → easy to test in isolation.
- Salary stored as float throughout; formatting only happens in generate_report().
- Status values are normalised to lowercase on load so filtering is case-insensitive.
- generate_report() both writes the file AND returns the text so callers can
  inspect output without re-reading the file.
"""

import csv
from collections import defaultdict
from datetime import datetime


# ---------------------------------------------------------------------------
# Cycle 1 — CSV loading
# ---------------------------------------------------------------------------

def load_employees(filepath):
    """Read employee records from a CSV file and return a list of dicts.

    Each dict has keys: name (str), department (str), salary (float),
    hire_date (str), status (str, lowercased).

    Raises:
        FileNotFoundError: if filepath does not exist.
        ValueError: if required columns are absent from the CSV header.
    """
    required_cols = {"name", "department", "salary", "hire_date", "status"}

    try:
        with open(filepath, newline="", encoding="utf-8") as fh:
            reader = csv.DictReader(fh)
            header = set(reader.fieldnames or [])
            missing = required_cols - header
            if missing:
                raise ValueError(
                    f"CSV missing required columns: {sorted(missing)}"
                )
            employees = []
            for row in reader:
                employees.append({
                    "name":       row["name"].strip(),
                    "department": row["department"].strip(),
                    "salary":     float(row["salary"]),
                    "hire_date":  row["hire_date"].strip(),
                    "status":     row["status"].strip().lower(),
                })
            return employees
    except FileNotFoundError:
        raise FileNotFoundError(f"Employee data file not found: {filepath}")


# ---------------------------------------------------------------------------
# Cycle 2 — Active employee filtering
# ---------------------------------------------------------------------------

def filter_active(employees):
    """Return a new list containing only employees whose status is 'active'."""
    return [e for e in employees if e["status"] == "active"]


# ---------------------------------------------------------------------------
# Cycle 3 — Department aggregates
# ---------------------------------------------------------------------------

def dept_aggregates(employees):
    """Compute per-department headcount and average salary.

    Args:
        employees: list of employee dicts (should already be filtered to active).

    Returns:
        dict mapping department name → {"headcount": int, "avg_salary": float}
    """
    salaries_by_dept = defaultdict(list)
    for emp in employees:
        salaries_by_dept[emp["department"]].append(emp["salary"])

    return {
        dept: {
            "headcount":  len(salaries),
            "avg_salary": sum(salaries) / len(salaries),
        }
        for dept, salaries in salaries_by_dept.items()
    }


# ---------------------------------------------------------------------------
# Cycle 4 — Overall statistics
# ---------------------------------------------------------------------------

def overall_stats(employees):
    """Compute aggregate statistics across all supplied employees.

    Returns a dict with:
        total_employees (int), avg_salary (float), min_salary (float),
        max_salary (float), num_departments (int)

    Returns zeroed stats (not an error) for an empty list.
    """
    if not employees:
        return {
            "total_employees": 0,
            "avg_salary":      0.0,
            "min_salary":      0.0,
            "max_salary":      0.0,
            "num_departments": 0,
        }

    salaries    = [e["salary"]     for e in employees]
    departments = {e["department"] for e in employees}

    return {
        "total_employees": len(employees),
        "avg_salary":      sum(salaries) / len(salaries),
        "min_salary":      min(salaries),
        "max_salary":      max(salaries),
        "num_departments": len(departments),
    }


# ---------------------------------------------------------------------------
# Cycle 5 — Report generation
# ---------------------------------------------------------------------------

def generate_report(employees, output_path):
    """Write a formatted summary report to output_path and return the text.

    Args:
        employees: list of active employee dicts.
        output_path: file path where the report will be written.

    Returns:
        The report as a str (identical to what was written to disk).

    Raises:
        ValueError: if employees is empty (nothing meaningful to report).
    """
    if not employees:
        raise ValueError(
            "Cannot generate report: no active employees found."
        )

    dept_stats = dept_aggregates(employees)
    stats      = overall_stats(employees)

    W = 60  # report width

    lines = [
        "=" * W,
        "EMPLOYEE SUMMARY REPORT",
        f"Generated : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "=" * W,
        "",
        "OVERALL STATISTICS",
        "-" * 40,
        f"{'Total Active Employees':<24}: {stats['total_employees']}",
        f"{'Departments':<24}: {stats['num_departments']}",
        f"{'Average Salary':<24}: ${stats['avg_salary']:>12,.2f}",
        f"{'Min Salary':<24}: ${stats['min_salary']:>12,.2f}",
        f"{'Max Salary':<24}: ${stats['max_salary']:>12,.2f}",
        "",
        "BY DEPARTMENT",
        "-" * 40,
    ]

    # Sort departments alphabetically for deterministic output.
    for dept in sorted(dept_stats):
        d = dept_stats[dept]
        lines.append(f"  {dept}")
        lines.append(f"    {'Headcount':<20}: {d['headcount']}")
        lines.append(f"    {'Average Salary':<20}: ${d['avg_salary']:>12,.2f}")

    lines += ["", "=" * W]

    report_text = "\n".join(lines)

    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(report_text)

    return report_text


# ---------------------------------------------------------------------------
# CLI entry point — run the full pipeline against a supplied CSV
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print(
            "Usage: python3 report.py <employees.csv> <output_report.txt>",
            file=sys.stderr,
        )
        sys.exit(1)

    csv_path, report_path = sys.argv[1], sys.argv[2]

    try:
        employees = load_employees(csv_path)
        active    = filter_active(employees)

        print(f"Loaded {len(employees)} employees, {len(active)} active.")

        text = generate_report(active, report_path)

        print(f"Report written to: {report_path}")
        print()
        print(text)

    except (FileNotFoundError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
