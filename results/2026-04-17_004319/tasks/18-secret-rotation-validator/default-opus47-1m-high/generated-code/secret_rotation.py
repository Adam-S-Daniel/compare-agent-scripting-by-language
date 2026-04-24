"""Secret rotation validator.

Reads a JSON config of secrets (each with a name, last-rotated date, rotation
policy in days, and a list of services that depend on it) and classifies every
secret as one of:

* expired — rotation deadline has already passed
* warning — deadline is within the configurable warning window
* ok      — deadline is comfortably in the future

The result is rendered as a markdown table (default) or JSON. Useful as a CI
check: exit code is 1 when any secret is expired, 2 on configuration errors,
0 otherwise — so a workflow can fail when something needs human attention.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable

# Status keys are kept as plain strings because they are part of the public
# JSON output and grouping order ("expired" first surfaces the most urgent).
URGENCY_ORDER = ("expired", "warning", "ok")

REQUIRED_SECRET_FIELDS = {
    "name",
    "last_rotated",
    "rotation_policy_days",
    "required_by",
}


def _parse_date(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


def classify_secret(secret: dict, current_date: date, warning_days: int) -> dict:
    """Return a copy of *secret* with status, expires_on, days_until_expiry."""
    last_rotated = _parse_date(secret["last_rotated"])
    policy_days = int(secret["rotation_policy_days"])
    expires_on = last_rotated + timedelta(days=policy_days)
    days_until_expiry = (expires_on - current_date).days
    if days_until_expiry < 0:
        status = "expired"
    elif days_until_expiry <= warning_days:
        # Inclusive boundary: a secret expiring exactly N days from now still
        # counts as a warning when warning_days == N.
        status = "warning"
    else:
        status = "ok"
    return {
        **secret,
        "expires_on": expires_on.isoformat(),
        "days_until_expiry": days_until_expiry,
        "status": status,
    }


def classify_secrets(secrets: Iterable[dict], current_date: date,
                     warning_days: int) -> list[dict]:
    return [classify_secret(s, current_date, warning_days) for s in secrets]


def group_by_urgency(classified: Iterable[dict]) -> dict[str, list[dict]]:
    """Bucket classified secrets by status, sorted by urgency within bucket."""
    groups: dict[str, list[dict]] = {k: [] for k in URGENCY_ORDER}
    for s in classified:
        groups[s["status"]].append(s)
    for bucket in groups.values():
        bucket.sort(key=lambda s: s["days_until_expiry"])
    return groups


def format_markdown(groups: dict[str, list[dict]]) -> str:
    lines: list[str] = ["# Secret Rotation Report", ""]
    for urgency in URGENCY_ORDER:
        items = groups[urgency]
        lines.append(f"## {urgency.upper()} ({len(items)})")
        lines.append("")
        if not items:
            lines.append("_None_")
            lines.append("")
            continue
        lines.append(
            "| Name | Last Rotated | Policy (days) | Expires On | "
            "Days Until | Required By |"
        )
        lines.append(
            "|------|--------------|---------------|------------|"
            "------------|-------------|"
        )
        for s in items:
            required = ", ".join(s.get("required_by", []))
            lines.append(
                f"| {s['name']} | {s['last_rotated']} | "
                f"{s['rotation_policy_days']} | {s['expires_on']} | "
                f"{s['days_until_expiry']} | {required} |"
            )
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def format_json_report(groups: dict[str, list[dict]]) -> str:
    summary = {urgency: len(groups[urgency]) for urgency in URGENCY_ORDER}
    return json.dumps({"summary": summary, "groups": groups}, indent=2)


def load_config(path: str | Path) -> dict[str, Any]:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Config file not found: {path}")
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e


def validate_config(cfg: dict) -> None:
    if "secrets" not in cfg or not isinstance(cfg["secrets"], list):
        raise ValueError("Config must contain a 'secrets' list")
    for i, s in enumerate(cfg["secrets"]):
        if not isinstance(s, dict):
            raise ValueError(f"Secret #{i} must be an object")
        missing = REQUIRED_SECRET_FIELDS - set(s.keys())
        if missing:
            raise ValueError(
                f"Secret #{i} ({s.get('name', '?')}) missing fields: "
                f"{sorted(missing)}"
            )


def run(config_path: str | Path, warning_days: int | None,
        output_format: str | None,
        current_date: str | date | None) -> tuple[str, dict[str, list[dict]]]:
    """Load + validate the config, classify, and render the report."""
    cfg = load_config(config_path)
    validate_config(cfg)

    # CLI args override config values; config supplies defaults; final fallback
    # is hard-coded sane defaults.
    if current_date is None:
        current_date = cfg.get("current_date")
    if isinstance(current_date, str):
        current_date = _parse_date(current_date)
    if current_date is None:
        current_date = date.today()

    if warning_days is None:
        warning_days = int(cfg.get("warning_days", 7))

    if output_format is None:
        output_format = cfg.get("format", "markdown")
    if output_format not in ("markdown", "json"):
        raise ValueError(f"Unknown format: {output_format}")

    classified = classify_secrets(cfg["secrets"], current_date, warning_days)
    groups = group_by_urgency(classified)

    report = (format_markdown(groups) if output_format == "markdown"
              else format_json_report(groups))
    return report, groups


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate secret rotation status from a JSON config.",
    )
    parser.add_argument("--config", required=True,
                        help="Path to JSON config file.")
    parser.add_argument("--warning-days", type=int, default=None,
                        help="Days ahead of expiry that count as 'warning'.")
    parser.add_argument("--format", choices=["markdown", "json"], default=None,
                        help="Output format (default: markdown).")
    parser.add_argument("--current-date", default=None,
                        help="Override 'now' for deterministic runs (YYYY-MM-DD).")
    args = parser.parse_args(argv)

    try:
        report, groups = run(
            args.config,
            args.warning_days,
            args.format,
            args.current_date,
        )
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    print(report)
    return 1 if groups["expired"] else 0


if __name__ == "__main__":
    sys.exit(main())
