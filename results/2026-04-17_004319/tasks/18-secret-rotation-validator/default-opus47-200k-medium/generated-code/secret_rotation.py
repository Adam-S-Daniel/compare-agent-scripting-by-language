"""Secret rotation validator.

Identifies secrets whose rotation is expired or approaching the warning
window, then emits a grouped report in either markdown or JSON form.

Approach:
  * `Secret` is a tiny dataclass — the domain record.
  * `classify_secret` decides urgency for one secret given `today` and the
    configured `warning_days` window. `today` is injected so tests can
    pin the date without monkey-patching.
  * `classify_secrets` buckets a list into expired/warning/ok.
  * `render_markdown` / `render_json` are pure formatters over the buckets.
  * `validate` wires it all together: load -> classify -> render.
  * `main` is the CLI entry point used by the GitHub Actions workflow.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import date
from typing import Iterable


# Urgency labels, ordered most-urgent first. Used for iteration order
# wherever we walk the grouped result (e.g. markdown rendering).
URGENCY_ORDER = ("expired", "warning", "ok")


@dataclass(frozen=True)
class Secret:
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: list[str]


def classify_secret(secret: Secret, *, today: date, warning_days: int) -> dict:
    """Return an info dict for a single secret, including its urgency bucket.

    A secret is:
      * expired  -> age >= policy (days_until_rotation <= 0)
      * warning  -> 0 < days_until_rotation <= warning_days
      * ok       -> days_until_rotation > warning_days
    """
    age_days = (today - secret.last_rotated).days
    days_until = secret.rotation_policy_days - age_days

    if days_until <= 0:
        urgency = "expired"
    elif days_until <= warning_days:
        urgency = "warning"
    else:
        urgency = "ok"

    info = {
        "name": secret.name,
        "last_rotated": secret.last_rotated.isoformat(),
        "rotation_policy_days": secret.rotation_policy_days,
        "required_by": list(secret.required_by),
        "age_days": age_days,
        "urgency": urgency,
    }
    if urgency == "expired":
        info["days_overdue"] = -days_until
    else:
        info["days_until_rotation"] = days_until
    return info


def classify_secrets(
    secrets: Iterable[Secret], *, today: date, warning_days: int
) -> dict[str, list[dict]]:
    """Bucket a collection of secrets into expired/warning/ok."""
    grouped: dict[str, list[dict]] = {k: [] for k in URGENCY_ORDER}
    for s in secrets:
        info = classify_secret(s, today=today, warning_days=warning_days)
        grouped[info["urgency"]].append(info)
    # Sort expired by most-overdue first; warning by soonest-due first.
    grouped["expired"].sort(key=lambda x: -x["days_overdue"])
    grouped["warning"].sort(key=lambda x: x["days_until_rotation"])
    grouped["ok"].sort(key=lambda x: x["name"])
    return grouped


# ---------- Loading -------------------------------------------------------

_REQUIRED_FIELDS = ("name", "last_rotated", "rotation_policy_days", "required_by")


def load_secrets(path: str) -> list[Secret]:
    """Load secrets from a JSON file. Raises informative errors on failure."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"Secrets file not found: {path}") from None

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e.msg} (line {e.lineno})") from e

    if not isinstance(data, list):
        raise ValueError(f"{path}: expected top-level JSON array of secrets")

    secrets: list[Secret] = []
    for i, entry in enumerate(data):
        if not isinstance(entry, dict):
            raise ValueError(f"{path}: entry {i} is not an object")
        missing = [k for k in _REQUIRED_FIELDS if k not in entry]
        if missing:
            raise ValueError(
                f"{path}: entry {i} ({entry.get('name', '?')}) missing fields: "
                f"{', '.join(missing)}"
            )
        try:
            lr = date.fromisoformat(entry["last_rotated"])
        except (TypeError, ValueError) as e:
            raise ValueError(
                f"{path}: entry {i} ({entry['name']}): invalid last_rotated "
                f"date '{entry['last_rotated']}' ({e})"
            ) from e
        policy = entry["rotation_policy_days"]
        if not isinstance(policy, int) or policy <= 0:
            raise ValueError(
                f"{path}: entry {i} ({entry['name']}): rotation_policy_days "
                f"must be a positive integer, got {policy!r}"
            )
        required_by = entry["required_by"]
        if not isinstance(required_by, list) or not all(
            isinstance(x, str) for x in required_by
        ):
            raise ValueError(
                f"{path}: entry {i} ({entry['name']}): required_by must be a "
                f"list of strings"
            )
        secrets.append(
            Secret(
                name=str(entry["name"]),
                last_rotated=lr,
                rotation_policy_days=policy,
                required_by=list(required_by),
            )
        )
    return secrets


# ---------- Rendering -----------------------------------------------------

def _summary(grouped: dict[str, list[dict]]) -> dict[str, int]:
    return {k: len(grouped[k]) for k in URGENCY_ORDER}


def render_markdown(grouped: dict[str, list[dict]]) -> str:
    """Render grouped results as a markdown report with one table per bucket."""
    lines: list[str] = ["# Secret Rotation Report", ""]
    summary = _summary(grouped)
    lines.append(
        f"**Summary:** {summary['expired']} expired, "
        f"{summary['warning']} warning, {summary['ok']} ok"
    )
    lines.append("")

    headings = {
        "expired": "Expired",
        "warning": "Warning",
        "ok": "OK",
    }
    for bucket in URGENCY_ORDER:
        items = grouped[bucket]
        lines.append(f"## {headings[bucket]} ({len(items)})")
        lines.append("")
        if not items:
            lines.append("_None_")
            lines.append("")
            continue
        lines.append(
            "| Name | Last Rotated | Policy (days) | Status | Required By |"
        )
        lines.append("|------|--------------|---------------|--------|-------------|")
        for item in items:
            if bucket == "expired":
                status = f"{item['days_overdue']} days overdue"
            elif bucket == "warning":
                status = f"due in {item['days_until_rotation']} days"
            else:
                status = f"{item['days_until_rotation']} days remaining"
            required_by = ", ".join(item["required_by"]) or "—"
            lines.append(
                f"| {item['name']} | {item['last_rotated']} | "
                f"{item['rotation_policy_days']} | {status} | {required_by} |"
            )
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_json(grouped: dict[str, list[dict]]) -> str:
    payload = {k: grouped[k] for k in URGENCY_ORDER}
    payload["summary"] = _summary(grouped)
    return json.dumps(payload, indent=2, sort_keys=False)


# ---------- Top-level validate ------------------------------------------

_FORMATS = {"markdown", "json"}


def validate(
    path: str,
    *,
    warning_days: int,
    output_format: str,
    today: date | None = None,
) -> str:
    if output_format not in _FORMATS:
        raise ValueError(
            f"Unsupported output format: {output_format!r} "
            f"(choose from {sorted(_FORMATS)})"
        )
    if today is None:
        today = date.today()
    secrets = load_secrets(path)
    grouped = classify_secrets(secrets, today=today, warning_days=warning_days)
    if output_format == "markdown":
        return render_markdown(grouped)
    return render_json(grouped)


# ---------- CLI ---------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="secret_rotation",
        description="Validate secret rotation status and generate a report.",
    )
    parser.add_argument("secrets_file", help="Path to secrets JSON file.")
    parser.add_argument(
        "--warning-days",
        type=int,
        default=7,
        help="Window (days) before expiry in which a secret is a 'warning'.",
    )
    parser.add_argument(
        "--format",
        choices=sorted(_FORMATS),
        default="markdown",
        help="Output format.",
    )
    parser.add_argument(
        "--today",
        help="Override today's date (ISO). Useful for deterministic CI runs.",
    )
    parser.add_argument(
        "--fail-on-expired",
        action="store_true",
        help="Exit non-zero if any secret is expired.",
    )
    args = parser.parse_args(argv)

    today = date.fromisoformat(args.today) if args.today else date.today()

    try:
        secrets = load_secrets(args.secrets_file)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    grouped = classify_secrets(secrets, today=today, warning_days=args.warning_days)
    output = (
        render_markdown(grouped)
        if args.format == "markdown"
        else render_json(grouped)
    )
    print(output)
    if args.fail_on_expired and grouped["expired"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
