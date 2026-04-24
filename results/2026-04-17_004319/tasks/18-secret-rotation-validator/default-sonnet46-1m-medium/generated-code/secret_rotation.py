"""
Secret Rotation Validator

Identifies secrets that are expired or expiring within a configurable warning
window. Produces a rotation report grouped by urgency (expired/warning/ok) in
either markdown or JSON format.

TDD: tests in tests/test_secret_rotation.py were written first (red), then
this implementation was added to make them pass (green).
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import List


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
    expires_on: date
    days_until_expiry: int   # <=0 means already expired
    urgency: str             # "expired" | "warning" | "ok"


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

_URGENCY_ORDER = {"expired": 0, "warning": 1, "ok": 2}


def evaluate_secrets(
    secrets: List[Secret],
    reference_date: date,
    warning_window_days: int = 30,
) -> List[SecretStatus]:
    """Classify each secret and return statuses sorted by urgency (expired first)."""
    statuses: List[SecretStatus] = []

    for s in secrets:
        expires_on = s.last_rotated + timedelta(days=s.rotation_policy_days)
        days_until_expiry = (expires_on - reference_date).days

        if days_until_expiry <= 0:
            urgency = "expired"
        elif days_until_expiry <= warning_window_days:
            urgency = "warning"
        else:
            urgency = "ok"

        statuses.append(SecretStatus(
            secret=s,
            expires_on=expires_on,
            days_until_expiry=days_until_expiry,
            urgency=urgency,
        ))

    # Primary sort: urgency tier; secondary: days_until_expiry (most overdue first)
    statuses.sort(key=lambda st: (_URGENCY_ORDER[st.urgency], st.days_until_expiry))
    return statuses


# ---------------------------------------------------------------------------
# Formatters
# ---------------------------------------------------------------------------

def _group_by_urgency(statuses: List[SecretStatus]):
    groups: dict[str, List[SecretStatus]] = {"expired": [], "warning": [], "ok": []}
    for s in statuses:
        groups[s.urgency].append(s)
    return groups


def format_markdown(
    statuses: List[SecretStatus],
    reference_date: date,
    warning_window: int,
) -> str:
    """Render a markdown report grouped by urgency."""
    groups = _group_by_urgency(statuses)
    lines = [
        "# Secret Rotation Report",
        "",
        f"**Reference Date:** {reference_date}",
        f"**Warning Window:** {warning_window} days",
        "",
    ]

    for urgency in ("expired", "warning", "ok"):
        items = groups[urgency]
        lines.append(f"## {urgency.upper()} ({len(items)})")
        lines.append("")
        if items:
            lines.append("| Name | Last Rotated | Expires | Days | Required By |")
            lines.append("|------|-------------|---------|------|-------------|")
            for item in items:
                d = item.days_until_expiry
                days_str = f"{abs(d)} days overdue" if d < 0 else (
                    "due today" if d == 0 else f"{d} days"
                )
                required = ", ".join(item.secret.required_by) if item.secret.required_by else "—"
                lines.append(
                    f"| {item.secret.name} | {item.secret.last_rotated} "
                    f"| {item.expires_on} | {days_str} | {required} |"
                )
        else:
            lines.append("_None_")
        lines.append("")

    return "\n".join(lines)


def format_json(
    statuses: List[SecretStatus],
    reference_date: date,
    warning_window: int,
) -> str:
    """Render a JSON report grouped by urgency."""
    groups = _group_by_urgency(statuses)

    def serialize(st: SecretStatus) -> dict:
        return {
            "name": st.secret.name,
            "last_rotated": str(st.secret.last_rotated),
            "expires_on": str(st.expires_on),
            "days_until_expiry": st.days_until_expiry,
            "rotation_policy_days": st.secret.rotation_policy_days,
            "required_by": st.secret.required_by,
        }

    report = {
        "reference_date": str(reference_date),
        "warning_window_days": warning_window,
        "summary": {
            "expired": len(groups["expired"]),
            "warning": len(groups["warning"]),
            "ok": len(groups["ok"]),
            "total": len(statuses),
        },
        "groups": {
            "expired": [serialize(s) for s in groups["expired"]],
            "warning": [serialize(s) for s in groups["warning"]],
            "ok": [serialize(s) for s in groups["ok"]],
        },
    }
    return json.dumps(report, indent=2)


# ---------------------------------------------------------------------------
# Config loader
# ---------------------------------------------------------------------------

def load_secrets(config_path: str) -> List[Secret]:
    """Load secrets from a JSON config file."""
    try:
        with open(config_path) as f:
            data = json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"Config file not found: {config_path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in config file: {e}")

    if "secrets" not in data:
        raise ValueError("Config must have a 'secrets' key")

    secrets: List[Secret] = []
    for item in data["secrets"]:
        name = item.get("name", "?")
        try:
            last_rotated = date.fromisoformat(item["last_rotated"])
        except (KeyError, ValueError) as e:
            raise ValueError(
                f"Invalid date format for secret '{name}': "
                f"{item.get('last_rotated', 'missing')!r} — {e}"
            )
        secrets.append(Secret(
            name=name,
            last_rotated=last_rotated,
            rotation_policy_days=int(item["rotation_policy_days"]),
            required_by=item.get("required_by", []),
        ))

    return secrets


# ---------------------------------------------------------------------------
# CLI entrypoint
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate secret rotation policies and generate a report."
    )
    parser.add_argument("--config", required=True, help="Path to secrets JSON config")
    parser.add_argument(
        "--reference-date",
        default=str(date.today()),
        help="Reference date YYYY-MM-DD (default: today)",
    )
    parser.add_argument(
        "--warning-window",
        type=int,
        default=30,
        help="Days ahead to flag as WARNING (default: 30)",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )

    args = parser.parse_args()

    try:
        reference_date = date.fromisoformat(args.reference_date)
    except ValueError:
        print(f"Error: invalid reference date '{args.reference_date}'", file=sys.stderr)
        sys.exit(1)

    try:
        secrets = load_secrets(args.config)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    statuses = evaluate_secrets(secrets, reference_date, args.warning_window)

    if args.format == "json":
        print(format_json(statuses, reference_date, args.warning_window))
    else:
        print(format_markdown(statuses, reference_date, args.warning_window))


if __name__ == "__main__":
    main()
