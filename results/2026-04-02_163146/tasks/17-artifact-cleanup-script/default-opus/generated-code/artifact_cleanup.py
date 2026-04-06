#!/usr/bin/env python3
"""
Artifact Cleanup — Retention policy engine with dry-run support.

Given a list of artifacts with metadata (name, size, creation date, workflow run ID),
applies configurable retention policies and generates a deletion plan.

Policies (all optional, union of matches is deleted):
  - max_age_days:    Delete artifacts older than N days.
  - max_total_bytes: Delete oldest artifacts until total size fits within budget.
  - keep_latest_n:   Per workflow run ID, keep only the N most recent artifacts.

Developed using red/green TDD — see test_artifact_cleanup.py.
"""
from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
from typing import Optional


# ===========================================================================
# GREEN Cycle 1 — Artifact data model
# ===========================================================================

@dataclass(frozen=True)
class Artifact:
    """Immutable representation of a single build/CI artifact."""

    name: str
    size_bytes: int
    created_at: datetime  # must be timezone-aware (UTC)
    workflow_run_id: str

    @property
    def size_mb(self) -> float:
        """Size expressed in megabytes."""
        return self.size_bytes / (1024 * 1024)

    def age_days(self, now: datetime) -> int:
        """Whole-number age in days relative to *now*."""
        return (now - self.created_at).days


def parse_artifacts(raw: list[dict]) -> list[Artifact]:
    """
    Parse a list of raw dicts (e.g. from JSON) into validated Artifact objects.

    Raises ValueError with a meaningful message for:
      - missing required fields
      - unparseable date strings
      - negative size values
    """
    required_fields = {"name", "size_bytes", "created_at", "workflow_run_id"}
    artifacts: list[Artifact] = []

    for i, entry in enumerate(raw):
        # Check for missing fields
        missing = required_fields - set(entry.keys())
        if missing:
            raise ValueError(
                f"Artifact at index {i} is missing required fields: {', '.join(sorted(missing))}"
            )

        # Validate size
        if entry["size_bytes"] < 0:
            raise ValueError(
                f"Artifact '{entry['name']}': size_bytes cannot be negative (got {entry['size_bytes']})"
            )

        # Parse the created_at date
        raw_date = entry["created_at"]
        if isinstance(raw_date, datetime):
            created = raw_date if raw_date.tzinfo else raw_date.replace(tzinfo=timezone.utc)
        elif isinstance(raw_date, str):
            try:
                # Support ISO 8601 with trailing Z or +00:00
                cleaned = raw_date.replace("Z", "+00:00")
                created = datetime.fromisoformat(cleaned)
            except (ValueError, TypeError) as exc:
                raise ValueError(
                    f"Artifact '{entry['name']}': could not parse date '{raw_date}' — {exc}"
                ) from exc
        else:
            raise ValueError(
                f"Artifact '{entry['name']}': created_at must be a string or datetime"
            )

        artifacts.append(Artifact(
            name=entry["name"],
            size_bytes=entry["size_bytes"],
            created_at=created,
            workflow_run_id=entry["workflow_run_id"],
        ))

    return artifacts


# ===========================================================================
# GREEN Cycle 2 — Max-age retention policy
# ===========================================================================

def apply_max_age_policy(
    artifacts: list[Artifact],
    max_age_days: int | None,
    now: datetime,
) -> list[Artifact]:
    """Return artifacts older than *max_age_days*. Returns [] if policy is disabled (None)."""
    if max_age_days is None:
        return []
    return [a for a in artifacts if a.age_days(now) > max_age_days]


# ===========================================================================
# GREEN Cycle 3 — Max-total-size retention policy
# ===========================================================================

def apply_max_total_size_policy(
    artifacts: list[Artifact],
    max_total_bytes: int | None,
    now: datetime,
) -> list[Artifact]:
    """
    If total artifact size exceeds *max_total_bytes*, delete the oldest artifacts
    first until the remaining set fits within the budget.
    Returns [] if policy is disabled (None) or already under budget.
    """
    if max_total_bytes is None:
        return []

    total = sum(a.size_bytes for a in artifacts)
    if total <= max_total_bytes:
        return []

    # Sort oldest-first and greedily remove until under budget
    sorted_arts = sorted(artifacts, key=lambda a: a.created_at)
    to_delete: list[Artifact] = []
    for art in sorted_arts:
        if total <= max_total_bytes:
            break
        to_delete.append(art)
        total -= art.size_bytes

    return to_delete


# ===========================================================================
# GREEN Cycle 4 — Keep-latest-N-per-workflow policy
# ===========================================================================

def apply_keep_latest_n_policy(
    artifacts: list[Artifact],
    keep_n: int | None,
) -> list[Artifact]:
    """
    For each workflow_run_id, keep only the *keep_n* most recent artifacts.
    Older extras are returned for deletion.
    Returns [] if policy is disabled (None).
    """
    if keep_n is None:
        return []

    # Group by workflow
    by_workflow: dict[str, list[Artifact]] = {}
    for a in artifacts:
        by_workflow.setdefault(a.workflow_run_id, []).append(a)

    to_delete: list[Artifact] = []
    for _wf, group in by_workflow.items():
        # Sort newest-first
        sorted_group = sorted(group, key=lambda a: a.created_at, reverse=True)
        to_delete.extend(sorted_group[keep_n:])

    return to_delete


# ===========================================================================
# GREEN Cycle 5 — Retention policy config & deletion plan
# ===========================================================================

@dataclass
class RetentionPolicy:
    """
    Configurable retention policy — all thresholds are optional.
    Validation raises ValueError with clear messages for invalid values.
    """

    max_age_days: int | None = None
    max_total_bytes: int | None = None
    keep_latest_n: int | None = None

    def __post_init__(self):
        if self.max_age_days is not None and self.max_age_days < 0:
            raise ValueError("max_age_days must be >= 0 (got {})".format(self.max_age_days))
        if self.max_total_bytes is not None and self.max_total_bytes < 0:
            raise ValueError("max_total_bytes must be >= 0 (got {})".format(self.max_total_bytes))
        if self.keep_latest_n is not None and self.keep_latest_n < 1:
            raise ValueError("keep_latest_n must be >= 1 (got {})".format(self.keep_latest_n))


@dataclass
class DeletionPlan:
    """The result of applying retention policies: what to delete and what to keep."""

    all_artifacts: list[Artifact]
    to_delete: list[Artifact]
    # Maps artifact name → list of policy names that flagged it
    _reasons: dict[str, list[str]] = field(default_factory=dict)

    @property
    def to_retain(self) -> list[Artifact]:
        delete_set = set(id(a) for a in self.to_delete)
        return [a for a in self.all_artifacts if id(a) not in delete_set]

    def summary(self) -> dict:
        """Produce a summary dict with counts and sizes."""
        retained = self.to_retain
        return {
            "total_artifacts": len(self.all_artifacts),
            "artifacts_to_delete": len(self.to_delete),
            "artifacts_retained": len(retained),
            "space_reclaimed_bytes": sum(a.size_bytes for a in self.to_delete),
            "space_retained_bytes": sum(a.size_bytes for a in retained),
        }

    def deletion_reasons(self) -> dict[str, list[str]]:
        """Return a mapping of artifact name → list of policies that flagged it."""
        return dict(self._reasons)


def generate_deletion_plan(
    artifacts: list[Artifact],
    policy: RetentionPolicy,
    now: datetime,
) -> DeletionPlan:
    """
    Apply all configured retention policies and produce a unified deletion plan.
    An artifact is deleted if ANY policy flags it.
    """
    # Track which policies flagged each artifact (by name)
    reasons: dict[str, list[str]] = {}

    def _record(flagged: list[Artifact], policy_name: str):
        for a in flagged:
            reasons.setdefault(a.name, []).append(policy_name)

    # Apply each policy independently
    aged_out = apply_max_age_policy(artifacts, policy.max_age_days, now)
    _record(aged_out, "max_age")

    over_size = apply_max_total_size_policy(artifacts, policy.max_total_bytes, now)
    _record(over_size, "max_total_size")

    excess_per_wf = apply_keep_latest_n_policy(artifacts, policy.keep_latest_n)
    _record(excess_per_wf, "keep_latest_n")

    # Union of all flagged artifacts (deduplicated by identity)
    seen_ids: set[int] = set()
    to_delete: list[Artifact] = []
    for a in aged_out + over_size + excess_per_wf:
        if id(a) not in seen_ids:
            seen_ids.add(id(a))
            to_delete.append(a)

    return DeletionPlan(all_artifacts=artifacts, to_delete=to_delete, _reasons=reasons)


# ===========================================================================
# GREEN Cycle 6 — Dry-run mode & cleanup runner
# ===========================================================================

@dataclass
class CleanupResult:
    """Wraps a DeletionPlan with execution metadata."""

    plan: DeletionPlan
    is_dry_run: bool
    executed: bool  # True only when dry_run=False and deletion was performed

    def to_dict(self) -> dict:
        """JSON-serializable representation of the full result."""
        summary = self.plan.summary()
        reasons = self.plan.deletion_reasons()
        return {
            "dry_run": self.is_dry_run,
            "executed": self.executed,
            "summary": summary,
            "deleted_artifacts": [
                {
                    "name": a.name,
                    "size_bytes": a.size_bytes,
                    "created_at": a.created_at.isoformat(),
                    "workflow_run_id": a.workflow_run_id,
                    "reasons": reasons.get(a.name, []),
                }
                for a in self.plan.to_delete
            ],
            "retained_artifacts": [
                {
                    "name": a.name,
                    "size_bytes": a.size_bytes,
                    "created_at": a.created_at.isoformat(),
                    "workflow_run_id": a.workflow_run_id,
                }
                for a in self.plan.to_retain
            ],
        }


def run_cleanup(
    artifacts: list[Artifact],
    policy: RetentionPolicy,
    now: datetime,
    dry_run: bool = True,
) -> CleanupResult:
    """
    Apply retention policies and optionally execute deletions.

    In dry-run mode (default), the plan is generated but nothing is deleted.
    When dry_run=False, the deletion callback would be invoked (here we simply
    mark the result as executed, since actual deletion depends on the platform).
    """
    plan = generate_deletion_plan(artifacts, policy, now)
    executed = not dry_run  # In a real system, this is where we'd call the delete API
    return CleanupResult(plan=plan, is_dry_run=dry_run, executed=executed)


# ===========================================================================
# CLI entry point — demonstrates usage with mock data
# ===========================================================================

def _format_bytes(b: int) -> str:
    """Human-readable byte size."""
    for unit in ("B", "KB", "MB", "GB"):
        if abs(b) < 1024:
            return f"{b:.1f} {unit}"
        b /= 1024  # type: ignore[assignment]
    return f"{b:.1f} TB"


def main():
    """Run the cleanup engine on built-in mock data and print the plan."""
    # Mock artifact data
    now = datetime.now(timezone.utc)
    mock_data = [
        {"name": "build-logs-v1",    "size_bytes": 1_000_000, "created_at": (now - timedelta(days=40)).isoformat(), "workflow_run_id": "build"},
        {"name": "build-logs-v2",    "size_bytes": 2_000_000, "created_at": (now - timedelta(days=22)).isoformat(), "workflow_run_id": "build"},
        {"name": "build-logs-v3",    "size_bytes": 1_500_000, "created_at": (now - timedelta(days=7)).isoformat(),  "workflow_run_id": "build"},
        {"name": "build-logs-v4",    "size_bytes": 1_000_000, "created_at": (now - timedelta(days=1)).isoformat(),  "workflow_run_id": "build"},
        {"name": "test-results-v1",  "size_bytes": 500_000,   "created_at": (now - timedelta(days=31)).isoformat(), "workflow_run_id": "test"},
        {"name": "test-results-v2",  "size_bytes": 800_000,   "created_at": (now - timedelta(days=12)).isoformat(), "workflow_run_id": "test"},
        {"name": "test-results-v3",  "size_bytes": 600_000,   "created_at": (now - timedelta(days=2)).isoformat(),  "workflow_run_id": "test"},
        {"name": "deploy-bundle-v1", "size_bytes": 5_000_000, "created_at": (now - timedelta(days=4)).isoformat(),  "workflow_run_id": "deploy"},
        {"name": "deploy-bundle-v2", "size_bytes": 5_000_000, "created_at": (now - timedelta(days=1)).isoformat(),  "workflow_run_id": "deploy"},
    ]

    # Parse command-line flags
    dry_run = "--execute" not in sys.argv

    artifacts = parse_artifacts(mock_data)
    policy = RetentionPolicy(max_age_days=30, max_total_bytes=10_000_000, keep_latest_n=2)
    result = run_cleanup(artifacts, policy, now=now, dry_run=dry_run)

    # Print human-readable output
    mode = "DRY RUN" if result.is_dry_run else "EXECUTING"
    print(f"=== Artifact Cleanup ({mode}) ===\n")
    print(f"Policy: max_age={policy.max_age_days}d, max_size={_format_bytes(policy.max_total_bytes or 0)}, keep_latest_n={policy.keep_latest_n}\n")

    summary = result.plan.summary()
    print(f"Total artifacts:     {summary['total_artifacts']}")
    print(f"Artifacts to delete: {summary['artifacts_to_delete']}")
    print(f"Artifacts retained:  {summary['artifacts_retained']}")
    print(f"Space reclaimed:     {_format_bytes(summary['space_reclaimed_bytes'])}")
    print(f"Space retained:      {_format_bytes(summary['space_retained_bytes'])}")

    if result.plan.to_delete:
        reasons = result.plan.deletion_reasons()
        print("\n--- Artifacts to delete ---")
        for a in result.plan.to_delete:
            why = ", ".join(reasons.get(a.name, ["unknown"]))
            print(f"  {a.name:25s}  {_format_bytes(a.size_bytes):>10s}  age={a.age_days(now):3d}d  wf={a.workflow_run_id}  [{why}]")

    if result.plan.to_retain:
        print("\n--- Artifacts retained ---")
        for a in result.plan.to_retain:
            print(f"  {a.name:25s}  {_format_bytes(a.size_bytes):>10s}  age={a.age_days(now):3d}d  wf={a.workflow_run_id}")

    # Also emit JSON for machine consumption
    print("\n--- JSON output ---")
    print(json.dumps(result.to_dict(), indent=2))


if __name__ == "__main__":
    main()
