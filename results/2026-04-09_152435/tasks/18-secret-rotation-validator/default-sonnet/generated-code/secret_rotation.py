"""
Secret Rotation Validator
=========================
Given a configuration of secrets with metadata, identify which secrets are
expired or expiring soon, and generate a rotation report.

Urgency levels:
  expired  — days_until_expiry <= 0  (already past due)
  warning  — 0 < days_until_expiry <= warning_window_days  (expiring soon)
  ok       — days_until_expiry > warning_window_days  (healthy)

Output formats: markdown table, JSON.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import List, Optional


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Secret:
    """Represents a single secret with its rotation metadata."""
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: List[str] = field(default_factory=list)


@dataclass
class SecretStatus:
    """The computed rotation status for a Secret."""
    secret: Secret
    days_until_expiry: int   # negative means already expired
    urgency: str             # 'expired' | 'warning' | 'ok'


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

DEFAULT_WARNING_WINDOW_DAYS = 7


def categorize_secret(
    secret: Secret,
    reference_date: date,
    warning_window_days: int = DEFAULT_WARNING_WINDOW_DAYS,
) -> SecretStatus:
    """Compute the urgency status for a single secret.

    Args:
        secret: The secret to evaluate.
        reference_date: The date to treat as "today" (allows deterministic tests).
        warning_window_days: Days before expiry to start showing warnings.

    Returns:
        SecretStatus with days_until_expiry and urgency label.
    """
    expiry_date = secret.last_rotated + timedelta(days=secret.rotation_policy_days)
    days_until = (expiry_date - reference_date).days

    if days_until <= 0:
        urgency = "expired"
    elif days_until <= warning_window_days:
        urgency = "warning"
    else:
        urgency = "ok"

    return SecretStatus(secret=secret, days_until_expiry=days_until, urgency=urgency)


def _parse_secret(raw: dict) -> Secret:
    """Parse one secret entry from the config dict.

    Raises ValueError with a descriptive message on invalid input.
    """
    if "name" not in raw:
        raise ValueError("Secret entry missing required 'name' field")

    name = raw["name"]

    try:
        last_rotated = date.fromisoformat(raw["last_rotated"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(
            f"Secret '{name}': invalid or missing 'last_rotated' date "
            f"(expected ISO-8601 YYYY-MM-DD, got {raw.get('last_rotated')!r})"
        ) from exc

    try:
        rotation_policy_days = int(raw["rotation_policy_days"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(
            f"Secret '{name}': invalid or missing 'rotation_policy_days'"
        ) from exc

    required_by = raw.get("required_by", [])
    return Secret(
        name=name,
        last_rotated=last_rotated,
        rotation_policy_days=rotation_policy_days,
        required_by=list(required_by),
    )


def validate_secrets(
    config: dict,
    reference_date: Optional[date] = None,
) -> List[SecretStatus]:
    """Process a configuration dict and return a status for every secret.

    Config schema:
        {
          "warning_window_days": 7,        # optional, defaults to 7
          "reference_date": "2026-04-10",  # optional, defaults to today
          "secrets": [
            {
              "name": "MY_SECRET",
              "last_rotated": "2026-01-01",
              "rotation_policy_days": 90,
              "required_by": ["service-a"]
            },
            ...
          ]
        }

    Args:
        config: Parsed configuration dictionary.
        reference_date: Override "today" for deterministic results.

    Returns:
        List of SecretStatus, one per secret in config.

    Raises:
        ValueError: On invalid or missing required fields.
    """
    warning_window = int(config.get("warning_window_days", DEFAULT_WARNING_WINDOW_DAYS))

    # Determine the reference date (priority: argument > config > today)
    if reference_date is None:
        ref_str = config.get("reference_date")
        if ref_str:
            try:
                reference_date = date.fromisoformat(ref_str)
            except ValueError as exc:
                raise ValueError(f"Invalid 'reference_date' in config: {ref_str!r}") from exc
        else:
            reference_date = date.today()

    raw_secrets = config.get("secrets", [])
    statuses: List[SecretStatus] = []
    for raw in raw_secrets:
        secret = _parse_secret(raw)
        status = categorize_secret(secret, reference_date, warning_window)
        statuses.append(status)

    return statuses


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

# Ordering for grouped output (most urgent first)
_URGENCY_ORDER = ["expired", "warning", "ok"]


def _group_by_urgency(statuses: List[SecretStatus]) -> dict[str, List[SecretStatus]]:
    """Return statuses grouped by urgency, in priority order."""
    groups: dict[str, List[SecretStatus]] = {u: [] for u in _URGENCY_ORDER}
    for s in statuses:
        groups[s.urgency].append(s)
    return groups


def format_markdown(statuses: List[SecretStatus]) -> str:
    """Render a markdown rotation report grouped by urgency.

    The report uses a GitHub-Flavored Markdown table with one section per
    urgency level.  Expired secrets appear first, then warnings, then ok.
    """
    groups = _group_by_urgency(statuses)
    lines: List[str] = []

    lines.append("# Secret Rotation Report\n")

    # Summary section
    summary_counts = {u: len(groups[u]) for u in _URGENCY_ORDER}
    lines.append("## Summary\n")
    lines.append(
        f"- **Expired**: {summary_counts['expired']}\n"
        f"- **Warning**: {summary_counts['warning']}\n"
        f"- **OK**: {summary_counts['ok']}\n"
    )

    # One table per urgency level (only render non-empty groups)
    section_titles = {
        "expired": "Expired Secrets (action required)",
        "warning": "Expiring Soon (warning)",
        "ok": "OK Secrets",
    }

    lines.append("## Details\n")
    lines.append("| Name | Urgency | Days Until Expiry | Required By |")
    lines.append("|------|---------|-------------------|-------------|")

    for urgency in _URGENCY_ORDER:
        for st in groups[urgency]:
            days = st.days_until_expiry
            days_str = str(days) if days > 0 else f"{days} (overdue)"
            services = ", ".join(st.secret.required_by) if st.secret.required_by else "-"
            lines.append(
                f"| {st.secret.name} | {urgency.upper()} | {days_str} | {services} |"
            )

    return "\n".join(lines) + "\n"


def format_json(statuses: List[SecretStatus]) -> str:
    """Render a JSON rotation report grouped by urgency.

    Output structure:
        {
          "summary": {"expired": N, "warning": N, "ok": N},
          "groups": {
            "expired": [{"name": ..., "days_until_expiry": ..., "required_by": [...], "last_rotated": "...", "rotation_policy_days": N}],
            "warning": [...],
            "ok": [...]
          }
        }
    """
    groups = _group_by_urgency(statuses)

    def status_to_dict(st: SecretStatus) -> dict:
        return {
            "name": st.secret.name,
            "last_rotated": st.secret.last_rotated.isoformat(),
            "rotation_policy_days": st.secret.rotation_policy_days,
            "days_until_expiry": st.days_until_expiry,
            "required_by": st.secret.required_by,
        }

    data = {
        "summary": {u: len(groups[u]) for u in _URGENCY_ORDER},
        "groups": {u: [status_to_dict(s) for s in groups[u]] for u in _URGENCY_ORDER},
    }
    return json.dumps(data, indent=2)


def generate_report(statuses: List[SecretStatus], fmt: str = "markdown") -> str:
    """Dispatch to the appropriate formatter.

    Args:
        statuses: List of SecretStatus objects from validate_secrets().
        fmt: Output format — 'markdown' or 'json'.

    Returns:
        Formatted report string.

    Raises:
        ValueError: For unrecognised format strings.
    """
    if fmt == "markdown":
        return format_markdown(statuses)
    if fmt == "json":
        return format_json(statuses)
    raise ValueError(
        f"Unknown output format {fmt!r}. Supported formats: 'markdown', 'json'."
    )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _cli() -> None:
    """Command-line interface: read a JSON config file and print the report.

    Usage:
        python secret_rotation.py <config.json> [--format markdown|json]
        python secret_rotation.py <config.json> [--reference-date YYYY-MM-DD]
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate secret rotation policies and generate a report."
    )
    parser.add_argument("config", help="Path to JSON config file")
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--reference-date",
        metavar="YYYY-MM-DD",
        help="Override today's date for deterministic output (default: today)",
    )
    args = parser.parse_args()

    try:
        with open(args.config) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Error: config file not found: {args.config}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in {args.config}: {exc}", file=sys.stderr)
        sys.exit(1)

    ref_date: Optional[date] = None
    if args.reference_date:
        try:
            ref_date = date.fromisoformat(args.reference_date)
        except ValueError:
            print(
                f"Error: invalid --reference-date {args.reference_date!r} "
                "(expected YYYY-MM-DD)",
                file=sys.stderr,
            )
            sys.exit(1)

    try:
        statuses = validate_secrets(config, reference_date=ref_date)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    report = generate_report(statuses, fmt=args.format)
    print(report)

    # Exit with non-zero code if any secrets are expired (useful in CI)
    expired_count = sum(1 for s in statuses if s.urgency == "expired")
    if expired_count > 0:
        sys.exit(2)


if __name__ == "__main__":
    _cli()
