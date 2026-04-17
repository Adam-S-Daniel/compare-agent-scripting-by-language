#!/usr/bin/env python3
"""Artifact retention cleanup tool.

Applies retention policies to a list of artifacts and produces a deletion plan.
Policies (all optional, combined with OR-to-delete semantics):
  - max_age_days: delete artifacts older than N days
  - max_total_size: delete oldest artifacts until total retained size <= N bytes
  - keep_latest_n_per_workflow: per workflow_run_id group, retain only N newest

Input artifact record: {name, size, created_at (ISO8601), workflow_run_id}
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Iterable


@dataclass
class Artifact:
    name: str
    size: int
    created_at: str  # ISO8601
    workflow_run_id: str

    @property
    def created_dt(self) -> datetime:
        dt = datetime.fromisoformat(self.created_at.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt


def parse_artifacts(raw: list[dict]) -> list[Artifact]:
    """Parse raw dicts into Artifact objects, validating required fields."""
    required = {"name", "size", "created_at", "workflow_run_id"}
    out = []
    for i, item in enumerate(raw):
        missing = required - item.keys()
        if missing:
            raise ValueError(f"artifact[{i}] missing fields: {sorted(missing)}")
        if not isinstance(item["size"], int) or item["size"] < 0:
            raise ValueError(f"artifact[{i}] size must be non-negative int")
        out.append(Artifact(
            name=item["name"],
            size=item["size"],
            created_at=item["created_at"],
            workflow_run_id=str(item["workflow_run_id"]),
        ))
    return out


def mark_by_max_age(
    artifacts: Iterable[Artifact], max_age_days: float, now: datetime
) -> set[int]:
    """Return indices of artifacts older than max_age_days."""
    cutoff_seconds = max_age_days * 86400
    return {
        i for i, a in enumerate(artifacts)
        if (now - a.created_dt).total_seconds() > cutoff_seconds
    }


def mark_by_keep_latest_n(
    artifacts: list[Artifact], keep_n: int
) -> set[int]:
    """Per workflow_run_id, keep the N newest; mark the rest for deletion."""
    groups: dict[str, list[int]] = {}
    for i, a in enumerate(artifacts):
        groups.setdefault(a.workflow_run_id, []).append(i)
    to_delete: set[int] = set()
    for idxs in groups.values():
        # Sort by date descending (newest first); drop the first keep_n.
        idxs.sort(key=lambda i: artifacts[i].created_dt, reverse=True)
        to_delete.update(idxs[keep_n:])
    return to_delete


def mark_by_max_total_size(
    artifacts: list[Artifact], max_total_size: int, already_deleted: set[int]
) -> set[int]:
    """Delete oldest first among survivors until total retained size <= limit."""
    survivors = [i for i in range(len(artifacts)) if i not in already_deleted]
    # Sort survivors by age: newest first (we keep newest, delete oldest).
    survivors.sort(key=lambda i: artifacts[i].created_dt, reverse=True)
    to_delete: set[int] = set()
    running = 0
    for i in survivors:
        if running + artifacts[i].size <= max_total_size:
            running += artifacts[i].size
        else:
            to_delete.add(i)
    return to_delete


def build_plan(
    artifacts: list[Artifact],
    *,
    max_age_days: float | None = None,
    keep_latest_n_per_workflow: int | None = None,
    max_total_size: int | None = None,
    now: datetime | None = None,
) -> dict:
    """Apply policies (in order) and return a deletion plan + summary."""
    if now is None:
        now = datetime.now(timezone.utc)
    delete_idx: set[int] = set()
    if max_age_days is not None:
        delete_idx |= mark_by_max_age(artifacts, max_age_days, now)
    if keep_latest_n_per_workflow is not None:
        if keep_latest_n_per_workflow < 0:
            raise ValueError("keep_latest_n_per_workflow must be >= 0")
        delete_idx |= mark_by_keep_latest_n(artifacts, keep_latest_n_per_workflow)
    if max_total_size is not None:
        if max_total_size < 0:
            raise ValueError("max_total_size must be >= 0")
        delete_idx |= mark_by_max_total_size(artifacts, max_total_size, delete_idx)

    deleted = [asdict(artifacts[i]) for i in sorted(delete_idx)]
    retained = [asdict(a) for i, a in enumerate(artifacts) if i not in delete_idx]
    reclaimed = sum(a["size"] for a in deleted)
    return {
        "deleted": deleted,
        "retained": retained,
        "summary": {
            "total_reclaimed_bytes": reclaimed,
            "deleted_count": len(deleted),
            "retained_count": len(retained),
        },
    }


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Artifact retention cleanup planner")
    p.add_argument("--input", required=True, help="Path to artifacts JSON file")
    p.add_argument("--max-age-days", type=float, default=None)
    p.add_argument("--keep-latest-n", type=int, default=None,
                   help="Keep latest N per workflow_run_id")
    p.add_argument("--max-total-size", type=int, default=None,
                   help="Max total retained size in bytes")
    p.add_argument("--now", default=None,
                   help="Override 'now' (ISO8601) for deterministic runs")
    p.add_argument("--dry-run", action="store_true",
                   help="Print plan only; do not emit delete-exit-code")
    p.add_argument("--output", default="-", help="Plan output path ('-' = stdout)")
    args = p.parse_args(argv)

    try:
        with open(args.input) as f:
            raw = json.load(f)
        artifacts = parse_artifacts(raw)
    except (OSError, ValueError, json.JSONDecodeError) as e:
        print(f"ERROR loading {args.input}: {e}", file=sys.stderr)
        return 2

    now = None
    if args.now:
        now = datetime.fromisoformat(args.now.replace("Z", "+00:00"))

    try:
        plan = build_plan(
            artifacts,
            max_age_days=args.max_age_days,
            keep_latest_n_per_workflow=args.keep_latest_n,
            max_total_size=args.max_total_size,
            now=now,
        )
    except ValueError as e:
        print(f"ERROR building plan: {e}", file=sys.stderr)
        return 2

    mode = "DRY-RUN" if args.dry_run else "EXECUTE"
    plan["mode"] = mode

    text = json.dumps(plan, indent=2, sort_keys=True)
    if args.output == "-":
        print(text)
    else:
        with open(args.output, "w") as f:
            f.write(text)

    s = plan["summary"]
    print(
        f"[{mode}] deleted={s['deleted_count']} "
        f"retained={s['retained_count']} "
        f"reclaimed_bytes={s['total_reclaimed_bytes']}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
