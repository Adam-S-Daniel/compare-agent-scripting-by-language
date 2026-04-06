"""
Secret Rotation Validator
=========================
Identifies secrets that are expired or expiring within a configurable warning
window, generates rotation reports, and outputs notifications grouped by
urgency (expired, warning, ok).

TDD approach:
  1. Write failing test
  2. Implement minimum code to pass
  3. Refactor for clarity
"""

import json
from dataclasses import dataclass, field
from datetime import date
from enum import Enum
from typing import List, Dict


# ============================================================
# Data Model
# ============================================================

@dataclass
class Secret:
    """
    Represents a secret with rotation metadata.

    Attributes:
        name: Unique identifier for the secret.
        last_rotated: Date the secret was last rotated.
        rotation_policy_days: How often (days) the secret must be rotated.
        required_by: Services that depend on this secret.
    """
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: List[str] = field(default_factory=list)

    @property
    def expiry_date(self) -> date:
        """The date on which this secret becomes (or became) expired."""
        from datetime import timedelta
        return self.last_rotated + timedelta(days=self.rotation_policy_days)

    @property
    def days_until_expiry(self) -> int:
        """
        Days remaining until the secret expires, relative to today.
        Negative values mean the secret is already expired.
        Zero means it expires today (treated as expired).
        """
        return (self.expiry_date - date.today()).days


# ============================================================
# Status Classification
# ============================================================

class RotationStatus(Enum):
    """Urgency level for a secret's rotation state."""
    EXPIRED = "expired"
    WARNING = "warning"
    OK = "ok"


def classify_secret(secret: Secret, warning_days: int) -> RotationStatus:
    """
    Classify a secret's rotation status.

    Rules:
      - days_until_expiry <= 0  →  EXPIRED
      - 0 < days_until_expiry <= warning_days  →  WARNING
      - days_until_expiry > warning_days  →  OK

    Args:
        secret: The secret to evaluate.
        warning_days: Number of days before expiry that triggers a warning.

    Returns:
        The RotationStatus for the secret.
    """
    days = secret.days_until_expiry
    if days <= 0:
        return RotationStatus.EXPIRED
    if days <= warning_days:
        return RotationStatus.WARNING
    return RotationStatus.OK


# ============================================================
# Report Generation
# ============================================================

def generate_report(secrets: List[Secret], warning_days: int) -> Dict[str, List[Secret]]:
    """
    Group secrets by their rotation status.

    Args:
        secrets: List of secrets to evaluate.
        warning_days: Configurable warning window (days before expiry).

    Returns:
        Dict with keys "expired", "warning", "ok", each mapping to a list
        of Secret objects in that urgency group.
    """
    report: Dict[str, List[Secret]] = {"expired": [], "warning": [], "ok": []}

    for secret in secrets:
        status = classify_secret(secret, warning_days)
        report[status.value].append(secret)

    return report


# ============================================================
# Output Formatters
# ============================================================

def _secret_to_dict(secret: Secret) -> dict:
    """Convert a Secret to a JSON-serialisable dict."""
    return {
        "name": secret.name,
        "last_rotated": secret.last_rotated.isoformat(),
        "expiry_date": secret.expiry_date.isoformat(),
        "days_until_expiry": secret.days_until_expiry,
        "rotation_policy_days": secret.rotation_policy_days,
        "required_by": secret.required_by,
    }


def format_json(report: Dict[str, List[Secret]], indent: int = 2) -> str:
    """
    Serialise the rotation report to a JSON string.

    Args:
        report: Output of generate_report().
        indent: JSON indentation level.

    Returns:
        Pretty-printed JSON string.
    """
    serialisable = {
        group: [_secret_to_dict(s) for s in secrets]
        for group, secrets in report.items()
    }
    return json.dumps(serialisable, indent=indent)


def _make_table(secrets: List[Secret]) -> str:
    """
    Build a Markdown table for a list of secrets.
    Returns a 'None' notice when the list is empty.
    """
    if not secrets:
        return "_None_\n"

    header = "| Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |"
    separator = "|------|-------------|------------|-------------------|-------------|"
    rows = [
        f"| {s.name} | {s.last_rotated} | {s.expiry_date} "
        f"| {s.days_until_expiry} | {', '.join(s.required_by) or '—'} |"
        for s in secrets
    ]
    return "\n".join([header, separator] + rows) + "\n"


def format_markdown(report: Dict[str, List[Secret]]) -> str:
    """
    Render the rotation report as a Markdown document with tables grouped
    by urgency.

    Args:
        report: Output of generate_report().

    Returns:
        Markdown-formatted string.
    """
    sections = [
        ("## 🔴 EXPIRED", report["expired"]),
        ("## 🟡 WARNING", report["warning"]),
        ("## 🟢 OK", report["ok"]),
    ]

    parts = ["# Secret Rotation Report\n"]
    for heading, secrets in sections:
        parts.append(heading)
        parts.append(_make_table(secrets))

    return "\n".join(parts)
