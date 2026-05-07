"""Artifact retention engine.

Pure logic for deciding which CI/CD artifacts to delete given a list of
retention policies. Designed to be testable in isolation: no network calls,
no real filesystem mutations -- just data in, plan out.

Policies (any subset can be combined):

  * max_age_days: anything older than this is eligible for deletion.
  * max_total_size_bytes: if retained set exceeds the budget, evict
    oldest-first until we are under it.
  * keep_latest_n_per_workflow: per workflow_run_id, the most recent N
    artifacts are *always* retained, overriding the other two policies.

The CLI ``main()`` reads JSON fixtures and prints a human-readable plan.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Iterable, List, Optional, TextIO


# ---------------------------------------------------------------------------
# Domain types
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Artifact:
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: str

    def __post_init__(self) -> None:
        # Force tz-aware comparisons so naive vs aware mixups blow up loudly
        # instead of silently producing wrong "ages".
        if self.created_at.tzinfo is None:
            raise ValueError(
                f"Artifact {self.name!r} created_at must be timezone-aware"
            )


@dataclass
class Policy:
    max_age_days: Optional[int] = None
    max_total_size_bytes: Optional[int] = None
    keep_latest_n_per_workflow: Optional[int] = None


@dataclass
class CleanupPlan:
    deleted: List[Artifact] = field(default_factory=list)
    retained: List[Artifact] = field(default_factory=list)

    @property
    def reclaimed_bytes(self) -> int:
        return sum(a.size_bytes for a in self.deleted)

    @property
    def retained_bytes(self) -> int:
        return sum(a.size_bytes for a in self.retained)


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------


def _protected_ids(
    artifacts: Iterable[Artifact], keep_n: Optional[int]
) -> set[int]:
    """Return id()s of artifacts that the keep-latest-N policy protects."""
    if keep_n is None or keep_n <= 0:
        return set()
    by_wf: dict[str, list[Artifact]] = {}
    for a in artifacts:
        by_wf.setdefault(a.workflow_run_id, []).append(a)
    protected: set[int] = set()
    for items in by_wf.values():
        # Newest first; the first N are kept.
        items.sort(key=lambda a: a.created_at, reverse=True)
        for a in items[:keep_n]:
            protected.add(id(a))
    return protected


def apply_policies(
    artifacts: Iterable[Artifact],
    policy: Policy,
    *,
    now: datetime,
) -> CleanupPlan:
    """Compute a CleanupPlan from artifacts + policy.

    Order of evaluation:
      1. Identify "protected" artifacts (keep-latest-N per workflow). These
         are immune to deletion regardless of other policies.
      2. Apply max_age_days: anything older than the cutoff that is not
         protected is moved to ``deleted``.
      3. Apply max_total_size_bytes: while the retained set is over budget,
         evict the oldest non-protected artifact until we are within budget.
    """
    items = list(artifacts)
    protected = _protected_ids(items, policy.keep_latest_n_per_workflow)

    deleted: List[Artifact] = []
    retained: List[Artifact] = []

    # Step 2: combine keep-latest-N (delete the un-protected) with max_age.
    # An artifact is deleted in this step if it is not protected AND either:
    #   - keep_latest_n_per_workflow is set (so non-protected = excess), or
    #   - max_age_days is set and the artifact is older than the cutoff.
    for a in items:
        is_protected = id(a) in protected
        excess_for_workflow = (
            policy.keep_latest_n_per_workflow is not None and not is_protected
        )
        too_old = (
            policy.max_age_days is not None
            and (now - a.created_at).days > policy.max_age_days
        )
        if (excess_for_workflow or too_old) and not is_protected:
            deleted.append(a)
        else:
            retained.append(a)

    # Step 3: max total size. Evict oldest first from the *retained* set,
    # skipping protected items. Stop when we're within budget or only
    # protected items remain.
    if policy.max_total_size_bytes is not None:
        total = sum(a.size_bytes for a in retained)
        # Sort oldest-first so eviction order is deterministic.
        eviction_order = sorted(retained, key=lambda a: a.created_at)
        for a in eviction_order:
            if total <= policy.max_total_size_bytes:
                break
            if id(a) in protected:
                continue
            retained.remove(a)
            deleted.append(a)
            total -= a.size_bytes

    return CleanupPlan(deleted=deleted, retained=retained)


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------


def _fmt_mb(b: int) -> str:
    return f"{b / (1024 * 1024):.2f} MB"


def format_plan(plan: CleanupPlan, *, dry_run: bool) -> str:
    """Render a CleanupPlan as a human-readable, deterministic report."""
    mode = "dry-run" if dry_run else "execute"
    total_seen = len(plan.deleted) + len(plan.retained)
    lines = [
        "=== Artifact Cleanup Plan ===",
        f"Mode: {mode}",
        f"Total artifacts seen: {total_seen}",
        f"Artifacts retained: {len(plan.retained)}",
        f"Artifacts deleted: {len(plan.deleted)}",
        f"Space reclaimed: {_fmt_mb(plan.reclaimed_bytes)}",
        f"Space retained: {_fmt_mb(plan.retained_bytes)}",
        "",
        "-- To delete --",
    ]
    # Sort by name so the output is stable regardless of evaluation order.
    for a in sorted(plan.deleted, key=lambda x: x.name):
        lines.append(
            f"  DELETE {a.name} "
            f"(size={_fmt_mb(a.size_bytes)}, workflow={a.workflow_run_id})"
        )
    lines.append("")
    lines.append("-- To retain --")
    for a in sorted(plan.retained, key=lambda x: x.name):
        lines.append(
            f"  KEEP   {a.name} "
            f"(size={_fmt_mb(a.size_bytes)}, workflow={a.workflow_run_id})"
        )
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------


_REQUIRED_ARTIFACT_FIELDS = ("name", "size_bytes", "created_at", "workflow_run_id")


def load_artifacts(raw: list) -> List[Artifact]:
    """Parse a list of dicts (e.g. parsed JSON) into Artifact objects."""
    out: List[Artifact] = []
    for i, item in enumerate(raw):
        missing = [f for f in _REQUIRED_ARTIFACT_FIELDS if f not in item]
        if missing:
            raise ValueError(
                f"artifact #{i} is missing required field(s): "
                + ", ".join(missing)
            )
        created_str = item["created_at"]
        # Accept "...Z" as UTC (Python <3.11 datetime.fromisoformat doesn't).
        if created_str.endswith("Z"):
            created_str = created_str[:-1] + "+00:00"
        try:
            created = datetime.fromisoformat(created_str)
        except ValueError as e:
            raise ValueError(
                f"artifact #{i} has invalid created_at {item['created_at']!r}: {e}"
            ) from e
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        out.append(
            Artifact(
                name=str(item["name"]),
                size_bytes=int(item["size_bytes"]),
                created_at=created,
                workflow_run_id=str(item["workflow_run_id"]),
            )
        )
    return out


def load_policy(raw: dict) -> Policy:
    """Parse a dict into a Policy. Unknown keys are ignored deliberately so
    fixtures can carry comments/metadata without breaking."""
    return Policy(
        max_age_days=raw.get("max_age_days"),
        max_total_size_bytes=raw.get("max_total_size_bytes"),
        keep_latest_n_per_workflow=raw.get("keep_latest_n_per_workflow"),
    )


# ---------------------------------------------------------------------------
# CLI entrypoint
# ---------------------------------------------------------------------------


def _parse_now(value: Optional[str]) -> datetime:
    if value is None:
        return datetime.now(timezone.utc)
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def main(
    argv: Optional[list[str]] = None,
    *,
    stdout: Optional[TextIO] = None,
    stderr: Optional[TextIO] = None,
) -> int:
    out = stdout if stdout is not None else sys.stdout
    err = stderr if stderr is not None else sys.stderr

    p = argparse.ArgumentParser(description="Plan CI artifact cleanup.")
    p.add_argument("--artifacts", required=True, help="path to artifacts JSON")
    p.add_argument("--policy", required=True, help="path to policy JSON")
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="report only; do not pretend to actually delete",
    )
    p.add_argument(
        "--now",
        default=None,
        help="override 'now' (ISO 8601, UTC). Useful for deterministic tests.",
    )
    args = p.parse_args(argv)

    try:
        with open(args.artifacts) as f:
            raw_arts = json.load(f)
        with open(args.policy) as f:
            raw_pol = json.load(f)
        artifacts = load_artifacts(raw_arts)
        policy = load_policy(raw_pol)
        now = _parse_now(args.now)
    except FileNotFoundError as e:
        print(f"Error: input file not found: {e.filename}", file=err)
        return 2
    except (ValueError, json.JSONDecodeError) as e:
        print(f"Error: failed to parse inputs: {e}", file=err)
        return 2

    plan = apply_policies(artifacts, policy, now=now)
    out.write(format_plan(plan, dry_run=args.dry_run))
    return 0


if __name__ == "__main__":
    sys.exit(main())
