#!/usr/bin/env python3
"""
Artifact cleanup script with configurable retention policies.

Applies three independent policies (in order):
  1. max_age_days    — delete artifacts older than N days
  2. keep_latest_n   — per workflow, delete all but the N newest
  3. max_total_size  — delete oldest remaining artifacts until total size fits

Generates a deletion plan (dry-run or live) with a human-readable summary.

CLI usage:
  python3 artifact_cleanup.py --fixtures artifacts.json \
      --max-age-days 30 --keep-latest-n 3 \
      --max-total-size-mb 1024 \
      --reference-date 2026-04-19 \
      --dry-run
"""
import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional


# ─── Data structures ──────────────────────────────────────────────────────────

@dataclass
class Artifact:
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str
    workflow: str


@dataclass
class RetentionPolicy:
    max_age_days: Optional[int] = None
    max_total_size_bytes: Optional[int] = None
    keep_latest_n: Optional[int] = None


@dataclass
class DeletionDecision:
    artifact: Artifact
    delete: bool
    reasons: list[str] = field(default_factory=list)


@dataclass
class DeletionPlan:
    decisions: list[DeletionDecision]

    @property
    def to_delete(self) -> list[DeletionDecision]:
        return [d for d in self.decisions if d.delete]

    @property
    def to_retain(self) -> list[DeletionDecision]:
        return [d for d in self.decisions if not d.delete]

    @property
    def space_reclaimed_bytes(self) -> int:
        return sum(d.artifact.size_bytes for d in self.to_delete)


# ─── Core logic ───────────────────────────────────────────────────────────────

def apply_retention_policies(
    artifacts: list[Artifact],
    policy: RetentionPolicy,
    reference_date: Optional[datetime] = None,
) -> DeletionPlan:
    """
    Apply retention policies and return a DeletionPlan.

    Policies are applied independently and are additive: an artifact is
    deleted if ANY policy marks it for deletion.
    """
    if reference_date is None:
        reference_date = datetime.now(timezone.utc)

    # Build a mutable decision record for each artifact
    decisions: dict[str, DeletionDecision] = {
        a.name: DeletionDecision(artifact=a, delete=False)
        for a in artifacts
    }

    # Policy 1: max age — delete anything older than max_age_days
    if policy.max_age_days is not None:
        for artifact in artifacts:
            age_days = (reference_date - artifact.created_at).days
            if age_days > policy.max_age_days:
                decisions[artifact.name].delete = True
                decisions[artifact.name].reasons.append(
                    f"exceeds max age ({age_days} days > {policy.max_age_days} days)"
                )

    # Policy 2: keep-latest-N — per workflow, only keep the N newest
    if policy.keep_latest_n is not None:
        workflow_groups: dict[str, list[Artifact]] = {}
        for artifact in artifacts:
            workflow_groups.setdefault(artifact.workflow, []).append(artifact)

        for wf_name, wf_artifacts in workflow_groups.items():
            # Sort newest-first so the first N are kept
            sorted_artifacts = sorted(
                wf_artifacts, key=lambda a: a.created_at, reverse=True
            )
            for artifact in sorted_artifacts[policy.keep_latest_n:]:
                decisions[artifact.name].delete = True
                reason = (
                    f"exceeds keep-latest-{policy.keep_latest_n} "
                    f"for workflow '{wf_name}'"
                )
                if reason not in decisions[artifact.name].reasons:
                    decisions[artifact.name].reasons.append(reason)

    # Policy 3: max total size — delete oldest non-deleted artifacts until
    # the retained total fits within the limit
    if policy.max_total_size_bytes is not None:
        retained = [a for a in artifacts if not decisions[a.name].delete]
        total_size = sum(a.size_bytes for a in retained)

        if total_size > policy.max_total_size_bytes:
            # Delete oldest first to free the most "stale" space
            retained_sorted = sorted(retained, key=lambda a: a.created_at)
            for artifact in retained_sorted:
                if total_size <= policy.max_total_size_bytes:
                    break
                decisions[artifact.name].delete = True
                decisions[artifact.name].reasons.append(
                    f"exceeds max total size "
                    f"({_fmt_bytes(total_size)} > "
                    f"{_fmt_bytes(policy.max_total_size_bytes)})"
                )
                total_size -= artifact.size_bytes

    return DeletionPlan(decisions=list(decisions.values()))


# ─── Formatting helpers ───────────────────────────────────────────────────────

def format_size(size_bytes: int) -> str:
    """Return a human-readable file size string."""
    if size_bytes >= 1024 ** 3:
        return f"{size_bytes / 1024 ** 3:.1f} GB"
    if size_bytes >= 1024 ** 2:
        return f"{size_bytes / 1024 ** 2:.1f} MB"
    if size_bytes >= 1024:
        return f"{size_bytes / 1024:.1f} KB"
    return f"{size_bytes} B"


def _fmt_bytes(n: int) -> str:
    """Short alias used internally in reason strings."""
    return format_size(n)


# ─── Summary generation ───────────────────────────────────────────────────────

def generate_summary(
    plan: DeletionPlan,
    policy: RetentionPolicy,
    dry_run: bool = False,
) -> str:
    """Return a multi-line human-readable deletion plan summary."""
    lines: list[str] = []
    mode = "DRY RUN" if dry_run else "LIVE"

    lines.append("=== Artifact Cleanup Plan ===")
    lines.append(f"Mode: {mode}")
    lines.append("")

    lines.append("Retention Policies:")
    if policy.max_age_days is not None:
        lines.append(f"  Max Age: {policy.max_age_days} days")
    if policy.max_total_size_bytes is not None:
        lines.append(f"  Max Total Size: {format_size(policy.max_total_size_bytes)}")
    if policy.keep_latest_n is not None:
        lines.append(f"  Keep Latest N: {policy.keep_latest_n} per workflow")
    lines.append("")

    to_delete = plan.to_delete
    to_retain = plan.to_retain

    lines.append(f"Artifacts to DELETE ({len(to_delete)}):")
    for d in sorted(to_delete, key=lambda x: x.artifact.created_at):
        reasons_str = ", ".join(d.reasons)
        lines.append(
            f"  - {d.artifact.name} "
            f"(workflow: {d.artifact.workflow}, "
            f"{format_size(d.artifact.size_bytes)}, "
            f"created: {d.artifact.created_at.strftime('%Y-%m-%d')}) "
            f"[{reasons_str}]"
        )
    lines.append("")

    lines.append(f"Artifacts to RETAIN ({len(to_retain)}):")
    for d in sorted(to_retain, key=lambda x: x.artifact.created_at, reverse=True):
        lines.append(
            f"  - {d.artifact.name} "
            f"(workflow: {d.artifact.workflow}, "
            f"{format_size(d.artifact.size_bytes)}, "
            f"created: {d.artifact.created_at.strftime('%Y-%m-%d')})"
        )
    lines.append("")

    lines.append("=== Summary ===")
    lines.append(f"Total artifacts: {len(plan.decisions)}")
    lines.append(f"Deleted: {len(to_delete)}")
    lines.append(f"Retained: {len(to_retain)}")
    lines.append(f"Space reclaimed: {format_size(plan.space_reclaimed_bytes)}")

    return "\n".join(lines)


# ─── JSON loading ─────────────────────────────────────────────────────────────

def load_artifacts_from_json(path: str) -> list[Artifact]:
    """
    Load artifacts from a JSON file.

    Expected format:
    [
      {
        "name": "build-artifact",
        "size_bytes": 104857600,
        "created_at": "2026-01-01T00:00:00+00:00",
        "workflow_run_id": "run-123",
        "workflow": "build"
      },
      ...
    ]
    """
    try:
        with open(path) as f:
            raw = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: fixtures file not found: {path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {path}: {exc}", file=sys.stderr)
        sys.exit(1)

    artifacts: list[Artifact] = []
    for i, item in enumerate(raw):
        try:
            created_at = datetime.fromisoformat(item["created_at"])
            if created_at.tzinfo is None:
                # Treat naive datetimes as UTC
                created_at = created_at.replace(tzinfo=timezone.utc)
            artifacts.append(
                Artifact(
                    name=item["name"],
                    size_bytes=int(item["size_bytes"]),
                    created_at=created_at,
                    workflow_run_id=str(item["workflow_run_id"]),
                    workflow=item["workflow"],
                )
            )
        except (KeyError, ValueError) as exc:
            print(f"ERROR: artifact[{i}] is malformed: {exc}", file=sys.stderr)
            sys.exit(1)

    return artifacts


# ─── CLI entry point ──────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Apply retention policies to a list of artifacts and generate a deletion plan."
    )
    parser.add_argument(
        "--fixtures", required=True, help="Path to JSON file with artifact list"
    )
    parser.add_argument(
        "--max-age-days", type=int, default=None,
        help="Delete artifacts older than N days"
    )
    parser.add_argument(
        "--max-total-size-mb", type=int, default=None,
        help="Delete oldest artifacts until total size is under N MB"
    )
    parser.add_argument(
        "--keep-latest-n", type=int, default=None,
        help="Keep only the N newest artifacts per workflow"
    )
    parser.add_argument(
        "--reference-date", default=None,
        help="Fixed reference date for age calculations (YYYY-MM-DD). Defaults to today."
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print deletion plan without performing deletions"
    )
    args = parser.parse_args()

    reference_date: Optional[datetime] = None
    if args.reference_date:
        try:
            reference_date = datetime.fromisoformat(args.reference_date).replace(
                tzinfo=timezone.utc
            )
        except ValueError:
            print(
                f"ERROR: invalid --reference-date '{args.reference_date}' "
                "(expected YYYY-MM-DD)",
                file=sys.stderr,
            )
            sys.exit(1)

    policy = RetentionPolicy(
        max_age_days=args.max_age_days,
        max_total_size_bytes=(
            args.max_total_size_mb * 1024 * 1024
            if args.max_total_size_mb is not None
            else None
        ),
        keep_latest_n=args.keep_latest_n,
    )

    artifacts = load_artifacts_from_json(args.fixtures)
    plan = apply_retention_policies(artifacts, policy, reference_date=reference_date)
    summary = generate_summary(plan, policy, dry_run=args.dry_run)
    print(summary)


if __name__ == "__main__":
    main()
