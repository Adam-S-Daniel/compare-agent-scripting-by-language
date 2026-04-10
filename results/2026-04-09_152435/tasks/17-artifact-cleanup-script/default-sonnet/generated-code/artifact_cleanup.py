#!/usr/bin/env python3
# artifact_cleanup.py
#
# Applies retention policies to a list of build artifacts and generates a
# deletion plan. Supports dry-run mode (no real deletions performed).
#
# TDD cycle:
#   RED   → tests in test_artifact_cleanup.py written first
#   GREEN → minimum implementation written here to pass all tests
#   REFACTOR → types, helpers, and CLI polished after tests go green

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import List, Optional, Set


# ── Domain types ─────────────────────────────────────────────────────────────

@dataclass
class Artifact:
    """Represents a single CI/CD artifact with its metadata."""
    name: str
    size_bytes: int
    created_at: date
    workflow_run_id: str


@dataclass
class RetentionPolicy:
    """
    Configures which artifacts to keep.

    max_age_days:         delete artifacts older than this many days.
    max_total_size_bytes: delete oldest artifacts until total size fits.
    keep_latest_n:        per workflow_run_id, keep only the N most recent.
    """
    max_age_days: Optional[int] = None
    max_total_size_bytes: Optional[int] = None
    keep_latest_n: Optional[int] = None


@dataclass
class DeletionPlan:
    """Result of applying retention policies to an artifact list."""
    to_delete: List[Artifact] = field(default_factory=list)
    to_retain: List[Artifact] = field(default_factory=list)

    @property
    def space_reclaimed_bytes(self) -> int:
        return sum(a.size_bytes for a in self.to_delete)


# ── Loader ────────────────────────────────────────────────────────────────────

def load_artifacts_from_dict(raw: List[dict]) -> List[Artifact]:
    """Parse a list of dicts (e.g. from JSON) into Artifact objects."""
    artifacts = []
    for item in raw:
        try:
            artifacts.append(Artifact(
                name=item["name"],
                size_bytes=int(item["size_bytes"]),
                created_at=date.fromisoformat(item["created_at"]),
                workflow_run_id=item["workflow_run_id"],
            ))
        except (KeyError, ValueError) as e:
            print(f"ERROR: invalid artifact record {item!r}: {e}", file=sys.stderr)
            sys.exit(1)
    return artifacts


# ── Policy engine ─────────────────────────────────────────────────────────────

def apply_policies(
    artifacts: List[Artifact],
    policy: RetentionPolicy,
    today: Optional[date] = None,
) -> DeletionPlan:
    """
    Evaluate every policy in order and collect the names of artifacts to delete.

    Policy evaluation order:
      1. max_age_days      — age-based expiry
      2. keep_latest_n     — per-workflow recency cap
      3. max_total_size    — global size cap (delete oldest first)
    """
    if today is None:
        today = date.today()

    to_delete_names: Set[str] = set()

    # ── Policy 1: max age ────────────────────────────────────────────────────
    if policy.max_age_days is not None:
        for artifact in artifacts:
            age_days = (today - artifact.created_at).days
            if age_days > policy.max_age_days:
                to_delete_names.add(artifact.name)

    # ── Policy 2: keep latest N per workflow ─────────────────────────────────
    if policy.keep_latest_n is not None:
        # Group artifacts by their workflow run ID
        by_workflow: dict[str, List[Artifact]] = {}
        for artifact in artifacts:
            by_workflow.setdefault(artifact.workflow_run_id, []).append(artifact)

        for wf_artifacts in by_workflow.values():
            # Sort newest-first; tail beyond keep_latest_n should be deleted
            sorted_desc = sorted(wf_artifacts, key=lambda a: a.created_at, reverse=True)
            for artifact in sorted_desc[policy.keep_latest_n:]:
                to_delete_names.add(artifact.name)

    # ── Policy 3: max total size (oldest first) ───────────────────────────────
    if policy.max_total_size_bytes is not None:
        # Only consider artifacts NOT already marked for deletion
        survivors = [a for a in artifacts if a.name not in to_delete_names]
        total = sum(a.size_bytes for a in survivors)
        if total > policy.max_total_size_bytes:
            # Delete the oldest survivors until we fit under the limit
            oldest_first = sorted(survivors, key=lambda a: a.created_at)
            for artifact in oldest_first:
                if total <= policy.max_total_size_bytes:
                    break
                to_delete_names.add(artifact.name)
                total -= artifact.size_bytes

    to_delete = [a for a in artifacts if a.name in to_delete_names]
    to_retain = [a for a in artifacts if a.name not in to_delete_names]

    return DeletionPlan(to_delete=to_delete, to_retain=to_retain)


# ── Formatting ────────────────────────────────────────────────────────────────

def format_size(size_bytes: int) -> str:
    """Human-readable byte count."""
    if size_bytes >= 1024 ** 3:
        return f"{size_bytes / 1024 ** 3:.1f} GB"
    if size_bytes >= 1024 ** 2:
        return f"{size_bytes / 1024 ** 2:.1f} MB"
    if size_bytes >= 1024:
        return f"{size_bytes / 1024:.1f} KB"
    return f"{size_bytes} B"


def generate_report(
    plan: DeletionPlan,
    policy: RetentionPolicy,
    dry_run: bool = True,
) -> str:
    """Render a human-readable cleanup report."""
    lines = ["=== Artifact Cleanup Report ==="]
    lines.append(f"Mode: {'DRY RUN' if dry_run else 'EXECUTE'}")

    # Summarise active policies
    policy_parts: List[str] = []
    if policy.max_age_days is not None:
        policy_parts.append(f"max_age={policy.max_age_days}d")
    if policy.max_total_size_bytes is not None:
        policy_parts.append(f"max_total_size={format_size(policy.max_total_size_bytes)}")
    if policy.keep_latest_n is not None:
        policy_parts.append(f"keep_latest_n={policy.keep_latest_n}")
    lines.append(f"Policies: {', '.join(policy_parts) if policy_parts else 'none'}")
    lines.append("")

    lines.append(f"Artifacts to DELETE ({len(plan.to_delete)}):")
    for a in plan.to_delete:
        lines.append(f"  - {a.name} ({format_size(a.size_bytes)}, {a.created_at}, {a.workflow_run_id})")

    lines.append("")
    lines.append(f"Artifacts to RETAIN ({len(plan.to_retain)}):")
    for a in plan.to_retain:
        lines.append(f"  - {a.name} ({format_size(a.size_bytes)}, {a.created_at}, {a.workflow_run_id})")

    lines.append("")
    lines.append("Summary:")
    lines.append(f"  Total artifacts: {len(plan.to_delete) + len(plan.to_retain)}")
    lines.append(f"  Deleted: {len(plan.to_delete)}")
    lines.append(f"  Retained: {len(plan.to_retain)}")
    lines.append(f"  Space reclaimed: {format_size(plan.space_reclaimed_bytes)}")

    return "\n".join(lines)


# ── CLI entry point ───────────────────────────────────────────────────────────

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Apply retention policies to CI/CD artifacts and generate a deletion plan.",
    )
    parser.add_argument(
        "--input", "-i",
        required=True,
        metavar="FILE",
        help="JSON file containing artifacts and policy (use '-' for stdin).",
    )
    parser.add_argument(
        "--today",
        metavar="YYYY-MM-DD",
        help="Override today's date (useful for deterministic CI runs).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Print what would be deleted without deleting (default: true).",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually perform deletions (not yet implemented for remote APIs).",
    )
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    # ── Load input ───────────────────────────────────────────────────────────
    try:
        if args.input == "-":
            raw = json.load(sys.stdin)
        else:
            with open(args.input) as fh:
                raw = json.load(fh)
    except FileNotFoundError:
        print(f"ERROR: input file not found: {args.input}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON in {args.input}: {e}", file=sys.stderr)
        return 1

    # ── Parse today override ─────────────────────────────────────────────────
    today: Optional[date] = None
    if args.today:
        try:
            today = date.fromisoformat(args.today)
        except ValueError:
            print(f"ERROR: --today must be YYYY-MM-DD, got {args.today!r}", file=sys.stderr)
            return 1

    # ── Build policy from JSON ────────────────────────────────────────────────
    policy_raw = raw.get("policy", {})
    policy = RetentionPolicy(
        max_age_days=policy_raw.get("max_age_days"),
        max_total_size_bytes=policy_raw.get("max_total_size_bytes"),
        keep_latest_n=policy_raw.get("keep_latest_n"),
    )

    # ── Load artifacts ────────────────────────────────────────────────────────
    artifacts = load_artifacts_from_dict(raw.get("artifacts", []))

    # ── Apply policies ────────────────────────────────────────────────────────
    plan = apply_policies(artifacts, policy, today=today)

    # ── Report ────────────────────────────────────────────────────────────────
    dry_run = not args.execute
    report = generate_report(plan, policy, dry_run=dry_run)
    print(report)

    if args.execute:
        # Placeholder: in a real implementation this would call the GitHub
        # Artifacts API or cloud storage SDK to delete each artifact.
        print("\n[execute mode] Deletion not yet wired to a real API.", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
