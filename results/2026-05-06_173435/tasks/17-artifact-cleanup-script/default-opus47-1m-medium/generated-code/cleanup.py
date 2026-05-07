"""Artifact retention / cleanup planner.

Reads a JSON list of artifacts, applies retention policies, and prints
which ones would be deleted vs retained. `--dry-run` is informational
only — this script never actually deletes anything (mock data).

Policies applied (any matching policy marks an artifact for deletion):
  * max_age_days: artifacts older than this are deleted.
  * keep_latest_per_workflow: per workflow_run_id, keep the N newest only.
  * max_total_size_bytes: if total > budget, delete oldest until <=.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Sequence


# --- Data model ---------------------------------------------------------

@dataclass(frozen=True)
class Artifact:
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str


@dataclass
class RetentionPolicy:
    """Optional fields default to "no constraint"."""
    max_age_days: int | None = None
    keep_latest_per_workflow: int | None = None
    max_total_size_bytes: int | None = None
    now: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class CleanupPlan:
    to_delete: list[Artifact]
    to_retain: list[Artifact]

    @property
    def bytes_reclaimed(self) -> int:
        return sum(a.size_bytes for a in self.to_delete)

    @property
    def deleted_count(self) -> int:
        return len(self.to_delete)

    @property
    def retained_count(self) -> int:
        return len(self.to_retain)


# --- Core planning ------------------------------------------------------

def plan_cleanup(
    artifacts: Sequence[Artifact], policy: RetentionPolicy
) -> CleanupPlan:
    """Decide which artifacts to delete given the policy.

    Approach: build a set of names to delete by unioning the matches from
    each policy, then partition. Order of policies is irrelevant since
    deletion is a union — that keeps the rules independent and easy to
    reason about.
    """
    delete_names: set[str] = set()

    if policy.max_age_days is not None:
        cutoff = policy.now - timedelta(days=policy.max_age_days)
        for a in artifacts:
            if a.created_at < cutoff:
                delete_names.add(a.name)

    if policy.keep_latest_per_workflow is not None:
        n = policy.keep_latest_per_workflow
        by_run: dict[str, list[Artifact]] = {}
        for a in artifacts:
            by_run.setdefault(a.workflow_run_id, []).append(a)
        for group in by_run.values():
            # newest first
            group.sort(key=lambda a: a.created_at, reverse=True)
            for older in group[n:]:
                delete_names.add(older.name)

    if policy.max_total_size_bytes is not None:
        budget = policy.max_total_size_bytes
        # Consider only currently-retained artifacts; the oldest go first.
        retained = [a for a in artifacts if a.name not in delete_names]
        retained.sort(key=lambda a: a.created_at)  # oldest first
        total = sum(a.size_bytes for a in retained)
        i = 0
        while total > budget and i < len(retained):
            delete_names.add(retained[i].name)
            total -= retained[i].size_bytes
            i += 1

    to_delete = [a for a in artifacts if a.name in delete_names]
    to_retain = [a for a in artifacts if a.name not in delete_names]
    return CleanupPlan(to_delete=to_delete, to_retain=to_retain)


# --- Output -------------------------------------------------------------

def format_summary(plan: CleanupPlan, dry_run: bool) -> str:
    mode = "DRY-RUN" if dry_run else "APPLY"
    lines = [
        f"=== Artifact Cleanup [{mode}] ===",
        f"Deleted: {plan.deleted_count}",
        f"Retained: {plan.retained_count}",
        f"Reclaimed: {plan.bytes_reclaimed} bytes",
        "",
        "To delete:",
    ]
    for a in plan.to_delete:
        lines.append(
            f"  - {a.name} ({a.size_bytes}B, run={a.workflow_run_id},"
            f" created={a.created_at.isoformat()})"
        )
    lines.append("")
    lines.append("To retain:")
    for a in plan.to_retain:
        lines.append(
            f"  + {a.name} ({a.size_bytes}B, run={a.workflow_run_id})"
        )
    return "\n".join(lines)


# --- Loading ------------------------------------------------------------

def load_artifacts(path: Path | str) -> list[Artifact]:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Artifact file not found: {p}")
    try:
        raw = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {p}: {e}") from e
    out: list[Artifact] = []
    for entry in raw:
        out.append(Artifact(
            name=entry["name"],
            size_bytes=int(entry["size_bytes"]),
            created_at=_parse_dt(entry["created_at"]),
            workflow_run_id=str(entry["workflow_run_id"]),
        ))
    return out


def _parse_dt(s: str) -> datetime:
    # Accept trailing 'Z' as UTC.
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return datetime.fromisoformat(s)


# --- CLI ----------------------------------------------------------------

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Plan artifact cleanup.")
    parser.add_argument("--input", required=True, help="Path to JSON fixture")
    parser.add_argument("--max-age-days", type=int, default=None)
    parser.add_argument("--keep-latest-per-workflow", type=int, default=None)
    parser.add_argument("--max-total-size-bytes", type=int, default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--now", default=None,
        help="Override 'now' as ISO-8601 (useful for deterministic CI tests).",
    )
    args = parser.parse_args(argv)

    try:
        artifacts = load_artifacts(args.input)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    now = _parse_dt(args.now) if args.now else datetime.now(timezone.utc)
    policy = RetentionPolicy(
        max_age_days=args.max_age_days,
        keep_latest_per_workflow=args.keep_latest_per_workflow,
        max_total_size_bytes=args.max_total_size_bytes,
        now=now,
    )
    plan = plan_cleanup(artifacts, policy)
    print(format_summary(plan, dry_run=args.dry_run))
    return 0


if __name__ == "__main__":
    sys.exit(main())
