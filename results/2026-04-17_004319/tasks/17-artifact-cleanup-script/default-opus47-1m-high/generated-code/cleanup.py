#!/usr/bin/env python3
"""
Artifact cleanup planner.

Applies retention policies (max age, keep-latest-N per workflow, max total
size) to a list of artifacts and produces a deletion plan. Supports a dry-run
mode that prints the plan without committing any "delete" semantics.

Since there is no real artifact store here, "delete" is modeled as selecting
artifacts for deletion and emitting a plan JSON document. A real integration
would consume this plan to call a registry API.
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


# --- Data model ---

@dataclass(frozen=True)
class Artifact:
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str
    workflow_name: str = "default"


@dataclass(frozen=True)
class RetentionPolicy:
    max_age_days: int | None = None
    max_total_size_bytes: int | None = None
    keep_latest_n_per_workflow: int | None = None


@dataclass
class DeletionPlan:
    deleted: list[Artifact] = field(default_factory=list)
    retained: list[Artifact] = field(default_factory=list)
    reasons: dict[str, list[str]] = field(default_factory=dict)

    @property
    def reclaimed_bytes(self) -> int:
        return sum(a.size_bytes for a in self.deleted)

    @property
    def retained_bytes(self) -> int:
        return sum(a.size_bytes for a in self.retained)


# --- Policy application ---

def _parse_iso(s: str) -> datetime:
    # Accept trailing Z as UTC (json's typical form).
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def build_plan(
    artifacts: Iterable[Artifact],
    policy: RetentionPolicy,
    *,
    now: datetime,
) -> DeletionPlan:
    """
    Apply retention policies and return a DeletionPlan.

    Order of reasoning:
      1. Age policy marks artifacts older than max_age_days.
      2. Keep-latest-N-per-workflow marks all but the N most recent per workflow_name.
      3. Max-total-size marks oldest surviving artifacts until total <= limit.
    The final deleted set is the union of all marks; the retained set is the rest.
    """
    artifacts = list(artifacts)
    marked: dict[str, set[str]] = {}  # artifact-key -> set of reason strings
    key = lambda a: f"{a.workflow_run_id}::{a.name}"  # noqa: E731

    def mark(a: Artifact, reason: str) -> None:
        marked.setdefault(key(a), set()).add(reason)

    # 1. Age
    if policy.max_age_days is not None:
        cutoff = now - _days(policy.max_age_days)
        for a in artifacts:
            if a.created_at < cutoff:
                mark(a, f"age>{policy.max_age_days}d")

    # 2. Keep-latest-N per workflow_name
    if policy.keep_latest_n_per_workflow is not None:
        n = policy.keep_latest_n_per_workflow
        by_workflow: dict[str, list[Artifact]] = {}
        for a in artifacts:
            by_workflow.setdefault(a.workflow_name, []).append(a)
        for wf, items in by_workflow.items():
            items.sort(key=lambda a: a.created_at, reverse=True)
            for surplus in items[n:]:
                mark(surplus, f"beyond latest-{n} of workflow '{wf}'")

    # 3. Max total size: apply to anything not already marked, oldest first.
    if policy.max_total_size_bytes is not None:
        limit = policy.max_total_size_bytes
        surviving = [a for a in artifacts if key(a) not in marked]
        surviving.sort(key=lambda a: a.created_at)  # oldest first
        total = sum(a.size_bytes for a in surviving)
        i = 0
        while total > limit and i < len(surviving):
            a = surviving[i]
            mark(a, f"total size > {limit}B")
            total -= a.size_bytes
            i += 1

    deleted = [a for a in artifacts if key(a) in marked]
    retained = [a for a in artifacts if key(a) not in marked]
    reasons = {key(a): sorted(marked[key(a)]) for a in deleted}
    return DeletionPlan(deleted=deleted, retained=retained, reasons=reasons)


def _days(n: int) -> "timedelta":
    from datetime import timedelta
    return timedelta(days=n)


# --- Formatting ---

def format_summary(plan: DeletionPlan, *, dry_run: bool) -> str:
    banner = "DRY RUN (no artifacts will be deleted)\n" if dry_run else ""
    lines = [
        banner + "Artifact cleanup plan",
        "=" * 40,
        f"Deleted: {len(plan.deleted)}",
        f"Retained: {len(plan.retained)}",
        f"Reclaimed bytes: {plan.reclaimed_bytes}",
        f"Retained bytes: {plan.retained_bytes}",
    ]
    if plan.deleted:
        lines.append("")
        lines.append("Deletions:")
        for a in plan.deleted:
            rs = ", ".join(plan.reasons.get(f"{a.workflow_run_id}::{a.name}", []))
            lines.append(f"  - {a.workflow_name}/{a.name} ({a.size_bytes}B) [{rs}]")
    return "\n".join(lines)


def plan_to_dict(plan: DeletionPlan, *, dry_run: bool) -> dict:
    def serialize(a: Artifact) -> dict:
        d = dataclasses.asdict(a)
        d["created_at"] = a.created_at.isoformat()
        return d

    return {
        "dry_run": dry_run,
        "summary": {
            "deleted_count": len(plan.deleted),
            "retained_count": len(plan.retained),
            "reclaimed_bytes": plan.reclaimed_bytes,
            "retained_bytes": plan.retained_bytes,
        },
        "deleted": [serialize(a) for a in plan.deleted],
        "retained": [serialize(a) for a in plan.retained],
        "reasons": plan.reasons,
    }


# --- Loading ---

REQUIRED_ARTIFACT_FIELDS = ("name", "size_bytes", "created_at", "workflow_run_id")


def load_artifacts(path: Path) -> list[Artifact]:
    if not path.exists():
        raise FileNotFoundError(f"Artifacts file not found: {path}")
    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Artifacts file is not valid JSON: {e}") from e
    if not isinstance(raw, list):
        raise ValueError("Artifacts file must be a JSON array of objects")
    out: list[Artifact] = []
    for i, item in enumerate(raw):
        if not isinstance(item, dict):
            raise ValueError(f"Artifact at index {i} is not an object")
        for f_ in REQUIRED_ARTIFACT_FIELDS:
            if f_ not in item:
                raise ValueError(f"Artifact at index {i} missing required field '{f_}'")
        try:
            out.append(
                Artifact(
                    name=str(item["name"]),
                    size_bytes=int(item["size_bytes"]),
                    created_at=_parse_iso(str(item["created_at"])),
                    workflow_run_id=str(item["workflow_run_id"]),
                    workflow_name=str(item.get("workflow_name", "default")),
                )
            )
        except (TypeError, ValueError) as e:
            raise ValueError(f"Artifact at index {i} has invalid field: {e}") from e
    return out


def load_policy(path: Path) -> RetentionPolicy:
    if not path.exists():
        raise FileNotFoundError(f"Policy file not found: {path}")
    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Policy file is not valid JSON: {e}") from e
    if not isinstance(raw, dict):
        raise ValueError("Policy file must be a JSON object")
    return RetentionPolicy(
        max_age_days=raw.get("max_age_days"),
        max_total_size_bytes=raw.get("max_total_size_bytes"),
        keep_latest_n_per_workflow=raw.get("keep_latest_n_per_workflow"),
    )


# --- CLI ---

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Plan artifact cleanup from a retention policy.")
    parser.add_argument("--artifacts", required=True, type=Path, help="Path to artifacts JSON file.")
    parser.add_argument("--policy", required=True, type=Path, help="Path to retention policy JSON file.")
    parser.add_argument("--output", type=Path, help="Write plan JSON to this path.")
    parser.add_argument("--now", default=None, help="ISO-8601 override for current time (for reproducible output).")
    parser.add_argument("--dry-run", action="store_true", help="Only print the plan; don't commit.")
    args = parser.parse_args(argv)

    try:
        artifacts = load_artifacts(args.artifacts)
        policy = load_policy(args.policy)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2

    now = _parse_iso(args.now) if args.now else datetime.now(timezone.utc)
    plan = build_plan(artifacts, policy, now=now)

    print(format_summary(plan, dry_run=args.dry_run))

    if args.output:
        args.output.write_text(json.dumps(plan_to_dict(plan, dry_run=args.dry_run), indent=2))
        print(f"\nPlan written to {args.output}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
