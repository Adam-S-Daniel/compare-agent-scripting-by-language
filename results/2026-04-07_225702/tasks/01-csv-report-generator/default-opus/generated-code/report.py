"""CSV Employee Report Generator.

Reads employee CSV data, filters to active employees, computes aggregates
(per-department and overall), and writes a formatted summary report.

Each function is independently testable, following TDD principles.
"""

import csv
import sys
from collections import defaultdict


def parse_csv(filepath):
    """Parse a CSV file into a list of employee dicts.

    Converts salary to float; all other fields remain strings.
    Raises FileNotFoundError with a clear message if the file doesn't exist.
    """
    try:
        with open(filepath, newline="") as f:
            reader = csv.DictReader(f)
            employees = []
            for row in reader:
                row["salary"] = float(row["salary"])
                employees.append(row)
            return employees
    except FileNotFoundError:
        raise FileNotFoundError(f"CSV file not found: {filepath}")


def filter_active(employees):
    """Return only employees whose status is 'active'."""
    return [e for e in employees if e.get("status") == "active"]


def compute_department_stats(employees):
    """Compute per-department headcount, average salary, and total salary.

    Returns a dict keyed by department name, e.g.:
        {"Engineering": {"headcount": 4, "avg_salary": 100000.0, "total_salary": 400000.0}}
    """
    if not employees:
        return {}

    # Accumulate salaries per department
    dept_salaries = defaultdict(list)
    for emp in employees:
        dept_salaries[emp["department"]].append(emp["salary"])

    stats = {}
    for dept, salaries in sorted(dept_salaries.items()):
        total = sum(salaries)
        count = len(salaries)
        stats[dept] = {
            "headcount": count,
            "avg_salary": total / count,
            "total_salary": total,
        }
    return stats


def compute_overall_stats(employees):
    """Compute overall statistics across all employees.

    Returns a dict with total_employees, avg_salary, min_salary,
    max_salary, and total_payroll.
    """
    if not employees:
        return {
            "total_employees": 0,
            "avg_salary": 0.0,
            "min_salary": 0.0,
            "max_salary": 0.0,
            "total_payroll": 0.0,
        }

    salaries = [e["salary"] for e in employees]
    total = sum(salaries)
    return {
        "total_employees": len(employees),
        "avg_salary": total / len(employees),
        "min_salary": min(salaries),
        "max_salary": max(salaries),
        "total_payroll": total,
    }


def format_report(dept_stats, overall):
    """Build a formatted text report from computed statistics."""
    lines = []
    lines.append("=" * 60)
    lines.append("         EMPLOYEE SUMMARY REPORT")
    lines.append("=" * 60)
    lines.append("")

    # Department breakdown
    lines.append("-" * 60)
    lines.append("  Department Breakdown")
    lines.append("-" * 60)

    if dept_stats:
        for dept, stats in sorted(dept_stats.items()):
            lines.append(f"  {dept}")
            lines.append(f"    Headcount:      {stats['headcount']}")
            lines.append(f"    Avg Salary:     ${stats['avg_salary']:,.2f}")
            lines.append(f"    Total Salary:   ${stats['total_salary']:,.2f}")
            lines.append("")
    else:
        lines.append("  No active employees found.")
        lines.append("")

    # Overall statistics
    lines.append("-" * 60)
    lines.append("  Overall Statistics")
    lines.append("-" * 60)
    lines.append(f"    Total Employees:  {overall['total_employees']}")
    lines.append(f"    Average Salary:   ${overall['avg_salary']:,.2f}")
    lines.append(f"    Min Salary:       ${overall['min_salary']:,.2f}")
    lines.append(f"    Max Salary:       ${overall['max_salary']:,.2f}")
    lines.append(f"    Total Payroll:    ${overall['total_payroll']:,.2f}")
    lines.append("")
    lines.append("=" * 60)

    return "\n".join(lines)


def write_report(content, filepath):
    """Write report content to a text file."""
    with open(filepath, "w") as f:
        f.write(content)


def generate_report(csv_path, output_path):
    """End-to-end pipeline: read CSV -> filter -> aggregate -> write report."""
    employees = parse_csv(csv_path)
    active = filter_active(employees)
    dept_stats = compute_department_stats(active)
    overall = compute_overall_stats(active)
    report_text = format_report(dept_stats, overall)
    write_report(report_text, output_path)


# Allow running from the command line: python report.py input.csv output.txt
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.csv> <output.txt>", file=sys.stderr)
        sys.exit(1)

    try:
        generate_report(sys.argv[1], sys.argv[2])
        print(f"Report written to {sys.argv[2]}")
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)
