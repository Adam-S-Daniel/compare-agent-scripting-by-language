#!/usr/bin/env python3
"""Secret rotation validator — identifies expired/expiring secrets and generates reports.

Reads a JSON config of secrets with metadata (name, last-rotated date, rotation policy,
required-by services), classifies each by urgency (expired, warning, ok), and outputs
a grouped rotation report in JSON or markdown format.
"""

import argparse
import json
import sys
from datetime import date, datetime


def classify_secret(
    secret: dict, reference_date: date, warning_window_days: int
) -> dict:
    """Classify a secret as expired, warning, or ok based on its rotation policy."""
    last_rotated = datetime.strptime(secret["last_rotated"], "%Y-%m-%d").date()
    days_since_rotation = (reference_date - last_rotated).days
    days_until_expiry = secret["rotation_policy_days"] - days_since_rotation

    if days_until_expiry <= 0:
        status = "expired"
    elif days_until_expiry <= warning_window_days:
        status = "warning"
    else:
        status = "ok"

    return {
        **secret,
        "days_since_rotation": days_since_rotation,
        "days_until_expiry": days_until_expiry,
        "status": status,
    }


def validate_config(config: dict) -> list[str]:
    """Validate top-level config structure. Returns a list of error messages."""
    errors = []
    if "secrets" not in config:
        errors.append("Config missing required field: 'secrets'")
        return errors
    if not config["secrets"]:
        errors.append("Config 'secrets' list is empty")
    ww = config.get("warning_window_days", 14)
    if not isinstance(ww, (int, float)) or ww < 0:
        errors.append("warning_window_days must be a non-negative number")
    return errors


def validate_secrets(secrets: list[dict]) -> list[str]:
    """Validate each secret entry. Returns a list of error messages."""
    errors = []
    for i, s in enumerate(secrets):
        prefix = f"Secret #{i + 1}"
        if "name" not in s:
            errors.append(f"{prefix}: missing required field 'name'")
            continue
        prefix = f"Secret '{s['name']}'"
        if "last_rotated" not in s:
            errors.append(f"{prefix}: missing 'last_rotated' date")
        else:
            try:
                datetime.strptime(s["last_rotated"], "%Y-%m-%d")
            except ValueError:
                errors.append(
                    f"{prefix}: invalid date format '{s['last_rotated']}' (expected YYYY-MM-DD)"
                )
        if "rotation_policy_days" not in s:
            errors.append(f"{prefix}: missing 'rotation_policy_days'")
        elif not isinstance(s["rotation_policy_days"], (int, float)) or s["rotation_policy_days"] <= 0:
            errors.append(f"{prefix}: rotation policy_days must be a positive number")
        if "required_by" not in s:
            errors.append(f"{prefix}: missing 'required_by'")
    return errors


def load_config(path: str) -> dict:
    """Load and parse a JSON config file."""
    with open(path) as f:
        return json.load(f)


def generate_json_report(config: dict, reference_date: date) -> dict:
    """Generate a JSON report grouping secrets by urgency."""
    warning_window = config.get("warning_window_days", 14)
    classified = [
        classify_secret(s, reference_date, warning_window) for s in config["secrets"]
    ]

    groups = {"expired": [], "warning": [], "ok": []}
    for s in classified:
        groups[s["status"]].append(s)

    # Sort: expired by days_until_expiry ascending (most overdue first),
    # warning/ok by days_until_expiry ascending (soonest expiry first)
    for key in groups:
        groups[key].sort(key=lambda s: s["days_until_expiry"])

    return {
        "reference_date": reference_date.isoformat(),
        "warning_window_days": warning_window,
        "summary": {
            "total": len(classified),
            "expired": len(groups["expired"]),
            "warning": len(groups["warning"]),
            "ok": len(groups["ok"]),
        },
        "secrets": groups,
    }


def generate_markdown_report(config: dict, reference_date: date) -> str:
    """Generate a markdown table report grouping secrets by urgency."""
    report = generate_json_report(config, reference_date)
    lines = []

    lines.append("# Secret Rotation Report")
    lines.append("")
    lines.append(f"**Reference Date:** {report['reference_date']}")
    lines.append(f"**Warning Window:** {report['warning_window_days']} days")
    lines.append("")

    # Summary table
    lines.append("## Summary")
    lines.append("")
    lines.append("| Status | Count |")
    lines.append("|--------|-------|")
    lines.append(f"| Expired | {report['summary']['expired']} |")
    lines.append(f"| Warning | {report['summary']['warning']} |")
    lines.append(f"| OK | {report['summary']['ok']} |")
    lines.append(f"| **Total** | **{report['summary']['total']}** |")
    lines.append("")

    # Expired secrets
    expired = report["secrets"]["expired"]
    lines.append(f"## Expired Secrets ({len(expired)})")
    lines.append("")
    if expired:
        lines.append("| Name | Last Rotated | Policy (days) | Days Overdue | Required By |")
        lines.append("|------|--------------|---------------|--------------|-------------|")
        for s in expired:
            services = ", ".join(s["required_by"])
            lines.append(
                f"| {s['name']} | {s['last_rotated']} | {s['rotation_policy_days']}"
                f" | {abs(s['days_until_expiry'])} | {services} |"
            )
    else:
        lines.append("No expired secrets.")
    lines.append("")

    # Warning secrets
    warning = report["secrets"]["warning"]
    lines.append(f"## Warning Secrets ({len(warning)})")
    lines.append("")
    if warning:
        lines.append("| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |")
        lines.append("|------|--------------|---------------|-------------------|-------------|")
        for s in warning:
            services = ", ".join(s["required_by"])
            lines.append(
                f"| {s['name']} | {s['last_rotated']} | {s['rotation_policy_days']}"
                f" | {s['days_until_expiry']} | {services} |"
            )
    else:
        lines.append("No secrets in warning state.")
    lines.append("")

    # OK secrets
    ok = report["secrets"]["ok"]
    lines.append(f"## OK Secrets ({len(ok)})")
    lines.append("")
    if ok:
        lines.append("| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |")
        lines.append("|------|--------------|---------------|-------------------|-------------|")
        for s in ok:
            services = ", ".join(s["required_by"])
            lines.append(
                f"| {s['name']} | {s['last_rotated']} | {s['rotation_policy_days']}"
                f" | {s['days_until_expiry']} | {services} |"
            )
    else:
        lines.append("No secrets in ok state.")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Secret Rotation Validator")
    parser.add_argument("--config", required=True, help="Path to secrets config JSON")
    parser.add_argument(
        "--format",
        choices=["json", "markdown"],
        default="json",
        help="Output format (default: json)",
    )
    parser.add_argument(
        "--reference-date",
        help="Reference date for expiry calculation (YYYY-MM-DD, default: today)",
    )
    parser.add_argument(
        "--warning-window",
        type=int,
        help="Override warning window days from config",
    )
    args = parser.parse_args()

    # Load and validate config
    try:
        config = load_config(args.config)
    except FileNotFoundError:
        print(f"Error: config file not found: {args.config}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in config: {e}", file=sys.stderr)
        sys.exit(1)

    errors = validate_config(config)
    if not errors:
        errors.extend(validate_secrets(config["secrets"]))
    if errors:
        print("Validation errors:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    # Apply overrides
    if args.warning_window is not None:
        config["warning_window_days"] = args.warning_window

    # Determine reference date
    if args.reference_date:
        try:
            ref_date = datetime.strptime(args.reference_date, "%Y-%m-%d").date()
        except ValueError:
            print(
                f"Error: invalid reference date '{args.reference_date}' (expected YYYY-MM-DD)",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        ref_date = date.today()

    # Generate and output report
    if args.format == "json":
        report = generate_json_report(config, ref_date)
        print(json.dumps(report, indent=2))
    else:
        print(generate_markdown_report(config, ref_date))


if __name__ == "__main__":
    main()
