#!/usr/bin/env python3
"""
Artifact Cleanup Script

Applies retention policies to a list of artifacts and generates a deletion plan.
Supports three policy types applied in order:
  1. max_age_days: Delete artifacts older than N days from the reference date
  2. keep_latest_n_per_workflow: Keep only the N most recent artifacts per workflow run ID
  3. max_total_size_mb: Delete the oldest remaining artifacts until total retained size fits

Input: JSON file with:
  - artifacts: list of {name, size_mb, created_at (ISO 8601), workflow_run_id}
  - policies: {max_age_days, max_total_size_mb, keep_latest_n_per_workflow}
  - dry_run: boolean (default true)
  - reference_date: ISO 8601 string (default: now)

Output: Human-readable deletion plan with per-artifact detail and summary stats.
"""

import json
import sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict


def parse_input(data):
    """Parse and validate the input JSON structure."""
    artifacts = data.get("artifacts", [])
    policies = data.get("policies", {})
    dry_run = data.get("dry_run", True)
    reference_date_str = data.get("reference_date")

    # Parse reference date or default to now
    if reference_date_str:
        reference_date = datetime.fromisoformat(reference_date_str.replace("Z", "+00:00"))
    else:
        reference_date = datetime.now(timezone.utc)

    # Validate artifact fields
    for i, a in enumerate(artifacts):
        for field in ("name", "size_mb", "created_at", "workflow_run_id"):
            if field not in a:
                raise ValueError(f"Artifact at index {i} missing required field '{field}'")

    return artifacts, policies, dry_run, reference_date


def parse_created_at(iso_string):
    """Parse an ISO 8601 date string into a timezone-aware datetime."""
    return datetime.fromisoformat(iso_string.replace("Z", "+00:00"))


def apply_max_age_policy(artifacts, max_age_days, reference_date):
    """
    Policy 1: Mark artifacts older than max_age_days for deletion.
    Returns a set of indices to delete.
    """
    if max_age_days is None:
        return set()

    cutoff = reference_date - timedelta(days=max_age_days)
    to_delete = set()
    for i, artifact in enumerate(artifacts):
        created = parse_created_at(artifact["created_at"])
        if created < cutoff:
            to_delete.add(i)
    return to_delete


def apply_keep_latest_n_policy(artifacts, keep_n):
    """
    Policy 2: For each workflow_run_id, keep only the N most recent artifacts.
    Returns a set of indices to delete.
    """
    if keep_n is None:
        return set()

    # Group artifact indices by workflow_run_id
    groups = defaultdict(list)
    for i, artifact in enumerate(artifacts):
        groups[artifact["workflow_run_id"]].append(i)

    to_delete = set()
    for wf_id, indices in groups.items():
        # Sort by creation date descending (newest first)
        sorted_indices = sorted(
            indices,
            key=lambda idx: artifacts[idx]["created_at"],
            reverse=True
        )
        # Everything beyond the first N gets deleted
        for idx in sorted_indices[keep_n:]:
            to_delete.add(idx)

    return to_delete


def apply_max_total_size_policy(artifacts, max_total_size_mb, already_deleted):
    """
    Policy 3: Delete the oldest retained artifacts until total retained size <= limit.
    Only considers artifacts not already marked for deletion by prior policies.
    Returns a set of additional indices to delete.
    """
    if max_total_size_mb is None:
        return set()

    # Build list of currently-retained artifacts with their indices
    retained = [(i, a) for i, a in enumerate(artifacts) if i not in already_deleted]
    total_size = sum(a["size_mb"] for _, a in retained)

    if total_size <= max_total_size_mb:
        return set()

    # Sort retained by creation date ascending (oldest first) — delete oldest first
    retained_sorted = sorted(retained, key=lambda x: x[1]["created_at"])

    to_delete = set()
    for i, artifact in retained_sorted:
        if total_size <= max_total_size_mb:
            break
        to_delete.add(i)
        total_size -= artifact["size_mb"]

    return to_delete


def generate_plan(artifacts, to_delete_indices, reasons, dry_run):
    """
    Build a human-readable deletion plan showing which artifacts are deleted
    (with reasons) and which are retained, plus summary statistics.
    """
    mode = "DRY RUN" if dry_run else "LIVE"
    lines = [f"=== Artifact Cleanup Plan ({mode}) ==="]

    # Separate into delete and retain lists
    delete_lines = []
    retain_lines = []

    for i, artifact in enumerate(artifacts):
        entry = (
            f"  - {artifact['name']} ({artifact['size_mb']} MB, "
            f"created {artifact['created_at'][:10]}, "
            f"run: {artifact['workflow_run_id']})"
        )
        if i in to_delete_indices:
            reason = reasons.get(i, "policy")
            delete_lines.append(f"{entry} [reason: {reason}]")
        else:
            retain_lines.append(entry)

    lines.append(f"Artifacts to DELETE ({len(delete_lines)}):")
    if delete_lines:
        lines.extend(delete_lines)
    else:
        lines.append("  (none)")

    lines.append(f"Artifacts to RETAIN ({len(retain_lines)}):")
    if retain_lines:
        lines.extend(retain_lines)
    else:
        lines.append("  (none)")

    # Compute summary statistics
    total = len(artifacts)
    deleted = len(delete_lines)
    retained = len(retain_lines)
    space_reclaimed = sum(artifacts[i]["size_mb"] for i in to_delete_indices)
    space_retained = sum(
        a["size_mb"] for i, a in enumerate(artifacts) if i not in to_delete_indices
    )

    lines.append("=== Summary ===")
    lines.append(f"Total artifacts: {total}")
    lines.append(f"Artifacts to delete: {deleted}")
    lines.append(f"Artifacts to retain: {retained}")
    lines.append(f"Space reclaimed: {space_reclaimed} MB")
    lines.append(f"Space retained: {space_retained} MB")

    return "\n".join(lines)


def run_cleanup(data):
    """
    Main entry point: parse input, apply all policies in order, and produce a plan.

    Policy application order:
      1. max_age_days — absolute age cutoff
      2. keep_latest_n_per_workflow — per-workflow cap
      3. max_total_size_mb — global size budget (applied to whatever remains)
    """
    artifacts, policies, dry_run, reference_date = parse_input(data)

    # Handle empty artifact list
    if not artifacts:
        return (
            "=== Artifact Cleanup Plan ===\n"
            "No artifacts to process.\n"
            "=== Summary ===\n"
            "Total artifacts: 0\n"
            "Artifacts to delete: 0\n"
            "Artifacts to retain: 0\n"
            "Space reclaimed: 0 MB\n"
            "Space retained: 0 MB"
        )

    reasons = {}

    # Policy 1: max age
    age_deletes = apply_max_age_policy(
        artifacts, policies.get("max_age_days"), reference_date
    )
    for i in age_deletes:
        reasons[i] = "exceeded max age"

    # Policy 2: keep latest N per workflow
    keep_n_deletes = apply_keep_latest_n_policy(
        artifacts, policies.get("keep_latest_n_per_workflow")
    )
    for i in keep_n_deletes:
        if i in reasons:
            reasons[i] += " + exceeded keep-latest-N"
        else:
            reasons[i] = "exceeded keep-latest-N"

    # Merge deletions from policies 1 and 2
    all_deletes = age_deletes | keep_n_deletes

    # Policy 3: max total size (only looks at artifacts not yet marked)
    size_deletes = apply_max_total_size_policy(
        artifacts, policies.get("max_total_size_mb"), all_deletes
    )
    for i in size_deletes:
        if i in reasons:
            reasons[i] += " + exceeded max total size"
        else:
            reasons[i] = "exceeded max total size"

    all_deletes = all_deletes | size_deletes

    return generate_plan(artifacts, all_deletes, reasons, dry_run)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Error: Usage: python artifact_cleanup.py <input.json>", file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    try:
        with open(input_file) as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in '{input_file}': {e}", file=sys.stderr)
        sys.exit(1)

    try:
        result = run_cleanup(data)
        print(result)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
