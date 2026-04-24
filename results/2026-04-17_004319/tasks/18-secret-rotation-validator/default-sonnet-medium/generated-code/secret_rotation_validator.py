#!/usr/bin/env python3
"""
Secret Rotation Validator

Reads a JSON config of secrets with metadata, classifies each secret as
expired / warning / ok based on rotation policy and a configurable warning
window, then generates a rotation report in JSON or Markdown format.
"""

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import List, Optional


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Secret:
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: List[str] = field(default_factory=list)


@dataclass
class SecretStatus:
    secret: Secret
    status: str                  # "expired" | "warning" | "ok"
    days_overdue: Optional[int] = None   # set only when expired
    days_remaining: Optional[int] = None  # set when warning or ok


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def check_secret(
    secret: Secret,
    reference_date: date,
    warning_window: int = 14,
) -> SecretStatus:
    """Classify a single secret relative to reference_date.

    Expired: expiry date <= reference_date (days_overdue >= 0)
    Warning: expiry within warning_window days
    OK: expiry more than warning_window days away
    """
    expiry = secret.last_rotated + timedelta(days=secret.rotation_policy_days)
    days_left = (expiry - reference_date).days  # negative means overdue

    if days_left <= 0:
        return SecretStatus(secret, "expired", days_overdue=-days_left)
    if days_left <= warning_window:
        return SecretStatus(secret, "warning", days_remaining=days_left)
    return SecretStatus(secret, "ok", days_remaining=days_left)


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_config(path: str) -> List[Secret]:
    """Load secrets from a JSON config file.

    Expected format:
    {
      "secrets": [
        {
          "name": "MY_SECRET",
          "last_rotated": "2026-01-01",
          "rotation_policy_days": 90,
          "required_by": ["svc-a"]   // optional
        }
      ]
    }
    """
    try:
        with open(path) as f:
            raw = f.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"Config file not found: {path}")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}")

    secrets: List[Secret] = []
    for i, entry in enumerate(data.get("secrets", [])):
        for required in ("name", "last_rotated", "rotation_policy_days"):
            if required not in entry:
                raise ValueError(
                    f"Secret at index {i} missing required field '{required}'"
                )
        try:
            last_rotated = date.fromisoformat(entry["last_rotated"])
        except ValueError as e:
            raise ValueError(
                f"Invalid date for secret '{entry.get('name', i)}': {e}"
            )
        secrets.append(
            Secret(
                name=entry["name"],
                last_rotated=last_rotated,
                rotation_policy_days=int(entry["rotation_policy_days"]),
                required_by=entry.get("required_by", []),
            )
        )
    return secrets


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(statuses: List[SecretStatus], fmt: str = "json") -> str:
    """Format the list of SecretStatus objects into a report.

    fmt: "json" or "markdown"
    """
    if fmt == "json":
        return _to_json(statuses)
    if fmt == "markdown":
        return _to_markdown(statuses)
    raise ValueError(f"Unknown format '{fmt}'. Use 'json' or 'markdown'.")


def _group(statuses: List[SecretStatus]) -> dict:
    grouped: dict = {"expired": [], "warning": [], "ok": []}
    for s in statuses:
        grouped[s.status].append(s)
    return grouped


def _to_json(statuses: List[SecretStatus]) -> str:
    grouped = _group(statuses)
    result = {}
    for status_key, items in grouped.items():
        result[status_key] = []
        for item in items:
            entry: dict = {
                "name": item.secret.name,
                "status": item.status,
                "required_by": item.secret.required_by,
            }
            if item.days_overdue is not None:
                entry["days_overdue"] = item.days_overdue
            if item.days_remaining is not None:
                entry["days_remaining"] = item.days_remaining
            result[status_key].append(entry)
    return json.dumps(result, indent=2)


def _to_markdown(statuses: List[SecretStatus]) -> str:
    grouped = _group(statuses)
    lines = ["# Secret Rotation Report", ""]

    labels = {
        "expired": "EXPIRED",
        "warning": "WARNING",
        "ok": "OK",
    }
    for status_key in ("expired", "warning", "ok"):
        items = grouped[status_key]
        lines.append(f"## {labels[status_key]} ({len(items)} secrets)")
        if items:
            lines.append("| Name | Days | Required By |")
            lines.append("|------|------|-------------|")
            for item in items:
                if item.days_overdue is not None:
                    days_str = f"{item.days_overdue} days overdue"
                else:
                    days_str = f"{item.days_remaining} days remaining"
                required = ", ".join(item.secret.required_by) or "none"
                lines.append(f"| {item.secret.name} | {days_str} | {required} |")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate secret rotation schedules and generate a report."
    )
    parser.add_argument(
        "--config",
        default="fixtures/default_config.json",
        help="Path to the secrets config JSON file",
    )
    parser.add_argument(
        "--format",
        choices=["json", "markdown"],
        default="json",
        help="Output format (default: json)",
    )
    parser.add_argument(
        "--warning-window",
        type=int,
        default=14,
        help="Days before expiry to start warning (default: 14)",
    )
    parser.add_argument(
        "--reference-date",
        default=None,
        help="Override today's date for testing (YYYY-MM-DD)",
    )
    args = parser.parse_args(argv)

    if args.reference_date:
        try:
            ref = date.fromisoformat(args.reference_date)
        except ValueError as e:
            print(f"ERROR: Invalid reference date: {e}", file=sys.stderr)
            return 1
    else:
        ref = date.today()

    try:
        secrets = load_config(args.config)
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    statuses = [
        check_secret(s, ref, warning_window=args.warning_window) for s in secrets
    ]

    print(generate_report(statuses, fmt=args.format))
    return 0


if __name__ == "__main__":
    sys.exit(main())
