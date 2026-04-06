"""
Secret Rotation Validator - CLI Entry Point
===========================================
Usage:
    python main.py                          # default: markdown, 14-day warning
    python main.py --format json            # JSON output
    python main.py --warning-days 30        # 30-day warning window
    python main.py --format json --warning-days 7

The mock secret configuration is defined in SAMPLE_SECRETS below.
"""

import argparse
import sys
from datetime import date, timedelta

from secret_rotation import Secret, generate_report, format_json, format_markdown


# ============================================================
# Mock Secret Configuration (sample data)
# ============================================================

def _d(days_ago: int) -> date:
    """Return a date that was `days_ago` days before today."""
    return date.today() - timedelta(days=days_ago)


SAMPLE_SECRETS = [
    # Already expired
    Secret(
        name="prod-db-password",
        last_rotated=_d(120),
        rotation_policy_days=90,
        required_by=["auth-service", "reporting-service"],
    ),
    Secret(
        name="legacy-api-key",
        last_rotated=_d(400),
        rotation_policy_days=365,
        required_by=["legacy-billing"],
    ),
    # Expiring soon (within typical 14-day warning)
    Secret(
        name="stripe-webhook-secret",
        last_rotated=_d(82),
        rotation_policy_days=90,
        required_by=["payment-service"],
    ),
    Secret(
        name="sendgrid-api-key",
        last_rotated=_d(78),
        rotation_policy_days=90,
        required_by=["email-service", "notification-service"],
    ),
    # OK (plenty of time left)
    Secret(
        name="jwt-signing-key",
        last_rotated=_d(10),
        rotation_policy_days=180,
        required_by=["auth-service", "api-gateway"],
    ),
    Secret(
        name="s3-access-key",
        last_rotated=_d(5),
        rotation_policy_days=365,
        required_by=["backup-service", "media-service"],
    ),
    Secret(
        name="internal-service-token",
        last_rotated=_d(45),
        rotation_policy_days=365,
        required_by=["internal-api"],
    ),
]


# ============================================================
# CLI
# ============================================================

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Validate secret rotation policies and generate reports."
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--warning-days",
        type=int,
        default=14,
        help="Days before expiry to issue a warning (default: 14)",
    )
    args = parser.parse_args(argv)

    if args.warning_days < 0:
        print("Error: --warning-days must be a non-negative integer.", file=sys.stderr)
        sys.exit(1)

    report = generate_report(SAMPLE_SECRETS, warning_days=args.warning_days)

    if args.format == "json":
        print(format_json(report))
    else:
        print(format_markdown(report))


if __name__ == "__main__":
    main()
