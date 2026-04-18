#!/usr/bin/env python3
"""Secret rotation validator.

Given a JSON config of secrets with metadata (name, last-rotated date, rotation
policy in days, required-by services), identify secrets that are expired or
about to expire within a configurable warning window, then emit a report as
either JSON or a Markdown document.

The module is designed for testability: `parse_config`, `classify_secret`,
`build_report`, `render_markdown`, and `render_json` are pure functions that
operate on plain data so unit tests can pin behaviour precisely.

CLI usage:
    python3 validator.py --config cfg.json --warning-days 14 \\
        --reference-date 2026-04-17 --format markdown
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any


class ValidationError(ValueError):
    """Raised when the input config is malformed."""


@dataclass(frozen=True)
class Secret:
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: list[str] = field(default_factory=list)

    @property
    def expires_on(self) -> date:
        from datetime import timedelta
        return self.last_rotated + timedelta(days=self.rotation_policy_days)


@dataclass(frozen=True)
class Status:
    severity: str            # "expired" | "warning" | "ok"
    days_until_expiry: int   # 0 when already expired
    days_overdue: int        # 0 when not yet expired


# -- classification ----------------------------------------------------------

def classify_secret(secret: Secret, reference_date: date, warning_days: int) -> Status:
    """Classify a secret relative to a reference date.

    Rules:
      * severity == "expired" when the secret's expiry date is strictly before
        the reference date.
      * severity == "warning" when expiry is within [0, warning_days] inclusive
        from the reference date. (The expiry day itself counts as a warning,
        not yet expired.)
      * severity == "ok" otherwise.
    """
    if warning_days < 0:
        raise ValueError("warning_days must be >= 0")
    delta_days = (secret.expires_on - reference_date).days
    if delta_days < 0:
        return Status(severity="expired", days_until_expiry=0, days_overdue=-delta_days)
    if delta_days <= warning_days:
        return Status(severity="warning", days_until_expiry=delta_days, days_overdue=0)
    return Status(severity="ok", days_until_expiry=delta_days, days_overdue=0)


# -- parsing -----------------------------------------------------------------

def parse_config(data: Any) -> list[Secret]:
    """Parse a loaded JSON document into a list of Secret records.

    Raises ValidationError with an actionable message on any malformed input.
    """
    if not isinstance(data, dict):
        raise ValidationError("config root must be a JSON object")
    if "secrets" not in data:
        raise ValidationError("config is missing required key 'secrets'")
    raw_secrets = data["secrets"]
    if not isinstance(raw_secrets, list):
        raise ValidationError("'secrets' must be a JSON array")

    parsed: list[Secret] = []
    for idx, entry in enumerate(raw_secrets):
        if not isinstance(entry, dict):
            raise ValidationError(f"secret #{idx} must be a JSON object")

        name = entry.get("name")
        if not isinstance(name, str) or not name:
            raise ValidationError(f"secret #{idx} missing non-empty 'name'")

        rot_raw = entry.get("last_rotated")
        if not isinstance(rot_raw, str):
            raise ValidationError(f"secret {name!r} missing 'last_rotated' ISO date")
        try:
            last_rotated = date.fromisoformat(rot_raw)
        except ValueError as exc:
            raise ValidationError(
                f"secret {name!r} has invalid 'last_rotated' value {rot_raw!r}: {exc}"
            ) from exc

        policy = entry.get("rotation_policy_days")
        if not isinstance(policy, int) or isinstance(policy, bool) or policy <= 0:
            raise ValidationError(
                f"secret {name!r} must have positive integer 'rotation_policy_days'"
            )

        required_by = entry.get("required_by", [])
        if not isinstance(required_by, list) or any(not isinstance(x, str) for x in required_by):
            raise ValidationError(f"secret {name!r} 'required_by' must be a list of strings")

        parsed.append(Secret(
            name=name,
            last_rotated=last_rotated,
            rotation_policy_days=policy,
            required_by=list(required_by),
        ))
    return parsed


# -- report ------------------------------------------------------------------

def _secret_row(secret: Secret, status: Status) -> dict[str, Any]:
    return {
        "name": secret.name,
        "last_rotated": secret.last_rotated.isoformat(),
        "expires_on": secret.expires_on.isoformat(),
        "rotation_policy_days": secret.rotation_policy_days,
        "required_by": list(secret.required_by),
        "severity": status.severity,
        "days_until_expiry": status.days_until_expiry,
        "days_overdue": status.days_overdue,
    }


def build_report(secrets: list[Secret], reference_date: date, warning_days: int) -> dict[str, Any]:
    """Partition secrets into buckets by severity and produce a summary."""
    expired: list[dict[str, Any]] = []
    warning: list[dict[str, Any]] = []
    ok: list[dict[str, Any]] = []

    for secret in secrets:
        status = classify_secret(secret, reference_date, warning_days)
        row = _secret_row(secret, status)
        if status.severity == "expired":
            expired.append(row)
        elif status.severity == "warning":
            warning.append(row)
        else:
            ok.append(row)

    # Stable ordering: most urgent first in each bucket.
    expired.sort(key=lambda r: (-r["days_overdue"], r["name"]))
    warning.sort(key=lambda r: (r["days_until_expiry"], r["name"]))
    ok.sort(key=lambda r: (r["days_until_expiry"], r["name"]))

    return {
        "reference_date": reference_date.isoformat(),
        "warning_days": warning_days,
        "expired": expired,
        "warning": warning,
        "ok": ok,
        "summary": {
            "expired_count": len(expired),
            "warning_count": len(warning),
            "ok_count": len(ok),
            "total": len(secrets),
        },
    }


# -- rendering ---------------------------------------------------------------

def render_json(report: dict[str, Any]) -> str:
    return json.dumps(report, indent=2, sort_keys=False)


def _md_table(rows: list[dict[str, Any]], columns: list[tuple[str, str]]) -> str:
    """Render a Markdown table. `columns` is a list of (field, header) pairs."""
    headers = [h for _, h in columns]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows:
        cells = []
        for field_name, _ in columns:
            value = row[field_name]
            if isinstance(value, list):
                value = ", ".join(value) if value else "-"
            cells.append(str(value))
        lines.append("| " + " | ".join(cells) + " |")
    return "\n".join(lines)


def render_markdown(report: dict[str, Any]) -> str:
    out: list[str] = []
    out.append("# Secret Rotation Report")
    out.append("")
    out.append(f"**Reference Date:** {report['reference_date']}  ")
    out.append(f"**Warning Window:** {report['warning_days']} days")
    out.append("")

    summary = report["summary"]
    out.append("## Summary")
    out.append("")
    out.append(f"- Expired: {summary['expired_count']}")
    out.append(f"- Warning: {summary['warning_count']}")
    out.append(f"- OK: {summary['ok_count']}")
    out.append(f"- Total: {summary['total']}")
    out.append("")

    expired_cols = [
        ("name", "Name"),
        ("last_rotated", "Last Rotated"),
        ("expires_on", "Expired On"),
        ("rotation_policy_days", "Policy (days)"),
        ("days_overdue", "Days Overdue"),
        ("required_by", "Required By"),
    ]
    upcoming_cols = [
        ("name", "Name"),
        ("last_rotated", "Last Rotated"),
        ("expires_on", "Expires On"),
        ("rotation_policy_days", "Policy (days)"),
        ("days_until_expiry", "Days Until Expiry"),
        ("required_by", "Required By"),
    ]

    out.append("## Expired")
    out.append("")
    if report["expired"]:
        out.append(_md_table(report["expired"], expired_cols))
    else:
        out.append("_No expired secrets._")
    out.append("")

    out.append("## Warning")
    out.append("")
    if report["warning"]:
        out.append(_md_table(report["warning"], upcoming_cols))
    else:
        out.append("_No warnings._")
    out.append("")

    out.append("## OK")
    out.append("")
    if report["ok"]:
        out.append(_md_table(report["ok"], upcoming_cols))
    else:
        out.append("_No healthy secrets._")
    out.append("")

    return "\n".join(out)


# -- CLI ---------------------------------------------------------------------

def _parse_reference_date(value: str | None) -> date:
    if value is None:
        return datetime.now(timezone.utc).date()
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise SystemExit(f"error: --reference-date must be ISO YYYY-MM-DD: {exc}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate secret rotation status.")
    parser.add_argument("--config", required=True, help="Path to JSON config file")
    parser.add_argument("--warning-days", type=int, default=14,
                        help="Days-before-expiry threshold for WARNING severity")
    parser.add_argument("--reference-date", default=None,
                        help="ISO date used as 'now'. Defaults to today (UTC).")
    parser.add_argument("--format", choices=["json", "markdown"], default="markdown")
    parser.add_argument("--output", default=None,
                        help="Write report to file instead of stdout")
    parser.add_argument("--strict", action="store_true",
                        help="Exit with code 2 if any secret is expired, 1 if any warning")
    args = parser.parse_args(argv)

    if args.warning_days < 0:
        print("error: --warning-days must be >= 0", file=sys.stderr)
        return 2

    cfg_path = Path(args.config)
    if not cfg_path.exists():
        print(f"error: config file not found: {cfg_path}", file=sys.stderr)
        return 2

    try:
        raw = json.loads(cfg_path.read_text())
    except json.JSONDecodeError as exc:
        print(f"error: invalid JSON in {cfg_path}: {exc}", file=sys.stderr)
        return 2

    try:
        secrets = parse_config(raw)
    except ValidationError as exc:
        print(f"error: invalid config: {exc}", file=sys.stderr)
        return 2

    ref_date = _parse_reference_date(args.reference_date)
    report = build_report(secrets, ref_date, args.warning_days)

    rendered = render_json(report) if args.format == "json" else render_markdown(report)

    if args.output:
        Path(args.output).write_text(rendered + ("\n" if not rendered.endswith("\n") else ""))
    else:
        print(rendered)

    if args.strict:
        if report["summary"]["expired_count"] > 0:
            return 2
        if report["summary"]["warning_count"] > 0:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
