#!/usr/bin/env python3
"""
CLI interface for secret rotation validator.

Usage:
  python3 secret_validator_cli.py <config_file> [--output-format json|markdown] [--warning-days 7]
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from secret_validator import Secret, SecretValidator


def load_config(config_path: str) -> list:
    """Load secrets configuration from JSON file."""
    try:
        with open(config_path, 'r') as f:
            data = json.load(f)
            if not isinstance(data, list):
                data = data.get('secrets', [])
            return data
    except FileNotFoundError:
        print(f"Error: Configuration file not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in config file: {config_path}", file=sys.stderr)
        sys.exit(1)


def validate_secret_config(config: dict) -> Secret:
    """Convert config dict to Secret object with validation."""
    required = {'name', 'last_rotated', 'rotation_policy_days', 'required_by'}
    missing = required - set(config.keys())

    if missing:
        raise ValueError(f"Missing required fields: {missing}")

    try:
        last_rotated = datetime.fromisoformat(config['last_rotated'])
    except (ValueError, TypeError) as e:
        raise ValueError(f"Invalid date format for 'last_rotated': {config['last_rotated']}") from e

    try:
        rotation_days = int(config['rotation_policy_days'])
    except (ValueError, TypeError) as e:
        raise ValueError(f"Invalid rotation_policy_days: {config['rotation_policy_days']}") from e

    required_by = config['required_by']
    if not isinstance(required_by, list):
        raise ValueError(f"'required_by' must be a list, got {type(required_by).__name__}")

    return Secret(
        name=config['name'],
        last_rotated=last_rotated,
        rotation_policy_days=rotation_days,
        required_by=required_by
    )


def main():
    parser = argparse.ArgumentParser(
        description="Secret rotation validator - identify expired/expiring secrets"
    )
    parser.add_argument(
        'config_file',
        help='Path to JSON configuration file with secrets'
    )
    parser.add_argument(
        '--output-format',
        choices=['json', 'markdown'],
        default='markdown',
        help='Output format (default: markdown)'
    )
    parser.add_argument(
        '--warning-days',
        type=int,
        default=7,
        help='Warning window in days (default: 7)'
    )

    args = parser.parse_args()

    # Load and validate configuration
    configs = load_config(args.config_file)

    if not configs:
        print("Error: No secrets found in configuration", file=sys.stderr)
        sys.exit(1)

    validator = SecretValidator(warning_window_days=args.warning_days)

    for i, config in enumerate(configs):
        try:
            secret = validate_secret_config(config)
            validator.add_secret(secret)
        except ValueError as e:
            print(f"Error in secret #{i}: {e}", file=sys.stderr)
            sys.exit(1)

    # Generate and output report
    report = validator.generate_report()

    if args.output_format == 'json':
        print(report.to_json())
    else:
        print(report.to_markdown())

    # Exit with appropriate code
    if report.expired_count > 0:
        sys.exit(1)  # Signal failure if any secrets are expired
    sys.exit(0)


if __name__ == '__main__':
    main()
