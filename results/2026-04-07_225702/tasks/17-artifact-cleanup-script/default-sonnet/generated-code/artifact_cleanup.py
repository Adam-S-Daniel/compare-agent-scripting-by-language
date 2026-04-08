# Artifact Cleanup Script
# Applies configurable retention policies to a list of CI/CD artifacts and
# produces a deletion plan (optionally as a dry-run).
#
# Retention policies (all optional, any combination):
#   - max_age_days          : delete artifacts older than N days
#   - max_total_size_bytes  : if total exceeds this, delete oldest first
#   - keep_latest_n         : per workflow_run_id, keep only the N newest

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Optional


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class Artifact:
    """Represents a single CI/CD artifact with its metadata (immutable/hashable)."""
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str

    @property
    def size_mb(self) -> float:
        """Convenience: size expressed in megabytes."""
        return self.size_bytes / (1024 * 1024)


@dataclass
class RetentionPolicy:
    """
    Describes the rules used to decide which artifacts to keep.

    All fields are optional; omitting a field means that constraint is not
    enforced.
    """
    max_age_days: Optional[int] = None
    max_total_size_bytes: Optional[int] = None
    keep_latest_n: Optional[int] = None


@dataclass
class DeletionPlan:
    """
    The result produced by applying retention policies.

    Attributes
    ----------
    to_delete : list of Artifact
        Artifacts that should be removed.
    to_retain : list of Artifact
        Artifacts that should be kept.
    dry_run : bool
        When True the plan was produced in dry-run mode (no side-effects were
        or should be performed).
    """
    to_delete: List[Artifact] = field(default_factory=list)
    to_retain: List[Artifact] = field(default_factory=list)
    dry_run: bool = False

    def summary(self) -> dict:
        """
        Return a human-readable summary dict with:
        - artifacts_deleted   : count of artifacts to be deleted
        - artifacts_retained  : count of artifacts to be kept
        - space_reclaimed_bytes : total bytes freed by deletion
        """
        return {
            "artifacts_deleted": len(self.to_delete),
            "artifacts_retained": len(self.to_retain),
            "space_reclaimed_bytes": sum(a.size_bytes for a in self.to_delete),
        }


# ---------------------------------------------------------------------------
# Policy application
# ---------------------------------------------------------------------------

def _now_utc() -> datetime:
    """Return the current UTC time (extracted so tests can monkeypatch if needed)."""
    return datetime.now(timezone.utc)


def apply_retention_policies(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
) -> DeletionPlan:
    """
    Apply all retention constraints and return a DeletionPlan.

    An artifact is marked for deletion if it violates at least one enabled
    policy.  The three policies are evaluated independently and their deletion
    sets are unioned.

    max_total_size_bytes is evaluated *after* the age and keep-n rules so that
    artifacts already slated for deletion are not double-counted against the
    remaining size budget.
    """
    to_delete: set[Artifact] = set()

    # --- Policy 1: max_age_days -------------------------------------------
    if policy.max_age_days is not None:
        now = _now_utc()
        for art in artifacts:
            # Use integer days (floor) so "exactly N days old" is retained
            age_days = (now - art.created_at).days
            if age_days > policy.max_age_days:
                to_delete.add(art)

    # --- Policy 2: keep_latest_n per workflow --------------------------------
    if policy.keep_latest_n is not None:
        # Group artifacts by workflow_run_id
        by_workflow: dict[str, list[Artifact]] = {}
        for art in artifacts:
            by_workflow.setdefault(art.workflow_run_id, []).append(art)

        for workflow_artifacts in by_workflow.values():
            # Sort newest-first (latest created_at first)
            sorted_artifacts = sorted(
                workflow_artifacts, key=lambda a: a.created_at, reverse=True
            )
            # Everything beyond the N-th position is excess
            for art in sorted_artifacts[policy.keep_latest_n:]:
                to_delete.add(art)

    # --- Policy 3: max_total_size_bytes --------------------------------------
    # After the previous two policies, compute remaining size and trim further
    # if still over budget (oldest-first).
    if policy.max_total_size_bytes is not None:
        # Only consider artifacts not already marked for deletion
        remaining = [a for a in artifacts if a not in to_delete]
        total_size = sum(a.size_bytes for a in remaining)

        if total_size > policy.max_total_size_bytes:
            # Sort oldest-first so we delete the least-recent ones first
            remaining_sorted = sorted(remaining, key=lambda a: a.created_at)
            for art in remaining_sorted:
                if total_size <= policy.max_total_size_bytes:
                    break
                to_delete.add(art)
                total_size -= art.size_bytes

    to_retain = [a for a in artifacts if a not in to_delete]
    return DeletionPlan(to_delete=list(to_delete), to_retain=to_retain)


# ---------------------------------------------------------------------------
# Public entrypoint
# ---------------------------------------------------------------------------

def generate_deletion_plan(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
    dry_run: bool = False,
) -> DeletionPlan:
    """
    High-level entry point.

    Applies retention policies and returns a DeletionPlan.  The input list is
    never modified.

    Parameters
    ----------
    artifacts : list of Artifact
        The full set of artifacts to evaluate.
    policy : RetentionPolicy
        Rules to apply.
    dry_run : bool, default False
        When True, the plan records what *would* be deleted but performs no
        actual deletion.  The caller is responsible for acting on the plan when
        dry_run is False.

    Returns
    -------
    DeletionPlan
        The computed deletion plan, annotated with the dry_run flag.
    """
    # Work on a copy so we never mutate the caller's list
    artifacts_copy = list(artifacts)
    plan = apply_retention_policies(artifacts_copy, policy)
    plan.dry_run = dry_run
    return plan


# ---------------------------------------------------------------------------
# CLI convenience (not required by the task but useful for manual testing)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import json
    from datetime import timedelta

    # --- Sample mock data ---
    now = _now_utc()
    sample_artifacts = [
        Artifact("build-linux-v1.2.zip",   50 * 1024 * 1024,  now - timedelta(days=60), "run-101"),
        Artifact("build-linux-v1.3.zip",   55 * 1024 * 1024,  now - timedelta(days=30), "run-102"),
        Artifact("build-linux-v1.4.zip",   60 * 1024 * 1024,  now - timedelta(days=5),  "run-103"),
        Artifact("build-win-v1.2.zip",     80 * 1024 * 1024,  now - timedelta(days=55), "run-104"),
        Artifact("build-win-v1.3.zip",     85 * 1024 * 1024,  now - timedelta(days=20), "run-105"),
        Artifact("test-results-old.tar",   10 * 1024 * 1024,  now - timedelta(days=45), "run-101"),
        Artifact("test-results-new.tar",   12 * 1024 * 1024,  now - timedelta(days=3),  "run-103"),
        Artifact("coverage-report.html",   5  * 1024 * 1024,  now - timedelta(days=90), "run-106"),
    ]

    sample_policy = RetentionPolicy(
        max_age_days=30,
        max_total_size_bytes=200 * 1024 * 1024,
        keep_latest_n=2,
    )

    plan = generate_deletion_plan(sample_artifacts, sample_policy, dry_run=True)
    summary = plan.summary()

    print("=== Artifact Cleanup Report (DRY RUN) ===\n")
    print(f"Policy: max_age={sample_policy.max_age_days}d, "
          f"max_size={sample_policy.max_total_size_bytes // (1024*1024)}MB, "
          f"keep_latest_n={sample_policy.keep_latest_n}\n")

    print("Artifacts to DELETE:")
    for art in sorted(plan.to_delete, key=lambda a: a.name):
        print(f"  [-] {art.name:40s}  {art.size_mb:7.1f} MB  age={((now - art.created_at).days)}d  run={art.workflow_run_id}")

    print("\nArtifacts to RETAIN:")
    for art in sorted(plan.to_retain, key=lambda a: a.name):
        print(f"  [+] {art.name:40s}  {art.size_mb:7.1f} MB  age={((now - art.created_at).days)}d  run={art.workflow_run_id}")

    print("\nSummary:")
    print(json.dumps({
        **summary,
        "space_reclaimed_mb": round(summary["space_reclaimed_bytes"] / (1024 * 1024), 2),
        "dry_run": plan.dry_run,
    }, indent=2))
