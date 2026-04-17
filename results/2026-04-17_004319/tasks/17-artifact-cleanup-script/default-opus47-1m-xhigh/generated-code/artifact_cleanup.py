"""
artifact_cleanup — apply retention policies to a list of artifacts and
generate a deletion plan with a summary.

The module is split into three layers:

1.  `RetentionPolicy`   — a plain dataclass describing the retention rules.
2.  `DeletionPlan`      — the result of applying a policy to a list of
                           artifacts: which get deleted, which get kept,
                           plus a summary and an `apply()` method that
                           can optionally run in dry-run mode.
3.  `build_deletion_plan()` — the pure function that evaluates the rules.
4.  `main()` CLI        — reads a JSON file of artifacts, prints the plan
                           as either human-readable text or JSON.

Each retention rule is evaluated independently; an artifact is deleted if
any rule selects it. This "union of deletions" semantics means policies
compose safely and a more aggressive rule cannot be overridden by a more
lenient one.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Iterable


# ---------------------------------------------------------------------------
# Policy
# ---------------------------------------------------------------------------


@dataclass
class RetentionPolicy:
    """Retention rules. All fields optional; `None` means rule disabled."""

    max_age_days: int | None = None
    max_total_size_bytes: int | None = None
    keep_latest_n_per_workflow: int | None = None

    def __post_init__(self) -> None:
        if self.max_age_days is not None and self.max_age_days < 0:
            raise ValueError("max_age_days must be >= 0")
        if self.max_total_size_bytes is not None and self.max_total_size_bytes < 0:
            raise ValueError("max_total_size_bytes must be >= 0")
        if (
            self.keep_latest_n_per_workflow is not None
            and self.keep_latest_n_per_workflow < 0
        ):
            raise ValueError("keep_latest_n_per_workflow must be >= 0")


# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------


@dataclass
class DeletionPlan:
    """The result of applying a policy to a list of artifacts."""

    to_delete: list[dict[str, Any]] = field(default_factory=list)
    to_retain: list[dict[str, Any]] = field(default_factory=list)
    reasons: dict[int, list[str]] = field(default_factory=dict)

    def summary(self) -> dict[str, int]:
        return {
            "artifacts_total": len(self.to_delete) + len(self.to_retain),
            "artifacts_retained": len(self.to_retain),
            "artifacts_deleted": len(self.to_delete),
            "bytes_reclaimed": sum(a["size_bytes"] for a in self.to_delete),
            "bytes_retained": sum(a["size_bytes"] for a in self.to_retain),
        }

    def apply(
        self,
        deleter: Callable[[dict[str, Any]], None],
        dry_run: bool = True,
    ) -> None:
        """Invoke `deleter` once per deletion candidate, unless dry-run."""
        if dry_run:
            return
        for artifact in self.to_delete:
            deleter(artifact)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


_REQUIRED_FIELDS = ("name", "size_bytes", "created_at", "workflow_run_id")


def _validate(artifacts: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    """Ensure each artifact has the fields we need; normalize created_at."""
    out: list[dict[str, Any]] = []
    for i, a in enumerate(artifacts):
        for field_name in _REQUIRED_FIELDS:
            if field_name not in a:
                raise ValueError(
                    f"artifact {i} missing required field '{field_name}'"
                )
        # Normalize created_at to a timezone-aware datetime for safe comparison.
        created = a["created_at"]
        if isinstance(created, str):
            # fromisoformat on 3.11+ handles "Z" timezone suffix.
            try:
                dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
            except ValueError as exc:
                raise ValueError(
                    f"artifact {i} has invalid created_at: {created!r}"
                ) from exc
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            a = {**a, "_created_dt": dt}
        elif isinstance(created, datetime):
            dt = created if created.tzinfo else created.replace(tzinfo=timezone.utc)
            a = {**a, "_created_dt": dt}
        else:
            raise ValueError(
                f"artifact {i} created_at must be str or datetime, got {type(created).__name__}"
            )
        if a["size_bytes"] < 0:
            raise ValueError(f"artifact {i} size_bytes must be >= 0")
        out.append(a)
    return out


# ---------------------------------------------------------------------------
# Policy evaluation
# ---------------------------------------------------------------------------


def build_deletion_plan(
    artifacts: Iterable[dict[str, Any]],
    policy: RetentionPolicy,
    now: datetime | None = None,
) -> DeletionPlan:
    """
    Evaluate each rule independently and take the union of deletion candidates.

    A rule-by-rule pass produces a set of IDs marked for deletion. Anything
    not in that set is retained, in the same order as the input.
    """
    if now is None:
        now = datetime.now(timezone.utc)
    elif now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)

    validated = _validate(artifacts)

    # Stable identity for each artifact. `id` is the canonical field when
    # present; otherwise fall back to its positional index.
    def _key(a: dict[str, Any], idx: int) -> Any:
        return a.get("id", f"idx:{idx}")

    to_delete_ids: set[Any] = set()
    reasons: dict[Any, list[str]] = {}

    def mark(a: dict[str, Any], idx: int, reason: str) -> None:
        k = _key(a, idx)
        to_delete_ids.add(k)
        reasons.setdefault(k, []).append(reason)

    # --- Rule 1: max_age_days ------------------------------------------------
    if policy.max_age_days is not None:
        cutoff = now - timedelta(days=policy.max_age_days)
        for idx, a in enumerate(validated):
            if a["_created_dt"] < cutoff:
                mark(a, idx, f"older than {policy.max_age_days}d")

    # --- Rule 2: keep_latest_n_per_workflow ---------------------------------
    # Group by `name` (the workflow/artifact family), sort each group newest
    # first, keep the first N, mark the rest for deletion.
    if policy.keep_latest_n_per_workflow is not None:
        groups: dict[str, list[tuple[int, dict[str, Any]]]] = {}
        for idx, a in enumerate(validated):
            groups.setdefault(a["name"], []).append((idx, a))
        for name, members in groups.items():
            members.sort(key=lambda pair: pair[1]["_created_dt"], reverse=True)
            for (idx, a) in members[policy.keep_latest_n_per_workflow:]:
                mark(a, idx, f"beyond keep-latest-{policy.keep_latest_n_per_workflow}")

    # --- Rule 3: max_total_size_bytes ---------------------------------------
    # Walk newest-first summing sizes; once the running total would exceed
    # the cap, mark every remaining (older) artifact for deletion. This
    # preserves the freshest data up to the budget.
    if policy.max_total_size_bytes is not None:
        ordered = sorted(
            enumerate(validated),
            key=lambda pair: pair[1]["_created_dt"],
            reverse=True,
        )
        running = 0
        for idx, a in ordered:
            if running + a["size_bytes"] > policy.max_total_size_bytes:
                mark(a, idx, f"would exceed size cap {policy.max_total_size_bytes}")
            else:
                running += a["size_bytes"]

    # --- Assemble plan ------------------------------------------------------
    to_delete: list[dict[str, Any]] = []
    to_retain: list[dict[str, Any]] = []
    plan_reasons: dict[int, list[str]] = {}
    for idx, a in enumerate(validated):
        clean = {k: v for k, v in a.items() if not k.startswith("_")}
        k = _key(a, idx)
        if k in to_delete_ids:
            to_delete.append(clean)
            plan_reasons[clean["id"]] = reasons.get(k, [])
        else:
            to_retain.append(clean)
    return DeletionPlan(to_delete=to_delete, to_retain=to_retain, reasons=plan_reasons)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _format_human(plan: DeletionPlan, dry_run: bool) -> str:
    lines: list[str] = []
    mode = "DRY RUN" if dry_run else "APPLY"
    lines.append(f"=== Artifact cleanup plan [{mode}] ===")
    s = plan.summary()
    lines.append(f"  total:     {s['artifacts_total']}")
    lines.append(f"  retained:  {s['artifacts_retained']} ({s['bytes_retained']:,} bytes)")
    lines.append(f"  to delete: {s['artifacts_deleted']} ({s['bytes_reclaimed']:,} bytes reclaimed)")
    if plan.to_delete:
        lines.append("")
        lines.append("Artifacts to delete:")
        for a in plan.to_delete:
            reason = ", ".join(plan.reasons.get(a["id"], []))
            lines.append(
                f"  - id={a['id']} name={a['name']} size={a['size_bytes']:,}B reason=[{reason}]"
            )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Apply retention policies to GitHub Actions artifacts."
    )
    parser.add_argument("--input", "-i", required=True, help="JSON file of artifacts")
    parser.add_argument("--max-age-days", type=int, default=None)
    parser.add_argument("--max-total-size-bytes", type=int, default=None)
    parser.add_argument("--keep-latest-n", type=int, default=None)
    parser.add_argument("--dry-run", action="store_true", help="Default mode")
    parser.add_argument("--apply", action="store_true", help="Actually delete")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable output")
    parser.add_argument(
        "--now",
        default=None,
        help="ISO-8601 timestamp to treat as 'now' (for deterministic runs)",
    )
    args = parser.parse_args(argv)

    if args.apply and args.dry_run:
        print("error: --dry-run and --apply are mutually exclusive", file=sys.stderr)
        return 2

    dry_run = not args.apply

    try:
        with open(args.input, "r", encoding="utf-8") as fh:
            artifacts = json.load(fh)
    except FileNotFoundError:
        print(f"error: input file not found: {args.input}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print(f"error: invalid JSON in {args.input}: {exc}", file=sys.stderr)
        return 2

    if not isinstance(artifacts, list):
        print("error: input must be a JSON list of artifacts", file=sys.stderr)
        return 2

    try:
        policy = RetentionPolicy(
            max_age_days=args.max_age_days,
            max_total_size_bytes=args.max_total_size_bytes,
            keep_latest_n_per_workflow=args.keep_latest_n,
        )
    except ValueError as exc:
        print(f"error: invalid policy: {exc}", file=sys.stderr)
        return 2

    now = (
        datetime.fromisoformat(args.now.replace("Z", "+00:00"))
        if args.now
        else datetime.now(timezone.utc)
    )

    try:
        plan = build_deletion_plan(artifacts, policy, now=now)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.json:
        payload = {
            "dry_run": dry_run,
            "summary": plan.summary(),
            "to_delete": plan.to_delete,
            "to_retain": plan.to_retain,
            "reasons": plan.reasons,
        }
        print(json.dumps(payload, indent=2, default=str))
    else:
        print(_format_human(plan, dry_run))

    return 0


if __name__ == "__main__":
    sys.exit(main())
