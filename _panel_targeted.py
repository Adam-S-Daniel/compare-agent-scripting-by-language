#!/usr/bin/env python3
"""One-off panel-judge driver targeting only the missing caches the
combined report needs: `*-opus` subdirs in 2026-04-09_152435 (opus46)
and `*-sonnet46-1m-*` in 2026-04-17_004319 (sonnet46-1m). Skips any
(variant × judge × kind) triple whose cache file already exists.

Not intended for long-term use — delete after the combined-report
parity pass is complete.
"""
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from test_quality import (
    compute_structural_metrics,
    evaluate_run_llm,
    evaluate_run_deliverable_llm,
    _tests_cache_file,
    _deliverable_cache_file,
)

JUDGES = ("haiku45", "gemini31pro")
KINDS = ("test-quality", "deliverable-quality")


def _collect_work() -> list[tuple[Path, dict, dict, str, str]]:
    """Return (variant_dir, metrics, structural, judge, kind) tuples for
    every missing cache across the targeted subsets."""
    targets: list[Path] = []

    # Older v4 run: legacy `sonnet` / `opus` short names (display-rename
    # to sonnet46-200k / opus46-200k). Both need panel judges for the
    # combined-report Conclusions to interpret the cross-version tiers.
    old = Path("results/2026-04-09_152435")
    for p in old.glob("tasks/*/*"):
        if p.name.endswith("-opus") or p.name.endswith("-sonnet"):
            targets.append(p)

    work: list[tuple[Path, dict, dict, str, str]] = []
    for variant_dir in targets:
        mf = variant_dir / "metrics.json"
        if not mf.exists():
            continue
        try:
            metrics = json.loads(mf.read_text())
        except Exception:
            continue
        gen = variant_dir / "generated-code"
        structural = compute_structural_metrics(gen)
        for judge in JUDGES:
            for kind in KINDS:
                if kind == "test-quality":
                    cache_file = variant_dir / _tests_cache_file(judge)
                else:
                    cache_file = variant_dir / _deliverable_cache_file(judge)
                if cache_file.exists():
                    continue
                work.append((variant_dir, metrics, structural, judge, kind))
    return work


def _run_one(task):
    variant_dir, metrics, structural, judge, kind = task
    if kind == "test-quality":
        s = evaluate_run_llm(variant_dir, metrics, structural,
                             judge_short=judge, force=False)
    else:
        s = evaluate_run_deliverable_llm(variant_dir, metrics, structural,
                                         judge_short=judge, force=False)
    return (variant_dir.name, judge, kind, s is not None)


def main() -> int:
    work = _collect_work()
    total = len(work)
    print(f"Targeted panel driver: {total} missing (variant × judge × kind)",
          file=sys.stderr, flush=True)
    if not total:
        return 0
    done = 0
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(_run_one, t) for t in work]
        for f in as_completed(futures):
            variant_name, judge, kind, ok = f.result()
            done += 1
            status = "ok" if ok else "FAIL"
            if done % 5 == 0 or done == total or not ok:
                print(f"  [{done}/{total}] {status} {variant_name} "
                      f"{judge} {kind}", file=sys.stderr, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
