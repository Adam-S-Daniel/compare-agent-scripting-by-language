"""
CSV Employee Report Generator

Reads employee CSV data, filters to active employees, computes department-level
and overall statistics, and outputs a formatted text report.

Built using TDD - each function corresponds to a test class in test_report.py.
"""

import csv
import sys


def parse_csv(filepath):
    """
    Parse a CSV file into a list of employee dicts.
    Converts salary to float for numeric operations.
    Raises FileNotFoundError if the file doesn't exist.
    """
    try:
        with open(filepath, newline="") as f:
            reader = csv.DictReader(f)
            employees = []
            for row in reader:
                # Convert salary string to float for calculations
                row["salary"] = float(row["salary"])
                employees.append(row)
            return employees
    except FileNotFoundError:
        raise FileNotFoundError(f"CSV file not found: {filepath}")


def filter_active(employees):
    """Return only employees whose status is 'active'."""
    return [e for e in employees if e["status"] == "active"]


def department_aggregates(employees):
    """
    Compute per-department headcount and average salary.
    Returns dict keyed by department name, each with 'headcount' and 'avg_salary'.
    """
    if not employees:
        return {}

    # Group salaries by department
    dept_salaries = {}
    for emp in employees:
        dept = emp["department"]
        dept_salaries.setdefault(dept, []).append(emp["salary"])

    return {
        dept: {
            "headcount": len(salaries),
            "avg_salary": sum(salaries) / len(salaries),
        }
        for dept, salaries in dept_salaries.items()
    }


def overall_statistics(employees):
    """
    Compute overall statistics: total headcount, average/min/max salary, total payroll.
    Returns a dict of stats. Handles empty employee list gracefully.
    """
    if not employees:
        return {
            "total_headcount": 0,
            "avg_salary": 0,
            "min_salary": 0,
            "max_salary": 0,
            "total_payroll": 0,
        }

    salaries = [e["salary"] for e in employees]
    return {
        "total_headcount": len(employees),
        "avg_salary": sum(salaries) / len(salaries),
        "min_salary": min(salaries),
        "max_salary": max(salaries),
        "total_payroll": sum(salaries),
    }


def format_report(dept_aggs, overall):
    """
    Format department aggregates and overall stats into a readable text report.
    Salaries are formatted with commas and dollar signs.
    """
    lines = []
    lines.append("=" * 55)
    lines.append("       EMPLOYEE SUMMARY REPORT")
    lines.append("=" * 55)
    lines.append("")

    # Department breakdown, sorted alphabetically
    lines.append("--- Department Breakdown ---")
    lines.append("")
    for dept in sorted(dept_aggs):
        info = dept_aggs[dept]
        lines.append(f"  {dept}")
        lines.append(f"    Headcount:      {info['headcount']}")
        lines.append(f"    Average Salary: ${info['avg_salary']:,.0f}")
        lines.append("")

    # Overall statistics
    lines.append("--- Overall Statistics ---")
    lines.append("")
    lines.append(f"  Total Headcount:  {overall['total_headcount']}")
    lines.append(f"  Average Salary:   ${overall['avg_salary']:,.0f}")
    lines.append(f"  Min Salary:       ${overall['min_salary']:,.0f}")
    lines.append(f"  Max Salary:       ${overall['max_salary']:,.0f}")
    lines.append(f"  Total Payroll:    ${overall['total_payroll']:,.0f}")
    lines.append("")
    lines.append("=" * 55)

    return "\n".join(lines)


def write_report(text, filepath):
    """
    Write report text to a file.
    Raises OSError if the directory doesn't exist.
    """
    with open(filepath, "w") as f:
        f.write(text)


def generate_report(csv_path, output_path):
    """
    End-to-end pipeline: read CSV -> filter active -> compute stats -> write report.
    """
    employees = parse_csv(csv_path)
    active = filter_active(employees)
    dept_aggs = department_aggregates(active)
    overall = overall_statistics(active)
    text = format_report(dept_aggs, overall)
    write_report(text, output_path)
    return text


if __name__ == "__main__":
    # CLI usage: python report.py <input.csv> [output.txt]
    if len(sys.argv) < 2:
        print("Usage: python report.py <input.csv> [output.txt]")
        print("  If output.txt is omitted, prints to stdout.")
        sys.exit(1)

    csv_file = sys.argv[1]
    out_file = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        employees = parse_csv(csv_file)
        active = filter_active(employees)
        dept_aggs = department_aggregates(active)
        overall = overall_statistics(active)
        report = format_report(dept_aggs, overall)

        if out_file:
            write_report(report, out_file)
            print(f"Report written to {out_file}")
        else:
            print(report)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error generating report: {e}", file=sys.stderr)
        sys.exit(1)
