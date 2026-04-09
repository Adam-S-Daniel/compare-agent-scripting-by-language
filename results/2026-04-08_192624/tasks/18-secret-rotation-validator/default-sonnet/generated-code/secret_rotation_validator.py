#!/usr/bin/env python3
"""
Secret Rotation Validator
=========================
Reads a JSON config of secrets with rotation metadata, identifies secrets
that are expired or approaching expiry, and generates a report grouped by
urgency: expired / warning / ok.

Supports two output formats: markdown table and JSON.

Usage:
    python secret_rotation_validator.py secrets.json [options]

Options:
    --warning-days INT     Days before expiry to show as warning  (default: 30)
    --format {markdown,json}  Output format                       (default: markdown)
    --reference-date YYYY-MM-DD  Override "today" for testing     (default: today)

Exit codes:
    0  — all secrets OK or only warnings
    1  — one or more secrets are expired (useful as a CI gate)
"""

import argparse
import json
import sys
from datetime import date, datetime
from typing import Optional

# Urgency levels ordered by severity (most urgent first)
URGENCY_LEVELS = ["expired", "warning", "ok"]


# ---------------------------------------------------------------------------
# TDD Cycle 5 (GREEN): load_secrets
# ---------------------------------------------------------------------------

def load_secrets(filepath: str) -> list:
    """Load and parse a secrets configuration JSON file.

    Expects a JSON array of secret objects.  Raises informative errors
    so callers get actionable messages rather than raw Python exceptions.
    """
    try:
        with open(filepath, "r") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        raise FileNotFoundError(f"Secrets config file not found: {filepath}")
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in secrets config '{filepath}': {exc}")

    if not isinstance(data, list):
        raise ValueError(
            f"Secrets config must be a JSON array; got {type(data).__name__}"
        )
    return data


# ---------------------------------------------------------------------------
# TDD Cycle 1 (GREEN): calculate_secret_status
# ---------------------------------------------------------------------------

def calculate_secret_status(
    secret: dict,
    warning_days: int,
    reference_date: Optional[date] = None,
) -> dict:
    """Calculate rotation status for a single secret.

    Returns a new dict containing all original fields plus:
      - days_since_rotation  (int)
      - days_until_expiry    (int, negative means overdue)
      - status               ('expired' | 'warning' | 'ok')
    """
    ref = reference_date or date.today()

    # Validate required fields
    for field in ("name", "last_rotated", "rotation_days"):
        if field not in secret:
            raise ValueError(
                f"Secret is missing required field '{field}': {secret}"
            )

    try:
        rotated_date = datetime.strptime(secret["last_rotated"], "%Y-%m-%d").date()
    except ValueError:
        raise ValueError(
            f"Invalid date format for secret '{secret['name']}': "
            f"'{secret['last_rotated']}' (expected YYYY-MM-DD)"
        )

    days_since = (ref - rotated_date).days
    days_until = secret["rotation_days"] - days_since

    if days_until < 0:
        status = "expired"
    elif days_until <= warning_days:
        status = "warning"
    else:
        status = "ok"

    return {
        **secret,
        "days_since_rotation": days_since,
        "days_until_expiry": days_until,
        "status": status,
    }


# ---------------------------------------------------------------------------
# TDD Cycle 2 (GREEN): analyze_secrets
# ---------------------------------------------------------------------------

def analyze_secrets(
    secrets: list,
    warning_days: int,
    reference_date: Optional[date] = None,
) -> dict:
    """Analyze all secrets and group results by urgency.

    Returns:
        {
          "expired": [...],
          "warning": [...],
          "ok":      [...]
        }
    """
    result: dict = {"expired": [], "warning": [], "ok": []}
    for secret in secrets:
        enriched = calculate_secret_status(secret, warning_days, reference_date)
        result[enriched["status"]].append(enriched)
    return result


# ---------------------------------------------------------------------------
# TDD Cycle 3 (GREEN): format_markdown
# ---------------------------------------------------------------------------

def format_markdown(analysis: dict) -> str:
    """Render the analysis as a Markdown report with per-urgency tables."""
    total = sum(len(v) for v in analysis.values())
    expired_count = len(analysis["expired"])
    warning_count = len(analysis["warning"])
    ok_count = len(analysis["ok"])

    lines = [
        "# Secret Rotation Report",
        "",
        f"**Total secrets:** {total}",
        f"**Expired:** {expired_count}",
        f"**Warning:** {warning_count}",
        f"**OK:** {ok_count}",
        "",
    ]

    for urgency in URGENCY_LEVELS:
        secrets = analysis[urgency]
        lines.append(f"## {urgency.upper()} ({len(secrets)})")
        lines.append("")

        if not secrets:
            lines.append("_No secrets in this category._")
            lines.append("")
            continue

        lines.append(
            "| Name | Last Rotated | Days Since Rotation | Days Until Expiry | Required By |"
        )
        lines.append(
            "|------|-------------|---------------------|-------------------|-------------|"
        )

        for s in secrets:
            required_by = (
                ", ".join(s["required_by"]) if s.get("required_by") else "-"
            )
            until = s["days_until_expiry"]
            until_str = (
                f"OVERDUE by {abs(until)} days" if until < 0 else str(until)
            )
            lines.append(
                f"| {s['name']} | {s['last_rotated']} "
                f"| {s['days_since_rotation']} "
                f"| {until_str} "
                f"| {required_by} |"
            )

        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# TDD Cycle 4 (GREEN): format_json
# ---------------------------------------------------------------------------

def format_json(analysis: dict) -> str:
    """Render the analysis as pretty-printed JSON."""
    output = {
        "summary": {
            "total": sum(len(v) for v in analysis.values()),
            "expired": len(analysis["expired"]),
            "warning": len(analysis["warning"]),
            "ok": len(analysis["ok"]),
        },
        "secrets": analysis,
    }
    return json.dumps(output, indent=2, default=str)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate secret rotation policies and generate reports."
    )
    parser.add_argument("secrets_file", help="Path to secrets configuration JSON")
    parser.add_argument(
        "--warning-days",
        type=int,
        default=30,
        metavar="DAYS",
        help="Days before expiry to issue a warning (default: 30)",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--reference-date",
        metavar="YYYY-MM-DD",
        help="Override today's date for calculations (useful for testing)",
    )

    args = parser.parse_args(argv)

    # Resolve optional reference date
    reference_date: Optional[date] = None
    if args.reference_date:
        try:
            reference_date = datetime.strptime(args.reference_date, "%Y-%m-%d").date()
        except ValueError:
            print(
                f"Error: invalid --reference-date '{args.reference_date}' "
                f"(expected YYYY-MM-DD)",
                file=sys.stderr,
            )
            return 1

    # Load secrets
    try:
        secrets = load_secrets(args.secrets_file)
    except (FileNotFoundError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    # Analyse
    try:
        analysis = analyze_secrets(secrets, args.warning_days, reference_date)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    # Render and print
    if args.format == "json":
        print(format_json(analysis))
    else:
        print(format_markdown(analysis))

    # Non-zero exit when expired secrets exist (useful as a CI gate)
    return 1 if analysis["expired"] else 0


if __name__ == "__main__":
    sys.exit(main())
