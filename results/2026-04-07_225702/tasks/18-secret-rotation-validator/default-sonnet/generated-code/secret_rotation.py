"""
Secret Rotation Validator
=========================

Identifies secrets that are expired or expiring within a configurable window,
generates a rotation report, and renders it as Markdown or JSON.

TDD cycles implemented here (each section was driven by failing tests):
  Cycle 1 — Secret model + classify_secret()
  Cycle 2 — generate_report()
  Cycle 3 — format_markdown()
  Cycle 4 — format_json()
"""

import json
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import List, Dict, Any


# ---------------------------------------------------------------------------
# CYCLE 1 — Secret model and single-secret classification
# ---------------------------------------------------------------------------

@dataclass
class Secret:
    """Represents a single managed secret with its rotation metadata."""
    name: str
    last_rotated: date
    rotation_policy_days: int
    required_by: List[str] = field(default_factory=list)

    @property
    def expiry_date(self) -> date:
        """The date on which this secret becomes expired."""
        return self.last_rotated + timedelta(days=self.rotation_policy_days)

    @property
    def days_remaining(self) -> int:
        """Positive → days until expiry; 0 → expires today; negative → already expired."""
        return (self.expiry_date - date.today()).days


def classify_secret(secret: Secret, warning_days: int) -> str:
    """
    Classify a secret into one of three urgency levels:

    - "expired"  : expiry_date <= today  (days_remaining <= 0)
    - "warning"  : days_remaining is within the warning window  (0 < days_remaining <= warning_days)
    - "ok"       : more than warning_days remain
    """
    remaining = secret.days_remaining
    if remaining <= 0:
        return "expired"
    if remaining <= warning_days:
        return "warning"
    return "ok"


# ---------------------------------------------------------------------------
# CYCLE 2 — Report generation (grouping secrets by urgency)
# ---------------------------------------------------------------------------

def _secret_to_entry(secret: Secret) -> Dict[str, Any]:
    """Convert a Secret to the dict shape used inside report groups."""
    return {
        "name": secret.name,
        "days_remaining": secret.days_remaining,
        "expiry_date": secret.expiry_date.isoformat(),
        "required_by": secret.required_by,
    }


def generate_report(secrets: List[Secret], warning_days: int) -> Dict[str, List[Dict[str, Any]]]:
    """
    Group secrets by urgency and return a structured report dict:

        {
            "expired": [...],
            "warning": [...],
            "ok":      [...],
        }

    Each entry contains: name, days_remaining, expiry_date, required_by.
    """
    report: Dict[str, List[Dict[str, Any]]] = {"expired": [], "warning": [], "ok": []}

    for secret in secrets:
        level = classify_secret(secret, warning_days)
        report[level].append(_secret_to_entry(secret))

    return report


# ---------------------------------------------------------------------------
# CYCLE 3 — Markdown table renderer
# ---------------------------------------------------------------------------

def _md_table(entries: List[Dict[str, Any]]) -> str:
    """Render a list of report entries as a Markdown table."""
    header = "| Name | Days Remaining | Expiry Date | Required By |\n"
    separator = "|------|----------------|-------------|-------------|\n"
    rows = ""
    for e in entries:
        required = ", ".join(e["required_by"]) if e["required_by"] else "—"
        rows += f"| {e['name']} | {e['days_remaining']} | {e['expiry_date']} | {required} |\n"
    return header + separator + rows


def format_markdown(report: Dict[str, List[Dict[str, Any]]]) -> str:
    """
    Render the rotation report as a Markdown document with three sections
    (Expired, Warning, OK), each containing a table or a placeholder message.
    """
    sections = {
        "Expired": ("expired", "No expired secrets"),
        "Warning": ("warning", "No warning secrets"),
        "OK":      ("ok",      "No OK secrets"),
    }

    lines: List[str] = ["# Secret Rotation Report\n"]

    for heading, (key, empty_msg) in sections.items():
        lines.append(f"## {heading}\n")
        entries = report.get(key, [])
        if entries:
            lines.append(_md_table(entries))
        else:
            lines.append(f"_{empty_msg}_\n")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CYCLE 4 — JSON renderer
# ---------------------------------------------------------------------------

def format_json(report: Dict[str, List[Dict[str, Any]]]) -> str:
    """
    Render the rotation report as a JSON string.

    Includes a top-level "metadata" key with:
      - generated_at : ISO date string for today
      - total_expired / total_warning / total_ok : counts per group
    """
    payload = {
        "metadata": {
            "generated_at": date.today().isoformat(),
            "total_expired": len(report.get("expired", [])),
            "total_warning": len(report.get("warning", [])),
            "total_ok":      len(report.get("ok", [])),
        },
        "expired": report.get("expired", []),
        "warning": report.get("warning", []),
        "ok":      report.get("ok", []),
    }
    return json.dumps(payload, indent=2)
