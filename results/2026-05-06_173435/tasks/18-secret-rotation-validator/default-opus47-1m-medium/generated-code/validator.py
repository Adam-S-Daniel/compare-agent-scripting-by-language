#!/usr/bin/env python3
"""Secret rotation validator.

Reads a JSON config of secrets (name, last_rotated, rotation_policy_days,
required_by) and classifies each as expired/warning/ok relative to a configurable
warning window. Renders a report as either a markdown table or JSON.

Exit codes:
  0 = no expired secrets
  2 = at least one secret is expired (so CI can fail-fast)
  1 = config error (file missing, invalid JSON, schema violation)
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any


class SecretValidationError(Exception):
    """Raised when input config cannot be loaded or a secret entry is malformed."""


# --- core classification -----------------------------------------------------

REQUIRED_FIELDS = ("name", "last_rotated", "rotation_policy_days", "required_by")


def _parse_iso_date(s: str, secret_name: str) -> date:
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except (ValueError, TypeError) as e:
        raise SecretValidationError(
            f"secret '{secret_name}': invalid last_rotated date '{s}' (expected YYYY-MM-DD)"
        ) from e


def classify_secret(secret: dict, warning_days: int, today: date) -> dict:
    """Return a dict describing this secret's rotation status.

    A secret is `expired` if days_until_expiry < 0, `warning` if it falls within
    [0, warning_days] inclusive, and `ok` otherwise. Boundary 0 is intentionally
    a warning (still rotated in time, but on the very edge).
    """
    for field in REQUIRED_FIELDS:
        if field not in secret:
            raise SecretValidationError(
                f"secret '{secret.get('name', '<unnamed>')}': missing required field '{field}'"
            )

    name = secret["name"]
    last_rotated = _parse_iso_date(secret["last_rotated"], name)
    policy = secret["rotation_policy_days"]
    if not isinstance(policy, int) or policy <= 0:
        raise SecretValidationError(
            f"secret '{name}': rotation_policy_days must be a positive integer"
        )

    days_elapsed = (today - last_rotated).days
    days_until_expiry = policy - days_elapsed

    if days_until_expiry < 0:
        status = "expired"
    elif days_until_expiry <= warning_days:
        status = "warning"
    else:
        status = "ok"

    return {
        "name": name,
        "last_rotated": secret["last_rotated"],
        "rotation_policy_days": policy,
        "required_by": list(secret["required_by"]),
        "days_until_expiry": days_until_expiry,
        "status": status,
    }


def classify_all(config: dict, warning_days: int, today: date) -> dict:
    """Classify every secret and group results by urgency."""
    if "secrets" not in config or not isinstance(config["secrets"], list):
        raise SecretValidationError("config must contain a 'secrets' list")

    grouped: dict[str, list[dict]] = {"expired": [], "warning": [], "ok": []}
    for secret in config["secrets"]:
        result = classify_secret(secret, warning_days=warning_days, today=today)
        grouped[result["status"]].append(result)

    # Sort within each group by urgency (most urgent first within expired/warning).
    grouped["expired"].sort(key=lambda s: s["days_until_expiry"])
    grouped["warning"].sort(key=lambda s: s["days_until_expiry"])
    grouped["ok"].sort(key=lambda s: -s["days_until_expiry"])
    return grouped


# --- IO ---------------------------------------------------------------------

def load_config(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError as e:
        raise SecretValidationError(f"config file not found: {path}") from e
    except json.JSONDecodeError as e:
        raise SecretValidationError(f"config file is not valid JSON: {path}: {e}") from e


# --- renderers --------------------------------------------------------------

_TABLE_HEADER = (
    "| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |\n"
    "|------|--------------|---------------|-------------------|-------------|"
)


def _row(s: dict) -> str:
    required = ", ".join(s["required_by"])
    return (
        f"| {s['name']} | {s['last_rotated']} | {s['rotation_policy_days']} "
        f"| {s['days_until_expiry']} | {required} |"
    )


def render_markdown(grouped: dict) -> str:
    sections = []
    for status, title in (("expired", "Expired"), ("warning", "Warning"), ("ok", "OK")):
        items = grouped.get(status, [])
        sections.append(f"## {title} ({len(items)})\n")
        if not items:
            sections.append("_No secrets in this group._\n")
            continue
        sections.append(_TABLE_HEADER)
        for s in items:
            sections.append(_row(s))
        sections.append("")  # blank line between sections
    return "\n".join(sections).rstrip() + "\n"


def render_json(grouped: dict) -> str:
    summary = {k: len(v) for k, v in grouped.items()}
    return json.dumps({**grouped, "summary": summary}, indent=2)


# --- CLI --------------------------------------------------------------------

def _parse_today(s: str | None) -> date:
    if s is None:
        return date.today()
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except ValueError as e:
        raise SecretValidationError(f"invalid --today value '{s}' (expected YYYY-MM-DD)") from e


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Validate secret rotation status.")
    p.add_argument("--config", required=True, help="Path to secrets JSON config.")
    p.add_argument(
        "--warning-days",
        type=int,
        default=7,
        help="Window (in days) before expiry to flag a secret as 'warning'.",
    )
    p.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="Output format.",
    )
    p.add_argument(
        "--today",
        default=None,
        help="Override today's date (YYYY-MM-DD). Useful for tests/CI determinism.",
    )
    args = p.parse_args(argv)

    try:
        today = _parse_today(args.today)
        config = load_config(args.config)
        grouped = classify_all(config, warning_days=args.warning_days, today=today)
    except SecretValidationError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    out = render_markdown(grouped) if args.format == "markdown" else render_json(grouped)
    print(out)

    return 2 if grouped["expired"] else 0


if __name__ == "__main__":
    sys.exit(main())
