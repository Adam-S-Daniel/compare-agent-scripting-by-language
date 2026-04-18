"""Secret rotation validator.

Reads a JSON config of secrets (name, last_rotated, rotation_days, services),
classifies each as expired / warning / ok relative to a configurable warning
window, and renders a report in markdown or JSON.

CLI:
    python secret_validator.py <config.json> [--format markdown|json]
                                              [--warning-days N]
                                              [--today YYYY-MM-DD]

Designed to be importable for unit tests; the CLI is just a thin shim.
Exit code is 1 if any secret is expired, 0 otherwise — useful in CI.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Iterable


# --- Domain model ----------------------------------------------------------

@dataclass
class Secret:
    """One rotatable credential plus its policy."""
    name: str
    last_rotated: date
    rotation_days: int
    services: list[str] = field(default_factory=list)

    def days_until_due(self, today: date) -> int:
        """Positive = days remaining. Zero/negative = days overdue."""
        age = (today - self.last_rotated).days
        return self.rotation_days - age


# --- Classification --------------------------------------------------------

URGENCIES = ("expired", "warning", "ok")


def classify_secret(secret: Secret, today: date, warning_days: int) -> str:
    """Map a secret to one of: expired / warning / ok."""
    remaining = secret.days_until_due(today)
    if remaining < 0:
        return "expired"
    if remaining <= warning_days:
        return "warning"
    return "ok"


def classify_secrets(
    secrets: Iterable[Secret], today: date, warning_days: int
) -> dict[str, list[Secret]]:
    """Bucket secrets by urgency. Within each bucket, sort by due date
    (most urgent first) for stable, useful report ordering."""
    buckets: dict[str, list[Secret]] = {u: [] for u in URGENCIES}
    for s in secrets:
        buckets[classify_secret(s, today, warning_days)].append(s)
    for bucket in buckets.values():
        bucket.sort(key=lambda s: s.days_until_due(today))
    return buckets


# --- Loading ---------------------------------------------------------------

REQUIRED_FIELDS = ("name", "last_rotated", "rotation_days", "services")


def load_secrets(path: str) -> list[Secret]:
    """Parse a secrets config file. Raises FileNotFoundError, ValueError."""
    try:
        with open(path, "r") as f:
            raw = f.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"Config file not found: {path}")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}")

    if not isinstance(data, dict) or "secrets" not in data:
        raise ValueError(f"Config {path} must be an object with a 'secrets' key")

    out: list[Secret] = []
    for item in data["secrets"]:
        name = item.get("name", "<unnamed>")
        missing = [f for f in REQUIRED_FIELDS if f not in item]
        if missing:
            raise ValueError(
                f"Secret '{name}' is missing required field(s): {', '.join(missing)}"
            )
        try:
            last_rotated = datetime.strptime(item["last_rotated"], "%Y-%m-%d").date()
        except ValueError as e:
            raise ValueError(
                f"Secret '{name}' has invalid last_rotated date: {e}"
            )
        out.append(Secret(
            name=name,
            last_rotated=last_rotated,
            rotation_days=int(item["rotation_days"]),
            services=list(item["services"]),
        ))
    return out


# --- Rendering -------------------------------------------------------------

def _row_dict(s: Secret, today: date) -> dict:
    """Common per-secret payload used by both renderers."""
    remaining = s.days_until_due(today)
    return {
        "name": s.name,
        "last_rotated": s.last_rotated.isoformat(),
        "rotation_days": s.rotation_days,
        "services": list(s.services),
        "days_remaining": remaining,
        "days_overdue": -remaining if remaining < 0 else 0,
    }


def render_json(
    secrets: Iterable[Secret], today: date, warning_days: int
) -> str:
    buckets = classify_secrets(secrets, today, warning_days)
    payload = {
        "generated_at": today.isoformat(),
        "warning_days": warning_days,
        "summary": {u: len(buckets[u]) for u in URGENCIES},
    }
    for u in URGENCIES:
        payload[u] = [_row_dict(s, today) for s in buckets[u]]
    return json.dumps(payload, indent=2)


def _markdown_table(rows: list[Secret], today: date, urgency: str) -> str:
    """Render one urgency group as a markdown table.

    The 'Status' column shows days overdue or days remaining so the table
    is useful on its own without re-reading the section heading.
    """
    headers = ["Name", "Last Rotated", "Policy (days)", "Status", "Services"]
    lines = ["| " + " | ".join(headers) + " |",
             "| " + " | ".join(["---"] * len(headers)) + " |"]
    for s in rows:
        remaining = s.days_until_due(today)
        if urgency == "expired":
            status = f"{-remaining}d overdue"
        else:
            status = f"{remaining}d remaining"
        lines.append("| " + " | ".join([
            s.name,
            s.last_rotated.isoformat(),
            str(s.rotation_days),
            status,
            ", ".join(s.services),
        ]) + " |")
    return "\n".join(lines)


def render_markdown(
    secrets: Iterable[Secret], today: date, warning_days: int
) -> str:
    buckets = classify_secrets(secrets, today, warning_days)
    parts = [
        "# Secret Rotation Report",
        f"_Generated {today.isoformat()} — warning window: {warning_days} days_",
        "",
        "## Summary",
        f"- Expired: {len(buckets['expired'])}",
        f"- Warning: {len(buckets['warning'])}",
        f"- OK: {len(buckets['ok'])}",
    ]
    titles = {"expired": "## Expired", "warning": "## Warning", "ok": "## OK"}
    for u in URGENCIES:
        if not buckets[u]:
            continue
        parts.extend(["", titles[u], "", _markdown_table(buckets[u], today, u)])
    return "\n".join(parts) + "\n"


# --- Public entry point ----------------------------------------------------

def validate(
    path: str,
    format: str = "markdown",
    warning_days: int = 7,
    today: date | None = None,
) -> str:
    """Load secrets and render a report. Raises ValueError on bad inputs."""
    if format not in ("markdown", "json"):
        raise ValueError(f"Unsupported format: {format!r} (use markdown or json)")
    secrets = load_secrets(path)
    today = today or date.today()
    if format == "json":
        return render_json(secrets, today, warning_days)
    return render_markdown(secrets, today, warning_days)


# --- CLI -------------------------------------------------------------------

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate secret rotation policies")
    p.add_argument("config", help="Path to secrets JSON config")
    p.add_argument("--format", choices=["markdown", "json"], default="markdown")
    p.add_argument("--warning-days", type=int, default=7,
                   help="Days before expiry to flag as 'warning' (default 7)")
    p.add_argument("--today", help="Override 'today' as YYYY-MM-DD (for testing)")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    today = (
        datetime.strptime(args.today, "%Y-%m-%d").date()
        if args.today else date.today()
    )
    try:
        output = validate(
            args.config,
            format=args.format,
            warning_days=args.warning_days,
            today=today,
        )
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2
    print(output)
    # Non-zero exit when anything is expired — handy for CI gating.
    secrets = load_secrets(args.config)
    if any(classify_secret(s, today, args.warning_days) == "expired"
           for s in secrets):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
