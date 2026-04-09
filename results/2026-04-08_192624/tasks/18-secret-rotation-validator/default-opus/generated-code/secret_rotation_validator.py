#!/usr/bin/env python3
"""
Secret Rotation Validator

Reads a JSON configuration of secrets with metadata, identifies secrets that are
expired or expiring within a configurable warning window, and generates a rotation
report grouped by urgency (expired, warning, ok).

Supports output formats: JSON, markdown table.

Usage:
    python3 secret_rotation_validator.py --config secrets.json [--warning-days 14] [--format json|markdown] [--reference-date YYYY-MM-DD]
"""

import argparse
import json
import sys
from datetime import datetime, timedelta


def parse_args(argv=None):
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Validate secret rotation status")
    parser.add_argument(
        "--config", required=True, help="Path to JSON config file with secret metadata"
    )
    parser.add_argument(
        "--warning-days",
        type=int,
        default=14,
        help="Number of days before expiry to trigger a warning (default: 14)",
    )
    parser.add_argument(
        "--format",
        choices=["json", "markdown"],
        default="json",
        help="Output format: json or markdown (default: json)",
    )
    parser.add_argument(
        "--reference-date",
        default=None,
        help="Reference date for calculations (YYYY-MM-DD). Defaults to today.",
    )
    return parser.parse_args(argv)


def load_config(config_path):
    """Load and validate the secrets configuration file."""
    try:
        with open(config_path, "r") as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: Config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in config file: {e}", file=sys.stderr)
        sys.exit(1)

    if "secrets" not in data or not isinstance(data["secrets"], list):
        print("Error: Config must contain a 'secrets' array", file=sys.stderr)
        sys.exit(1)

    required_fields = ["name", "last_rotated", "rotation_policy_days", "required_by"]
    for i, secret in enumerate(data["secrets"]):
        for field in required_fields:
            if field not in secret:
                print(
                    f"Error: Secret at index {i} missing required field '{field}'",
                    file=sys.stderr,
                )
                sys.exit(1)

    return data["secrets"]


def classify_secret(secret, reference_date, warning_days):
    """
    Classify a single secret into expired, warning, or ok.

    Returns a dict with the secret info plus:
      - status: 'expired', 'warning', or 'ok'
      - expires_on: the computed expiration date string
      - days_until_expiry: integer (negative means already expired)
    """
    last_rotated = datetime.strptime(secret["last_rotated"], "%Y-%m-%d").date()
    policy_days = secret["rotation_policy_days"]
    expires_on = last_rotated + timedelta(days=policy_days)
    days_until_expiry = (expires_on - reference_date).days

    if days_until_expiry < 0:
        status = "expired"
    elif days_until_expiry <= warning_days:
        status = "warning"
    else:
        status = "ok"

    return {
        "name": secret["name"],
        "last_rotated": secret["last_rotated"],
        "rotation_policy_days": policy_days,
        "required_by": secret["required_by"],
        "expires_on": expires_on.isoformat(),
        "days_until_expiry": days_until_expiry,
        "status": status,
    }


def generate_report(secrets, reference_date, warning_days):
    """
    Generate a full rotation report from a list of secrets.

    Returns a dict with:
      - reference_date: the date used for calculations
      - warning_days: the warning window
      - summary: counts per status
      - groups: { expired: [...], warning: [...], ok: [...] }
    """
    classified = [classify_secret(s, reference_date, warning_days) for s in secrets]

    groups = {"expired": [], "warning": [], "ok": []}
    for item in classified:
        groups[item["status"]].append(item)

    # Sort expired by most overdue first, warning by soonest first
    groups["expired"].sort(key=lambda x: x["days_until_expiry"])
    groups["warning"].sort(key=lambda x: x["days_until_expiry"])
    groups["ok"].sort(key=lambda x: x["days_until_expiry"])

    return {
        "reference_date": reference_date.isoformat(),
        "warning_days": warning_days,
        "summary": {
            "total": len(classified),
            "expired": len(groups["expired"]),
            "warning": len(groups["warning"]),
            "ok": len(groups["ok"]),
        },
        "groups": groups,
    }


def format_json(report):
    """Format report as JSON string."""
    return json.dumps(report, indent=2)


def format_markdown(report):
    """Format report as a markdown table grouped by urgency."""
    lines = []
    lines.append(f"# Secret Rotation Report")
    lines.append(f"")
    lines.append(f"**Reference Date:** {report['reference_date']}")
    lines.append(f"**Warning Window:** {report['warning_days']} days")
    lines.append(f"")
    lines.append(f"## Summary")
    lines.append(f"")
    s = report["summary"]
    lines.append(f"| Status | Count |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Expired | {s['expired']} |")
    lines.append(f"| Warning | {s['warning']} |")
    lines.append(f"| OK | {s['ok']} |")
    lines.append(f"| **Total** | **{s['total']}** |")
    lines.append(f"")

    for group_name, label in [
        ("expired", "EXPIRED"),
        ("warning", "WARNING"),
        ("ok", "OK"),
    ]:
        items = report["groups"][group_name]
        lines.append(f"## {label} ({len(items)})")
        lines.append(f"")
        if items:
            lines.append(
                f"| Name | Last Rotated | Policy (days) | Expires On | Days Until Expiry | Required By |"
            )
            lines.append(
                f"|------|-------------|---------------|------------|-------------------|-------------|"
            )
            for item in items:
                services = ", ".join(item["required_by"])
                lines.append(
                    f"| {item['name']} | {item['last_rotated']} | {item['rotation_policy_days']} | {item['expires_on']} | {item['days_until_expiry']} | {services} |"
                )
        else:
            lines.append("No secrets in this category.")
        lines.append(f"")

    return "\n".join(lines)


def main(argv=None):
    """Main entry point."""
    args = parse_args(argv)

    if args.reference_date:
        try:
            reference_date = datetime.strptime(args.reference_date, "%Y-%m-%d").date()
        except ValueError:
            print(
                f"Error: Invalid reference date format: {args.reference_date}. Use YYYY-MM-DD.",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        reference_date = datetime.now().date()

    secrets = load_config(args.config)
    report = generate_report(secrets, reference_date, args.warning_days)

    if args.format == "json":
        output = format_json(report)
    else:
        output = format_markdown(report)

    print(output)

    # Exit with non-zero if any secrets are expired
    if report["summary"]["expired"] > 0:
        sys.exit(2)


if __name__ == "__main__":
    main()
