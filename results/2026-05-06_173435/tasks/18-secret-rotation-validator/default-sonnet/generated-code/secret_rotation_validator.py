"""
Secret Rotation Validator

Given a JSON config of secrets with metadata, identifies expired/expiring
secrets and generates a rotation report grouped by urgency:
  - expired:  rotation deadline has passed
  - warning:  expires within the warning window (default 14 days)
  - ok:       more than warning-window days remaining

Supports JSON and Markdown output formats.

Usage:
  python3 secret_rotation_validator.py --config secrets-config.json \
      [--format json|markdown] [--warning-window N] [--reference-date YYYY-MM-DD]
"""

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Optional


# ---------------------------------------------------------------------------
# Domain model
# ---------------------------------------------------------------------------

@dataclass
class Secret:
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: list

    @property
    def expires_on(self) -> date:
        return self.last_rotated + timedelta(days=self.rotation_policy_days)

    def days_until_expiry(self, reference_date: date) -> int:
        return (self.expires_on - reference_date).days

    def status(self, reference_date: date, warning_window_days: int) -> str:
        days = self.days_until_expiry(reference_date)
        if days < 0:
            return "expired"
        if days <= warning_window_days:
            return "warning"
        return "ok"


@dataclass
class RotationReport:
    expired: list
    warning: list
    ok: list
    reference_date: date
    warning_window_days: int


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def load_config(config_path: str) -> dict:
    """Load and return the JSON config file."""
    with open(config_path) as f:
        return json.load(f)


def parse_secrets(config: dict) -> list:
    """Convert raw config dict into a list of Secret objects."""
    secrets = []
    for item in config.get("secrets", []):
        secrets.append(Secret(
            name=item["name"],
            last_rotated=date.fromisoformat(item["last_rotated"]),
            rotation_policy_days=item["rotation_policy_days"],
            required_by=item.get("required_by", []),
        ))
    return secrets


def generate_report(
    secrets: list,
    reference_date: date,
    warning_window_days: int,
) -> RotationReport:
    """Categorise each secret and return a RotationReport."""
    expired, warning, ok = [], [], []
    for s in secrets:
        days = s.days_until_expiry(reference_date)
        entry = {
            "name": s.name,
            "last_rotated": s.last_rotated.isoformat(),
            "expires_on": s.expires_on.isoformat(),
            "days_until_expiry": days,
            "rotation_policy_days": s.rotation_policy_days,
            "required_by": s.required_by,
        }
        bucket = s.status(reference_date, warning_window_days)
        if bucket == "expired":
            expired.append(entry)
        elif bucket == "warning":
            warning.append(entry)
        else:
            ok.append(entry)
    return RotationReport(
        expired=expired,
        warning=warning,
        ok=ok,
        reference_date=reference_date,
        warning_window_days=warning_window_days,
    )


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

def format_json(report: RotationReport) -> str:
    """Return the report as a pretty-printed JSON string."""
    return json.dumps({
        "reference_date": report.reference_date.isoformat(),
        "warning_window_days": report.warning_window_days,
        "summary": {
            "expired": len(report.expired),
            "warning": len(report.warning),
            "ok": len(report.ok),
        },
        "expired": report.expired,
        "warning": report.warning,
        "ok": report.ok,
    }, indent=2)


def format_markdown(report: RotationReport) -> str:
    """Return the report as a Markdown document with tables."""
    lines = [
        "# Secret Rotation Report",
        "",
        f"**Reference Date**: {report.reference_date}",
        f"**Warning Window**: {report.warning_window_days} days",
        "",
        "## Summary",
        "",
        "| Urgency | Count |",
        "|---------|-------|",
        f"| Expired | {len(report.expired)} |",
        f"| Warning | {len(report.warning)} |",
        f"| OK      | {len(report.ok)} |",
        "",
    ]

    def _table(title: str, entries: list) -> list:
        if not entries:
            return []
        rows = [
            f"## {title}",
            "",
            "| Name | Last Rotated | Expires On | Days | Required By |",
            "|------|-------------|------------|------|-------------|",
        ]
        for e in entries:
            required = ", ".join(e["required_by"]) if e["required_by"] else "-"
            rows.append(
                f"| {e['name']} | {e['last_rotated']} | {e['expires_on']} "
                f"| {e['days_until_expiry']} | {required} |"
            )
        rows.append("")
        return rows

    lines.extend(_table("Expired Secrets", report.expired))
    lines.extend(_table("Warning — Expiring Soon", report.warning))
    lines.extend(_table("OK — Current", report.ok))
    return "\n".join(lines)


def _print_ci_summary(report: RotationReport) -> None:
    """Print machine-parseable summary markers for CI pipeline assertions."""
    e_names = ",".join(s["name"] for s in report.expired) or "none"
    w_names = ",".join(s["name"] for s in report.warning) or "none"
    o_names = ",".join(s["name"] for s in report.ok) or "none"
    print(
        f"ROTATION-SUMMARY: "
        f"expired={len(report.expired)} "
        f"warning={len(report.warning)} "
        f"ok={len(report.ok)}"
    )
    print(f"EXPIRED-NAMES: {e_names}")
    print(f"WARNING-NAMES: {w_names}")
    print(f"OK-NAMES: {o_names}")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate secret rotation policies and produce a report."
    )
    parser.add_argument("--config", required=True, help="Path to secrets config JSON")
    parser.add_argument(
        "--format", choices=["json", "markdown"], default="json",
        help="Output format (default: json)",
    )
    parser.add_argument(
        "--warning-window", type=int, default=14,
        help="Days before expiry to start warning (default: 14)",
    )
    parser.add_argument(
        "--reference-date",
        help="Reference date YYYY-MM-DD (default: today)",
    )
    args = parser.parse_args(argv)

    reference_date = (
        date.fromisoformat(args.reference_date)
        if args.reference_date
        else date.today()
    )

    try:
        config = load_config(args.config)
        secrets = parse_secrets(config)
        report = generate_report(secrets, reference_date, args.warning_window)
    except FileNotFoundError:
        print(f"Error: config file not found: {args.config}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in {args.config}: {exc}", file=sys.stderr)
        return 1
    except (KeyError, ValueError) as exc:
        print(f"Error: malformed config: {exc}", file=sys.stderr)
        return 1

    # Print CI-parseable summary markers first (easy to grep in act logs)
    _print_ci_summary(report)
    print()

    # Print the requested format
    if args.format == "json":
        print(format_json(report))
    else:
        print(format_markdown(report))

    return 0


if __name__ == "__main__":
    sys.exit(main())
