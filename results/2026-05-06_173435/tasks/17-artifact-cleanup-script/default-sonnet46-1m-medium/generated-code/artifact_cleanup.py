"""
Artifact retention cleanup script.

Applies configurable retention policies to a list of CI/CD artifacts and
produces a DeletionPlan describing which artifacts to remove and the total
space that would be reclaimed.  Supports dry-run mode.

Retention policies (all optional, combinable):
  max_age_days      — delete artifacts older than N days
  keep_latest_n     — keep only the N most-recent artifacts per workflow run
  max_total_size_mb — delete oldest artifacts until total size is under the limit

Usage as a script (mock data demo):
  python artifact_cleanup.py [--dry-run]
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Artifact:
    name: str
    size_mb: float
    created_at: datetime
    workflow_run_id: str


@dataclass
class RetentionPolicy:
    max_age_days: Optional[int] = None
    max_total_size_mb: Optional[float] = None
    keep_latest_n: Optional[int] = None


@dataclass
class DeletionPlan:
    to_delete: list[Artifact]
    to_retain: list[Artifact]
    dry_run: bool = False

    @property
    def space_reclaimed_mb(self) -> float:
        return sum(a.size_mb for a in self.to_delete)

    def summary(self) -> dict:
        return {
            "total_artifacts": len(self.to_delete) + len(self.to_retain),
            "deleted": len(self.to_delete),
            "retained": len(self.to_retain),
            "space_reclaimed_mb": round(self.space_reclaimed_mb, 2),
            "dry_run": self.dry_run,
        }

    def report(self) -> str:
        s = self.summary()
        lines = [
            f"{'[DRY RUN] ' if self.dry_run else ''}Artifact Deletion Plan",
            f"  Total artifacts : {s['total_artifacts']}",
            f"  To delete       : {s['deleted']}",
            f"  To retain       : {s['retained']}",
            f"  Space reclaimed : {s['space_reclaimed_mb']:.2f} MB",
        ]
        if self.to_delete:
            lines.append("  Artifacts to delete:")
            for a in self.to_delete:
                lines.append(f"    - {a.name} ({a.size_mb:.1f} MB, run {a.workflow_run_id}, created {a.created_at.date()})")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def apply_retention_policies(
    artifacts: list[Artifact],
    policy: RetentionPolicy,
    now: Optional[datetime] = None,
    dry_run: bool = False,
) -> DeletionPlan:
    """
    Apply retention policies and return a DeletionPlan.

    Policies are applied in order:
      1. max_age_days  — time-based eviction
      2. keep_latest_n — per-workflow cardinality limit (applied to survivors)
      3. max_total_size_mb — size cap, deleting oldest survivors first

    An artifact is deleted if *any* policy marks it.
    """
    if now is None:
        now = datetime.now(timezone.utc)

    to_delete: set[str] = set()

    # --- Policy 1: max age ---
    if policy.max_age_days is not None:
        for a in artifacts:
            age_days = (now - a.created_at).days
            if age_days > policy.max_age_days:
                to_delete.add(a.name)

    # --- Policy 2: keep latest N per workflow run ---
    if policy.keep_latest_n is not None:
        by_workflow: dict[str, list[Artifact]] = defaultdict(list)
        for a in artifacts:
            if a.name not in to_delete:
                by_workflow[a.workflow_run_id].append(a)

        for run_artifacts in by_workflow.values():
            # Sort descending by creation date; keep the first N
            sorted_desc = sorted(run_artifacts, key=lambda x: x.created_at, reverse=True)
            for a in sorted_desc[policy.keep_latest_n:]:
                to_delete.add(a.name)

    # --- Policy 3: max total size (delete oldest survivors first) ---
    if policy.max_total_size_mb is not None:
        survivors = [a for a in artifacts if a.name not in to_delete]
        total_mb = sum(a.size_mb for a in survivors)

        if total_mb > policy.max_total_size_mb:
            # Delete oldest first until total is within the budget
            oldest_first = sorted(survivors, key=lambda x: x.created_at)
            for a in oldest_first:
                if total_mb <= policy.max_total_size_mb:
                    break
                to_delete.add(a.name)
                total_mb -= a.size_mb

    deleted = [a for a in artifacts if a.name in to_delete]
    retained = [a for a in artifacts if a.name not in to_delete]

    return DeletionPlan(to_delete=deleted, to_retain=retained, dry_run=dry_run)


# ---------------------------------------------------------------------------
# CLI entry point (demo with mock data)
# ---------------------------------------------------------------------------

MOCK_ARTIFACTS = [
    Artifact("artifact-old-a",  50.0,  datetime(2026, 1,  8, tzinfo=timezone.utc), "run-001"),
    Artifact("artifact-old-b",  75.0,  datetime(2026,  2,  7, tzinfo=timezone.utc), "run-001"),
    Artifact("artifact-mid",   100.0,  datetime(2026,  4,  1, tzinfo=timezone.utc), "run-002"),
    Artifact("artifact-new",    25.0,  datetime(2026,  5,  1, tzinfo=timezone.utc), "run-002"),
]

DEMO_POLICY = RetentionPolicy(
    max_age_days=30,
    max_total_size_mb=200,
    keep_latest_n=2,
)


def main(argv: list[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]

    dry_run = "--dry-run" in argv

    plan = apply_retention_policies(
        MOCK_ARTIFACTS,
        DEMO_POLICY,
        now=datetime(2026, 5, 8, tzinfo=timezone.utc),
        dry_run=dry_run,
    )

    print(plan.report())
    print()
    print(json.dumps(plan.summary(), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
