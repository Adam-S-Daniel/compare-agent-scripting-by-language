"""Secret rotation validator.

Reads a JSON config of secrets, classifies each as expired/warning/ok against
a `now` reference date and warning window, and renders a report in JSON or
markdown.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Iterable


class ValidatorError(Exception):
    """Raised when the input config cannot be parsed or validated."""


@dataclass
class Secret:
    name: str
    last_rotated: str  # ISO date string YYYY-MM-DD
    policy_days: int
    services: list[str] = field(default_factory=list)

    def days_remaining(self, now: date) -> int:
        """Negative when expired, positive when still in policy."""
        last = _parse_date(self.last_rotated, field="last_rotated")
        elapsed = (now - last).days
        return self.policy_days - elapsed


def _parse_date(value: str, field: str = "date") -> date:
    try:
        return date.fromisoformat(value)
    except (TypeError, ValueError) as exc:
        raise ValidatorError(f"invalid {field}: {value!r}") from exc


def classify(secrets: Iterable[Secret], *, now: str, warn_days: int):
    """Bucket secrets by urgency relative to `now`.

    Expired buckets are sorted most-overdue first; warning by least time
    remaining; ok by most time remaining.
    """
    today = _parse_date(now, field="now")
    expired, warning, ok = [], [], []
    for s in secrets:
        remaining = s.days_remaining(today)
        if remaining < 0:
            expired.append(s)
        elif remaining <= warn_days:
            warning.append(s)
        else:
            ok.append(s)
    expired.sort(key=lambda s: s.days_remaining(today))         # most negative first
    warning.sort(key=lambda s: s.days_remaining(today))
    ok.sort(key=lambda s: -s.days_remaining(today))
    return {"expired": expired, "warning": warning, "ok": ok}


def load_secrets(path: Path) -> list[Secret]:
    p = Path(path)
    if not p.exists():
        raise ValidatorError(f"config file not found: {p}")
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as exc:
        raise ValidatorError(f"invalid JSON in {p}: {exc.msg}") from exc
    items = data.get("secrets")
    if not isinstance(items, list):
        raise ValidatorError("config must contain a 'secrets' list")
    required = ("name", "last_rotated", "policy_days", "services")
    out: list[Secret] = []
    for i, raw in enumerate(items):
        for key in required:
            if key not in raw:
                raise ValidatorError(f"secret #{i} missing field: {key}")
        # Validate the date eagerly so bad input fails at load time.
        _parse_date(raw["last_rotated"], field=f"last_rotated for {raw['name']!r}")
        out.append(Secret(
            name=raw["name"],
            last_rotated=raw["last_rotated"],
            policy_days=int(raw["policy_days"]),
            services=list(raw["services"]),
        ))
    return out


# --- renderers -------------------------------------------------------------

def _secret_row(s: Secret, now: date) -> dict:
    remaining = s.days_remaining(now)
    return {
        "name": s.name,
        "last_rotated": s.last_rotated,
        "policy_days": s.policy_days,
        "days_remaining": remaining,
        "days_overdue": -remaining if remaining < 0 else 0,
        "services": list(s.services),
    }


def render_json(report: dict, *, now: str) -> str:
    today = _parse_date(now, field="now")
    payload = {
        "generated_at": now,
        "summary": {k: len(v) for k, v in report.items()},
        "buckets": {k: [_secret_row(s, today) for s in v] for k, v in report.items()},
    }
    return json.dumps(payload, indent=2)


def render_markdown(report: dict, *, now: str) -> str:
    today = _parse_date(now, field="now")
    headers = ["Name", "Last Rotated", "Policy (days)", "Days Remaining", "Services"]
    sep = "| " + " | ".join(headers) + " |"
    divider = "| " + " | ".join(["---"] * len(headers)) + " |"
    lines: list[str] = [f"# Secret Rotation Report ({now})", ""]
    titles = {"expired": "Expired", "warning": "Warning", "ok": "OK"}
    for bucket in ("expired", "warning", "ok"):
        lines.append(f"## {titles[bucket]} ({len(report[bucket])})")
        if not report[bucket]:
            lines.append("_none_")
            lines.append("")
            continue
        lines.append(sep)
        lines.append(divider)
        for s in report[bucket]:
            r = _secret_row(s, today)
            lines.append(
                f"| {r['name']} | {r['last_rotated']} | {r['policy_days']} | "
                f"{r['days_remaining']} | {', '.join(r['services'])} |"
            )
        lines.append("")
    return "\n".join(lines)


# --- CLI -------------------------------------------------------------------

def _today_iso() -> str:
    return date.today().isoformat()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Secret rotation validator")
    ap.add_argument("--config", required=True, help="Path to JSON config")
    ap.add_argument("--now", default=_today_iso(), help="Reference date YYYY-MM-DD")
    ap.add_argument("--warn-days", type=int, default=7,
                    help="Warning window in days before policy expiry")
    ap.add_argument("--format", choices=("json", "markdown"), default="json")
    ap.add_argument("--fail-on-expired", action="store_true",
                    help="Exit 2 if any secret is expired")
    args = ap.parse_args(argv)

    try:
        secrets = load_secrets(Path(args.config))
        report = classify(secrets, now=args.now, warn_days=args.warn_days)
    except ValidatorError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.format == "json":
        sys.stdout.write(render_json(report, now=args.now) + "\n")
    else:
        sys.stdout.write(render_markdown(report, now=args.now) + "\n")

    if args.fail_on_expired and report["expired"]:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
