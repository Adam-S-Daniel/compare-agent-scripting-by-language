"""
Artifact cleanup: apply retention policies to a list of artifacts, produce a
deletion plan with a summary (space reclaimed, counts).  Supports dry-run mode.

TDD note: test_artifact_cleanup.py was written first; this file was created to
make those tests pass, then refactored for clarity.
"""
import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Artifact:
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str


@dataclass
class RetentionPolicy:
    # Delete any artifact older than this many days.
    max_age_days: Optional[int] = None
    # Delete oldest artifacts until total size is at or below this limit.
    max_total_size_bytes: Optional[int] = None
    # Per workflow_run_id: keep only the N most-recently-created artifacts.
    keep_latest_n: Optional[int] = None


@dataclass
class DeletionPlan:
    to_delete: List[Artifact]
    to_retain: List[Artifact]
    space_reclaimed_bytes: int
    dry_run: bool

    @property
    def deleted_count(self) -> int:
        return len(self.to_delete)

    @property
    def retained_count(self) -> int:
        return len(self.to_retain)


# ---------------------------------------------------------------------------
# Individual policy evaluators
# ---------------------------------------------------------------------------

def _age_deletes(artifacts: List[Artifact], max_age_days: int, now: datetime) -> List[Artifact]:
    cutoff_ts = now.timestamp() - max_age_days * 86400
    return [a for a in artifacts if a.created_at.timestamp() < cutoff_ts]


def _size_deletes(artifacts: List[Artifact], max_bytes: int) -> List[Artifact]:
    """Return the oldest artifacts that must be removed to reach the size limit."""
    by_age = sorted(artifacts, key=lambda a: a.created_at)
    total = sum(a.size_bytes for a in by_age)
    to_delete: List[Artifact] = []
    for a in by_age:
        if total <= max_bytes:
            break
        to_delete.append(a)
        total -= a.size_bytes
    return to_delete


def _keep_latest_n_deletes(artifacts: List[Artifact], keep_n: int) -> List[Artifact]:
    """For each workflow_run_id, keep only the keep_n newest; return the rest."""
    by_workflow: Dict[str, List[Artifact]] = {}
    for a in artifacts:
        by_workflow.setdefault(a.workflow_run_id, []).append(a)

    to_delete: List[Artifact] = []
    for wf_artifacts in by_workflow.values():
        sorted_wf = sorted(wf_artifacts, key=lambda a: a.created_at, reverse=True)
        to_delete.extend(sorted_wf[keep_n:])
    return to_delete


# ---------------------------------------------------------------------------
# Core public API
# ---------------------------------------------------------------------------

def apply_retention_policies(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
    now: Optional[datetime] = None,
) -> Tuple[List[Artifact], List[Artifact]]:
    """
    Apply all configured retention policies.  An artifact is deleted if ANY
    policy marks it for deletion.  Policies are evaluated in order: age first,
    then size (on the survivors), then keep-latest-N (on the survivors).

    Returns (to_retain, to_delete).
    """
    if now is None:
        now = datetime.now(timezone.utc)

    doomed: set = set()  # tracks artifact id()s already condemned

    if policy.max_age_days is not None:
        for a in _age_deletes(artifacts, policy.max_age_days, now):
            doomed.add(id(a))

    survivors = [a for a in artifacts if id(a) not in doomed]

    if policy.max_total_size_bytes is not None:
        for a in _size_deletes(survivors, policy.max_total_size_bytes):
            doomed.add(id(a))

    survivors = [a for a in artifacts if id(a) not in doomed]

    if policy.keep_latest_n is not None:
        for a in _keep_latest_n_deletes(survivors, policy.keep_latest_n):
            doomed.add(id(a))

    to_delete = [a for a in artifacts if id(a) in doomed]
    to_retain = [a for a in artifacts if id(a) not in doomed]
    return to_retain, to_delete


def generate_deletion_plan(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
    dry_run: bool = True,
    now: Optional[datetime] = None,
) -> DeletionPlan:
    """Apply policies and return a DeletionPlan describing what would be removed."""
    to_retain, to_delete = apply_retention_policies(artifacts, policy, now)
    return DeletionPlan(
        to_delete=to_delete,
        to_retain=to_retain,
        space_reclaimed_bytes=sum(a.size_bytes for a in to_delete),
        dry_run=dry_run,
    )


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def format_bytes(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"


def print_plan(plan: DeletionPlan) -> None:
    mode = "DRY RUN" if plan.dry_run else "EXECUTING"
    print(f"ARTIFACT CLEANUP PLAN ({mode})")
    print("=" * 44)
    print(f"Artifacts analyzed: {plan.deleted_count + plan.retained_count}")
    print(f"Artifacts to delete: {plan.deleted_count}")
    print(f"Artifacts to retain: {plan.retained_count}")
    print(f"Space reclaimed: {format_bytes(plan.space_reclaimed_bytes)}")
    print()
    if plan.to_delete:
        print("Deletion list:")
        for a in sorted(plan.to_delete, key=lambda x: x.created_at):
            print(
                f"  - {a.name} ({format_bytes(a.size_bytes)}, "
                f"created {a.created_at.strftime('%Y-%m-%d')}, "
                f"workflow: {a.workflow_run_id})"
            )
    else:
        print("Nothing to delete.")
    print()
    if plan.to_retain:
        print("Retained:")
        for a in sorted(plan.to_retain, key=lambda x: x.created_at, reverse=True):
            print(
                f"  - {a.name} ({format_bytes(a.size_bytes)}, "
                f"created {a.created_at.strftime('%Y-%m-%d')}, "
                f"workflow: {a.workflow_run_id})"
            )


# ---------------------------------------------------------------------------
# Fixture loading (used by CLI and workflow steps)
# ---------------------------------------------------------------------------

def load_fixture(path: str):
    """
    Load a JSON fixture file.  Returns (artifacts, policy, dry_run, expected, now).
    'now' is read from the fixture so date-relative tests are deterministic.
    """
    with open(path) as fh:
        data = json.load(fh)

    artifacts = [
        Artifact(
            name=item["name"],
            size_bytes=item["size_bytes"],
            created_at=datetime.fromisoformat(item["created_at"]),
            workflow_run_id=item["workflow_run_id"],
        )
        for item in data["artifacts"]
    ]

    pd = data.get("policy", {})
    policy = RetentionPolicy(
        max_age_days=pd.get("max_age_days"),
        max_total_size_bytes=pd.get("max_total_size_bytes"),
        keep_latest_n=pd.get("keep_latest_n"),
    )

    dry_run = data.get("dry_run", True)
    expected = data.get("expected", {})

    now_str = data.get("now")
    now = datetime.fromisoformat(now_str) if now_str else None

    return artifacts, policy, dry_run, expected, now


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="Artifact cleanup with retention policies")
    parser.add_argument("--fixture", required=True, help="Path to fixture JSON file")
    args = parser.parse_args()

    try:
        artifacts, policy, dry_run, expected, now = load_fixture(args.fixture)
    except (FileNotFoundError, KeyError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: Failed to load fixture '{args.fixture}': {exc}", file=sys.stderr)
        return 1

    plan = generate_deletion_plan(artifacts, policy, dry_run=dry_run, now=now)
    print_plan(plan)

    if not expected:
        return 0

    errors: List[str] = []
    checks = {
        "deleted_count":        plan.deleted_count,
        "retained_count":       plan.retained_count,
        "space_reclaimed_bytes": plan.space_reclaimed_bytes,
    }
    for key, actual in checks.items():
        if key in expected and actual != expected[key]:
            errors.append(f"{key}: expected {expected[key]}, got {actual}")

    if "dry_run" in expected and plan.dry_run != expected["dry_run"]:
        errors.append(f"dry_run: expected {expected['dry_run']}, got {plan.dry_run}")

    if errors:
        print("\nVALIDATION ERRORS:")
        for err in errors:
            print(f"  FAIL: {err}")
        return 1

    print("\nVALIDATION: ALL ASSERTIONS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
