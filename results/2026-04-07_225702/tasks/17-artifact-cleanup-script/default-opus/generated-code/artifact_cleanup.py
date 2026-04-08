"""
Artifact retention policy engine.

Applies configurable retention policies to a list of CI/CD artifacts and
produces a deletion plan showing what to remove and what to keep, along
with a human-readable summary.  Supports dry-run mode.
"""

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from typing import Callable, Optional

# Required keys every artifact dict must have.
REQUIRED_ARTIFACT_FIELDS = {"name", "size_bytes", "created_at", "workflow_run_id"}


@dataclass
class RetentionPolicy:
    """Configurable retention rules. All fields are optional — omitted rules are not enforced."""
    max_age_days: Optional[int] = None        # delete artifacts older than this
    max_total_size_bytes: Optional[int] = None # cap on total retained size
    keep_latest_n_per_workflow: Optional[int] = None  # keep N newest per workflow_run_id

    def validate(self) -> None:
        """Raise ValueError if any configured values are nonsensical."""
        if self.max_age_days is not None and self.max_age_days <= 0:
            raise ValueError("max_age_days must be positive")
        if self.max_total_size_bytes is not None and self.max_total_size_bytes <= 0:
            raise ValueError("max_total_size_bytes must be positive")
        if self.keep_latest_n_per_workflow is not None and self.keep_latest_n_per_workflow <= 0:
            raise ValueError("keep_latest_n_per_workflow must be positive")


@dataclass
class CleanupResult:
    """Outcome of applying retention policies."""
    to_delete: list = field(default_factory=list)
    to_retain: list = field(default_factory=list)


def _validate_artifacts(artifacts: list[dict]) -> None:
    """Ensure every artifact has the required fields."""
    for a in artifacts:
        missing = REQUIRED_ARTIFACT_FIELDS - set(a.keys())
        if missing:
            raise ValueError(
                f"Artifact '{a.get('name', '<unknown>')}' missing required fields: "
                f"{', '.join(sorted(missing))}"
            )


def apply_retention_policies(
    artifacts: list[dict],
    policy: RetentionPolicy,
    now: Optional[datetime] = None,
) -> CleanupResult:
    """Apply retention policies and return which artifacts to delete vs retain.

    Policies are applied in order: max-age → keep-latest-N → max-total-size.
    Each stage can only move artifacts from "retain" to "delete", never the reverse.
    """
    if now is None:
        now = datetime.now()

    _validate_artifacts(artifacts)

    # Start with all artifacts in the "retain" set; policies move them to "delete".
    to_delete: list[dict] = []
    to_retain = list(artifacts)

    # --- Max-age policy ---
    if policy.max_age_days is not None:
        still_retained = []
        for a in to_retain:
            age_days = (now - a["created_at"]).total_seconds() / 86400
            if age_days > policy.max_age_days:
                to_delete.append(a)
            else:
                still_retained.append(a)
        to_retain = still_retained

    # --- Keep-latest-N per workflow ---
    if policy.keep_latest_n_per_workflow is not None:
        by_workflow: dict[str, list[dict]] = defaultdict(list)
        for a in to_retain:
            by_workflow[a["workflow_run_id"]].append(a)

        still_retained = []
        for wf_id, group in by_workflow.items():
            # Sort newest-first by creation date
            group.sort(key=lambda a: a["created_at"], reverse=True)
            still_retained.extend(group[: policy.keep_latest_n_per_workflow])
            to_delete.extend(group[policy.keep_latest_n_per_workflow :])
        to_retain = still_retained

    # --- Max total size policy (drop oldest first until under budget) ---
    if policy.max_total_size_bytes is not None:
        # Sort retained artifacts newest-first so we preferentially keep recent ones
        to_retain.sort(key=lambda a: a["created_at"], reverse=True)
        budget = policy.max_total_size_bytes
        still_retained = []
        running_total = 0
        for a in to_retain:
            if running_total + a["size_bytes"] <= budget:
                still_retained.append(a)
                running_total += a["size_bytes"]
            else:
                to_delete.append(a)
        to_retain = still_retained

    return CleanupResult(to_delete=to_delete, to_retain=to_retain)


def generate_summary(result: CleanupResult, dry_run: bool = False) -> str:
    """Produce a human-readable deletion plan from a CleanupResult."""
    total_delete = len(result.to_delete)
    total_retain = len(result.to_retain)
    reclaimed_bytes = sum(a["size_bytes"] for a in result.to_delete)
    reclaimed_mb = reclaimed_bytes / (1024 * 1024)

    header = "=== Artifact Cleanup Plan ==="
    if dry_run:
        header = "=== Artifact Cleanup Plan (DRY RUN) ==="

    lines = [
        header,
        f"  {total_delete} artifact(s) to delete",
        f"  {total_retain} artifact(s) to retain",
        f"  Space reclaimed: {reclaimed_mb:.2f} MB",
        "",
    ]

    if result.to_delete:
        lines.append("Artifacts to DELETE:")
        for a in result.to_delete:
            size_mb = a["size_bytes"] / (1024 * 1024)
            status = a.get("_delete_status", "")
            suffix = f"  [{status}]" if status else ""
            lines.append(
                f"  - {a['name']}  ({size_mb:.1f} MB, "
                f"workflow: {a['workflow_run_id']}, "
                f"created: {a['created_at'].isoformat()}){suffix}"
            )
        lines.append("")

    if result.to_retain:
        lines.append("Artifacts to RETAIN:")
        for a in result.to_retain:
            size_mb = a["size_bytes"] / (1024 * 1024)
            lines.append(
                f"  - {a['name']}  ({size_mb:.1f} MB, "
                f"workflow: {a['workflow_run_id']}, "
                f"created: {a['created_at'].isoformat()})"
            )

    return "\n".join(lines)


def run_cleanup(
    artifacts: list[dict],
    policy: RetentionPolicy,
    delete_fn: Optional[Callable[[dict], None]] = None,
    dry_run: bool = True,
    now: Optional[datetime] = None,
) -> str:
    """Top-level orchestrator: apply policies, optionally execute deletions, return summary.

    Args:
        artifacts: List of artifact dicts with name/size_bytes/created_at/workflow_run_id.
        policy: Retention policy to apply.
        delete_fn: Callback invoked for each artifact to delete (skipped in dry-run).
        dry_run: If True (default), no deletions are performed — only a plan is generated.
        now: Override for "current time" (useful for testing).
    """
    result = apply_retention_policies(artifacts, policy, now=now)

    # Execute deletions unless in dry-run mode
    if not dry_run and delete_fn is not None:
        for a in result.to_delete:
            try:
                delete_fn(a)
                a["_delete_status"] = "DELETED"
            except Exception as exc:
                a["_delete_status"] = f"FAILED: {exc}"

    return generate_summary(result, dry_run=dry_run)


# ---------------------------------------------------------------------------
# CLI entrypoint with mock data for demonstration
# ---------------------------------------------------------------------------

def _build_mock_artifacts() -> list[dict]:
    """Generate a realistic set of mock CI/CD artifacts for demonstration."""
    from datetime import timedelta
    now = datetime.now()
    MB = 1024 * 1024
    return [
        # Deploy workflow — multiple builds over time
        {"name": "deploy-v1.0.0.tar.gz", "size_bytes": 250 * MB,
         "created_at": now - timedelta(days=90), "workflow_run_id": "deploy-pipeline"},
        {"name": "deploy-v1.1.0.tar.gz", "size_bytes": 260 * MB,
         "created_at": now - timedelta(days=60), "workflow_run_id": "deploy-pipeline"},
        {"name": "deploy-v1.2.0.tar.gz", "size_bytes": 270 * MB,
         "created_at": now - timedelta(days=30), "workflow_run_id": "deploy-pipeline"},
        {"name": "deploy-v1.3.0.tar.gz", "size_bytes": 280 * MB,
         "created_at": now - timedelta(days=7), "workflow_run_id": "deploy-pipeline"},
        {"name": "deploy-v1.4.0.tar.gz", "size_bytes": 290 * MB,
         "created_at": now - timedelta(days=1), "workflow_run_id": "deploy-pipeline"},
        # Test workflow — coverage reports
        {"name": "coverage-report-feb.html", "size_bytes": 15 * MB,
         "created_at": now - timedelta(days=65), "workflow_run_id": "test-suite"},
        {"name": "coverage-report-mar.html", "size_bytes": 16 * MB,
         "created_at": now - timedelta(days=35), "workflow_run_id": "test-suite"},
        {"name": "coverage-report-apr.html", "size_bytes": 17 * MB,
         "created_at": now - timedelta(days=3), "workflow_run_id": "test-suite"},
        # Lint workflow — small artifacts
        {"name": "lint-results-old.json", "size_bytes": 1 * MB,
         "created_at": now - timedelta(days=120), "workflow_run_id": "lint"},
        {"name": "lint-results-recent.json", "size_bytes": 1 * MB,
         "created_at": now - timedelta(days=2), "workflow_run_id": "lint"},
    ]


def _mock_delete(artifact: dict) -> None:
    """Simulate deletion (just prints; a real implementation would call an API)."""
    print(f"  [mock] Deleting artifact: {artifact['name']}")


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Artifact cleanup tool — apply retention policies and generate a deletion plan."
    )
    parser.add_argument("--max-age-days", type=int, default=None,
                        help="Delete artifacts older than this many days")
    parser.add_argument("--max-total-size-mb", type=int, default=None,
                        help="Maximum total size of retained artifacts in MB")
    parser.add_argument("--keep-latest-n", type=int, default=None,
                        help="Keep the N most recent artifacts per workflow")
    parser.add_argument("--dry-run", action="store_true", default=True,
                        help="Show deletion plan without deleting (default)")
    parser.add_argument("--execute", action="store_true",
                        help="Actually perform deletions (uses mock delete)")
    args = parser.parse_args()

    policy = RetentionPolicy(
        max_age_days=args.max_age_days,
        max_total_size_bytes=(args.max_total_size_mb * 1024 * 1024) if args.max_total_size_mb else None,
        keep_latest_n_per_workflow=args.keep_latest_n,
    )

    try:
        policy.validate()
    except ValueError as e:
        print(f"Error: {e}")
        raise SystemExit(1)

    artifacts = _build_mock_artifacts()
    dry_run = not args.execute

    summary = run_cleanup(artifacts, policy, delete_fn=_mock_delete, dry_run=dry_run)
    print(summary)


if __name__ == "__main__":
    main()
