"""
Artifact Cleanup Script
=======================
Applies retention policies to a list of artifacts and generates a deletion plan.

Retention policies supported:
  - max_age_days:          Delete artifacts older than N days
  - max_total_size_bytes:  Delete oldest artifacts until total size is within limit
  - keep_latest_n:         Keep only the N most recent artifacts per workflow run ID

Dry-run mode generates the same plan without marking it as executable.
"""

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import List, Optional, Tuple


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class Artifact:
    """Represents a single CI/CD artifact with metadata."""
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str

    @property
    def size_mb(self) -> float:
        """Return artifact size in megabytes."""
        return self.size_bytes / (1024 * 1024)

    @property
    def age_days(self) -> float:
        """Return artifact age in days (relative to now)."""
        delta = datetime.now() - self.created_at
        return delta.total_seconds() / 86400


@dataclass
class RetentionPolicy:
    """
    Defines the rules for artifact retention.

    All policies are optional. When a policy is None it is not applied.
    An artifact is deleted if ANY active policy marks it for deletion.
    """
    max_age_days: Optional[int] = None
    max_total_size_bytes: Optional[int] = None
    keep_latest_n: Optional[int] = None


@dataclass
class DeletionPlan:
    """
    The outcome of applying retention policies to a list of artifacts.

    Attributes:
        to_delete:  Artifacts that should be removed.
        to_keep:    Artifacts that should be retained.
        is_dry_run: True when the plan was generated in simulation mode.
    """
    to_delete: List[Artifact]
    to_keep: List[Artifact]
    is_dry_run: bool = False

    @property
    def artifacts_deleted(self) -> int:
        return len(self.to_delete)

    @property
    def artifacts_retained(self) -> int:
        return len(self.to_keep)

    @property
    def space_reclaimed_bytes(self) -> int:
        return sum(a.size_bytes for a in self.to_delete)

    @property
    def space_reclaimed_mb(self) -> float:
        return self.space_reclaimed_bytes / (1024 * 1024)

    def summary(self) -> str:
        """Human-readable summary of the deletion plan."""
        prefix = "[DRY RUN] " if self.is_dry_run else ""
        lines = [
            f"{prefix}Artifact Deletion Plan",
            f"  Artifacts to delete : {self.artifacts_deleted}",
            f"  Artifacts to keep   : {self.artifacts_retained}",
            f"  Space reclaimed     : {self.space_reclaimed_mb:.2f} MB",
        ]
        if self.to_delete:
            lines.append("  Artifacts marked for deletion:")
            for a in self.to_delete:
                lines.append(f"    - {a.name} ({a.size_mb:.1f} MB, {a.age_days:.0f} days old)")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Policy application logic
# ---------------------------------------------------------------------------

def _apply_max_age(artifacts: List[Artifact], max_age_days: int) -> set:
    """Return the set of artifact names that exceed the maximum age."""
    cutoff = datetime.now() - timedelta(days=max_age_days)
    # Strictly older than cutoff (created_at < cutoff)
    return {a.name for a in artifacts if a.created_at < cutoff}


def _apply_keep_latest_n(artifacts: List[Artifact], n: int) -> set:
    """
    Return names of artifacts to delete so that at most N artifacts
    per workflow_run_id are kept (the N most recent by created_at).
    """
    from collections import defaultdict
    by_workflow: dict = defaultdict(list)
    for a in artifacts:
        by_workflow[a.workflow_run_id].append(a)

    to_delete_names = set()
    for workflow_id, group in by_workflow.items():
        # Sort newest-first; everything beyond position N is deleted
        sorted_group = sorted(group, key=lambda a: a.created_at, reverse=True)
        for a in sorted_group[n:]:
            to_delete_names.add(a.name)

    return to_delete_names


def _apply_max_total_size(artifacts: List[Artifact], max_bytes: int) -> set:
    """
    Return names of the oldest artifacts that must be removed so the
    remaining collection fits within max_bytes.
    """
    total = sum(a.size_bytes for a in artifacts)
    if total <= max_bytes:
        return set()

    # Delete oldest first until we are within the limit
    sorted_oldest_first = sorted(artifacts, key=lambda a: a.created_at)
    to_delete_names = set()
    for a in sorted_oldest_first:
        if total <= max_bytes:
            break
        to_delete_names.add(a.name)
        total -= a.size_bytes

    return to_delete_names


def apply_retention_policies(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
) -> Tuple[List[Artifact], List[Artifact]]:
    """
    Apply all active retention policies and partition artifacts into
    (to_delete, to_keep).

    An artifact is deleted if ANY policy marks it for deletion.
    Policies are applied independently and their results are unioned.
    """
    if not artifacts:
        return [], []

    # Collect names to delete from each active policy
    delete_names: set = set()

    if policy.max_age_days is not None:
        delete_names |= _apply_max_age(artifacts, policy.max_age_days)

    if policy.keep_latest_n is not None:
        delete_names |= _apply_keep_latest_n(artifacts, policy.keep_latest_n)

    if policy.max_total_size_bytes is not None:
        # Size policy sees ALL artifacts (before other policy deletions)
        delete_names |= _apply_max_total_size(artifacts, policy.max_total_size_bytes)

    to_delete = [a for a in artifacts if a.name in delete_names]
    to_keep = [a for a in artifacts if a.name not in delete_names]
    return to_delete, to_keep


# ---------------------------------------------------------------------------
# Deletion plan generation
# ---------------------------------------------------------------------------

def generate_deletion_plan(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
    dry_run: bool = False,
) -> DeletionPlan:
    """
    Generate a DeletionPlan by applying retention policies to the artifact list.

    Args:
        artifacts:  All known artifacts.
        policy:     Retention policy to apply.
        dry_run:    When True, the plan is flagged as a simulation only.

    Returns:
        A DeletionPlan describing which artifacts to remove and a summary.
    """
    to_delete, to_keep = apply_retention_policies(artifacts, policy)
    return DeletionPlan(
        to_delete=to_delete,
        to_keep=to_keep,
        is_dry_run=dry_run,
    )


# ---------------------------------------------------------------------------
# CLI entry point (for manual usage / demonstration)
# ---------------------------------------------------------------------------

def _demo() -> None:
    """Run a quick demonstration with mock artifact data."""
    now = datetime.now()

    mock_artifacts = [
        Artifact("nightly-build-old.zip",    50 * 1024 * 1024, now - timedelta(days=90),  "run-001"),
        Artifact("nightly-build-recent.zip", 50 * 1024 * 1024, now - timedelta(days=5),   "run-002"),
        Artifact("pr-123-v1.zip",            10 * 1024 * 1024, now - timedelta(days=40),  "pr-123"),
        Artifact("pr-123-v2.zip",            10 * 1024 * 1024, now - timedelta(days=20),  "pr-123"),
        Artifact("pr-123-v3.zip",            10 * 1024 * 1024, now - timedelta(days=2),   "pr-123"),
        Artifact("release-1.0.zip",          80 * 1024 * 1024, now - timedelta(days=120), "release-1"),
        Artifact("release-2.0.zip",          80 * 1024 * 1024, now - timedelta(days=10),  "release-2"),
    ]

    policy = RetentionPolicy(
        max_age_days=30,
        max_total_size_bytes=150 * 1024 * 1024,
        keep_latest_n=2,
    )

    print("=== Dry Run ===")
    plan = generate_deletion_plan(mock_artifacts, policy, dry_run=True)
    print(plan.summary())

    print("\n=== Real Run ===")
    plan = generate_deletion_plan(mock_artifacts, policy, dry_run=False)
    print(plan.summary())


if __name__ == "__main__":
    _demo()
