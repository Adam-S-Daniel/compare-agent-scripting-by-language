#!/usr/bin/env python3
"""
Artifact cleanup script.

Applies retention policies to a list of artifacts and generates a deletion plan.
Policies supported:
  - max_age_days: delete artifacts older than N days
  - max_total_size_mb: keep total size under N MB (oldest deleted first)
  - keep_latest_n_per_workflow: keep only the N most recent artifacts per workflow run ID

Supports dry-run mode (default) which only reports what would be deleted.
"""

import json
import sys
from datetime import datetime, timedelta, timezone


def parse_artifacts(raw):
    """Parse a list of artifact dicts, validating required fields."""
    required = {"name", "size_mb", "created_at", "workflow_run_id"}
    artifacts = []
    for i, item in enumerate(raw):
        missing = required - set(item.keys())
        if missing:
            raise ValueError(f"Artifact at index {i} missing fields: {', '.join(sorted(missing))}")
        try:
            size = float(item["size_mb"])
            if size < 0:
                raise ValueError(f"Artifact '{item['name']}' has negative size: {size}")
        except (TypeError, ValueError) as e:
            if "negative" in str(e):
                raise
            raise ValueError(f"Artifact '{item['name']}' has invalid size: {item['size_mb']}")
        try:
            created = datetime.fromisoformat(item["created_at"])
        except (TypeError, ValueError):
            raise ValueError(f"Artifact '{item['name']}' has invalid date: {item['created_at']}")
        artifacts.append({
            "name": str(item["name"]),
            "size_mb": size,
            "created_at": created,
            "workflow_run_id": str(item["workflow_run_id"]),
        })
    return artifacts


def apply_max_age_policy(artifacts, max_age_days, now=None):
    """Mark artifacts older than max_age_days for deletion."""
    if now is None:
        now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=max_age_days)
    to_delete = set()
    for a in artifacts:
        # Make comparison timezone-aware
        created = a["created_at"]
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        if created < cutoff:
            to_delete.add(a["name"])
    return to_delete


def apply_keep_latest_n_policy(artifacts, keep_n):
    """Keep only the N most recent artifacts per workflow run ID."""
    from collections import defaultdict
    by_workflow = defaultdict(list)
    for a in artifacts:
        by_workflow[a["workflow_run_id"]].append(a)

    to_delete = set()
    for wf_id, wf_artifacts in by_workflow.items():
        # Sort by created_at descending, keep first N
        sorted_arts = sorted(wf_artifacts, key=lambda x: x["created_at"], reverse=True)
        for a in sorted_arts[keep_n:]:
            to_delete.add(a["name"])
    return to_delete


def apply_max_total_size_policy(artifacts, max_total_size_mb):
    """Delete oldest artifacts first until total size is under the limit."""
    # Sort by created_at ascending (oldest first for deletion)
    sorted_arts = sorted(artifacts, key=lambda x: x["created_at"])
    total = sum(a["size_mb"] for a in sorted_arts)
    to_delete = set()
    for a in sorted_arts:
        if total <= max_total_size_mb:
            break
        to_delete.add(a["name"])
        total -= a["size_mb"]
    return to_delete


def generate_deletion_plan(artifacts, policy, dry_run=True, now=None):
    """
    Apply all configured retention policies and generate a deletion plan.

    policy dict may contain:
      - max_age_days (int)
      - max_total_size_mb (float)
      - keep_latest_n_per_workflow (int)

    Returns a dict with:
      - dry_run (bool)
      - artifacts_deleted (list of artifact names)
      - artifacts_retained (list of artifact names)
      - total_space_reclaimed_mb (float)
      - total_space_retained_mb (float)
      - summary (str)
    """
    if not artifacts:
        return {
            "dry_run": dry_run,
            "artifacts_deleted": [],
            "artifacts_retained": [],
            "total_space_reclaimed_mb": 0.0,
            "total_space_retained_mb": 0.0,
            "summary": "No artifacts to process.",
        }

    to_delete = set()

    # Apply each policy; union of all deletions
    if "max_age_days" in policy:
        to_delete |= apply_max_age_policy(artifacts, policy["max_age_days"], now=now)

    if "keep_latest_n_per_workflow" in policy:
        to_delete |= apply_keep_latest_n_policy(artifacts, policy["keep_latest_n_per_workflow"])

    if "max_total_size_mb" in policy:
        # Apply size policy only to artifacts not already marked for deletion
        remaining = [a for a in artifacts if a["name"] not in to_delete]
        size_deletes = apply_max_total_size_policy(remaining, policy["max_total_size_mb"])
        to_delete |= size_deletes

    deleted = [a for a in artifacts if a["name"] in to_delete]
    retained = [a for a in artifacts if a["name"] not in to_delete]

    reclaimed = sum(a["size_mb"] for a in deleted)
    retained_size = sum(a["size_mb"] for a in retained)

    mode = "DRY RUN" if dry_run else "LIVE"
    summary = (
        f"[{mode}] Deletion plan: "
        f"{len(deleted)} artifact(s) to delete, "
        f"{len(retained)} artifact(s) to retain. "
        f"Space reclaimed: {reclaimed:.1f} MB. "
        f"Space retained: {retained_size:.1f} MB."
    )

    return {
        "dry_run": dry_run,
        "artifacts_deleted": sorted([a["name"] for a in deleted]),
        "artifacts_retained": sorted([a["name"] for a in retained]),
        "total_space_reclaimed_mb": round(reclaimed, 2),
        "total_space_retained_mb": round(retained_size, 2),
        "summary": summary,
    }


def main():
    """CLI entry point. Reads JSON config from file or stdin."""
    import argparse
    parser = argparse.ArgumentParser(description="Artifact cleanup script")
    parser.add_argument("--config", "-c", help="Path to JSON config file (or - for stdin)")
    parser.add_argument("--live", action="store_true", help="Run in live mode (not dry-run)")
    args = parser.parse_args()

    config_source = args.config or "-"
    if config_source == "-":
        data = json.load(sys.stdin)
    else:
        with open(config_source) as f:
            data = json.load(f)

    artifacts_raw = data.get("artifacts", [])
    policy = data.get("policy", {})
    dry_run = not args.live

    try:
        artifacts = parse_artifacts(artifacts_raw)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    now_str = data.get("now")
    now = datetime.fromisoformat(now_str) if now_str else None

    plan = generate_deletion_plan(artifacts, policy, dry_run=dry_run, now=now)

    print(plan["summary"])
    print(f"\nDeleted ({len(plan['artifacts_deleted'])}):")
    for name in plan["artifacts_deleted"]:
        print(f"  - {name}")
    print(f"\nRetained ({len(plan['artifacts_retained'])}):")
    for name in plan["artifacts_retained"]:
        print(f"  - {name}")
    print(f"\nSpace reclaimed: {plan['total_space_reclaimed_mb']} MB")
    print(f"Space retained: {plan['total_space_retained_mb']} MB")

    # Output as JSON for machine consumption
    print("\n--- JSON OUTPUT ---")
    print(json.dumps(plan, indent=2))

    return plan


if __name__ == "__main__":
    main()
