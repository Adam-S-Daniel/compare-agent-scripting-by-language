#!/usr/bin/env python3
"""Artifact cleanup script - applies retention policies to CI/CD artifacts.

Accepts a JSON input file with artifact metadata and retention policies,
then generates a deletion plan showing which artifacts to remove and retain.
"""

import json
import sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict


def parse_date(date_str):
    """Parse ISO 8601 date string to datetime."""
    return datetime.fromisoformat(date_str.replace("Z", "+00:00"))


def validate_input(data):
    """Validate input data structure. Returns error message or None."""
    if not isinstance(data, dict):
        return "Input must be a JSON object"
    if "artifacts" not in data:
        return "Missing required field: artifacts"
    if not isinstance(data["artifacts"], list):
        return "Field 'artifacts' must be a list"
    if "policies" not in data:
        return "Missing required field: policies"
    if not isinstance(data["policies"], dict):
        return "Field 'policies' must be an object"

    required_artifact_fields = ["name", "size", "created_at", "workflow_run_id"]
    for i, artifact in enumerate(data["artifacts"]):
        if not isinstance(artifact, dict):
            return f"Artifact at index {i} must be an object"
        for field in required_artifact_fields:
            if field not in artifact:
                return f"Artifact at index {i} missing required field: {field}"
        if not isinstance(artifact["size"], (int, float)) or artifact["size"] < 0:
            return f"Artifact at index {i} has invalid size: {artifact['size']}"
        try:
            parse_date(artifact["created_at"])
        except (ValueError, TypeError):
            return f"Artifact at index {i} has invalid date: {artifact['created_at']}"

    policies = data["policies"]
    if "max_age_days" in policies and policies["max_age_days"] is not None:
        if not isinstance(policies["max_age_days"], (int, float)) or policies["max_age_days"] <= 0:
            return "Policy max_age_days must be a positive number"
    if "keep_latest_n" in policies and policies["keep_latest_n"] is not None:
        if not isinstance(policies["keep_latest_n"], int) or policies["keep_latest_n"] <= 0:
            return "Policy keep_latest_n must be a positive integer"
    if "max_total_size_bytes" in policies and policies["max_total_size_bytes"] is not None:
        if not isinstance(policies["max_total_size_bytes"], (int, float)) or policies["max_total_size_bytes"] <= 0:
            return "Policy max_total_size_bytes must be a positive number"

    return None


def apply_policies(artifacts, policies, reference_date_str=None, dry_run=True):
    """Apply retention policies and return a deletion plan.

    Policy application order:
    1. max_age_days - remove artifacts older than N days
    2. keep_latest_n - per artifact name, keep only the N most recent
    3. max_total_size_bytes - if retained set exceeds budget, drop oldest first
    """
    if reference_date_str:
        ref_date = parse_date(reference_date_str)
    else:
        ref_date = datetime.now(timezone.utc)

    retained = list(artifacts)
    deleted = []

    # Policy 1: max_age_days
    max_age = policies.get("max_age_days")
    if max_age is not None:
        cutoff = ref_date - timedelta(days=max_age)
        new_retained = []
        for a in retained:
            if parse_date(a["created_at"]) < cutoff:
                deleted.append({**a, "reason": "exceeded_max_age"})
            else:
                new_retained.append(a)
        retained = new_retained

    # Policy 2: keep_latest_n per artifact name
    keep_n = policies.get("keep_latest_n")
    if keep_n is not None:
        groups = defaultdict(list)
        for a in retained:
            groups[a["name"]].append(a)

        new_retained = []
        for name, group in groups.items():
            group.sort(key=lambda x: parse_date(x["created_at"]), reverse=True)
            new_retained.extend(group[:keep_n])
            for a in group[keep_n:]:
                deleted.append({**a, "reason": "exceeded_keep_latest_n"})
        retained = new_retained

    # Policy 3: max_total_size_bytes (keep newest first, drop oldest)
    max_size = policies.get("max_total_size_bytes")
    if max_size is not None:
        retained.sort(key=lambda x: parse_date(x["created_at"]), reverse=True)
        new_retained = []
        total = 0
        for a in retained:
            if total + a["size"] <= max_size:
                new_retained.append(a)
                total += a["size"]
            else:
                deleted.append({**a, "reason": "exceeded_max_total_size"})
        retained = new_retained

    space_reclaimed = sum(a["size"] for a in deleted)
    space_retained = sum(a["size"] for a in retained)

    plan = {
        "dry_run": dry_run,
        "to_delete": sorted(deleted, key=lambda x: (x["name"], x["created_at"])),
        "to_retain": sorted(retained, key=lambda x: (x["name"], x["created_at"])),
        "summary": {
            "total_artifacts": len(artifacts),
            "artifacts_to_delete": len(deleted),
            "artifacts_to_retain": len(retained),
            "space_reclaimed_bytes": space_reclaimed,
            "space_retained_bytes": space_retained,
        },
    }
    return plan


def main():
    if len(sys.argv) < 2:
        print("Error: No input file specified", file=sys.stderr)
        print("Usage: artifact_cleanup.py <input.json>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    try:
        with open(input_path) as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in input file: {e}", file=sys.stderr)
        sys.exit(1)

    error = validate_input(data)
    if error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)

    artifacts = data["artifacts"]
    policies = data["policies"]
    reference_date = data.get("reference_date")
    dry_run = data.get("dry_run", True)

    plan = apply_policies(artifacts, policies, reference_date, dry_run)
    print(json.dumps(plan, indent=2))


if __name__ == "__main__":
    main()
