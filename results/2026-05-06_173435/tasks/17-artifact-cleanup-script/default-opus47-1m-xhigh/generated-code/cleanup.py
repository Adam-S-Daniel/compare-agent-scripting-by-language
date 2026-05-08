"""Artifact retention/cleanup planner.

Given a JSON list of CI artifact metadata, apply three retention policies and
emit a deletion plan with a summary. The script never actually deletes
anything; it produces a structured plan that a downstream executor would act
on.

Policies (any combination):

  * --max-age-days N           Delete artifacts older than N days.
  * --max-total-size BYTES     Cap total retained size at BYTES, evicting
                               oldest artifacts first.
  * --keep-latest N            Keep only the N newest artifacts per name
                               (treating ``name`` as the workflow identifier).

When multiple policies match the same artifact, the *first* matching policy
in the order above is recorded as the deletion reason. This is deterministic
and easier to debug than reporting all reasons.

Input JSON shape (a list of objects):

    [
      {
        "id": "<string>",
        "name": "<workflow/artifact name>",
        "size_bytes": <int>,
        "created_at": "<ISO-8601 timestamp, Z or offset>",
        "workflow_run_id": <int>
      },
      ...
    ]

CLI:

    python3 cleanup.py --input artifacts.json \
        [--max-age-days N] [--max-total-size BYTES] [--keep-latest N] \
        [--dry-run] [--output plan.json] [--now ISO8601]

The ``--now`` flag exists purely so CI tests are deterministic: it lets a
fixture pin "today" so age math doesn't depend on the wall clock.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


class CleanupError(Exception):
    """Raised for any expected, user-visible failure (bad input, etc.)."""


@dataclass(frozen=True)
class Artifact:
    id: str
    name: str
    size_bytes: int
    created_at: datetime
    workflow_run_id: int

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "size_bytes": self.size_bytes,
            "created_at": self.created_at.isoformat(),
            "workflow_run_id": self.workflow_run_id,
        }


@dataclass(frozen=True)
class Deletion:
    id: str
    name: str
    size_bytes: int
    reason: str

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "size_bytes": self.size_bytes,
            "reason": self.reason,
        }


@dataclass
class CleanupConfig:
    max_age_days: int | None = None
    max_total_size_bytes: int | None = None
    keep_latest_n_per_workflow: int | None = None
    dry_run: bool = False


@dataclass
class CleanupPlan:
    deletions: list[Deletion] = field(default_factory=list)
    retained: list[Artifact] = field(default_factory=list)
    summary: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "summary": self.summary,
            "deletions": [d.to_dict() for d in self.deletions],
            "retained": [a.to_dict() for a in self.retained],
        }


# ---------------------------------------------------------------------------
# Input loading
# ---------------------------------------------------------------------------
_REQUIRED_FIELDS = ("id", "name", "size_bytes", "created_at", "workflow_run_id")


def _parse_iso(ts: str) -> datetime:
    # Accept trailing "Z" (UTC) which fromisoformat doesn't on 3.10. 3.11+ does.
    s = ts.replace("Z", "+00:00") if ts.endswith("Z") else ts
    try:
        dt = datetime.fromisoformat(s)
    except ValueError as exc:
        raise CleanupError(f"invalid created_at timestamp {ts!r}: {exc}") from exc
    if dt.tzinfo is None:
        # Treat naive timestamps as UTC for sanity.
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def load_artifacts(path: Path) -> list[Artifact]:
    """Load and validate a JSON file describing artifacts."""
    try:
        raw = json.loads(Path(path).read_text())
    except FileNotFoundError as exc:
        raise CleanupError(f"input file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CleanupError(f"input file is not valid JSON: {exc}") from exc

    if not isinstance(raw, list):
        raise CleanupError(
            f"expected a JSON list of artifact objects, got {type(raw).__name__}"
        )

    artifacts: list[Artifact] = []
    for i, entry in enumerate(raw):
        if not isinstance(entry, dict):
            raise CleanupError(f"artifact #{i} is not a JSON object")
        missing = [k for k in _REQUIRED_FIELDS if k not in entry]
        if missing:
            raise CleanupError(
                f"artifact #{i} (id={entry.get('id')!r}) missing required fields: "
                f"{', '.join(missing)}"
            )
        try:
            artifacts.append(
                Artifact(
                    id=str(entry["id"]),
                    name=str(entry["name"]),
                    size_bytes=int(entry["size_bytes"]),
                    created_at=_parse_iso(str(entry["created_at"])),
                    workflow_run_id=int(entry["workflow_run_id"]),
                )
            )
        except (TypeError, ValueError) as exc:
            raise CleanupError(
                f"artifact #{i} (id={entry.get('id')!r}) has invalid field type: {exc}"
            ) from exc
    return artifacts


# ---------------------------------------------------------------------------
# Policy engine
# ---------------------------------------------------------------------------
def _apply_max_age(
    artifacts: Iterable[Artifact], cfg: CleanupConfig, now: datetime
) -> dict[str, str]:
    """Return {artifact_id: reason} for artifacts older than max_age_days."""
    if cfg.max_age_days is None:
        return {}
    cutoff = now - __import__("datetime").timedelta(days=cfg.max_age_days)
    return {a.id: "max_age_days" for a in artifacts if a.created_at < cutoff}


def _apply_keep_latest(
    artifacts: Iterable[Artifact], cfg: CleanupConfig
) -> dict[str, str]:
    """Group by name, keep the newest N per group."""
    if cfg.keep_latest_n_per_workflow is None:
        return {}
    by_name: dict[str, list[Artifact]] = {}
    for a in artifacts:
        by_name.setdefault(a.name, []).append(a)
    drop: dict[str, str] = {}
    for group in by_name.values():
        # Newest first.
        ordered = sorted(group, key=lambda a: a.created_at, reverse=True)
        for old in ordered[cfg.keep_latest_n_per_workflow:]:
            drop[old.id] = "keep_latest_n_per_workflow"
    return drop


def _apply_max_total_size(
    artifacts: Iterable[Artifact],
    cfg: CleanupConfig,
    already_dropped: set[str],
) -> dict[str, str]:
    """Among still-kept artifacts, evict oldest first until under the cap."""
    if cfg.max_total_size_bytes is None:
        return {}
    surviving = [a for a in artifacts if a.id not in already_dropped]
    total = sum(a.size_bytes for a in surviving)
    if total <= cfg.max_total_size_bytes:
        return {}
    # Evict oldest first.
    ordered = sorted(surviving, key=lambda a: a.created_at)
    drop: dict[str, str] = {}
    for a in ordered:
        if total <= cfg.max_total_size_bytes:
            break
        drop[a.id] = "max_total_size_bytes"
        total -= a.size_bytes
    return drop


def build_plan(
    artifacts: list[Artifact],
    cfg: CleanupConfig,
    now: datetime | None = None,
) -> CleanupPlan:
    """Apply all configured policies and return a plan.

    Order of evaluation (matters for the recorded reason):
        1. max_age_days
        2. keep_latest_n_per_workflow
        3. max_total_size_bytes (only considers artifacts not yet dropped,
           since size-based eviction is meaningless once the policy-violators
           are already gone).
    """
    if now is None:
        now = datetime.now(timezone.utc)

    drops: dict[str, str] = {}

    def _merge(new: dict[str, str]) -> None:
        for aid, reason in new.items():
            drops.setdefault(aid, reason)

    # Cheap policies first so size-based eviction sees the smallest possible
    # set of "already-condemned" artifacts and only drops what's still needed.
    _merge(_apply_max_age(artifacts, cfg, now))
    _merge(_apply_keep_latest(artifacts, cfg))
    _merge(_apply_max_total_size(artifacts, cfg, set(drops)))

    deletions: list[Deletion] = []
    retained: list[Artifact] = []
    for a in artifacts:
        if a.id in drops:
            deletions.append(Deletion(a.id, a.name, a.size_bytes, drops[a.id]))
        else:
            retained.append(a)

    summary = {
        "total_artifacts": len(artifacts),
        "deleted_count": len(deletions),
        "retained_count": len(retained),
        "space_reclaimed_bytes": sum(d.size_bytes for d in deletions),
        "space_retained_bytes": sum(a.size_bytes for a in retained),
        "dry_run": cfg.dry_run,
        "policies": {
            "max_age_days": cfg.max_age_days,
            "max_total_size_bytes": cfg.max_total_size_bytes,
            "keep_latest_n_per_workflow": cfg.keep_latest_n_per_workflow,
        },
    }
    return CleanupPlan(deletions=deletions, retained=retained, summary=summary)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
def render_summary(plan: CleanupPlan) -> str:
    s = plan.summary
    lines = []
    if s.get("dry_run"):
        lines.append("=== DRY RUN — no artifacts will actually be deleted ===")
    lines.append(
        f"Plan: {s['deleted_count']} deleted, {s['retained_count']} retained "
        f"(of {s['total_artifacts']} total)"
    )
    lines.append(
        f"Space: {s['space_reclaimed_bytes']} bytes reclaimed, "
        f"{s['space_retained_bytes']} bytes retained"
    )
    pol = s.get("policies", {})
    lines.append(
        "Policies: "
        f"max_age_days={pol.get('max_age_days')}, "
        f"max_total_size_bytes={pol.get('max_total_size_bytes')}, "
        f"keep_latest_n_per_workflow={pol.get('keep_latest_n_per_workflow')}"
    )
    if plan.deletions:
        lines.append("Deletions:")
        for d in plan.deletions:
            lines.append(
                f"  - {d.id} ({d.name}, {d.size_bytes} bytes) -> {d.reason}"
            )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Plan artifact cleanup based on retention policies.")
    p.add_argument("--input", required=True, type=Path, help="Path to artifacts JSON file.")
    p.add_argument("--max-age-days", type=int, default=None)
    p.add_argument("--max-total-size", type=int, default=None,
                   help="Cap on total size of retained artifacts (bytes).")
    p.add_argument("--keep-latest", type=int, default=None,
                   help="Keep only the N newest artifacts per name.")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--output", type=Path, default=None,
                   help="Write the plan as JSON here. If omitted, JSON goes to stdout.")
    p.add_argument("--now", type=str, default=None,
                   help="Override 'now' as ISO-8601. Used for deterministic tests.")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parse_args(argv)
        artifacts = load_artifacts(args.input)
        cfg = CleanupConfig(
            max_age_days=args.max_age_days,
            max_total_size_bytes=args.max_total_size,
            keep_latest_n_per_workflow=args.keep_latest,
            dry_run=args.dry_run,
        )
        now = _parse_iso(args.now) if args.now else None
        plan = build_plan(artifacts, cfg, now=now)

        # Human summary always to stderr so stdout stays parseable JSON.
        print(render_summary(plan), file=sys.stderr)

        plan_json = json.dumps(plan.to_dict(), indent=2, sort_keys=True)
        if args.output:
            args.output.write_text(plan_json + "\n")
        else:
            print(plan_json)
        return 0
    except CleanupError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
