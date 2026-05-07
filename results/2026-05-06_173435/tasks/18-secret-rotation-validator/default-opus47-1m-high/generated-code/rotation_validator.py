"""Secret rotation validator.

Reads a JSON config of secrets with metadata, classifies each into
``expired`` / ``warning`` / ``ok`` based on its rotation policy and a
configurable warning window, and produces either a Markdown rotation
report or a JSON payload.

Design notes:
- ``today`` and ``warning_days`` are explicit parameters (not implicit
  ``date.today()`` calls) so the library and CLI behave deterministically
  in tests and in CI.
- ``days_until_due`` is signed: positive = days remaining, zero or
  negative = overdue. ``classify`` treats due-today as expired because
  the policy window has elapsed.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class Secret:
    """A single secret entry with its rotation metadata."""

    name: str
    last_rotated: date
    policy_days: int
    services: list[str] = field(default_factory=list)

    @property
    def due_date(self) -> date:
        return self.last_rotated + timedelta(days=self.policy_days)

    def days_until_due(self, today: date) -> int:
        return (self.due_date - today).days


# --- classification -----------------------------------------------------

def classify(secret: Secret, *, today: date, warning_days: int) -> str:
    """Return ``"expired"``, ``"warning"``, or ``"ok"`` for ``secret``.

    A secret is *expired* when its due date is on or before ``today``.
    Otherwise, if the due date is within ``warning_days`` (inclusive) of
    ``today``, it is *warning*. Anything further out is *ok*.
    """
    days_until = secret.days_until_due(today)
    if days_until <= 0:
        return "expired"
    if days_until <= warning_days:
        return "warning"
    return "ok"


def classify_all(
    secrets: Iterable[Secret], *, today: date, warning_days: int
) -> dict[str, list[Secret]]:
    """Bucket ``secrets`` into expired / warning / ok lists.

    Within each bucket, secrets are sorted by urgency (most overdue or
    soonest-due first) so reports read naturally.
    """
    buckets: dict[str, list[Secret]] = {"expired": [], "warning": [], "ok": []}
    for s in secrets:
        buckets[classify(s, today=today, warning_days=warning_days)].append(s)
    for name in buckets:
        buckets[name].sort(key=lambda s: s.days_until_due(today))
    return buckets


def summarize(grouped: dict[str, list[Secret]]) -> dict[str, int]:
    return {
        "expired": len(grouped["expired"]),
        "warning": len(grouped["warning"]),
        "ok": len(grouped["ok"]),
        "total": sum(len(v) for v in grouped.values()),
    }


# --- loading ------------------------------------------------------------

_REQUIRED_FIELDS = ("name", "last_rotated", "policy_days", "services")


def load_secrets(path: str) -> list[Secret]:
    """Load and validate a JSON list of secret records.

    Errors are raised as ``FileNotFoundError`` or ``ValueError`` with
    messages naming the offending file/index/field, so CLI output is
    actionable.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Secrets config not found: {path}")
    try:
        raw = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e.msg} (line {e.lineno})") from e

    if not isinstance(raw, list):
        raise ValueError(f"Expected a JSON list of secret records in {path}")

    secrets: list[Secret] = []
    for i, item in enumerate(raw):
        if not isinstance(item, dict):
            raise ValueError(f"Entry {i} in {path} is not an object")
        for key in _REQUIRED_FIELDS:
            if key not in item:
                raise ValueError(
                    f"Entry {i} ({item.get('name', '?')}) missing required field: {key}"
                )
        try:
            last_rotated = datetime.strptime(item["last_rotated"], "%Y-%m-%d").date()
        except (ValueError, TypeError) as e:
            raise ValueError(
                f"Invalid last_rotated date for entry {i} ({item['name']}): "
                f"{item['last_rotated']!r} (expected YYYY-MM-DD)"
            ) from e

        policy_days = item["policy_days"]
        if not isinstance(policy_days, int) or policy_days <= 0:
            raise ValueError(
                f"policy_days must be positive integer for entry {i} ({item['name']}); "
                f"got {policy_days!r}"
            )

        services = item["services"]
        if not isinstance(services, list) or not all(isinstance(s, str) for s in services):
            raise ValueError(
                f"services must be a list of strings for entry {i} ({item['name']})"
            )

        secrets.append(
            Secret(
                name=item["name"],
                last_rotated=last_rotated,
                policy_days=policy_days,
                services=list(services),
            )
        )
    return secrets


# --- rendering ----------------------------------------------------------

def _row(s: Secret, today: date) -> str:
    days = s.days_until_due(today)
    days_cell = f"{-days} overdue" if days <= 0 else f"{days} until due"
    services = ", ".join(s.services) if s.services else "_none_"
    return (
        f"| {s.name} | {s.last_rotated.isoformat()} | {s.policy_days} | "
        f"{s.due_date.isoformat()} | {days_cell} | {services} |"
    )


_TABLE_HEADER = (
    "| Name | Last Rotated | Policy (days) | Due | "
    "Days Overdue / Until Due | Services |"
)
_TABLE_DIVIDER = "|------|--------------|---------------|-----|--------------------------|----------|"


def render_markdown(
    grouped: dict[str, list[Secret]], *, today: date, warning_days: int
) -> str:
    summary = summarize(grouped)
    lines: list[str] = [
        "# Secret Rotation Report",
        "",
        f"Generated for {today.isoformat()} (warning window: {warning_days} days)",
        "",
        "## Summary",
        "",
        f"- **Total:** {summary['total']}",
        f"- **Expired:** {summary['expired']}",
        f"- **Warning:** {summary['warning']}",
        f"- **OK:** {summary['ok']}",
        "",
    ]
    for bucket_label, key in (("Expired", "expired"), ("Warning", "warning"), ("OK", "ok")):
        lines.append(f"## {bucket_label}")
        lines.append("")
        if not grouped[key]:
            lines.append("_None_")
            lines.append("")
            continue
        lines.append(_TABLE_HEADER)
        lines.append(_TABLE_DIVIDER)
        for s in grouped[key]:
            lines.append(_row(s, today))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _entry_dict(s: Secret, today: date) -> dict:
    return {
        "name": s.name,
        "last_rotated": s.last_rotated.isoformat(),
        "policy_days": s.policy_days,
        "due_date": s.due_date.isoformat(),
        "days_until_due": s.days_until_due(today),
        "services": list(s.services),
    }


def render_json(
    grouped: dict[str, list[Secret]], *, today: date, warning_days: int
) -> str:
    payload = {
        "generated_for": today.isoformat(),
        "warning_days": warning_days,
        "summary": summarize(grouped),
        "expired": [_entry_dict(s, today) for s in grouped["expired"]],
        "warning": [_entry_dict(s, today) for s in grouped["warning"]],
        "ok": [_entry_dict(s, today) for s in grouped["ok"]],
    }
    return json.dumps(payload, indent=2)


# --- CLI ----------------------------------------------------------------

def _parse_today(value: str | None) -> date:
    if value is None or value == "":
        return date.today()
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError as e:
        raise SystemExit(f"error: --today must be YYYY-MM-DD, got {value!r}") from e


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate secret rotation freshness against a policy."
    )
    parser.add_argument("config", help="Path to JSON secrets config")
    parser.add_argument(
        "--warning-days",
        type=int,
        default=14,
        help="Days before due date to flag as warning (default: 14)",
    )
    parser.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--today",
        default=None,
        help="Override today's date (YYYY-MM-DD); defaults to system date",
    )
    parser.add_argument(
        "--fail-on",
        choices=("never", "expired", "warning"),
        default="never",
        help=(
            "Exit non-zero when secrets reach this urgency. "
            "'expired' fails if any expired; 'warning' fails on expired or warning."
        ),
    )
    args = parser.parse_args(argv)

    if args.warning_days < 0:
        print("error: --warning-days must be >= 0", file=sys.stderr)
        return 2

    today = _parse_today(args.today)

    try:
        secrets = load_secrets(args.config)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    grouped = classify_all(secrets, today=today, warning_days=args.warning_days)

    if args.format == "json":
        print(render_json(grouped, today=today, warning_days=args.warning_days))
    else:
        print(render_markdown(grouped, today=today, warning_days=args.warning_days))

    if args.fail_on == "expired" and grouped["expired"]:
        return 1
    if args.fail_on == "warning" and (grouped["expired"] or grouped["warning"]):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
