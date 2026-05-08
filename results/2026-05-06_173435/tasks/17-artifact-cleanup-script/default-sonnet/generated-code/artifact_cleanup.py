"""
Artifact cleanup script.

Applies retention policies to a list of CI/CD artifacts and produces a
deletion plan.  Policies applied (each is optional):
  - max_age_days:               delete artifacts older than N days
  - keep_latest_n_per_workflow: keep only the N most-recent artifacts per
                                workflow_run_id group (oldest deleted first)
  - max_total_size_bytes:       if total size exceeds the limit, delete oldest
                                artifacts first until we're under the limit

All policies are unioned: an artifact is deleted if ANY policy marks it.
"""
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
from typing import List, Optional


@dataclass
class Artifact:
    name: str
    size: int              # bytes
    created_at: datetime   # timezone-aware
    workflow_run_id: str


@dataclass
class RetentionPolicy:
    max_age_days: Optional[int] = None
    max_total_size_bytes: Optional[int] = None
    keep_latest_n_per_workflow: Optional[int] = None


@dataclass
class DeletionPlan:
    artifacts_to_delete: List[Artifact]
    artifacts_to_keep: List[Artifact]
    space_reclaimed_bytes: int
    dry_run: bool = False


def apply_retention_policies(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
    now: Optional[datetime] = None,
    dry_run: bool = False,
) -> DeletionPlan:
    """Return a DeletionPlan by applying all configured retention policies."""
    if now is None:
        now = datetime.now(timezone.utc)

    to_delete: set = set()  # artifact names marked for deletion

    # Policy 1: max age
    if policy.max_age_days is not None:
        cutoff = now - timedelta(days=policy.max_age_days)
        for a in artifacts:
            if a.created_at < cutoff:
                to_delete.add(a.name)

    # Policy 2: keep-latest-N per workflow — operates on survivors so far
    if policy.keep_latest_n_per_workflow is not None:
        # Group by workflow_run_id, sort newest-first, mark excess for deletion
        by_workflow: dict = {}
        for a in artifacts:
            by_workflow.setdefault(a.workflow_run_id, []).append(a)

        for wf_id, group in by_workflow.items():
            # Sort newest first
            sorted_group = sorted(group, key=lambda a: a.created_at, reverse=True)
            # Keep only the first N; mark the rest
            for a in sorted_group[policy.keep_latest_n_per_workflow:]:
                to_delete.add(a.name)

    # Policy 3: max total size — delete oldest survivors until under limit
    if policy.max_total_size_bytes is not None:
        # Work with artifacts NOT already marked for deletion
        survivors = [a for a in artifacts if a.name not in to_delete]
        total = sum(a.size for a in survivors)
        if total > policy.max_total_size_bytes:
            # Delete oldest first
            sorted_survivors = sorted(survivors, key=lambda a: a.created_at)
            for a in sorted_survivors:
                if total <= policy.max_total_size_bytes:
                    break
                to_delete.add(a.name)
                total -= a.size

    deleted = [a for a in artifacts if a.name in to_delete]
    kept = [a for a in artifacts if a.name not in to_delete]
    reclaimed = sum(a.size for a in deleted)

    return DeletionPlan(
        artifacts_to_delete=deleted,
        artifacts_to_keep=kept,
        space_reclaimed_bytes=reclaimed,
        dry_run=dry_run,
    )


def format_summary(plan: DeletionPlan) -> str:
    """Return a human-readable summary of the deletion plan."""
    mode = "[DRY RUN] " if plan.dry_run else ""
    lines = [
        f"{mode}Deletion Plan Summary",
        f"  Artifacts to delete : {len(plan.artifacts_to_delete)}",
        f"  Artifacts to keep   : {len(plan.artifacts_to_keep)}",
        f"  Space reclaimed     : {plan.space_reclaimed_bytes} bytes"
        f" ({plan.space_reclaimed_bytes / (1024*1024):.1f} MB)",
    ]
    if plan.artifacts_to_delete:
        lines.append("  Artifacts marked for deletion:")
        for a in sorted(plan.artifacts_to_delete, key=lambda x: x.created_at):
            lines.append(
                f"    - {a.name}  ({a.size // (1024*1024)} MB,"
                f" run={a.workflow_run_id},"
                f" created={a.created_at.strftime('%Y-%m-%d')})"
            )
    return "\n".join(lines)


def load_artifacts_from_json(path: str) -> List[Artifact]:
    """Load artifact list from a JSON file."""
    with open(path) as f:
        data = json.load(f)
    artifacts = []
    for item in data:
        created_at = datetime.fromisoformat(item["created_at"])
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        artifacts.append(Artifact(
            name=item["name"],
            size=item["size"],
            created_at=created_at,
            workflow_run_id=item["workflow_run_id"],
        ))
    return artifacts


def load_policy_from_json(path: str) -> RetentionPolicy:
    """Load retention policy from a JSON file."""
    with open(path) as f:
        data = json.load(f)
    return RetentionPolicy(
        max_age_days=data.get("max_age_days"),
        max_total_size_bytes=data.get("max_total_size_bytes"),
        keep_latest_n_per_workflow=data.get("keep_latest_n_per_workflow"),
    )


def main(argv: Optional[List[str]] = None) -> int:
    import argparse
    parser = argparse.ArgumentParser(description="Artifact cleanup tool")
    parser.add_argument("--input", required=True, help="Path to artifacts JSON file")
    parser.add_argument("--policy", required=True, help="Path to retention policy JSON")
    parser.add_argument("--dry-run", action="store_true", help="Show plan without deleting")
    parser.add_argument("--output", help="Write JSON deletion plan to this file")
    args = parser.parse_args(argv)

    try:
        artifacts = load_artifacts_from_json(args.input)
        policy = load_policy_from_json(args.policy)
    except (FileNotFoundError, KeyError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    plan = apply_retention_policies(artifacts, policy, dry_run=args.dry_run)
    summary = format_summary(plan)
    print(summary)

    # Machine-readable markers for test harness assertions
    print(f"ARTIFACTS_TO_DELETE={len(plan.artifacts_to_delete)}")
    print(f"ARTIFACTS_TO_KEEP={len(plan.artifacts_to_keep)}")
    print(f"SPACE_RECLAIMED_BYTES={plan.space_reclaimed_bytes}")
    print(f"DRY_RUN={plan.dry_run}")

    if args.output:
        result = {
            "artifacts_to_delete": len(plan.artifacts_to_delete),
            "artifacts_to_keep": len(plan.artifacts_to_keep),
            "space_reclaimed_bytes": plan.space_reclaimed_bytes,
            "dry_run": plan.dry_run,
            "deleted": [
                {
                    "name": a.name,
                    "size": a.size,
                    "workflow_run_id": a.workflow_run_id,
                    "created_at": a.created_at.isoformat(),
                }
                for a in plan.artifacts_to_delete
            ],
        }
        with open(args.output, "w") as f:
            json.dump(result, f, indent=2)

    return 0


if __name__ == "__main__":
    sys.exit(main())
