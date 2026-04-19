#!/usr/bin/env python3
"""
Artifact cleanup CLI tool.
Reads JSON artifact data, applies retention policies, generates deletion plans.
"""
import json
import sys
import argparse
from datetime import datetime
from artifact_cleanup import Artifact, RetentionPolicy, ArtifactCleaner


def load_artifacts_from_json(json_file: str) -> list:
    """Load artifacts from JSON file."""
    with open(json_file, 'r') as f:
        data = json.load(f)

    artifacts = []
    for item in data.get('artifacts', []):
        artifact = Artifact(
            name=item['name'],
            size_bytes=item['size_bytes'],
            created_at=datetime.fromisoformat(item['created_at']),
            workflow_run_id=item['workflow_run_id'],
        )
        artifacts.append(artifact)
    return artifacts


def run_cleanup(
    artifacts_file: str,
    max_age_days: int,
    max_total_size_bytes: int,
    keep_latest_n: int,
    dry_run: bool = True,
) -> dict:
    """Execute the cleanup and return the plan."""
    artifacts = load_artifacts_from_json(artifacts_file)
    policy = RetentionPolicy(
        max_age_days=max_age_days,
        max_total_size_bytes=max_total_size_bytes,
        keep_latest_n_per_workflow=keep_latest_n,
    )
    cleaner = ArtifactCleaner(policy)
    plan = cleaner.plan_deletions(artifacts, dry_run=dry_run)

    return {
        'dry_run': plan.dry_run,
        'summary': plan.summary(),
        'to_delete': [
            {
                'name': a.name,
                'size_bytes': a.size_bytes,
                'created_at': a.created_at.isoformat(),
                'workflow_run_id': a.workflow_run_id,
            }
            for a in plan.to_delete
        ],
        'to_keep': [
            {
                'name': a.name,
                'size_bytes': a.size_bytes,
                'created_at': a.created_at.isoformat(),
                'workflow_run_id': a.workflow_run_id,
            }
            for a in plan.to_keep
        ],
    }


def main():
    parser = argparse.ArgumentParser(
        description='Artifact cleanup tool with retention policies'
    )
    parser.add_argument(
        '--artifacts',
        required=True,
        help='JSON file with artifact metadata',
    )
    parser.add_argument(
        '--max-age-days',
        type=int,
        default=30,
        help='Maximum artifact age in days',
    )
    parser.add_argument(
        '--max-total-size',
        type=int,
        default=1_000_000_000,
        help='Maximum total size in bytes',
    )
    parser.add_argument(
        '--keep-latest-n',
        type=int,
        default=5,
        help='Keep latest N artifacts per workflow',
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        default=True,
        help='Run without actually deleting (default: true)',
    )
    parser.add_argument(
        '--execute',
        action='store_true',
        help='Actually delete artifacts (overrides --dry-run)',
    )
    parser.add_argument(
        '--output',
        help='Output JSON file with deletion plan',
    )

    args = parser.parse_args()

    dry_run = not args.execute
    result = run_cleanup(
        artifacts_file=args.artifacts,
        max_age_days=args.max_age_days,
        max_total_size_bytes=args.max_total_size,
        keep_latest_n=args.keep_latest_n,
        dry_run=dry_run,
    )

    # Output the plan
    output = json.dumps(result, indent=2)
    print(output)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(output)

    # Exit with status based on deletions
    if result['summary']['artifacts_to_delete'] > 0:
        print(
            f"\n📊 Summary:",
            file=sys.stderr,
        )
        print(
            f"  Artifacts to delete: {result['summary']['artifacts_to_delete']}",
            file=sys.stderr,
        )
        print(
            f"  Artifacts to keep: {result['summary']['artifacts_to_keep']}",
            file=sys.stderr,
        )
        print(
            f"  Space to reclaim: {result['summary']['space_reclaimed_bytes']} bytes",
            file=sys.stderr,
        )
        print(
            f"  Mode: {'DRY-RUN' if dry_run else 'EXECUTE'}",
            file=sys.stderr,
        )
    else:
        print("✓ No artifacts need to be deleted", file=sys.stderr)

    return 0


if __name__ == '__main__':
    sys.exit(main())
