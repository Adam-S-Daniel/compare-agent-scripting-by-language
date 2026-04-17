#!/usr/bin/env python3
"""Combine metrics from multiple run directories into a single comparison
markdown at results/results_<dir1>__<dir2>[...].md.

Only tasks present in EVERY input dir are included, so aggregates are
apples-to-apples. This matters when inputs disagree on task coverage
(e.g. v4 has task 14 — archived everywhere else — whose inclusion would
distort v4's totals against newer runs that skip it).

Runs whose effort_level is null (pre-effort CLI flag, v1-v4) are annotated
with an inferred default (`medium` on Max subscription per Anthropic docs
at /en/model-config#adjust-effort-level) so they render alongside
effort-tagged runs in the grouping.

Usage:
    python3 combine_results.py results/2026-04-17_004319 results/2026-04-09_152435
"""
import sys
import json
from datetime import datetime
from pathlib import Path
from collections import defaultdict
from zoneinfo import ZoneInfo


def load_run_metrics(run_dir: Path) -> list[dict]:
    """Load all metrics.json under run_dir/tasks/*/*/metrics.json."""
    out: list[dict] = []
    for mf in sorted(run_dir.glob("tasks/*/*/metrics.json")):
        try:
            out.append(json.loads(mf.read_text()))
        except Exception:
            pass
    return out


def intersect_task_ids(metrics_lists: list[list[dict]]) -> set[str]:
    """Task IDs present in every input list."""
    if not metrics_lists:
        return set()
    sets = [set(m["task_id"] for m in lst) for lst in metrics_lists]
    return set.intersection(*sets)


def filter_to_tasks(metrics: list[dict], task_ids: set[str]) -> list[dict]:
    """Return only metrics whose task_id is in `task_ids`."""
    return [m for m in metrics if m["task_id"] in task_ids]


def infer_default_effort(m: dict, inferred_default: str = "medium") -> dict:
    """Return a copy of m with effort_level set to `inferred_default` when
    the original is null/empty. Pre-effort runs (v1-v4) came from CLI
    versions that didn't record effort; on a Max subscription the effective
    default was `medium` (see Anthropic's model-config docs)."""
    if not m.get("effort_level"):
        out = dict(m)
        out["effort_level"] = inferred_default
        return out
    return m


def _label(m: dict) -> str:
    """Variant label combining model_short with effort_level. Matches the
    identifier used by generate_results.py so a reader comparing the two
    reports sees the same strings."""
    eff = m.get("effort_level")
    return f"{m['model_short']}-{eff}" if eff else m["model_short"]


def aggregate_rows(metrics: list[dict]) -> list[dict]:
    """Group by (language_mode, model_short, effort_level) and average the
    per-run values. Each row captures one (language, model, effort) combo."""
    by_key: dict[tuple, list[dict]] = defaultdict(list)
    for m in metrics:
        by_key[(m["language_mode"], m["model_short"], m.get("effort_level"))].append(m)
    rows = []
    for (mode, model, effort), mm in sorted(by_key.items()):
        n = len(mm)
        if n == 0:
            continue
        rows.append({
            "mode": mode,
            "model": model,
            "effort": effort,
            "variant": f"{model}-{effort}" if effort else model,
            "n": n,
            "avg_dur": sum(m["timing"]["grand_total_duration_ms"] for m in mm) / n / 1000,
            "avg_errors": sum(m["quality"]["error_count"] for m in mm) / n,
            "avg_turns": sum(m["timing"]["num_turns"] for m in mm) / n,
            "avg_cost": sum(m["cost"]["total_cost_usd"] for m in mm) / n,
            "total_cost": sum(m["cost"]["total_cost_usd"] for m in mm),
            "avg_lines": sum(m["code_metrics"]["total_lines"] for m in mm) / n,
        })
    return rows


def _dur(seconds: float) -> str:
    return f"{seconds/60:.1f}min"


def _load_llm_scores(run_dirs: list[Path]) -> dict[tuple, float]:
    """Map (run_dir_name, task_id, mode, variant_label) → Overall score."""
    scores = {}
    for rd in run_dirs:
        for cache in rd.glob("tasks/*/*/test-quality-llm.json"):
            try:
                data = json.loads(cache.read_text())
            except Exception:
                continue
            ovr = data.get("overall")
            if not isinstance(ovr, (int, float)):
                continue
            # task_id and variant are in the path: .../tasks/<task>/<mode>-<variant>/
            parts = cache.parts
            task_id = parts[-3]
            mode_variant = parts[-2]
            scores[(rd.name, task_id, mode_variant)] = float(ovr)
    return scores


def _build_markdown(
    run_dirs: list[Path],
    annotated: list[dict],
    common: set[str],
    dropped: dict[str, set[str]],
    inferred_default: str,
    llm_scores: dict[tuple, float],
) -> str:
    et = ZoneInfo("America/New_York")
    now = datetime.now(et).strftime("%Y-%m-%d %I:%M:%S %p ET")
    lines: list[str] = []
    lines.append("# Combined Benchmark Results")
    lines.append("")
    lines.append(f"**Last updated:** {now}")
    lines.append("")
    lines.append("**Source run directories:**")
    for rd in run_dirs:
        lines.append(f"- `{rd.name}`")
    lines.append("")

    lines.append("## Scope")
    lines.append("")
    lines.append("Only tasks present in every source directory are included so aggregate averages and totals are apples-to-apples.")
    lines.append(f"- **Common tasks kept:** {len(common)}")
    if common:
        lines.append(f"  - IDs: {', '.join(sorted(common))}")
    total_dropped = {t for ids in dropped.values() for t in ids}
    if total_dropped:
        lines.append(f"- **Dropped (not in every source dir):** {', '.join(sorted(total_dropped))}")
        for name, ids in dropped.items():
            if ids:
                lines.append(f"  - `{name}` contributed but was dropped for: {', '.join(sorted(ids))}")
    lines.append(f"- **Pre-effort runs annotated as:** `{inferred_default}` (Max-subscription CLI default per Anthropic docs)")
    lines.append("")

    if not common:
        lines.append("## No tasks in common")
        lines.append("")
        lines.append("The input directories share no tasks, so there is nothing to compare. Add more overlap and re-run.")
        return "\n".join(lines) + "\n"

    rows = aggregate_rows(annotated)

    # Attach avg LLM score (Overall) per variant, if judge data is available.
    # Build a by-variant list of scores.
    scores_by_variant: dict[tuple, list[float]] = defaultdict(list)
    for m in annotated:
        key = (m.get("source_run_dir"), m["task_id"], m.get("original_subdir", f"{m['language_mode']}-{_label(m)}"))
        if key in llm_scores:
            scores_by_variant[(m["language_mode"], _label(m))].append(llm_scores[key])
    for r in rows:
        vkey = (r["mode"], r["variant"])
        if scores_by_variant[vkey]:
            scores = scores_by_variant[vkey]
            r["avg_llm"] = sum(scores) / len(scores)
            r["avg_llm_n"] = len(scores)
        else:
            r["avg_llm"] = 0.0
            r["avg_llm_n"] = 0
        r["avg_llm_disp"] = f"{r['avg_llm']:.1f}" if r["avg_llm_n"] > 0 else "—"

    # ── Rankings ──
    lines.append("## Rankings by Language/Model/Effort")
    lines.append("")
    lines.append("*Lower rank = better on that axis (1 = fastest / cheapest / highest LLM score).*")
    lines.append("*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*")
    lines.append("")
    dur_rank = {id(r): i + 1 for i, r in enumerate(sorted(rows, key=lambda r: r["avg_dur"]))}
    cost_rank = {id(r): i + 1 for i, r in enumerate(sorted(rows, key=lambda r: r["avg_cost"]))}
    llm_scored = [r for r in rows if r["avg_llm_n"] > 0]
    llm_rank = {id(r): i + 1 for i, r in enumerate(sorted(llm_scored, key=lambda r: -r["avg_llm"]))}
    lines.append("| Language | Model | Duration | Cost | LLM Score |")
    lines.append("|----------|-------|----------|------|-----------|")
    for r in sorted(rows, key=lambda r: (r["mode"], r["variant"])):
        llm_cell = str(llm_rank[id(r)]) if id(r) in llm_rank else "—"
        lines.append(f"| {r['mode']} | {r['variant']} | {dur_rank[id(r)]} | {cost_rank[id(r)]} | {llm_cell} |")
    lines.append("")

    # ── Comparison ──
    lines.append("## Comparison by Language/Model/Effort")
    lines.append("")
    lines.append("*Avg LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*")
    lines.append("")
    lines.append("| Language | Model | Runs | Avg Duration | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |")
    lines.append("|----------|-------|------|--------------|------------|-----------|----------|------------|---------------|")
    for r in sorted(rows, key=lambda r: (r["mode"], r["variant"])):
        lines.append(
            f"| {r['mode']} | {r['variant']} | {r['n']} | {_dur(r['avg_dur'])} "
            f"| {r['avg_errors']:.1f} | {r['avg_turns']:.0f} "
            f"| ${r['avg_cost']:.2f} | ${r['total_cost']:.2f} | {r['avg_llm_disp']} |"
        )
    lines.append("")

    # ── Per-Run (sorted by task, language, model) ──
    lines.append("## Per-Run Results")
    lines.append("")
    lines.append("*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*")
    lines.append("")
    lines.append("| Task | Language | Model | Source | Duration | Turns | Errors | Cost | LLM Score |")
    lines.append("|------|----------|-------|--------|----------|-------|--------|------|-----------|")
    pr_rows = []
    for m in annotated:
        key = (m.get("source_run_dir"), m["task_id"], m.get("original_subdir", f"{m['language_mode']}-{_label(m)}"))
        score = llm_scores.get(key)
        pr_rows.append({
            "task": m["task_name"][:34],
            "task_id": m["task_id"],
            "mode": m["language_mode"],
            "variant": _label(m),
            "source": m.get("source_run_dir", ""),
            "dur": m["timing"]["grand_total_duration_ms"] / 1000,
            "turns": m["timing"]["num_turns"],
            "errors": m["quality"]["error_count"],
            "cost": m["cost"]["total_cost_usd"],
            "llm_disp": f"{score:.1f}" if isinstance(score, (int, float)) else "—",
        })
    for r in sorted(pr_rows, key=lambda r: (r["task_id"], r["mode"], r["variant"], r["source"])):
        lines.append(
            f"| {r['task']} | {r['mode']} | {r['variant']} | {r['source']} "
            f"| {_dur(r['dur'])} | {r['turns']} | {r['errors']} "
            f"| ${r['cost']:.2f} | {r['llm_disp']} |"
        )
    lines.append("")

    return "\n".join(lines) + "\n"


def combine(run_dirs: list[Path], output_path: Path,
            inferred_default_effort: str = "medium") -> dict:
    """Combine metrics from run_dirs; write combined markdown to output_path.

    Returns a summary dict:
      - common_task_ids: set[str]
      - dropped: {run_dir_name -> set[task_ids dropped from that dir]}
      - n_by_dir: {run_dir_name -> metric count after intersection}
    """
    metrics_lists = [load_run_metrics(d) for d in run_dirs]
    common = intersect_task_ids(metrics_lists)

    dropped: dict[str, set[str]] = {}
    for d, ms in zip(run_dirs, metrics_lists):
        all_ids = set(m["task_id"] for m in ms)
        dropped[d.name] = all_ids - common

    annotated: list[dict] = []
    for d, ms in zip(run_dirs, metrics_lists):
        filtered = filter_to_tasks(ms, common)
        for m in filtered:
            # Capture the on-disk subdir name BEFORE effort annotation so
            # downstream LLM-cache lookups resolve to real files. v4-era
            # metrics live at `<mode>-<model>/` (no effort suffix) even
            # after we annotate `effort_level=medium` for display.
            original_variant = _label(m)
            a = infer_default_effort(m, inferred_default_effort)
            a["source_run_dir"] = d.name
            a["original_subdir"] = f"{m['language_mode']}-{original_variant}"
            annotated.append(a)

    llm_scores = _load_llm_scores(run_dirs)
    md = _build_markdown(run_dirs, annotated, common, dropped,
                         inferred_default_effort, llm_scores)
    output_path.write_text(md)

    return {
        "common_task_ids": common,
        "dropped": dropped,
        "n_by_dir": {d.name: sum(1 for m in annotated if m.get("source_run_dir") == d.name)
                     for d in run_dirs},
        "output_path": output_path,
    }


def _default_output_path(repo_root: Path, run_dirs: list[Path]) -> Path:
    names = "__".join(d.name for d in run_dirs)
    return repo_root / "results" / f"results_{names}.md"


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: combine_results.py <run_dir1> <run_dir2> [<run_dir3> ...]",
              file=sys.stderr)
        return 1
    repo_root = Path(__file__).parent.resolve()
    run_dirs: list[Path] = []
    for arg in sys.argv[1:]:
        p = Path(arg)
        if not p.is_absolute():
            p = (repo_root / p).resolve()
        if not p.is_dir():
            print(f"error: {p} is not a directory", file=sys.stderr)
            return 1
        run_dirs.append(p)
    out = _default_output_path(repo_root, run_dirs)
    summary = combine(run_dirs, out)
    print(f"Wrote {out}")
    print(f"  Common tasks: {len(summary['common_task_ids'])}")
    for name, ids in summary["dropped"].items():
        if ids:
            print(f"  Dropped from {name}: {sorted(ids)}")
    for name, n in summary["n_by_dir"].items():
        print(f"  Metrics from {name}: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
