"""Secret rotation validator.

Reads a JSON file describing secrets (name, last-rotated date, rotation policy
in days, services that depend on them), classifies each one as expired,
within a warning window, or healthy, and emits a grouped report in either
Markdown or JSON.

Designed for CI/CD: with `--strict`, exits non-zero when any secret is
expired so a workflow can fail the build. The companion GitHub Actions
workflow drives this script through `act` for end-to-end validation.

Style note: written using red/green TDD. Tests under `tests/` were authored
first; this module is the minimum implementation that passes them.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Iterable, List, Sequence


# --- Domain model --------------------------------------------------------

@dataclass(frozen=True)
class Secret:
    """A managed secret with a rotation policy."""
    name: str
    last_rotated: date
    rotation_days: int
    services: List[str]


class InvalidConfigError(ValueError):
    """Raised when the secrets config file is missing or malformed."""


# --- Core logic ----------------------------------------------------------

def _due_date(secret: Secret) -> date:
    """When the secret must next be rotated."""
    from datetime import timedelta
    return secret.last_rotated + timedelta(days=secret.rotation_days)


def categorize_secret(secret: Secret, today: date, warning_days: int) -> str:
    """Classify a secret's rotation urgency.

    Returns one of:
      - "expired" — due date is today or in the past
      - "warning" — due date is within `warning_days` days from today
      - "ok"      — due date is further out than the warning window
    """
    due = _due_date(secret)
    days_until_due = (due - today).days
    if days_until_due <= 0:
        return "expired"
    if days_until_due <= warning_days:
        return "warning"
    return "ok"


def _entry(secret: Secret, today: date) -> dict:
    """Materialize a serializable view of one secret with computed fields."""
    due = _due_date(secret)
    days_until_due = (due - today).days
    return {
        "name": secret.name,
        "last_rotated": secret.last_rotated.isoformat(),
        "due_date": due.isoformat(),
        # Both fields included so JSON consumers can pick whichever they prefer
        # without reinterpreting the sign convention.
        "days_overdue": -days_until_due,
        "days_until_due": days_until_due,
        "rotation_days": secret.rotation_days,
        "services": list(secret.services),
    }


def generate_report(
    secrets: Sequence[Secret],
    today: date,
    warning_days: int,
) -> dict:
    """Build a structured report grouping secrets by urgency."""
    groups: dict[str, list[dict]] = {"expired": [], "warning": [], "ok": []}
    for s in secrets:
        bucket = categorize_secret(s, today, warning_days)
        groups[bucket].append(_entry(s, today))

    # Most urgent items first within each group, so the top of the report
    # spotlights the worst offenders.
    groups["expired"].sort(key=lambda e: e["days_overdue"], reverse=True)
    groups["warning"].sort(key=lambda e: e["days_until_due"])
    groups["ok"].sort(key=lambda e: e["days_until_due"])

    return {
        "generated": today.isoformat(),
        "warning_days": warning_days,
        "summary": {
            "total": len(secrets),
            "expired": len(groups["expired"]),
            "warning": len(groups["warning"]),
            "ok": len(groups["ok"]),
        },
        "expired": groups["expired"],
        "warning": groups["warning"],
        "ok": groups["ok"],
    }


# --- Output formats ------------------------------------------------------

def _markdown_table(rows: Iterable[dict], days_column: str) -> str:
    """Render a list of secret entries as a Markdown table.

    `days_column` controls whether the third numeric column is "Days Overdue"
    (for expired) or "Days Until Due" (for warning/ok).
    """
    rows = list(rows)
    if not rows:
        return "_No secrets in this group._\n"
    header = f"| Name | Last Rotated | Due Date | {days_column} | Services |\n"
    sep = "|------|--------------|----------|" + "-" * (len(days_column) + 2) + "|----------|\n"
    body = []
    for r in rows:
        days_value = r["days_overdue"] if days_column == "Days Overdue" else r["days_until_due"]
        services = ", ".join(r["services"])
        body.append(f"| {r['name']} | {r['last_rotated']} | {r['due_date']} | {days_value} | {services} |")
    return header + sep + "\n".join(body) + "\n"


def format_markdown(report: dict) -> str:
    """Render the report as a Markdown document."""
    s = report["summary"]
    lines = [
        "# Secret Rotation Report",
        "",
        f"Generated: {report['generated']}",
        f"Warning window: {report['warning_days']} days",
        f"Total secrets: {s['total']} ({s['expired']} expired, {s['warning']} warning, {s['ok']} ok)",
        "",
        f"## Expired ({s['expired']})",
        "",
        _markdown_table(report["expired"], "Days Overdue"),
        f"## Warning ({s['warning']})",
        "",
        _markdown_table(report["warning"], "Days Until Due"),
        f"## OK ({s['ok']})",
        "",
        _markdown_table(report["ok"], "Days Until Due"),
    ]
    return "\n".join(lines)


def format_json(report: dict) -> str:
    """Render the report as a pretty-printed JSON document."""
    return json.dumps(report, indent=2, sort_keys=False)


# --- Config loading ------------------------------------------------------

_REQUIRED_FIELDS = ("name", "last_rotated", "rotation_days", "services")


def load_config(path: Path) -> List[Secret]:
    """Load and validate a secrets-config JSON file.

    Raises:
        InvalidConfigError: if the file is missing, not valid JSON, or any
            secret entry is malformed (missing field, bad date, non-positive
            rotation_days).
    """
    p = Path(path)
    if not p.exists():
        raise InvalidConfigError(f"config file not found: {p}")
    try:
        raw = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise InvalidConfigError(f"invalid JSON in {p}: {e}") from e

    if not isinstance(raw, dict) or "secrets" not in raw:
        raise InvalidConfigError(f"config must be an object with a 'secrets' key")
    if not isinstance(raw["secrets"], list):
        raise InvalidConfigError(f"'secrets' must be a list")

    out: List[Secret] = []
    for i, item in enumerate(raw["secrets"]):
        if not isinstance(item, dict):
            raise InvalidConfigError(f"secret #{i} is not an object")
        for f in _REQUIRED_FIELDS:
            if f not in item:
                raise InvalidConfigError(f"secret #{i} ({item.get('name', '?')}) missing field '{f}'")
        try:
            last = date.fromisoformat(item["last_rotated"])
        except (TypeError, ValueError) as e:
            raise InvalidConfigError(
                f"secret '{item['name']}' has invalid date '{item['last_rotated']}': {e}"
            ) from e
        days = item["rotation_days"]
        if not isinstance(days, int) or days <= 0:
            raise InvalidConfigError(
                f"secret '{item['name']}' has invalid rotation_days '{days}' (must be positive int)"
            )
        services = item["services"]
        if not isinstance(services, list) or not all(isinstance(s, str) for s in services):
            raise InvalidConfigError(
                f"secret '{item['name']}' services must be a list of strings"
            )
        out.append(Secret(
            name=item["name"],
            last_rotated=last,
            rotation_days=days,
            services=services,
        ))
    return out


# --- CLI -----------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="secret_rotation",
        description="Validate secret rotation health and emit a grouped report.",
    )
    p.add_argument("--config", required=True, type=Path,
                   help="Path to secrets JSON config file.")
    p.add_argument("--format", choices=["markdown", "json"], default="markdown",
                   help="Output format (default: markdown).")
    p.add_argument("--warning-days", type=int, default=14,
                   help="Days before due-date a secret enters the 'warning' bucket (default: 14).")
    p.add_argument("--reference-date", type=str, default=None,
                   help="Override 'today' (YYYY-MM-DD). Default: actual today. "
                        "Useful for deterministic CI testing.")
    p.add_argument("--strict", action="store_true",
                   help="Exit code 2 when any secret is expired (for CI gating).")
    return p


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry point. Returns process exit code."""
    args = _build_parser().parse_args(argv)

    if args.warning_days < 0:
        print("Error: --warning-days must be >= 0", file=sys.stderr)
        return 1

    if args.reference_date:
        try:
            today = date.fromisoformat(args.reference_date)
        except ValueError as e:
            print(f"Error: invalid --reference-date '{args.reference_date}': {e}",
                  file=sys.stderr)
            return 1
    else:
        today = date.today()

    try:
        secrets = load_config(args.config)
    except InvalidConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    report = generate_report(secrets, today, args.warning_days)

    if args.format == "json":
        sys.stdout.write(format_json(report) + "\n")
    else:
        sys.stdout.write(format_markdown(report))

    if args.strict and report["summary"]["expired"] > 0:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
