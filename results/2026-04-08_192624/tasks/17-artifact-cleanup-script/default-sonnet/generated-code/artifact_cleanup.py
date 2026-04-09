"""
Artifact Cleanup Script
=======================
Applies retention policies to a list of build artifacts and produces a
deletion plan.  Three policy types are supported:

  max_age_days               – delete artifacts older than N days
  max_total_size_bytes       – delete oldest artifacts until total ≤ limit
  keep_latest_n_per_workflow – for each workflow, keep only the N most recent
                               workflow runs' artifacts

The script can be run in dry-run mode; in that mode it produces the same plan
output but takes no destructive action (and is clearly labeled as a dry run).

Exit codes:
  0 – success
  1 – fatal error (bad fixture file, invalid JSON, etc.)

TDD notes
---------
  CYCLE 1 GREEN: implemented parse_date + apply_age_policy
  CYCLE 2 GREEN: implemented apply_size_policy
  CYCLE 3 GREEN: implemented apply_keep_latest_n_policy
  CYCLE 4 GREEN: implemented apply_retention_policies (chains the three above)
  CYCLE 5 GREEN: implemented generate_deletion_plan + format_plan
  REFACTOR: extracted parse_date as a module-level helper; unified date
            handling; added ARTIFACT_CLEANUP_SUMMARY marker line.
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Set


# ─────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────

def parse_date(date_str: str) -> datetime:
    """Parse an ISO-8601 date string into a timezone-aware datetime.

    Accepts the trailing 'Z' shorthand for UTC as well as explicit offsets.
    """
    # Normalise the 'Z' suffix that GitHub and many CI tools emit.
    normalised = date_str.replace("Z", "+00:00")
    return datetime.fromisoformat(normalised)


# ─────────────────────────────────────────────────────────────
# Policy functions
# Each function returns a *set of artifact names* that violate the policy.
# ─────────────────────────────────────────────────────────────

def apply_age_policy(
    artifacts: List[Dict],
    max_age_days: int,
    reference_date: datetime,
) -> Set[str]:
    """Return the set of artifact names older than *max_age_days*.

    The cutoff is calculated as reference_date − max_age_days.  Artifacts
    created strictly before the cutoff are marked for deletion; those created
    on or after are retained.
    """
    cutoff = reference_date - timedelta(days=max_age_days)
    return {
        a["name"]
        for a in artifacts
        if parse_date(a["created_at"]) < cutoff
    }


def apply_size_policy(
    artifacts: List[Dict],
    max_total_size_bytes: int,
) -> Set[str]:
    """Return the minimum set of artifact names to delete to stay under the
    total-size limit.

    Artifacts are removed oldest-first (by creation date) until the remaining
    total is at or below *max_total_size_bytes*.
    """
    total = sum(a["size"] for a in artifacts)
    if total <= max_total_size_bytes:
        return set()

    # Sort oldest first so we evict the least-valuable artifacts first.
    sorted_arts = sorted(artifacts, key=lambda a: parse_date(a["created_at"]))
    to_delete: Set[str] = set()
    for art in sorted_arts:
        if total <= max_total_size_bytes:
            break
        to_delete.add(art["name"])
        total -= art["size"]
    return to_delete


def apply_keep_latest_n_policy(
    artifacts: List[Dict],
    keep_latest_n: int,
) -> Set[str]:
    """Return artifact names that belong to workflow runs outside the top-N.

    Grouping is done by (workflow_name, workflow_run_id).  Within each
    workflow, runs are ranked by the *latest* artifact creation date in that
    run.  The N most-recent runs are kept; all others are deleted.
    """
    # Build: { workflow_name → { run_id → [artifacts] } }
    by_workflow: Dict[str, Dict[str, List[Dict]]] = {}
    for art in artifacts:
        wf = art.get("workflow_name", "default")
        run_id = art["workflow_run_id"]
        by_workflow.setdefault(wf, {}).setdefault(run_id, []).append(art)

    to_delete: Set[str] = set()
    for wf_name, runs in by_workflow.items():
        def run_date(run_id: str) -> datetime:
            # A run's "date" is the latest creation date among its artifacts.
            return max(parse_date(a["created_at"]) for a in runs[run_id])

        sorted_run_ids = sorted(runs.keys(), key=run_date, reverse=True)
        # Anything beyond the first keep_latest_n runs is evicted.
        for run_id in sorted_run_ids[keep_latest_n:]:
            for art in runs[run_id]:
                to_delete.add(art["name"])

    return to_delete


# ─────────────────────────────────────────────────────────────
# Orchestration
# ─────────────────────────────────────────────────────────────

def apply_retention_policies(
    artifacts: List[Dict],
    policies: Dict,
    reference_date: Optional[datetime] = None,
) -> Dict:
    """Apply all configured retention policies and return a result dict.

    Policies are applied in this order so that later policies operate on the
    *already-culled* set, avoiding double-counting:
      1. max_age_days
      2. max_total_size_bytes
      3. keep_latest_n_per_workflow

    Returns:
        {
            "to_delete": [artifact, ...],
            "to_retain": [artifact, ...],
            "reasons":   { artifact_name: [reason_str, ...] },
        }
    """
    if reference_date is None:
        reference_date = datetime.now(timezone.utc)

    delete_names: Set[str] = set()
    reasons: Dict[str, List[str]] = {}

    # ── Phase 1: age ──────────────────────────────────────────
    if "max_age_days" in policies:
        age_limit = policies["max_age_days"]
        for name in apply_age_policy(artifacts, age_limit, reference_date):
            delete_names.add(name)
            reasons.setdefault(name, []).append(
                f"older than {age_limit} days"
            )

    # ── Phase 2: total size ───────────────────────────────────
    if "max_total_size_bytes" in policies:
        remaining = [a for a in artifacts if a["name"] not in delete_names]
        size_limit = policies["max_total_size_bytes"]
        for name in apply_size_policy(remaining, size_limit):
            delete_names.add(name)
            reasons.setdefault(name, []).append(
                f"total size exceeds {size_limit} bytes"
            )

    # ── Phase 3: keep-latest-N ────────────────────────────────
    if "keep_latest_n_per_workflow" in policies:
        remaining = [a for a in artifacts if a["name"] not in delete_names]
        n = policies["keep_latest_n_per_workflow"]
        for name in apply_keep_latest_n_policy(remaining, n):
            delete_names.add(name)
            reasons.setdefault(name, []).append(
                f"exceeds keep-latest-{n} runs per workflow"
            )

    return {
        "to_delete": [a for a in artifacts if a["name"] in delete_names],
        "to_retain": [a for a in artifacts if a["name"] not in delete_names],
        "reasons": reasons,
    }


# ─────────────────────────────────────────────────────────────
# Plan generation & formatting
# ─────────────────────────────────────────────────────────────

def generate_deletion_plan(result: Dict, dry_run: bool = False) -> Dict:
    """Build a structured deletion plan from a retention-policy result."""
    to_delete = result["to_delete"]
    to_retain  = result["to_retain"]
    reasons    = result["reasons"]

    space_bytes = sum(a["size"] for a in to_delete)
    space_mb    = round(space_bytes / (1024 * 1024), 2)

    return {
        "dry_run": dry_run,
        "to_delete": [
            {
                "name":            a["name"],
                "size":            a["size"],
                "created_at":      a["created_at"],
                "workflow_run_id": a["workflow_run_id"],
                "reasons":         reasons.get(a["name"], []),
            }
            for a in to_delete
        ],
        "to_retain": [
            {
                "name":            a["name"],
                "size":            a["size"],
                "created_at":      a["created_at"],
                "workflow_run_id": a["workflow_run_id"],
            }
            for a in to_retain
        ],
        "summary": {
            "total_artifacts":     len(to_delete) + len(to_retain),
            "artifacts_to_delete": len(to_delete),
            "artifacts_to_retain": len(to_retain),
            "space_reclaimed_bytes": space_bytes,
            "space_reclaimed_mb":    space_mb,
        },
    }


def format_plan(plan: Dict) -> str:
    """Return a human-readable string representation of a deletion plan.

    The last section always contains a machine-readable ARTIFACT_CLEANUP_SUMMARY
    line that the test harness uses to assert exact expected values without
    having to parse prose output.

    Line format:
        ARTIFACT_CLEANUP_SUMMARY: total=N deleted=N retained=N \
            space_bytes=N space_mb=F dry_run=true|false
    """
    s = plan["summary"]
    dr = plan["dry_run"]
    lines: List[str] = []

    if dr:
        lines.append("=== DRY RUN — no artifacts will be deleted ===")
    else:
        lines.append("=== ARTIFACT CLEANUP PLAN ===")

    lines.append(f"Total artifacts  : {s['total_artifacts']}")
    lines.append(f"To delete        : {s['artifacts_to_delete']}")
    lines.append(f"To retain        : {s['artifacts_to_retain']}")
    lines.append(
        f"Space to reclaim : {s['space_reclaimed_mb']} MB"
        f" ({s['space_reclaimed_bytes']} bytes)"
    )
    lines.append("")

    if plan["to_delete"]:
        lines.append("ARTIFACTS TO DELETE:")
        for a in plan["to_delete"]:
            reasons_str = "; ".join(a["reasons"]) or "no reason specified"
            lines.append(
                f"  - {a['name']}"
                f" ({a['size']} bytes, created {a['created_at']})"
                f" [reason: {reasons_str}]"
            )

    if plan["to_retain"]:
        lines.append("")
        lines.append("ARTIFACTS TO RETAIN:")
        for a in plan["to_retain"]:
            lines.append(f"  - {a['name']} ({a['size']} bytes)")

    # Machine-readable summary — always the last line.
    lines.append("")
    lines.append(
        f"ARTIFACT_CLEANUP_SUMMARY:"
        f" total={s['total_artifacts']}"
        f" deleted={s['artifacts_to_delete']}"
        f" retained={s['artifacts_to_retain']}"
        f" space_bytes={s['space_reclaimed_bytes']}"
        f" space_mb={s['space_reclaimed_mb']}"
        f" dry_run={'true' if dr else 'false'}"
    )

    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────
# CLI entry point
# ─────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Apply retention policies to a list of build artifacts."
    )
    parser.add_argument(
        "--fixture",
        required=True,
        help="Path to a JSON file containing artifact list and policies.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show the deletion plan without taking any action.",
    )
    parser.add_argument(
        "--output-json",
        action="store_true",
        help="Print the deletion plan as JSON (default: human-readable).",
    )
    parser.add_argument(
        "--reference-date",
        help="Override today's date for age calculations (ISO-8601).",
    )
    args = parser.parse_args()

    # ── Load fixture ──────────────────────────────────────────
    try:
        with open(args.fixture) as fh:
            data = json.load(fh)
    except FileNotFoundError:
        print(f"ERROR: fixture file not found: {args.fixture}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in fixture file: {exc}", file=sys.stderr)
        return 1

    artifacts = data.get("artifacts", [])
    policies  = data.get("policies",  {})

    if not isinstance(artifacts, list):
        print("ERROR: 'artifacts' must be a JSON array.", file=sys.stderr)
        return 1
    if not isinstance(policies, dict):
        print("ERROR: 'policies' must be a JSON object.", file=sys.stderr)
        return 1

    # ── Resolve reference date ────────────────────────────────
    reference_date: Optional[datetime] = None
    if args.reference_date:
        reference_date = parse_date(args.reference_date)
    elif "reference_date" in data:
        reference_date = parse_date(data["reference_date"])

    # ── Apply policies & generate plan ────────────────────────
    result = apply_retention_policies(artifacts, policies, reference_date)
    plan   = generate_deletion_plan(result, dry_run=args.dry_run)

    if args.output_json:
        print(json.dumps(plan, indent=2))
    else:
        print(format_plan(plan))

    return 0


if __name__ == "__main__":
    sys.exit(main())
