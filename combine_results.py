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

# Reuse the collapsible-sort helpers from generate_results so the
# rankings/comparison tables here share the same look-and-feel (single
# source of truth for how <details> blocks render).
from generate_results import (  # noqa: E402
    _collapsible_table, _emit_sorted_variants, _ratio_tier, _llm_tier,
    _tier_num,
)


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


_DISPLAY_RENAME = {"opus": "opus46", "sonnet": "sonnet46"}


def _path_label(m: dict) -> str:
    """On-disk subdir label — exact filesystem path component, no rename."""
    eff = m.get("effort_level")
    return f"{m['model_short']}-{eff}" if eff else m["model_short"]


def _label(m: dict) -> str:
    """Display label used for grouping and the Model column in tables.
    Applies _DISPLAY_RENAME so legacy `opus`/`sonnet` (pre-effort CLI,
    resolving to 4.6 in this repo's history) read as `opus46`/`sonnet46`
    alongside explicit `opus47-1m-*` entries. Matches generate_results.py."""
    eff = m.get("effort_level")
    short = _DISPLAY_RENAME.get(m["model_short"], m["model_short"])
    return f"{short}-{eff}" if eff else short


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
        display_model = _DISPLAY_RENAME.get(model, model)
        rows.append({
            "mode": mode,
            "model": display_model,
            "effort": effort,
            "variant": f"{display_model}-{effort}" if effort else display_model,
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

    # Compute rank + tier once; the Tiers and Rankings sections reuse them.
    for i, r in enumerate(sorted(rows, key=lambda r: r["avg_dur"]), start=1):
        r["dur_rank"] = i
    for i, r in enumerate(sorted(rows, key=lambda r: r["avg_cost"]), start=1):
        r["cost_rank"] = i
    llm_scored = [r for r in rows if r["avg_llm_n"] > 0]
    for i, r in enumerate(sorted(llm_scored, key=lambda r: -r["avg_llm"]), start=1):
        r["llm_rank"] = i
    _llm_sentinel = len(rows) + 1
    for r in rows:
        r.setdefault("llm_rank", _llm_sentinel)
        r["llm_rank_disp"] = str(r["llm_rank"]) if r["llm_rank"] != _llm_sentinel else "—"
    best_dur = min(r["avg_dur"] for r in rows)
    best_cost = min(r["avg_cost"] for r in rows)
    for r in rows:
        r["dur_tier"] = _ratio_tier(r["avg_dur"] / best_dur)
        r["cost_tier"] = _ratio_tier(r["avg_cost"] / best_cost)
        r["llm_tier"] = _llm_tier(r["avg_llm"]) if r["avg_llm_n"] > 0 else "—"

    # ── Tiers (bin by value so gap-vs-cluster is visible at a glance) ──
    lines.append("## Tiers by Language/Model/Effort")
    lines.append("")
    lines.append("*Duration / Cost tier = ratio of this combo's average to the best combo's "
                 "average on that axis (lower ratio = better). Bands: "
                 "**A** ≤1.15×, **B** ≤1.40×, **C** ≤1.80×, **D** ≤2.50×, **E** >2.50×.*")
    lines.append("*LLM Score tier = absolute Overall score band. "
                 "**A** ≥4.5, **B** ≥3.5, **C** ≥2.5, **D** ≥1.5, **E** <1.5, `—` = no data.*")
    lines.append("*If every row in a column is tier A, those combos are effectively tied on that axis.*")
    lines.append("")
    tr_hdr = "| Language | Model | Duration | Cost | LLM Score |"
    tr_sep = "|----------|-------|----------|------|-----------|"
    def _fmt_tr(r):
        return (f"| {r['mode']} | {r['variant']} "
                f"| {r['dur_tier']} ({_dur(r['avg_dur'])}) "
                f"| {r['cost_tier']} (${r['avg_cost']:.2f}) "
                f"| {r['llm_tier']}"
                + (f" ({r['avg_llm']:.1f})" if r['avg_llm_n'] > 0 else "")
                + " |")
    lines.append(tr_hdr)
    lines.append(tr_sep)
    for r in sorted(rows, key=lambda r: (r["mode"], r["variant"])):
        lines.append(_fmt_tr(r))
    lines.append("")
    # Sort variants for Tiers. Primary = sorted-on axis; secondary =
    # average numeric tier of the OTHER two axes, so ties on primary
    # break toward the combo that is stronger overall.
    lines.extend(_emit_sorted_variants(tr_hdr, tr_sep, rows, [
        ("Sorted by Duration tier (A-first), then avg of Cost/LLM tiers",
         lambda r: (_tier_num(r["dur_tier"]),
                    (_tier_num(r["cost_tier"]) + _tier_num(r["llm_tier"])) / 2),
         False),
        ("Sorted by Cost tier (A-first), then avg of Duration/LLM tiers",
         lambda r: (_tier_num(r["cost_tier"]),
                    (_tier_num(r["dur_tier"]) + _tier_num(r["llm_tier"])) / 2),
         False),
        ("Sorted by LLM Score tier (A-first; no-data last), then avg of Duration/Cost tiers",
         lambda r: (_tier_num(r["llm_tier"]),
                    (_tier_num(r["dur_tier"]) + _tier_num(r["cost_tier"])) / 2),
         False),
    ], _fmt_tr))
    lines.append("")

    # ── Rankings ──
    lines.append("## Rankings by Language/Model/Effort")
    lines.append("")
    lines.append("*Lower rank = better on that axis (1 = fastest / cheapest / highest LLM score).*")
    lines.append("*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*")
    lines.append("")
    rk_hdr = "| Language | Model | Duration | Cost | LLM Score |"
    rk_sep = "|----------|-------|----------|------|-----------|"
    def _fmt_rk(r):
        return f"| {r['mode']} | {r['variant']} | {r['dur_rank']} | {r['cost_rank']} | {r['llm_rank_disp']} |"
    lines.append(rk_hdr)
    lines.append(rk_sep)
    for r in sorted(rows, key=lambda r: (r["mode"], r["variant"])):
        lines.append(_fmt_rk(r))
    lines.append("")
    lines.extend(_emit_sorted_variants(rk_hdr, rk_sep, rows, [
        ("Sorted by Duration rank (fastest first)", "dur_rank", False),
        ("Sorted by Cost rank (cheapest first)", "cost_rank", False),
        ("Sorted by LLM Score rank (best first; no-data last)", "llm_rank", False),
    ], _fmt_rk))
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
            # Capture the on-disk subdir name BEFORE effort annotation AND
            # before the _label display rename so downstream LLM-cache
            # lookups resolve to real files. v4-era metrics live at
            # `<mode>-<model>/` (plain short name, no effort suffix)
            # regardless of how we render them in tables.
            a = infer_default_effort(m, inferred_default_effort)
            a["source_run_dir"] = d.name
            a["original_subdir"] = f"{m['language_mode']}-{_path_label(m)}"
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
