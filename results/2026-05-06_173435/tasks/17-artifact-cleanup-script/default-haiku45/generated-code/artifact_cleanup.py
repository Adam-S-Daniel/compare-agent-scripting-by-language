"""
Artifact retention policy manager.

Applies retention policies to artifacts with metadata, determines which to delete,
and generates a deletion plan with summary metrics.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import json


@dataclass
class Artifact:
    """Represents a build artifact with metadata."""
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str

    def age_days(self, reference_time: datetime) -> float:
        """Calculate age in days relative to reference time."""
        delta = reference_time - self.created_at
        return delta.total_seconds() / (24 * 3600)


@dataclass
class RetentionPolicy:
    """Defines retention constraints for artifacts."""
    max_age_days: float
    max_total_size_bytes: float
    keep_latest_n: float

    def __post_init__(self):
        """Validate policy parameters."""
        if self.max_age_days < 0:
            raise ValueError("max_age_days must be non-negative")
        if self.max_total_size_bytes < 0:
            raise ValueError("max_total_size_bytes must be non-negative")
        if self.keep_latest_n < 0:
            raise ValueError("keep_latest_n must be non-negative")


@dataclass
class DeletionPlan:
    """Represents the deletion plan with summary metrics."""
    artifacts_to_delete: List[Artifact]
    artifacts_to_retain: List[Artifact]
    summary: Dict[str, Any]
    dry_run: bool = False


class ArtifactCleanup:
    """Applies retention policies to determine which artifacts to delete."""

    def __init__(self, artifacts: List[Artifact], policy: RetentionPolicy, dry_run: bool = False):
        """
        Initialize artifact cleanup manager.

        Args:
            artifacts: List of artifact objects with metadata.
            policy: RetentionPolicy defining constraints.
            dry_run: If True, generate plan without modifying anything.
        """
        self.artifacts = artifacts
        self.policy = policy
        self.dry_run = dry_run

    def generate_plan(self, reference_time: Optional[datetime] = None) -> DeletionPlan:
        """
        Generate a deletion plan based on retention policy.

        Applies policies in order:
        1. Delete artifacts older than max_age_days
        2. Keep only latest N per workflow run ID
        3. Delete oldest artifacts until total size is under limit

        Args:
            reference_time: Time to use for age calculations (default: now).

        Returns:
            DeletionPlan with artifacts to delete/retain and summary.
        """
        if reference_time is None:
            reference_time = datetime.now()

        # Start with all artifacts as candidates for retention
        candidates = {a.name: a for a in self.artifacts}
        to_delete = set()

        # Policy 1: Age-based deletion
        if self.policy.max_age_days != float('inf'):
            for artifact in self.artifacts:
                if artifact.age_days(reference_time) > self.policy.max_age_days:
                    to_delete.add(artifact.name)

        # Policy 2: Keep latest N per workflow run ID
        if self.policy.keep_latest_n != float('inf'):
            by_run_id = {}
            for artifact in self.artifacts:
                if artifact.name not in to_delete:
                    if artifact.workflow_run_id not in by_run_id:
                        by_run_id[artifact.workflow_run_id] = []
                    by_run_id[artifact.workflow_run_id].append(artifact)

            # Sort by creation time (oldest first) within each run ID
            for run_id in by_run_id:
                sorted_artifacts = sorted(by_run_id[run_id], key=lambda a: a.created_at)
                keep_count = int(self.policy.keep_latest_n)
                # Mark older artifacts for deletion
                for artifact in sorted_artifacts[:-keep_count] if keep_count > 0 else sorted_artifacts:
                    to_delete.add(artifact.name)

        # Policy 3: Size-based deletion (delete oldest first)
        if self.policy.max_total_size_bytes != float('inf'):
            retained = [a for a in self.artifacts if a.name not in to_delete]
            retained_size = sum(a.size_bytes for a in retained)

            if retained_size > self.policy.max_total_size_bytes:
                # Sort by age (oldest first) to delete oldest first
                sorted_by_age = sorted(retained, key=lambda a: a.created_at)
                for artifact in sorted_by_age:
                    if retained_size <= self.policy.max_total_size_bytes:
                        break
                    to_delete.add(artifact.name)
                    retained_size -= artifact.size_bytes

        # Build final lists
        artifacts_to_delete = [a for a in self.artifacts if a.name in to_delete]
        artifacts_to_retain = [a for a in self.artifacts if a.name not in to_delete]

        # Calculate summary metrics
        space_reclaimed = sum(a.size_bytes for a in artifacts_to_delete)
        summary = {
            'total_artifacts': len(self.artifacts),
            'artifacts_to_delete': len(artifacts_to_delete),
            'artifacts_to_retain': len(artifacts_to_retain),
            'space_reclaimed_bytes': space_reclaimed,
            'space_reclaimed_mb': round(space_reclaimed / (1024 * 1024), 2),
            'retained_size_bytes': sum(a.size_bytes for a in artifacts_to_retain),
        }

        return DeletionPlan(
            artifacts_to_delete=artifacts_to_delete,
            artifacts_to_retain=artifacts_to_retain,
            summary=summary,
            dry_run=self.dry_run
        )

    def to_json(self, plan: DeletionPlan) -> str:
        """
        Serialize deletion plan to JSON.

        Args:
            plan: DeletionPlan to serialize.

        Returns:
            JSON string representation of the plan.
        """
        def artifact_to_dict(a: Artifact) -> Dict[str, Any]:
            return {
                'name': a.name,
                'size_bytes': a.size_bytes,
                'size_mb': round(a.size_bytes / (1024 * 1024), 2),
                'created_at': a.created_at.isoformat(),
                'workflow_run_id': a.workflow_run_id,
            }

        return json.dumps({
            'dry_run': plan.dry_run,
            'summary': plan.summary,
            'artifacts_to_delete': [artifact_to_dict(a) for a in plan.artifacts_to_delete],
            'artifacts_to_retain': [artifact_to_dict(a) for a in plan.artifacts_to_retain],
        }, indent=2)
