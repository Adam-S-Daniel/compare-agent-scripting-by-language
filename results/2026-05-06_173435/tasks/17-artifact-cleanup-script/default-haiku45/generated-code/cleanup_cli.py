#!/usr/bin/env python3
"""
CLI entry point for artifact cleanup script.

Usage:
    python3 cleanup_cli.py --artifacts ARTIFACTS_JSON --max-age DAYS --max-size SIZE_MB --keep-latest N [--dry-run]

Example:
    python3 cleanup_cli.py \\
        --artifacts artifacts.json \\
        --max-age 30 \\
        --max-size 1024 \\
        --keep-latest 5 \\
        --dry-run
"""
import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from artifact_cleanup import Artifact, RetentionPolicy, ArtifactCleanup


def load_artifacts_from_json(json_path: str) -> list:
    """
    Load artifact metadata from JSON file.

    Expected JSON format:
    [
        {
            "name": "artifact-name.zip",
            "size_bytes": 1024,
            "created_at": "2026-05-01T12:00:00",
            "workflow_run_id": "run-123"
        },
        ...
    ]
    """
    try:
        with open(json_path) as f:
            data = json.load(f)

        artifacts = []
        for item in data:
            artifact = Artifact(
                name=item['name'],
                size_bytes=int(item['size_bytes']),
                created_at=datetime.fromisoformat(item['created_at']),
                workflow_run_id=item['workflow_run_id']
            )
            artifacts.append(artifact)
        return artifacts
    except FileNotFoundError:
        print(f"Error: Artifacts file not found: {json_path}", file=sys.stderr)
        sys.exit(1)
    except (json.JSONDecodeError, KeyError, ValueError) as e:
        print(f"Error: Invalid artifacts JSON: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    """Parse arguments and run artifact cleanup."""
    parser = argparse.ArgumentParser(
        description='Apply retention policies to artifacts and generate deletion plan.'
    )
    parser.add_argument(
        '--artifacts',
        required=True,
        help='Path to JSON file with artifact metadata'
    )
    parser.add_argument(
        '--max-age',
        type=int,
        default=30,
        help='Maximum artifact age in days (default: 30)'
    )
    parser.add_argument(
        '--max-size',
        type=int,
        default=1024,
        help='Maximum total size in MB (default: 1024)'
    )
    parser.add_argument(
        '--keep-latest',
        type=int,
        default=5,
        help='Keep latest N artifacts per workflow run (default: 5)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Generate plan without actually deleting'
    )
    parser.add_argument(
        '--output',
        default=None,
        help='Save plan to JSON file (default: stdout)'
    )

    args = parser.parse_args()

    # Load artifacts
    artifacts = load_artifacts_from_json(args.artifacts)

    # Create policy
    try:
        policy = RetentionPolicy(
            max_age_days=args.max_age,
            max_total_size_bytes=args.max_size * 1024 * 1024,
            keep_latest_n=args.keep_latest
        )
    except ValueError as e:
        print(f"Error: Invalid policy parameters: {e}", file=sys.stderr)
        sys.exit(1)

    # Generate plan
    cleanup = ArtifactCleanup(artifacts, policy, dry_run=args.dry_run)
    plan = cleanup.generate_plan()

    # Output plan
    output_json = cleanup.to_json(plan)

    if args.output:
        try:
            with open(args.output, 'w') as f:
                f.write(output_json)
            print(f"Plan saved to: {args.output}")
        except IOError as e:
            print(f"Error: Failed to write output file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(output_json)

    # Print summary to stderr for visibility
    print("\n=== Deletion Plan Summary ===", file=sys.stderr)
    print(f"Total artifacts: {plan.summary['total_artifacts']}", file=sys.stderr)
    print(f"To delete: {plan.summary['artifacts_to_delete']}", file=sys.stderr)
    print(f"To retain: {plan.summary['artifacts_to_retain']}", file=sys.stderr)
    print(f"Space reclaimed: {plan.summary['space_reclaimed_mb']:.2f} MB", file=sys.stderr)
    if args.dry_run:
        print("(DRY RUN - No artifacts were actually deleted)", file=sys.stderr)

    return 0


if __name__ == '__main__':
    sys.exit(main())
