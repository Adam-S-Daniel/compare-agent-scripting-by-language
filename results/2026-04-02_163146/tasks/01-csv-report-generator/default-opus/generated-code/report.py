#!/usr/bin/env python3
"""
CSV Employee Report Generator

Reads a CSV file of employee records, filters to active employees,
computes aggregates (avg salary, headcount by department, overall stats),
and outputs a formatted summary report.

Built using red/green TDD — each function was driven by a failing test first.
"""

import csv
import sys
from collections import defaultdict


def parse_csv(filepath):
    """Parse a CSV file into a list of employee dicts with typed salary field.

    Raises FileNotFoundError if the file doesn't exist, and ValueError if
    the file is empty or missing a header row.
    """
    with open(filepath, newline="") as f:
        content = f.read()

    if not content.strip():
        raise ValueError("CSV file is empty or missing header")

    rows = list(csv.DictReader(content.strip().splitlines()))

    # Convert salary to a numeric type
    for row in rows:
        try:
            row["salary"] = int(row["salary"])
        except (ValueError, KeyError):
            try:
                row["salary"] = float(row["salary"])
            except (ValueError, KeyError):
                raise ValueError(f"Invalid salary value for {row.get('name', '?')}: {row.get('salary')}")

    return rows


def filter_active(employees):
    """Return only employees whose status is 'active'."""
    return [e for e in employees if e.get("status") == "active"]


def aggregate_by_department(employees):
    """Compute per-department headcount, total salary, and average salary.

    Returns a dict keyed by department name, each value being a dict with
    keys: headcount, total_salary, avg_salary.
    """
    if not employees:
        return {}

    depts = defaultdict(lambda: {"headcount": 0, "total_salary": 0})

    for emp in employees:
        dept = emp["department"]
        depts[dept]["headcount"] += 1
        depts[dept]["total_salary"] += emp["salary"]

    # Compute averages after accumulating totals
    result = {}
    for dept, data in sorted(depts.items()):
        avg = data["total_salary"] / data["headcount"]
        result[dept] = {
            "headcount": data["headcount"],
            "total_salary": data["total_salary"],
            "avg_salary": round(avg, 2),
        }

    return result


def overall_stats(employees):
    """Compute overall statistics across all employees.

    Returns a dict with: total_headcount, avg_salary, min_salary, max_salary.
    """
    if not employees:
        return {"total_headcount": 0, "avg_salary": 0, "min_salary": 0, "max_salary": 0}

    salaries = [e["salary"] for e in employees]
    return {
        "total_headcount": len(employees),
        "avg_salary": round(sum(salaries) / len(salaries), 2),
        "min_salary": min(salaries),
        "max_salary": max(salaries),
    }


def format_report(employees):
    """Build a human-readable text report from a list of active employees."""
    dept_agg = aggregate_by_department(employees)
    stats = overall_stats(employees)

    lines = []
    lines.append("=" * 60)
    lines.append("         EMPLOYEE SUMMARY REPORT")
    lines.append("=" * 60)
    lines.append("")

    # Per-department breakdown
    lines.append("DEPARTMENT BREAKDOWN")
    lines.append("-" * 40)

    for dept, data in sorted(dept_agg.items()):
        lines.append(f"  {dept}")
        lines.append(f"    Headcount:      {data['headcount']}")
        lines.append(f"    Total Salary:   ${data['total_salary']:,.2f}")
        lines.append(f"    Avg Salary:     ${data['avg_salary']:,.2f}")
        lines.append("")

    # Overall statistics
    lines.append("Overall Statistics")
    lines.append("-" * 40)
    lines.append(f"  Total Headcount:  {stats['total_headcount']}")
    lines.append(f"  Average Salary:   ${stats['avg_salary']:,.2f}")
    lines.append(f"  Min Salary:       ${stats['min_salary']:,.2f}")
    lines.append(f"  Max Salary:       ${stats['max_salary']:,.2f}")
    lines.append("")
    lines.append("=" * 60)

    return "\n".join(lines)


def generate_report(input_csv, output_file):
    """End-to-end: read CSV, filter, aggregate, write formatted report."""
    employees = parse_csv(input_csv)
    active = filter_active(employees)
    report = format_report(active)

    with open(output_file, "w") as f:
        f.write(report)


# Allow standalone execution: python report.py input.csv output.txt
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
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
