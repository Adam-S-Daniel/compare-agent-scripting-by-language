"""
Secret Rotation Validator
=========================
Identifies secrets that are expired or expiring within a configurable warning window.
Generates rotation reports and notifications grouped by urgency (expired, warning, ok).
Supports multiple output formats: markdown table and JSON.

Architecture:
- SecretConfig: Data class representing a single secret's configuration.
- parse_secret_config(): Parses and validates raw dict data into a SecretConfig.
- classify_secret(): Determines urgency status for a single secret.
- generate_report(): Classifies all secrets and builds a structured report.
- format_markdown(): Renders the report as a markdown table.
- format_json(): Renders the report as JSON.
"""

from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any
import json


# --- Data Model ---

@dataclass
class SecretConfig:
    """Represents a secret with its rotation metadata."""
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: list[str]


# --- Urgency levels for classification ---

EXPIRED = "expired"
WARNING = "warning"
OK = "ok"


@dataclass
class SecretStatus:
    """A secret with its computed urgency status and days info."""
    config: SecretConfig
    status: str           # one of EXPIRED, WARNING, OK
    days_since_rotation: int
    days_until_expiry: int  # negative means overdue


# --- Parsing & Validation ---

REQUIRED_FIELDS = ["name", "last_rotated", "rotation_policy_days", "required_by"]


def parse_secret_config(data: dict[str, Any]) -> SecretConfig:
    """
    Parse a dict into a SecretConfig, validating all required fields.
    Raises ValueError with a descriptive message on invalid input.
    """
    # Check required fields
    for field_name in REQUIRED_FIELDS:
        if field_name not in data:
            raise ValueError(
                f"Missing required field '{field_name}' in secret configuration"
            )

    name = data["name"]
    if not isinstance(name, str) or not name.strip():
        raise ValueError("'name' must be a non-empty string")

    # Parse date
    raw_date = data["last_rotated"]
    try:
        last_rotated = date.fromisoformat(raw_date)
    except (ValueError, TypeError):
        raise ValueError(
            f"Invalid date format for 'last_rotated': '{raw_date}'. "
            f"Expected ISO format (YYYY-MM-DD)."
        )

    # Validate rotation policy
    rotation_policy_days = data["rotation_policy_days"]
    if not isinstance(rotation_policy_days, int) or rotation_policy_days <= 0:
        raise ValueError(
            f"'rotation_policy_days' must be a positive integer, got {rotation_policy_days}"
        )

    # Validate required_by
    required_by = data["required_by"]
    if not isinstance(required_by, list):
        raise ValueError("'required_by' must be a list of service names")

    return SecretConfig(
        name=name,
        last_rotated=last_rotated,
        rotation_policy_days=rotation_policy_days,
        required_by=required_by,
    )


# --- Classification ---

def classify_secret(
    config: SecretConfig,
    warning_window_days: int = 14,
    reference_date: date | None = None,
) -> SecretStatus:
    """
    Classify a secret as expired, warning, or ok based on its rotation policy.

    Args:
        config: The secret configuration to evaluate.
        warning_window_days: Number of days before expiry to trigger a warning.
        reference_date: The date to evaluate against (defaults to today).

    Returns:
        A SecretStatus with the computed urgency level.
    """
    if warning_window_days < 0:
        raise ValueError(
            f"'warning_window_days' must be non-negative, got {warning_window_days}"
        )

    today = reference_date or date.today()
    expiry_date = config.last_rotated + timedelta(days=config.rotation_policy_days)
    days_since_rotation = (today - config.last_rotated).days
    days_until_expiry = (expiry_date - today).days

    if days_until_expiry < 0:
        status = EXPIRED
    elif days_until_expiry <= warning_window_days:
        status = WARNING
    else:
        status = OK

    return SecretStatus(
        config=config,
        status=status,
        days_since_rotation=days_since_rotation,
        days_until_expiry=days_until_expiry,
    )


# --- Report Generation ---

@dataclass
class RotationReport:
    """A full rotation report with secrets grouped by urgency."""
    expired: list[SecretStatus] = field(default_factory=list)
    warning: list[SecretStatus] = field(default_factory=list)
    ok: list[SecretStatus] = field(default_factory=list)
    reference_date: date = field(default_factory=date.today)
    warning_window_days: int = 14


def generate_report(
    configs: list[SecretConfig],
    warning_window_days: int = 14,
    reference_date: date | None = None,
) -> RotationReport:
    """
    Classify all secrets and produce a grouped rotation report.

    Args:
        configs: List of secret configurations to evaluate.
        warning_window_days: Days before expiry that trigger a warning.
        reference_date: The date to evaluate against (defaults to today).

    Returns:
        RotationReport with secrets grouped by urgency.
    """
    ref = reference_date or date.today()
    report = RotationReport(
        reference_date=ref,
        warning_window_days=warning_window_days,
    )

    for config in configs:
        secret_status = classify_secret(config, warning_window_days, ref)
        if secret_status.status == EXPIRED:
            report.expired.append(secret_status)
        elif secret_status.status == WARNING:
            report.warning.append(secret_status)
        else:
            report.ok.append(secret_status)

    return report


# --- Output Formatters ---

def _status_to_dict(ss: SecretStatus) -> dict:
    """Convert a SecretStatus to a JSON-serializable dict."""
    return {
        "name": ss.config.name,
        "status": ss.status,
        "last_rotated": ss.config.last_rotated.isoformat(),
        "rotation_policy_days": ss.config.rotation_policy_days,
        "days_since_rotation": ss.days_since_rotation,
        "days_until_expiry": ss.days_until_expiry,
        "required_by": ss.config.required_by,
    }


def format_json(report: RotationReport, indent: int = 2) -> str:
    """
    Format a rotation report as a JSON string.

    Returns a JSON object with 'metadata' and 'secrets' grouped by urgency.
    """
    data = {
        "metadata": {
            "reference_date": report.reference_date.isoformat(),
            "warning_window_days": report.warning_window_days,
            "total_secrets": (
                len(report.expired) + len(report.warning) + len(report.ok)
            ),
            "expired_count": len(report.expired),
            "warning_count": len(report.warning),
            "ok_count": len(report.ok),
        },
        "secrets": {
            "expired": [_status_to_dict(s) for s in report.expired],
            "warning": [_status_to_dict(s) for s in report.warning],
            "ok": [_status_to_dict(s) for s in report.ok],
        },
    }
    return json.dumps(data, indent=indent)


def format_markdown(report: RotationReport) -> str:
    """
    Format a rotation report as a markdown string with a table per urgency group.

    Includes a summary header and one table per non-empty urgency group.
    """
    lines: list[str] = []
    total = len(report.expired) + len(report.warning) + len(report.ok)

    # Header
    lines.append(f"# Secret Rotation Report")
    lines.append(f"")
    lines.append(f"**Date:** {report.reference_date.isoformat()}")
    lines.append(f"**Warning window:** {report.warning_window_days} days")
    lines.append(f"**Total secrets:** {total}")
    lines.append(f"")

    # Summary counts
    lines.append(f"| Status | Count |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Expired | {len(report.expired)} |")
    lines.append(f"| Warning | {len(report.warning)} |")
    lines.append(f"| OK | {len(report.ok)} |")
    lines.append(f"")

    # Helper to render a group table
    def _render_group(title: str, statuses: list[SecretStatus]) -> None:
        if not statuses:
            return
        lines.append(f"## {title}")
        lines.append(f"")
        lines.append(
            "| Secret | Last Rotated | Policy (days) | Days Until Expiry | Required By |"
        )
        lines.append(
            "|--------|-------------|---------------|-------------------|-------------|"
        )
        for ss in statuses:
            services = ", ".join(ss.config.required_by)
            lines.append(
                f"| {ss.config.name} "
                f"| {ss.config.last_rotated.isoformat()} "
                f"| {ss.config.rotation_policy_days} "
                f"| {ss.days_until_expiry} "
                f"| {services} |"
            )
        lines.append(f"")

    _render_group("Expired", report.expired)
    _render_group("Warning", report.warning)
    _render_group("OK", report.ok)

    return "\n".join(lines)


# --- Bulk Loading ---

def load_secrets_from_json(json_str: str) -> list[SecretConfig]:
    """
    Parse a JSON string containing a list of secret config dicts.
    Returns validated SecretConfig objects.
    Raises ValueError with details on any invalid entry.
    """
    try:
        data = json.loads(json_str)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON input: {e}")

    if not isinstance(data, list):
        raise ValueError("Expected a JSON array of secret configurations")

    configs: list[SecretConfig] = []
    errors: list[str] = []

    for i, entry in enumerate(data):
        try:
            configs.append(parse_secret_config(entry))
        except ValueError as e:
            errors.append(f"Secret at index {i}: {e}")

    if errors:
        raise ValueError(
            "Validation errors in secret configurations:\n"
            + "\n".join(f"  - {err}" for err in errors)
        )

    return configs
