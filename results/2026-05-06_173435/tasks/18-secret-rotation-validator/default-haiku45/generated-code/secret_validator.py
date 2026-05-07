#!/usr/bin/env python3
"""
Secret Rotation Validator
Identifies secrets that are expired or expiring within a configurable window.
Generates rotation reports in markdown and JSON formats.
"""

import json
import sys
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import List, Dict, Any, Optional


class SecretStatus(Enum):
    """Classification of secret rotation status."""

    EXPIRED = "expired"
    WARNING = "warning"
    OK = "ok"


@dataclass
class SecretConfig:
    """Configuration for a single secret."""

    name: str
    last_rotated: datetime
    rotation_policy_days: int
    required_by_services: List[str]


def validate_secrets(
    configs: List[SecretConfig],
    current_time: Optional[datetime] = None,
    warning_days: int = 7,
) -> List[Dict[str, Any]]:
    """
    Validate secrets and return their status.

    Args:
        configs: List of SecretConfig objects
        current_time: Current datetime (defaults to now)
        warning_days: Days until expiry to trigger WARNING status

    Returns:
        List of dicts with validation results
    """
    if current_time is None:
        current_time = datetime.now()

    results = []
    for config in configs:
        days_since_rotation = (current_time - config.last_rotated).days
        days_until_expiry = config.rotation_policy_days - days_since_rotation

        # Determine status
        if days_until_expiry < 0:
            status = SecretStatus.EXPIRED
        elif days_until_expiry <= warning_days:
            status = SecretStatus.WARNING
        else:
            status = SecretStatus.OK

        results.append(
            {
                "name": config.name,
                "status": status,
                "last_rotated": config.last_rotated,
                "rotation_policy_days": config.rotation_policy_days,
                "days_until_expiry": days_until_expiry,
                "required_by_services": config.required_by_services,
            }
        )

    return results


def generate_markdown_report(results: List[Dict[str, Any]]) -> str:
    """
    Generate a markdown table report grouped by urgency.

    Args:
        results: List of validation results from validate_secrets()

    Returns:
        Markdown formatted report
    """
    # Group by status
    grouped = {"expired": [], "warning": [], "ok": []}
    for result in results:
        status_key = result["status"].value
        grouped[status_key].append(result)

    lines = []
    lines.append("# Secret Rotation Report\n")
    lines.append(f"Generated: {datetime.now().isoformat()}\n")

    # Single unified table with all secrets
    lines.append("| Name | Status | Services | Days Until Expiry |")
    lines.append("|------|--------|----------|------------------|")

    # Expired section
    if grouped["expired"]:
        for secret in grouped["expired"]:
            services = ", ".join(secret["required_by_services"])
            days = secret["days_until_expiry"]
            lines.append(f"| {secret['name']} | EXPIRED | {services} | {days} |")

    # Warning section
    if grouped["warning"]:
        for secret in grouped["warning"]:
            services = ", ".join(secret["required_by_services"])
            days = secret["days_until_expiry"]
            lines.append(f"| {secret['name']} | WARNING | {services} | {days} |")

    # OK section
    if grouped["ok"]:
        for secret in grouped["ok"]:
            services = ", ".join(secret["required_by_services"])
            days = secret["days_until_expiry"]
            lines.append(f"| {secret['name']} | OK | {services} | {days} |")

    if not results:
        lines.append("| (no secrets configured) | — | — | — |")

    lines.append("")

    # Summary section
    expired_count = len(grouped["expired"])
    warning_count = len(grouped["warning"])
    ok_count = len(grouped["ok"])

    lines.append("## Summary\n")
    lines.append(f"- **Expired:** {expired_count}")
    lines.append(f"- **Warning:** {warning_count}")
    lines.append(f"- **OK:** {ok_count}")
    lines.append("")

    return "\n".join(lines)


def generate_json_report(results: List[Dict[str, Any]]) -> str:
    """
    Generate a JSON report of validation results.

    Args:
        results: List of validation results from validate_secrets()

    Returns:
        JSON formatted report as string
    """
    # Count by status
    summary = {
        "expired": sum(1 for r in results if r["status"] == SecretStatus.EXPIRED),
        "warning": sum(1 for r in results if r["status"] == SecretStatus.WARNING),
        "ok": sum(1 for r in results if r["status"] == SecretStatus.OK),
    }

    # Convert SecretStatus enum values to strings
    secrets_data = []
    for result in results:
        secret_dict = dict(result)
        secret_dict["status"] = result["status"].value
        secret_dict["last_rotated"] = (
            result["last_rotated"].isoformat()
            if isinstance(result["last_rotated"], datetime)
            else result["last_rotated"]
        )
        secrets_data.append(secret_dict)

    report = {
        "timestamp": datetime.now().isoformat(),
        "summary": summary,
        "secrets": secrets_data,
    }

    return json.dumps(report, indent=2)


def load_config(config_path: str) -> List[SecretConfig]:
    """
    Load secret configuration from a JSON file.

    Args:
        config_path: Path to JSON config file

    Returns:
        List of SecretConfig objects

    Raises:
        FileNotFoundError: If config file doesn't exist
        json.JSONDecodeError: If config is not valid JSON
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(path, "r") as f:
        data = json.load(f)

    configs = []
    for item in data:
        # Parse date string if needed
        last_rotated = item["last_rotated"]
        if isinstance(last_rotated, str):
            last_rotated = datetime.fromisoformat(last_rotated)

        configs.append(
            SecretConfig(
                name=item["name"],
                last_rotated=last_rotated,
                rotation_policy_days=item["rotation_policy_days"],
                required_by_services=item["required_by_services"],
            )
        )

    return configs


def main():
    """Main entry point for CLI usage."""
    import argparse

    parser = argparse.ArgumentParser(description="Secret Rotation Validator")
    parser.add_argument(
        "--config", required=True, help="Path to JSON config file"
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format",
    )
    parser.add_argument(
        "--warning-days",
        type=int,
        default=7,
        help="Days until expiry to trigger warning",
    )

    args = parser.parse_args()

    try:
        configs = load_config(args.config)
        results = validate_secrets(configs, warning_days=args.warning_days)

        if args.format == "json":
            print(generate_json_report(results))
        else:
            print(generate_markdown_report(results))

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in config file: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
