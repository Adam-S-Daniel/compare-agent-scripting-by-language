#!/usr/bin/env python3
"""
Secret Rotation Validator

Loads secrets with rotation metadata, computes their urgency relative to a
configurable warning window, generates a grouped report, and outputs it as
either a Markdown table or JSON.

TDD note: tests in tests/test_secret_rotation.py were written first (failing),
then this module was written to make them pass.
"""

import argparse
import json
import sys
from datetime import date, timedelta
from pathlib import Path


# ── Data loading ──────────────────────────────────────────────────────────────

def load_secrets(config_path: str) -> list[dict]:
    """Load secrets list from a JSON config file.

    Accepts either a top-level list or {"secrets": [...]} envelope.
    Raises FileNotFoundError or ValueError on bad input.
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in config {config_path!r}: {exc}") from exc

    if isinstance(raw, dict):
        return raw.get("secrets", [])
    if isinstance(raw, list):
        return raw
    raise ValueError(f"Expected a list or {{\"secrets\": [...]}} object, got {type(raw).__name__}")


# ── Status computation ────────────────────────────────────────────────────────

def check_secret_status(
    secret: dict,
    reference_date: date,
    warning_days: int = 14,
) -> dict:
    """Return a status dict for a single secret.

    Urgency rules:
      expired : days_until_expiry < 0  (rotation deadline has passed)
      warning : 0 <= days_until_expiry <= warning_days
      ok      : days_until_expiry > warning_days
    """
    last_rotated = date.fromisoformat(secret["last_rotated"])
    rotation_days: int = secret["rotation_days"]
    expiry_date = last_rotated + timedelta(days=rotation_days)
    days_until_expiry = (expiry_date - reference_date).days
    days_since_rotation = (reference_date - last_rotated).days

    if days_until_expiry < 0:
        urgency = "expired"
    elif days_until_expiry <= warning_days:
        urgency = "warning"
    else:
        urgency = "ok"

    return {
        "name": secret["name"],
        "last_rotated": secret["last_rotated"],
        "rotation_days": rotation_days,
        "required_by": secret.get("required_by", []),
        "days_since_rotation": days_since_rotation,
        "days_until_expiry": days_until_expiry,
        "expiry_date": expiry_date.isoformat(),
        "urgency": urgency,
    }


# ── Report generation ─────────────────────────────────────────────────────────

def generate_report(
    secrets: list[dict],
    reference_date: date,
    warning_days: int = 14,
) -> dict:
    """Generate a rotation report grouped by urgency level."""
    results = [check_secret_status(s, reference_date, warning_days) for s in secrets]

    expired = [r for r in results if r["urgency"] == "expired"]
    warning = [r for r in results if r["urgency"] == "warning"]
    ok = [r for r in results if r["urgency"] == "ok"]

    return {
        "generated_at": reference_date.isoformat(),
        "warning_window_days": warning_days,
        "expired": expired,
        "warning": warning,
        "ok": ok,
        "summary": {
            "total": len(results),
            "expired_count": len(expired),
            "warning_count": len(warning),
            "ok_count": len(ok),
        },
    }


# ── Output formatters ─────────────────────────────────────────────────────────

_STATUS_LABEL = {"expired": "EXPIRED", "warning": "WARNING", "ok": "OK"}


def format_markdown(report: dict) -> str:
    """Render the report as a Markdown table grouped by urgency."""
    s = report["summary"]
    lines = [
        "# Secret Rotation Report",
        "",
        f"Generated: {report['generated_at']}  "
        f"| Warning window: {report['warning_window_days']} days",
        "",
        f"**Summary**: {s['total']} total | "
        f"{s['expired_count']} expired | "
        f"{s['warning_count']} warning | "
        f"{s['ok_count']} ok",
        "",
    ]

    all_secrets = report["expired"] + report["warning"] + report["ok"]
    if not all_secrets:
        lines.append("_No secrets configured._")
        return "\n".join(lines)

    lines += [
        "| Status | Secret Name | Last Rotated | Days Until Expiry | Required By |",
        "|--------|-------------|--------------|-------------------|-------------|",
    ]

    for sec in all_secrets:
        days = sec["days_until_expiry"]
        days_str = str(days) if days >= 0 else f"{days} (overdue)"
        services = ", ".join(sec["required_by"]) if sec["required_by"] else "—"
        label = _STATUS_LABEL[sec["urgency"]]
        lines.append(
            f"| {label:<7} | {sec['name']:<11} | {sec['last_rotated']} "
            f"| {days_str:<17} | {services} |"
        )

    return "\n".join(lines)


def format_json(report: dict) -> str:
    """Serialize the report to indented JSON."""
    return json.dumps(report, indent=2)


# ── CLI entry point ───────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate secret rotation policies and generate a report."
    )
    parser.add_argument("config", help="Path to the secrets JSON config file")
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--warning-days",
        type=int,
        default=14,
        help="Days before expiry to trigger a warning (default: 14)",
    )
    parser.add_argument(
        "--date",
        help="Reference date as YYYY-MM-DD (default: today)",
    )
    args = parser.parse_args()

    reference_date = date.fromisoformat(args.date) if args.date else date.today()

    try:
        secrets = load_secrets(args.config)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    report = generate_report(secrets, reference_date, args.warning_days)

    if args.format == "json":
        print(format_json(report))
    else:
        print(format_markdown(report))


if __name__ == "__main__":
    main()
