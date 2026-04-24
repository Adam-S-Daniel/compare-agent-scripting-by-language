#!/usr/bin/env python3
"""
Artifact retention / cleanup planner.

Approach:
  - Pure-functional policy layer: each `apply_*` returns the set of artifacts
    that policy would delete. Policies are composed by union in `build_plan`.
  - No real deletion ever happens here — this is a planner. `--dry-run` only
    tags the output so downstream consumers know not to act on it.
  - CLI is a thin shell around `build_plan` so tests can exercise both paths.

Artifact schema:
  { name, size_bytes, created_at (ISO-8601), workflow_run_id, workflow_name }
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


REQUIRED_FIELDS = ("name", "size_bytes", "created_at", "workflow_run_id", "workflow_name")


class ArtifactError(ValueError):
    """Raised on malformed artifact input."""


def load_artifacts(path: Path) -> list[dict]:
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise ArtifactError(f"Could not load artifacts from {path}: {exc}") from exc
    if not isinstance(data, list):
        raise ArtifactError("Artifact file must contain a JSON array")
    return data


def parse_created_at(value: str) -> datetime:
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Invalid ISO-8601 timestamp: {value!r}") from exc
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _validate(arts: list[dict]) -> None:
    for i, a in enumerate(arts):
        missing = [f for f in REQUIRED_FIELDS if f not in a]
        if missing:
            raise ArtifactError(f"Artifact #{i} missing fields: {missing}")


def apply_max_age(arts: list[dict], max_age_days: int, now: datetime) -> list[dict]:
    """Flag artifacts older than max_age_days for deletion."""
    cutoff = now.timestamp() - max_age_days * 86400
    return [a for a in arts if parse_created_at(a["created_at"]).timestamp() < cutoff]


def apply_keep_latest_n(arts: list[dict], n: int) -> list[dict]:
    """Within each workflow_name group, flag everything except the newest N."""
    by_wf: dict[str, list[dict]] = {}
    for a in arts:
        by_wf.setdefault(a["workflow_name"], []).append(a)
    flagged: list[dict] = []
    for group in by_wf.values():
        # newest first
        ordered = sorted(group, key=lambda a: parse_created_at(a["created_at"]), reverse=True)
        flagged.extend(ordered[n:])
    return flagged


def apply_max_total_size(arts: list[dict], max_total_bytes: int) -> list[dict]:
    """
    Greedy: while total exceeds budget, evict the largest-then-oldest artifact.
    Returns the eviction set.
    """
    total = sum(a["size_bytes"] for a in arts)
    if total <= max_total_bytes:
        return []
    # sort by size desc, then oldest first (tiebreak)
    ordered = sorted(
        arts,
        key=lambda a: (-a["size_bytes"], parse_created_at(a["created_at"]).timestamp()),
    )
    flagged: list[dict] = []
    for a in ordered:
        if total <= max_total_bytes:
            break
        flagged.append(a)
        total -= a["size_bytes"]
    return flagged


def build_plan(
    artifacts: list[dict],
    *,
    max_age_days: int | None = None,
    max_total_bytes: int | None = None,
    keep_latest_n: int | None = None,
    now: datetime | None = None,
    dry_run: bool = False,
) -> dict:
    """Compose policies and produce a deletion plan with summary."""
    _validate(artifacts)
    now = now or datetime.now(timezone.utc)

    flagged_ids: set[int] = set()

    def _mark(flagged: list[dict]) -> None:
        for a in flagged:
            flagged_ids.add(id(a))

    # Order matters only for size policy — apply age/keep-N first, then size on
    # the survivors so we don't double-count space already being reclaimed.
    if max_age_days is not None:
        _mark(apply_max_age(artifacts, max_age_days, now))
    if keep_latest_n is not None:
        _mark(apply_keep_latest_n(artifacts, keep_latest_n))
    if max_total_bytes is not None:
        survivors = [a for a in artifacts if id(a) not in flagged_ids]
        _mark(apply_max_total_size(survivors, max_total_bytes))

    delete = [a for a in artifacts if id(a) in flagged_ids]
    keep = [a for a in artifacts if id(a) not in flagged_ids]

    total_before = sum(a["size_bytes"] for a in artifacts)
    reclaimed = sum(a["size_bytes"] for a in delete)

    return {
        "delete": delete,
        "keep": keep,
        "summary": {
            "retained_count": len(keep),
            "deleted_count": len(delete),
            "space_reclaimed_bytes": reclaimed,
            "total_size_before_bytes": total_before,
            "total_size_after_bytes": total_before - reclaimed,
            "dry_run": dry_run,
        },
    }


def _parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Plan artifact cleanup under retention policies.")
    p.add_argument("--input", required=True, type=Path)
    p.add_argument("--output", type=Path, help="Write plan JSON here (else stdout).")
    p.add_argument("--max-age-days", type=int)
    p.add_argument("--max-total-bytes", type=int)
    p.add_argument("--keep-latest-n", type=int)
    p.add_argument("--now", help="ISO-8601 timestamp to use as 'now' (for determinism).")
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    try:
        arts = load_artifacts(args.input)
        now = parse_created_at(args.now) if args.now else datetime.now(timezone.utc)
        plan = build_plan(
            arts,
            max_age_days=args.max_age_days,
            max_total_bytes=args.max_total_bytes,
            keep_latest_n=args.keep_latest_n,
            now=now,
            dry_run=args.dry_run,
        )
    except ArtifactError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    payload = json.dumps(plan, indent=2)
    if args.output:
        args.output.write_text(payload)
    else:
        print(payload)

    s = plan["summary"]
    mode = "DRY-RUN" if args.dry_run else "EXECUTE"
    print(
        f"[{mode}] deleted={s['deleted_count']} retained={s['retained_count']} "
        f"reclaimed_bytes={s['space_reclaimed_bytes']} "
        f"before={s['total_size_before_bytes']} after={s['total_size_after_bytes']}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
