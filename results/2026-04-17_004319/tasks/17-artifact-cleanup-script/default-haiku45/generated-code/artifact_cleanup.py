"""
Artifact cleanup script with retention policies.
Supports dry-run mode and generates deletion plans with summaries.
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import List


@dataclass
class Artifact:
    """Represents a single artifact with metadata."""

    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str


@dataclass
class RetentionPolicy:
    """Configuration for artifact retention."""

    max_age_days: int
    max_total_size_bytes: int
    keep_latest_n_per_workflow: int


@dataclass
class DeletionPlan:
    """Plan for artifact deletion with summary."""

    to_delete: List[Artifact] = field(default_factory=list)
    to_keep: List[Artifact] = field(default_factory=list)
    dry_run: bool = False

    def summary(self) -> dict:
        """Generate summary of deletion plan."""
        space_reclaimed = sum(a.size_bytes for a in self.to_delete)
        return {
            "artifacts_to_delete": len(self.to_delete),
            "artifacts_to_keep": len(self.to_keep),
            "space_reclaimed_bytes": space_reclaimed,
        }


class ArtifactCleaner:
    """Main cleanup engine applying retention policies."""

    def __init__(self, policy: RetentionPolicy):
        self.policy = policy

    def plan_deletions(
        self, artifacts: List[Artifact], dry_run: bool = False
    ) -> DeletionPlan:
        """
        Determine which artifacts to delete based on retention policies.
        Applies policies in order: max_age, keep_latest_n, max_total_size.
        """
        plan = DeletionPlan(dry_run=dry_run)

        if not artifacts:
            return plan

        # Track candidates for deletion using indices to avoid hashability issues
        to_delete_indices = set()

        # Policy 1: Delete by max age
        now = datetime.now()
        max_age_threshold = now - timedelta(days=self.policy.max_age_days)
        for idx, artifact in enumerate(artifacts):
            if artifact.created_at < max_age_threshold:
                to_delete_indices.add(idx)

        # Policy 2: Keep only latest N per workflow
        candidates = [
            (idx, a) for idx, a in enumerate(artifacts) if idx not in to_delete_indices
        ]

        # Group by workflow_run_id
        by_workflow = {}
        for idx, artifact in candidates:
            if artifact.workflow_run_id not in by_workflow:
                by_workflow[artifact.workflow_run_id] = []
            by_workflow[artifact.workflow_run_id].append((idx, artifact))

        for workflow_id, workflow_artifacts in by_workflow.items():
            # Sort by creation date descending (newest first)
            sorted_artifacts = sorted(
                workflow_artifacts, key=lambda x: x[1].created_at, reverse=True
            )
            # Mark all but the latest N for deletion
            for idx, artifact in sorted_artifacts[self.policy.keep_latest_n_per_workflow :]:
                to_delete_indices.add(idx)

        # Policy 3: Delete oldest artifacts if total size exceeds max
        remaining_indices = [
            (idx, a) for idx, a in enumerate(artifacts) if idx not in to_delete_indices
        ]
        total_size = sum(a.size_bytes for _, a in remaining_indices)

        if total_size > self.policy.max_total_size_bytes:
            # Sort by creation date (oldest first) to delete oldest first
            remaining_sorted = sorted(
                remaining_indices, key=lambda x: x[1].created_at
            )
            for idx, artifact in remaining_sorted:
                if total_size <= self.policy.max_total_size_bytes:
                    break
                to_delete_indices.add(idx)
                total_size -= artifact.size_bytes

        # Separate into keep/delete lists
        plan.to_delete = sorted(
            [a for idx, a in enumerate(artifacts) if idx in to_delete_indices],
            key=lambda a: a.created_at,
        )
        plan.to_keep = sorted(
            [a for idx, a in enumerate(artifacts) if idx not in to_delete_indices],
            key=lambda a: a.created_at,
        )

        return plan
