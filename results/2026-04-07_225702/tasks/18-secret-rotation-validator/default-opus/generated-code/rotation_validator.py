"""Secret rotation validator — identifies expired/expiring secrets and generates reports.

Processes a configuration of secrets with metadata (name, last-rotated date,
rotation policy in days, required-by services) and classifies each secret as
expired, warning, or ok. Supports markdown and JSON output formats.
"""

import json
import sys
from datetime import date, timedelta
from pathlib import Path


# -- Core classification logic --

def classify_secret(
    last_rotated: date,
    rotation_days: int,
    warning_days: int,
    today: date | None = None,
) -> str:
    """Classify a secret as 'expired', 'warning', or 'ok' based on its rotation policy.

    A secret expires rotation_days after last_rotated. The warning window starts
    warning_days before the expiry date.
    """
    today = today or date.today()
    expiry_date = last_rotated + timedelta(days=rotation_days)
    warning_date = expiry_date - timedelta(days=warning_days)

    if today >= expiry_date:
        return "expired"
    elif today >= warning_date:
        return "warning"
    else:
        return "ok"


# -- Input validation and processing --

REQUIRED_FIELDS = {"name", "last_rotated", "rotation_days", "required_by"}


def _parse_secret(raw: dict) -> dict:
    """Validate and parse a raw secret dict. Raises ValueError on bad input."""
    name = raw.get("name", "<unknown>")

    missing = REQUIRED_FIELDS - set(raw.keys())
    if missing:
        raise ValueError(
            f"Secret '{name}' is missing required fields: {', '.join(sorted(missing))}"
        )

    if raw["rotation_days"] <= 0:
        raise ValueError(
            f"Secret '{name}' has invalid rotation_days: {raw['rotation_days']} (must be positive)"
        )

    try:
        last_rotated = date.fromisoformat(raw["last_rotated"])
    except (ValueError, TypeError):
        raise ValueError(
            f"Secret '{name}' has invalid last_rotated date: '{raw['last_rotated']}'"
        )

    return {
        "name": name,
        "last_rotated": last_rotated,
        "rotation_days": raw["rotation_days"],
        "required_by": raw["required_by"],
    }


def validate_secrets(
    secrets: list[dict],
    warning_days: int = 7,
    today: date | None = None,
) -> dict:
    """Process a list of secret configs and group them by urgency.

    Returns a dict with keys 'expired', 'warning', 'ok', each containing a list
    of enriched secret dicts with classification and days_until_expiry.
    """
    today = today or date.today()
    report: dict[str, list] = {"expired": [], "warning": [], "ok": []}

    for raw in secrets:
        parsed = _parse_secret(raw)
        status = classify_secret(
            parsed["last_rotated"], parsed["rotation_days"], warning_days, today
        )
        expiry_date = parsed["last_rotated"] + timedelta(days=parsed["rotation_days"])
        days_until = (expiry_date - today).days

        entry = {
            "name": parsed["name"],
            "last_rotated": parsed["last_rotated"].isoformat(),
            "rotation_days": parsed["rotation_days"],
            "expiry_date": expiry_date.isoformat(),
            "days_until_expiry": days_until,
            "status": status,
            "required_by": parsed["required_by"],
        }
        report[status].append(entry)

    return report


# -- Output formatters --

def _format_table(entries: list[dict]) -> str:
    """Render a list of secret entries as a markdown table."""
    if not entries:
        return "None.\n"
    lines = [
        "| Name | Last Rotated | Expires | Days Left | Required By |",
        "|------|-------------|---------|-----------|-------------|",
    ]
    for e in entries:
        services = ", ".join(e["required_by"])
        lines.append(
            f"| {e['name']} | {e['last_rotated']} | {e['expiry_date']} "
            f"| {e['days_until_expiry']} | {services} |"
        )
    return "\n".join(lines) + "\n"


def format_markdown(report: dict) -> str:
    """Format the full report as a markdown document with tables per urgency level."""
    sections = []
    sections.append("# Secret Rotation Report\n")
    for label, key in [("Expired", "expired"), ("Warning", "warning"), ("OK", "ok")]:
        sections.append(f"## {label}\n")
        sections.append(_format_table(report[key]))
    return "\n".join(sections)


def format_json(report: dict) -> str:
    """Format the report as pretty-printed JSON."""
    return json.dumps(report, indent=2)


# -- Config file loading --

def load_config(path: str) -> dict:
    """Load a secrets config file (JSON). Returns dict with 'secrets' and 'warning_days'."""
    filepath = Path(path)
    if not filepath.exists():
        raise FileNotFoundError(f"Config file not found: {path}")

    raw = filepath.read_text()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}")

    return data


# -- CLI entry point --

def main():
    """CLI: rotation_validator.py <config.json> [--format markdown|json] [--warning-days N]"""
    import argparse

    parser = argparse.ArgumentParser(description="Secret rotation validator")
    parser.add_argument("config", help="Path to secrets config JSON file")
    parser.add_argument(
        "--format", choices=["markdown", "json"], default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--warning-days", type=int, default=None,
        help="Warning window in days (overrides config file value)",
    )
    args = parser.parse_args()

    try:
        config = load_config(args.config)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    warning_days = args.warning_days or config.get("warning_days", 7)

    try:
        report = validate_secrets(config["secrets"], warning_days=warning_days)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.format == "json":
        print(format_json(report))
    else:
        print(format_markdown(report))

    # Exit with non-zero if any secrets are expired
    if report["expired"]:
        sys.exit(2)


if __name__ == "__main__":
    main()
