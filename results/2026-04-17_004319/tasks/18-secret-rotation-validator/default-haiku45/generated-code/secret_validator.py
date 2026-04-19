"""
Secret rotation validator.

Manages secrets with metadata, identifies expired/expiring secrets,
generates reports in multiple formats (markdown, JSON).
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from typing import List, Optional


class Urgency(Enum):
    """Classification of secret urgency based on rotation status."""
    EXPIRED = "EXPIRED"
    WARNING = "WARNING"
    OK = "OK"


class Secret:
    """Represents a secret with rotation metadata."""

    def __init__(
        self,
        name: str,
        last_rotated: datetime,
        rotation_policy_days: int,
        required_by: List[str]
    ):
        self.name = name
        self.last_rotated = last_rotated
        self.rotation_policy_days = rotation_policy_days
        self.required_by = required_by

    def is_expired(self, as_of: Optional[datetime] = None) -> bool:
        """Check if secret is past its rotation deadline."""
        if as_of is None:
            as_of = datetime.now()
        deadline = self.last_rotated + timedelta(days=self.rotation_policy_days)
        return as_of > deadline

    def days_until_expiry(self, as_of: Optional[datetime] = None) -> int:
        """Calculate days remaining until expiry. Negative if expired."""
        if as_of is None:
            as_of = datetime.now()
        deadline = self.last_rotated + timedelta(days=self.rotation_policy_days)
        delta = deadline - as_of
        return delta.days

    def get_urgency(self, warning_window_days: int, as_of: Optional[datetime] = None) -> Urgency:
        """Classify secret urgency."""
        if self.is_expired(as_of):
            return Urgency.EXPIRED
        days_left = self.days_until_expiry(as_of)
        if days_left <= warning_window_days:
            return Urgency.WARNING
        return Urgency.OK


class RotationReport:
    """Contains categorized secrets and report generation methods."""

    def __init__(self, secrets_by_urgency: dict):
        self.secrets_by_urgency = secrets_by_urgency
        self.expired_count = len(secrets_by_urgency.get(Urgency.EXPIRED, []))
        self.warning_count = len(secrets_by_urgency.get(Urgency.WARNING, []))
        self.ok_count = len(secrets_by_urgency.get(Urgency.OK, []))

    def to_markdown(self) -> str:
        """Generate markdown table output."""
        lines = [
            "# Secret Rotation Report",
            "",
            "## Summary",
            f"- **Expired**: {self.expired_count}",
            f"- **Warning**: {self.warning_count}",
            f"- **OK**: {self.ok_count}",
            "",
            "## Details",
            "",
        ]

        for urgency in [Urgency.EXPIRED, Urgency.WARNING, Urgency.OK]:
            secrets = self.secrets_by_urgency.get(urgency, [])
            if not secrets:
                continue

            lines.append(f"### {urgency.value}")
            lines.append("")
            lines.append("| Secret | Last Rotated | Days Until Expiry | Required By |")
            lines.append("|--------|--------------|-------------------|-------------|")

            for secret in secrets:
                last_rot = secret.last_rotated.strftime("%Y-%m-%d")
                days_left = secret.days_until_expiry()
                services = ", ".join(secret.required_by)
                lines.append(
                    f"| {secret.name} | {last_rot} | {days_left} | {services} |"
                )
            lines.append("")

        return "\n".join(lines)

    def to_json(self) -> str:
        """Generate JSON output."""
        output = {
            "summary": {
                "expired": self.expired_count,
                "warning": self.warning_count,
                "ok": self.ok_count
            },
            "by_urgency": {}
        }

        for urgency in [Urgency.EXPIRED, Urgency.WARNING, Urgency.OK]:
            secrets = self.secrets_by_urgency.get(urgency, [])
            output["by_urgency"][urgency.value] = [
                {
                    "name": s.name,
                    "last_rotated": s.last_rotated.isoformat(),
                    "days_until_expiry": s.days_until_expiry(),
                    "required_by": s.required_by
                }
                for s in secrets
            ]

        return json.dumps(output, indent=2)


class SecretValidator:
    """Main validator class for managing secrets and generating reports."""

    def __init__(self, warning_window_days: int = 7):
        self.warning_window_days = warning_window_days
        self.secrets: List[Secret] = []

    def add_secret(self, secret: Secret) -> None:
        """Add a secret to be tracked."""
        self.secrets.append(secret)

    def generate_report(self) -> RotationReport:
        """Categorize secrets and generate a report."""
        secrets_by_urgency = {
            Urgency.EXPIRED: [],
            Urgency.WARNING: [],
            Urgency.OK: []
        }

        for secret in self.secrets:
            urgency = secret.get_urgency(self.warning_window_days)
            secrets_by_urgency[urgency].append(secret)

        return RotationReport(secrets_by_urgency)
