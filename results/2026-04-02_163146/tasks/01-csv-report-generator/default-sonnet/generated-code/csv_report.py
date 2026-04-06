"""
CSV Report Generator
====================
Reads a CSV file of employee records, filters to active employees,
computes department and overall aggregates, and writes a formatted
text summary report.

TDD approach:
  - Tests in test_csv_report.py drove each function in this module.
  - Functions are intentionally small and independently testable.
"""

import csv
from pathlib import Path
from collections import defaultdict
from typing import Any


# ─────────────────────────────────────────────
# 1. Parsing
# ─────────────────────────────────────────────

def parse_csv(file_path: str) -> list[dict[str, str]]:
    """
    Read a CSV file and return a list of row dicts.

    Each dict contains string values keyed by column header.
    Raises FileNotFoundError with the file path in the message if the
    file does not exist.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"CSV file not found: {file_path}")

    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        return [dict(row) for row in reader]


# ─────────────────────────────────────────────
# 2. Filtering
# ─────────────────────────────────────────────

def filter_active(records: list[dict[str, str]]) -> list[dict[str, str]]:
    """
    Return only records where status == 'active' (case-insensitive).
    """
    return [r for r in records if r.get("status", "").strip().lower() == "active"]


# ─────────────────────────────────────────────
# 3. Department aggregates
# ─────────────────────────────────────────────

def compute_department_stats(records: list[dict[str, str]]) -> dict[str, dict[str, Any]]:
    """
    Compute headcount and average salary grouped by department.

    Returns:
        {
          "Engineering": {"headcount": 3, "avg_salary": 92500.0},
          ...
        }
    """
    if not records:
        return {}

    buckets: dict[str, list[float]] = defaultdict(list)
    for r in records:
        dept   = r.get("department", "Unknown").strip()
        salary = float(r.get("salary", 0))
        buckets[dept].append(salary)

    return {
        dept: {
            "headcount":  len(salaries),
            "avg_salary": sum(salaries) / len(salaries),
        }
        for dept, salaries in sorted(buckets.items())
    }


# ─────────────────────────────────────────────
# 4. Overall statistics
# ─────────────────────────────────────────────

def compute_overall_stats(records: list[dict[str, str]]) -> dict[str, Any]:
    """
    Compute overall statistics across all (active) employees.

    Returns a dict with:
      - total_employees
      - avg_salary
      - min_salary
      - max_salary
      - department_count
    """
    if not records:
        return {
            "total_employees":  0,
            "avg_salary":       0.0,
            "min_salary":       0.0,
            "max_salary":       0.0,
            "department_count": 0,
        }

    salaries = [float(r.get("salary", 0)) for r in records]
    departments = {r.get("department", "Unknown").strip() for r in records}

    return {
        "total_employees":  len(records),
        "avg_salary":       sum(salaries) / len(salaries),
        "min_salary":       min(salaries),
        "max_salary":       max(salaries),
        "department_count": len(departments),
    }


# ─────────────────────────────────────────────
# 5. Report generation
# ─────────────────────────────────────────────

def generate_report(
    dept_stats:    dict[str, dict[str, Any]],
    overall_stats: dict[str, Any],
    output_path:   str,
) -> None:
    """
    Write a formatted human-readable summary report to *output_path*.

    The report contains:
      - A header
      - Per-department section: headcount + average salary
      - An overall statistics section
    """
    lines: list[str] = []

    _sep  = "=" * 60
    _dash = "-" * 60

    # ── Header ──────────────────────────────────────────────────
    lines.append(_sep)
    lines.append("  EMPLOYEE SALARY REPORT — ACTIVE EMPLOYEES ONLY")
    lines.append(_sep)
    lines.append("")

    # ── Department breakdown ─────────────────────────────────────
    lines.append("DEPARTMENT BREAKDOWN")
    lines.append(_dash)
    lines.append(f"{'Department':<20} {'Headcount':>10} {'Avg Salary':>14}")
    lines.append(_dash)

    for dept, stats in dept_stats.items():
        avg_fmt = f"${stats['avg_salary']:>12,.2f}"
        lines.append(f"{dept:<20} {stats['headcount']:>10} {avg_fmt}")

    lines.append(_dash)
    lines.append("")

    # ── Overall statistics ───────────────────────────────────────
    lines.append("OVERALL STATISTICS")
    lines.append(_dash)
    lines.append(f"  Total active employees : {overall_stats['total_employees']}")
    lines.append(f"  Departments            : {overall_stats['department_count']}")
    lines.append(f"  Average salary         : ${overall_stats['avg_salary']:,.2f}")
    lines.append(f"  Minimum salary         : ${overall_stats['min_salary']:,.2f}")
    lines.append(f"  Maximum salary         : ${overall_stats['max_salary']:,.2f}")
    lines.append(_sep)
    lines.append("")

    report_text = "\n".join(lines)
    Path(output_path).write_text(report_text, encoding="utf-8")


# ─────────────────────────────────────────────
# CLI entry point
# ─────────────────────────────────────────────

def main() -> None:
    """
    Run the full pipeline:
      1. Parse fixtures/employees.csv
      2. Filter active employees
      3. Compute department and overall stats
      4. Write report.txt
    """
    import sys

    input_csv  = sys.argv[1] if len(sys.argv) > 1 else "fixtures/employees.csv"
    output_txt = sys.argv[2] if len(sys.argv) > 2 else "report.txt"

    try:
        records       = parse_csv(input_csv)
        active        = filter_active(records)
        dept_stats    = compute_department_stats(active)
        overall_stats = compute_overall_stats(active)
        generate_report(dept_stats, overall_stats, output_txt)
        print(f"Report written to: {output_txt}")
        print(f"Active employees: {overall_stats['total_employees']} "
              f"across {overall_stats['department_count']} departments")
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
