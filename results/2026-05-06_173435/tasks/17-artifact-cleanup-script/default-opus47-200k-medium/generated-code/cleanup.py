#!/usr/bin/env python3
"""Artifact cleanup script.

Applies retention policies (max age, max total size, keep-latest-N per workflow)
to a list of artifacts and produces a deletion plan with a summary. Supports
dry-run mode (no plan file written; plan printed to stdout).
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, List, Optional


@dataclass
class Artifact:
    id: str
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str

    def to_dict(self) -> dict:
        d = asdict(self)
        d["created_at"] = self.created_at.astimezone(timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        return d


REQUIRED_FIELDS = ("id", "name", "size_bytes", "created_at", "workflow_run_id")


def _parse_iso(ts: str) -> datetime:
    # Accept trailing 'Z' as UTC.
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    dt = datetime.fromisoformat(ts)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def load_artifacts(path: Path) -> List[Artifact]:
    """Load artifacts from a JSON file. Raises FileNotFoundError or ValueError."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Artifact input file not found: {path}")
    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e
    if not isinstance(raw, list):
        raise ValueError(f"Expected a JSON array in {path}, got {type(raw).__name__}")

    out = []
    for i, item in enumerate(raw):
        for f in REQUIRED_FIELDS:
            if f not in item:
                raise ValueError(f"Artifact at index {i} missing field: {f}")
        out.append(
            Artifact(
                id=str(item["id"]),
                name=str(item["name"]),
                size_bytes=int(item["size_bytes"]),
                created_at=_parse_iso(str(item["created_at"])),
                workflow_run_id=str(item["workflow_run_id"]),
            )
        )
    return out


def apply_max_age_policy(
    artifacts: Iterable[Artifact], max_age_days: int, now: datetime
) -> List[Artifact]:
    """Return artifacts older than `max_age_days` from `now`."""
    cutoff = now - timedelta(days=max_age_days)
    return [a for a in artifacts if a.created_at < cutoff]


def apply_keep_latest_n_policy(
    artifacts: Iterable[Artifact], keep_n: int
) -> List[Artifact]:
    """For each workflow_run_id group, keep the `keep_n` most recent artifacts;
    return the rest as deletion candidates."""
    by_workflow: dict[str, List[Artifact]] = {}
    for a in artifacts:
        by_workflow.setdefault(a.workflow_run_id, []).append(a)
    to_delete: List[Artifact] = []
    for group in by_workflow.values():
        # Newest first; drop first keep_n; rest are eligible for deletion.
        sorted_group = sorted(group, key=lambda a: a.created_at, reverse=True)
        to_delete.extend(sorted_group[keep_n:])
    return to_delete


def apply_max_total_size_policy(
    artifacts: Iterable[Artifact], max_total_bytes: int
) -> List[Artifact]:
    """If total size exceeds budget, evict oldest first until within budget."""
    items = list(artifacts)
    total = sum(a.size_bytes for a in items)
    if total <= max_total_bytes:
        return []
    # Oldest first.
    sorted_items = sorted(items, key=lambda a: a.created_at)
    to_delete: List[Artifact] = []
    for a in sorted_items:
        if total <= max_total_bytes:
            break
        to_delete.append(a)
        total -= a.size_bytes
    return to_delete


def build_deletion_plan(
    artifacts: List[Artifact],
    max_age_days: Optional[int],
    keep_latest_n: Optional[int],
    max_total_bytes: Optional[int],
    now: datetime,
) -> dict:
    """Combine policies. An artifact is deleted if ANY policy marks it.
    Returns a plan dict with `to_delete`, `to_retain`, and `summary`."""
    delete_ids: set[str] = set()

    if max_age_days is not None:
        for a in apply_max_age_policy(artifacts, max_age_days, now):
            delete_ids.add(a.id)

    if keep_latest_n is not None:
        for a in apply_keep_latest_n_policy(artifacts, keep_latest_n):
            delete_ids.add(a.id)

    if max_total_bytes is not None:
        # Apply to artifacts that would otherwise be retained, but evaluate
        # against the full set's total size for budget purposes.
        for a in apply_max_total_size_policy(artifacts, max_total_bytes):
            delete_ids.add(a.id)

    to_delete = [a for a in artifacts if a.id in delete_ids]
    to_retain = [a for a in artifacts if a.id not in delete_ids]
    bytes_reclaimed = sum(a.size_bytes for a in to_delete)

    return {
        "to_delete": to_delete,
        "to_retain": to_retain,
        "summary": {
            "total_count": len(artifacts),
            "deleted_count": len(to_delete),
            "retained_count": len(to_retain),
            "bytes_reclaimed": bytes_reclaimed,
            "bytes_retained": sum(a.size_bytes for a in to_retain),
        },
    }


def _plan_to_jsonable(plan: dict) -> dict:
    return {
        "to_delete": [a.to_dict() for a in plan["to_delete"]],
        "to_retain": [a.to_dict() for a in plan["to_retain"]],
        "summary": plan["summary"],
    }


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Artifact retention cleanup planner")
    parser.add_argument("--input", required=True, help="Path to JSON artifact list")
    parser.add_argument("--max-age-days", type=int, default=None)
    parser.add_argument("--keep-latest-n", type=int, default=None,
                        help="Keep N most recent artifacts per workflow_run_id")
    parser.add_argument("--max-total-bytes", type=int, default=None)
    parser.add_argument("--output", default=None,
                        help="Write plan JSON to this path (ignored in --dry-run)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print plan to stdout; do not write a plan file")
    parser.add_argument("--now", default=None,
                        help="Override 'now' (ISO 8601). Defaults to current UTC time.")
    args = parser.parse_args(argv)

    try:
        artifacts = load_artifacts(Path(args.input))
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    now = _parse_iso(args.now) if args.now else datetime.now(timezone.utc)

    plan = build_deletion_plan(
        artifacts,
        max_age_days=args.max_age_days,
        keep_latest_n=args.keep_latest_n,
        max_total_bytes=args.max_total_bytes,
        now=now,
    )
    jsonable = _plan_to_jsonable(plan)
    summary = plan["summary"]

    if args.dry_run:
        # Print a banner so callers can detect dry-run mode in stdout.
        print("DRY-RUN: no artifacts will be deleted.")
        print(json.dumps(jsonable, indent=2))
    else:
        if args.output:
            Path(args.output).write_text(json.dumps(jsonable, indent=2))
        else:
            print(json.dumps(jsonable, indent=2))

    print(
        f"Summary: total={summary['total_count']} "
        f"deleted={summary['deleted_count']} retained={summary['retained_count']} "
        f"bytes_reclaimed={summary['bytes_reclaimed']}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
