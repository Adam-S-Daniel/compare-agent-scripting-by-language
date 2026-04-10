#!/usr/bin/env python3
"""
Secret Rotation Validator

Identifies secrets that are expired or expiring within a configurable warning
window, generates a rotation report, and outputs notifications grouped by
urgency (expired, warning, ok). Supports markdown table and JSON output.

TDD Approach — each function was developed test-first:
  1. test_parse_config        -> parse_config()
  2. test_classify_secret     -> classify_secret()
  3. test_generate_report     -> generate_report()
  4. test_validate_secrets    -> validate_secrets() integration
  5. test_error_handling      -> error paths in all functions
"""

import json
import sys
import argparse
from datetime import datetime


def parse_config(config_path):
    """Parse secret configuration from a JSON file.

    RED:   test expects a dict with 'secrets' list from valid JSON file
    GREEN: read file, json.load, validate 'secrets' key exists and is a list
    """
    try:
        with open(config_path, "r") as f:
            config = json.load(f)
    except FileNotFoundError:
        raise ValueError(f"Configuration file not found: {config_path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in configuration file: {e}")

    if "secrets" not in config:
        raise ValueError("Configuration must contain a 'secrets' key")
    if not isinstance(config["secrets"], list):
        raise ValueError("'secrets' must be a list")

    return config


def classify_secret(secret, reference_date, warning_window_days):
    """Classify a single secret as expired, warning, or ok.

    RED:   test_classify_expired  — past rotation policy  -> 'expired'
    RED:   test_classify_warning  — within warning window -> 'warning'
    RED:   test_classify_ok       — well within policy    -> 'ok'
    GREEN: days_until_expiry = policy - (ref - last_rotated).days
    """
    required_fields = ["name", "last_rotated", "rotation_policy_days", "required_by"]
    for field in required_fields:
        if field not in secret:
            raise ValueError(f"Secret missing required field: '{field}'")

    try:
        last_rotated = datetime.strptime(secret["last_rotated"], "%Y-%m-%d")
    except ValueError:
        raise ValueError(
            f"Invalid date format for secret '{secret['name']}': "
            f"expected YYYY-MM-DD, got '{secret['last_rotated']}'"
        )

    days_since_rotation = (reference_date - last_rotated).days
    rotation_policy = secret["rotation_policy_days"]
    days_until_expiry = rotation_policy - days_since_rotation

    if days_until_expiry < 0:
        status = "expired"
    elif days_until_expiry <= warning_window_days:
        status = "warning"
    else:
        status = "ok"

    return {
        "name": secret["name"],
        "last_rotated": secret["last_rotated"],
        "rotation_policy_days": rotation_policy,
        "required_by": secret["required_by"],
        "days_since_rotation": days_since_rotation,
        "days_until_expiry": days_until_expiry,
        "status": status,
    }


def generate_report(classified_secrets, output_format):
    """Generate a rotation report in the specified format.

    RED:   test_report_json     — valid JSON with summary + grouped secrets
    RED:   test_report_markdown — markdown table with header row
    GREEN: group by status, dispatch to formatter
    """
    groups = {"expired": [], "warning": [], "ok": []}
    for secret in classified_secrets:
        groups[secret["status"]].append(secret)

    if output_format == "json":
        return _format_json(groups)
    elif output_format == "markdown":
        return _format_markdown(groups)
    else:
        raise ValueError(
            f"Unsupported output format: '{output_format}'. Use 'json' or 'markdown'."
        )


def _format_json(groups):
    """Format report as JSON with summary counts and grouped secrets."""
    report = {
        "summary": {
            "expired": len(groups["expired"]),
            "warning": len(groups["warning"]),
            "ok": len(groups["ok"]),
            "total": sum(len(v) for v in groups.values()),
        },
        "secrets": groups,
    }
    return json.dumps(report, indent=2)


def _format_markdown(groups):
    """Format report as a markdown table sorted by urgency."""
    lines = []
    lines.append("# Secret Rotation Report")
    lines.append("")

    total = sum(len(v) for v in groups.values())
    lines.append(
        f"**Total secrets:** {total} | "
        f"**Expired:** {len(groups['expired'])} | "
        f"**Warning:** {len(groups['warning'])} | "
        f"**OK:** {len(groups['ok'])}"
    )
    lines.append("")

    lines.append(
        "| Name | Status | Last Rotated | Policy (days) "
        "| Days Until Expiry | Required By |"
    )
    lines.append(
        "|------|--------|--------------|---------------"
        "|-------------------|-------------|"
    )

    # Expired first, then warning, then ok
    for status in ["expired", "warning", "ok"]:
        for s in groups[status]:
            required = ", ".join(s["required_by"])
            lines.append(
                f"| {s['name']} | {s['status'].upper()} | {s['last_rotated']} | "
                f"{s['rotation_policy_days']} | {s['days_until_expiry']} | {required} |"
            )

    lines.append("")
    return "\n".join(lines)


def validate_secrets(config_path, reference_date=None, warning_window=14,
                     output_format="json"):
    """Main entry point: parse config, classify secrets, generate report.

    RED:   test_validate_integration — full pipeline produces correct output
    GREEN: wire parse_config -> classify_secret -> generate_report
    """
    config = parse_config(config_path)

    if reference_date:
        ref_date = datetime.strptime(reference_date, "%Y-%m-%d")
    else:
        ref_date = datetime.now()

    # Config-level warning window overrides CLI default
    warn_days = config.get("warning_window_days", warning_window)

    classified = []
    for secret in config["secrets"]:
        classified.append(classify_secret(secret, ref_date, warn_days))

    return generate_report(classified, output_format)


def main():
    parser = argparse.ArgumentParser(description="Secret Rotation Validator")
    parser.add_argument("config", help="Path to secrets configuration JSON file")
    parser.add_argument(
        "--date", help="Reference date (YYYY-MM-DD), defaults to today"
    )
    parser.add_argument(
        "--warning-window", type=int, default=14,
        help="Warning window in days (default: 14)",
    )
    parser.add_argument(
        "--format", choices=["json", "markdown"], default="json",
        help="Output format (default: json)",
    )

    args = parser.parse_args()

    try:
        result = validate_secrets(
            args.config, args.date, args.warning_window, args.format
        )
        print(result)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
