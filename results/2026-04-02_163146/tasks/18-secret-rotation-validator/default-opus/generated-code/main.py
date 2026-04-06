#!/usr/bin/env python3
"""
Secret Rotation Validator — CLI Entry Point
============================================
Usage:
    python3 main.py [OPTIONS]

Options:
    --input FILE        Path to JSON file with secret configs (default: test_fixtures.json)
    --format FORMAT     Output format: 'json' or 'markdown' (default: markdown)
    --warning-days N    Warning window in days (default: 14)
    --date YYYY-MM-DD   Reference date for evaluation (default: today)

Example:
    python3 main.py --input test_fixtures.json --format json --warning-days 7
    python3 main.py --format markdown --date 2026-04-01
"""

import argparse
import sys
from datetime import date
from pathlib import Path

from secret_rotation_validator import (
    load_secrets_from_json,
    generate_report,
    format_json,
    format_markdown,
)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate secret rotation policies and generate reports."
    )
    parser.add_argument(
        "--input",
        default="test_fixtures.json",
        help="Path to JSON file with secret configurations (default: test_fixtures.json)",
    )
    parser.add_argument(
        "--format",
        choices=["json", "markdown"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--warning-days",
        type=int,
        default=14,
        help="Warning window in days before expiry (default: 14)",
    )
    parser.add_argument(
        "--date",
        default=None,
        help="Reference date in YYYY-MM-DD format (default: today)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Main entry point. Returns 0 on success, 1 on error."""
    args = parse_args(argv)

    # Resolve reference date
    ref_date: date | None = None
    if args.date:
        try:
            ref_date = date.fromisoformat(args.date)
        except ValueError:
            print(f"Error: Invalid date format '{args.date}'. Use YYYY-MM-DD.", file=sys.stderr)
            return 1

    # Load secrets from file
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        return 1

    try:
        json_str = input_path.read_text()
        configs = load_secrets_from_json(json_str)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # Generate report
    report = generate_report(configs, warning_window_days=args.warning_days, reference_date=ref_date)

    # Format and print
    if args.format == "json":
        print(format_json(report))
    else:
        print(format_markdown(report))

    return 0


if __name__ == "__main__":
    sys.exit(main())
